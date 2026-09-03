#!/usr/bin/env bash
set -euo pipefail

db_container="${SUPABASE_DB_CONTAINER:-supabase_db_Innebandy}"
coach_a="f1000000-0000-4000-8000-000000000001"
coach_b="f1000000-0000-4000-8000-000000000002"
team_id="f2000000-0000-4000-8000-000000000001"
result_dir="$(mktemp -d)"

cleanup_db() {
  docker exec -i "$db_container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 >/dev/null <<SQL
delete from public.team_members where team_id = '$team_id';
delete from public.teams where id = '$team_id';
delete from auth.users where id in ('$coach_a', '$coach_b');
SQL
}
cleanup() { cleanup_db; rm -rf "$result_dir"; }
trap cleanup EXIT
cleanup_db

docker exec -i "$db_container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 >/dev/null <<SQL
insert into auth.users (id, email) values
  ('$coach_a', 'team-concurrency-a@example.test'),
  ('$coach_b', 'team-concurrency-b@example.test');
insert into public.teams (id, name, slug) values ('$team_id', 'Team concurrency', 'team-concurrency');
insert into public.team_members (team_id, user_id, role, is_active) values
  ('$team_id', '$coach_a', 'coach', true),
  ('$team_id', '$coach_b', 'coach', true);
SQL

# Two active coaches try to deactivate each other at the same time. Before the row-locking fix,
# each transaction locked its own target row first and the team's active-coach set second, in
# opposite orders, which deadlocked. This reproduces that race and asserts it no longer does,
# and that the team never ends up with zero active coaches regardless of which side wins.
docker exec -i "$db_container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 >"$result_dir/first" 2>&1 <<SQL &
begin;
set application_name = 'team_membership_first';
set local role service_role;
set local request.jwt.claims = '{"role":"service_role"}';
select public.deactivate_team_member('$coach_a', '$team_id', '$coach_b', md5('coach' || true::text));
select pg_sleep(2);
commit;
SQL
first_pid=$!

for _ in {1..50}; do
  ready="$(docker exec -i "$db_container" psql -U postgres -d postgres -Atq -c "select count(*) from pg_stat_activity where application_name = 'team_membership_first' and state = 'active' and query like 'select pg_sleep%';")"
  [[ "$ready" == "1" ]] && break
  sleep .05
done
[[ "${ready:-0}" == "1" ]] || { echo "First transaction never reached its held lock."; exit 1; }

docker exec -i "$db_container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 >"$result_dir/second" 2>&1 <<SQL || true
begin;
set local role service_role;
set local request.jwt.claims = '{"role":"service_role"}';
select public.deactivate_team_member('$coach_b', '$team_id', '$coach_a', md5('coach' || true::text));
commit;
SQL

wait "$first_pid"

if grep -qi "deadlock" "$result_dir/first" "$result_dir/second"; then
  echo "Concurrent deactivation deadlocked instead of serializing."
  cat "$result_dir/first" "$result_dir/second"
  exit 1
fi

if ! grep -q "LAST_ACTIVE_COACH" "$result_dir/second"; then
  echo "Expected the second, now-last-coach deactivation to be rejected with LAST_ACTIVE_COACH."
  cat "$result_dir/second"
  exit 1
fi

active_coaches="$(docker exec -i "$db_container" psql -U postgres -d postgres -Atq -c "select count(*) from public.team_members where team_id = '$team_id' and role = 'coach' and is_active;")"
[[ "$active_coaches" == "1" ]] || { echo "Expected exactly one active coach to remain, found $active_coaches."; exit 1; }

echo "Concurrent mutual deactivation serializes without deadlock and never leaves the team without an active coach."
