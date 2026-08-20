#!/usr/bin/env bash
set -euo pipefail

db_container="${SUPABASE_DB_CONTAINER:-supabase_db_Innebandy}"
coach_id="97100000-0000-4000-8000-000000000001"
team_id="97200000-0000-4000-8000-000000000001"
season_id="97300000-0000-4000-8000-000000000001"
player_one="97400000-0000-4000-8000-000000000001"
player_two="97400000-0000-4000-8000-000000000002"
match_id="97500000-0000-4000-8000-000000000001"
request_id="97600000-0000-4000-8000-000000000001"
boundary="2026-08-20 00:00+00"
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

cleanup() {
  cleanup_db
  rm -rf "$result_dir"
}
trap cleanup EXIT

cleanup_db

docker exec -i "$db_container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 >/dev/null <<SQL
insert into auth.users (id, email) values ('$coach_id', 'selection-concurrency@example.test');
insert into public.teams (id, name, slug) values ('$team_id', 'Concurrency test', 'selection-concurrency');
insert into public.team_members (team_id, user_id) values ('$team_id', '$coach_id');
insert into public.seasons (id, team_id, name, starts_on, ends_on)
values ('$season_id', '$team_id', 'Concurrency season', '2026-08-01', '2027-05-31');
insert into public.players (id, team_id, season_id, first_name, level, rotation_order) values
  ('$player_one', '$team_id', '$season_id', 'First', 1, 1),
  ('$player_two', '$team_id', '$season_id', 'Second', 2, 2);
insert into public.matches (id, team_id, season_id, opponent, starts_at, target_players, request_id)
values ('$match_id', '$team_id', '$season_id', 'Concurrency opponent', '2026-09-20 10:00+00', 1, '$request_id');
SQL

fingerprint="$(docker exec -i "$db_container" psql -U postgres -d postgres -Atq -v ON_ERROR_STOP=1 <<SQL
begin;
set local role authenticated;
set local request.jwt.claim.sub = '$coach_id';
select public.get_regular_allocation_source('$team_id', '$season_id', '$boundary') ->> 'fingerprint';
rollback;
SQL
)"

first_payload="[{\"matchId\":\"$match_id\",\"playerIds\":[\"$player_one\"]}]"
second_payload="[{\"matchId\":\"$match_id\",\"playerIds\":[\"$player_two\"]}]"

docker exec -i "$db_container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 >"$result_dir/first" 2>&1 <<SQL &
begin;
set application_name = 'selection_concurrency_first';
set local role service_role;
set local request.jwt.claims = '{"role":"service_role"}';
select public.save_regular_allocation('$coach_id', '$team_id', '$season_id', '$boundary', '$fingerprint', '$first_payload'::jsonb);
select pg_sleep(2);
commit;
SQL
first_pid=$!

first_ready="0"
for _ in {1..50}; do
  first_ready="$(docker exec -i "$db_container" psql -U postgres -d postgres -Atq -v ON_ERROR_STOP=1 -c "select count(*) from pg_stat_activity where application_name = 'selection_concurrency_first' and state = 'active' and query like 'select pg_sleep%';")"
  [[ "$first_ready" == "1" ]] && break
  sleep 0.05
done
if [[ "$first_ready" != "1" ]]; then
  echo "First save never reached the open-transaction synchronization point."
  wait "$first_pid" || true
  exit 1
fi

set +e
docker exec -i "$db_container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 >"$result_dir/second" 2>&1 <<SQL
begin;
set local role service_role;
set local request.jwt.claims = '{"role":"service_role"}';
select public.save_regular_allocation('$coach_id', '$team_id', '$season_id', '$boundary', '$fingerprint', '$second_payload'::jsonb);
commit;
SQL
second_status=$?
set -e
wait "$first_pid"

if [[ "$second_status" -eq 0 ]] || ! rg -q "STALE_PREVIEW" "$result_dir/second"; then
  echo "Concurrent save did not serialize to a stable stale-preview result."
  exit 1
fi

final_state="$(docker exec -i "$db_container" psql -U postgres -d postgres -Atq -v ON_ERROR_STOP=1 -c "select count(*) || ':' || min(player_id::text) from public.match_players where match_id = '$match_id';")"
if [[ "$final_state" != "1:$player_one" ]]; then
  echo "Concurrent saves left a mixed or incomplete allocation."
  exit 1
fi

echo "Concurrent selection saves serialize to one complete allocation."
