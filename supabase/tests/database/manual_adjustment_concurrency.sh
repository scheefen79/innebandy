#!/usr/bin/env bash
set -euo pipefail

db_container="${SUPABASE_DB_CONTAINER:-supabase_db_Innebandy}"
coach_id="b1000000-0000-4000-8000-000000000001"
team_id="b2000000-0000-4000-8000-000000000001"
season_id="b3000000-0000-4000-8000-000000000001"
outgoing="b4000000-0000-4000-8000-000000000001"
incoming_one="b4000000-0000-4000-8000-000000000002"
incoming_two="b4000000-0000-4000-8000-000000000003"
match_id="b5000000-0000-4000-8000-000000000001"
request_id="b6000000-0000-4000-8000-000000000001"
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
insert into auth.users (id, email) values ('$coach_id', 'manual-concurrency@example.test');
insert into public.teams (id, name, slug) values ('$team_id', 'Manual concurrency', 'manual-concurrency');
insert into public.team_members (team_id, user_id) values ('$team_id', '$coach_id');
insert into public.seasons (id, team_id, name, starts_on, ends_on) values ('$season_id', '$team_id', 'Season', '2026-08-01', '2027-05-31');
insert into public.players (id, team_id, season_id, first_name, level, rotation_order) values
  ('$outgoing', '$team_id', '$season_id', 'Outgoing', 1, 1),
  ('$incoming_one', '$team_id', '$season_id', 'Incoming one', 2, 2),
  ('$incoming_two', '$team_id', '$season_id', 'Incoming two', 3, 3);
insert into public.matches (id, team_id, season_id, opponent, starts_at, target_players, request_id)
values ('$match_id', '$team_id', '$season_id', 'Opponent', '2027-03-01 10:00+00', 1, '$request_id');
insert into public.match_players (team_id, season_id, match_id, player_id, selection_type, selection_source, selection_status)
values ('$team_id', '$season_id', '$match_id', '$outgoing', 'regular', 'automatic', 'selected');
SQL

fingerprint="$(docker exec -i "$db_container" psql -U postgres -d postgres -Atq -v ON_ERROR_STOP=1 <<SQL
begin;
set local role authenticated;
set local request.jwt.claim.sub = '$coach_id';
select public.get_manual_adjustment_source('$team_id', '$season_id', '$match_id') ->> 'fingerprint';
rollback;
SQL
)"

docker exec -i "$db_container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 >"$result_dir/first" 2>&1 <<SQL &
begin;
set application_name = 'manual_adjustment_concurrency_first';
set local role service_role;
set local request.jwt.claims = '{"role":"service_role"}';
select public.create_manual_regular_adjustment('$coach_id', '$team_id', '$season_id', '$match_id', '$outgoing', '$incoming_one', '$fingerprint');
select pg_sleep(2);
commit;
SQL
first_pid=$!

first_ready="0"
for _ in {1..50}; do
  first_ready="$(docker exec -i "$db_container" psql -U postgres -d postgres -Atq -c "select count(*) from pg_stat_activity where application_name = 'manual_adjustment_concurrency_first' and state = 'active' and query like 'select pg_sleep%';")"
  [[ "$first_ready" == "1" ]] && break
  sleep 0.05
done
if [[ "$first_ready" != "1" ]]; then
  wait "$first_pid" || true
  echo "First manual adjustment never reached the synchronization point."
  exit 1
fi

set +e
docker exec -i "$db_container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 >"$result_dir/second" 2>&1 <<SQL
begin;
set local role service_role;
set local request.jwt.claims = '{"role":"service_role"}';
select public.create_manual_regular_adjustment('$coach_id', '$team_id', '$season_id', '$match_id', '$outgoing', '$incoming_two', '$fingerprint');
commit;
SQL
second_status=$?
set -e
wait "$first_pid"

if [[ "$second_status" -eq 0 ]] || ! rg -q "STALE_SELECTION" "$result_dir/second"; then
  echo "Concurrent manual adjustment did not stop with STALE_SELECTION."
  exit 1
fi

final_state="$(docker exec -i "$db_container" psql -U postgres -d postgres -Atq -c "select count(*) || ':' || string_agg(player_id::text || ':' || selection_status, ',' order by selection_status) from public.match_players where match_id = '$match_id';")"
expected_state="2:$outgoing:removed,$incoming_one:selected"
if [[ "$final_state" != "$expected_state" ]]; then
  echo "Concurrent manual adjustments left an incomplete or mixed pair."
  exit 1
fi
echo "Concurrent manual adjustments serialize to one complete pair."
