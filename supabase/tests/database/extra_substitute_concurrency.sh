#!/usr/bin/env bash
set -euo pipefail

db_container="${SUPABASE_DB_CONTAINER:-supabase_db_Innebandy}"
coach_id="d1000000-0000-4000-8000-000000000001"
team_id="d2000000-0000-4000-8000-000000000001"
season_id="d3000000-0000-4000-8000-000000000001"
regular_id="d4000000-0000-4000-8000-000000000001"
extra_id="d4000000-0000-4000-8000-000000000002"
match_id="d5000000-0000-4000-8000-000000000001"
request_id="d6000000-0000-4000-8000-000000000001"
result_dir="$(mktemp -d)"

cleanup_db() {
  docker exec -i "$db_container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 >/dev/null <<SQL
delete from public.match_players where team_id = '$team_id';
delete from public.matches where team_id = '$team_id';
delete from public.players where team_id = '$team_id';
delete from public.seasons where team_id = '$team_id';
delete from public.team_members where team_id = '$team_id';
delete from public.teams where id = '$team_id';
delete from auth.users where id = '$coach_id';
SQL
}
cleanup() { cleanup_db; rm -rf "$result_dir"; }
trap cleanup EXIT
cleanup_db

docker exec -i "$db_container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 >/dev/null <<SQL
insert into auth.users (id, email) values ('$coach_id', 'extra-concurrency@example.test');
insert into public.teams (id, name, slug) values ('$team_id', 'Extra concurrency', 'extra-concurrency');
insert into public.team_members (team_id, user_id) values ('$team_id', '$coach_id');
insert into public.seasons (id, team_id, name, starts_on, ends_on) values ('$season_id', '$team_id', 'Season', '2026-08-01', '2027-05-31');
insert into public.players (id, team_id, season_id, first_name, level, rotation_order) values
  ('$regular_id', '$team_id', '$season_id', 'Regular', 1, 1),
  ('$extra_id', '$team_id', '$season_id', 'Extra', 2, 2);
insert into public.matches (id, team_id, season_id, opponent, starts_at, target_players, request_id)
values ('$match_id', '$team_id', '$season_id', 'Opponent', '2027-03-01 10:00+00', 1, '$request_id');
insert into public.match_players (team_id, season_id, match_id, player_id, selection_type, selection_source, selection_status)
values ('$team_id', '$season_id', '$match_id', '$regular_id', 'regular', 'automatic', 'selected');
SQL

fingerprint() {
  docker exec -i "$db_container" psql -U postgres -d postgres -Atq -v ON_ERROR_STOP=1 <<SQL
begin;
set local role authenticated;
set local request.jwt.claim.sub = '$coach_id';
select public.get_extra_substitute_source('$team_id', '$season_id', '$match_id') ->> 'fingerprint';
rollback;
SQL
}

add_fp="$(fingerprint)"
docker exec -i "$db_container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 >"$result_dir/add-first" 2>&1 <<SQL &
begin;
set application_name = 'extra_add_first';
set local role service_role;
set local request.jwt.claims = '{"role":"service_role"}';
select public.add_extra_substitute('$coach_id','$team_id','$season_id','$match_id','$extra_id','$add_fp');
select pg_sleep(2);
commit;
SQL
first_pid=$!

for _ in {1..50}; do
  ready="$(docker exec -i "$db_container" psql -U postgres -d postgres -Atq -c "select count(*) from pg_stat_activity where application_name='extra_add_first' and state='active' and query like 'select pg_sleep%';")"
  [[ "$ready" == "1" ]] && break
  sleep 0.05
done
[[ "${ready:-0}" == "1" ]] || { echo "First add never reached synchronization point."; exit 1; }

docker exec -i "$db_container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 >"$result_dir/add-second" 2>&1 <<SQL
begin;
set local role service_role;
set local request.jwt.claims = '{"role":"service_role"}';
select public.add_extra_substitute('$coach_id','$team_id','$season_id','$match_id','$extra_id','$add_fp');
commit;
SQL
wait "$first_pid"

row_count="$(docker exec -i "$db_container" psql -U postgres -d postgres -Atq -c "select count(*) from public.match_players where match_id='$match_id' and player_id='$extra_id';")"
[[ "$row_count" == "1" ]] || { echo "Concurrent add created an invalid row count."; exit 1; }

remove_fp="$(fingerprint)"
docker exec -i "$db_container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 >"$result_dir/remove-first" 2>&1 <<SQL &
begin;
set application_name = 'extra_remove_first';
set local role service_role;
set local request.jwt.claims = '{"role":"service_role"}';
select public.remove_extra_substitute('$coach_id','$team_id','$season_id','$match_id','$extra_id','$remove_fp');
select pg_sleep(2);
commit;
SQL
remove_pid=$!

for _ in {1..50}; do
  remove_ready="$(docker exec -i "$db_container" psql -U postgres -d postgres -Atq -c "select count(*) from pg_stat_activity where application_name='extra_remove_first' and state='active' and query like 'select pg_sleep%';")"
  [[ "$remove_ready" == "1" ]] && break
  sleep 0.05
done
[[ "${remove_ready:-0}" == "1" ]] || { echo "Remove never reached synchronization point."; exit 1; }

set +e
docker exec -i "$db_container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 >"$result_dir/add-during-remove" 2>&1 <<SQL
begin;
set local role service_role;
set local request.jwt.claims = '{"role":"service_role"}';
select public.add_extra_substitute('$coach_id','$team_id','$season_id','$match_id','$extra_id','$remove_fp');
commit;
SQL
add_during_remove_status=$?
set -e
wait "$remove_pid"

if [[ "$add_during_remove_status" -eq 0 ]] || ! rg -q "STALE_SELECTION" "$result_dir/add-during-remove"; then
  echo "Add racing with remove did not stop as stale."
  exit 1
fi
final_count="$(docker exec -i "$db_container" psql -U postgres -d postgres -Atq -c "select count(*) from public.match_players where match_id='$match_id' and player_id='$extra_id';")"
[[ "$final_count" == "0" ]] || { echo "Add/remove race left a lost update."; exit 1; }
echo "Concurrent extra operations serialize without duplicates or lost updates."
