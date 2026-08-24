#!/usr/bin/env bash
set -euo pipefail
db_container="${SUPABASE_DB_CONTAINER:-supabase_db_Innebandy}"
coach="e1100000-0000-4000-8000-000000000001"; team="e2100000-0000-4000-8000-000000000001"; season="e3100000-0000-4000-8000-000000000001"; result_dir="$(mktemp -d)"
cleanup_db(){ docker exec -i "$db_container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 >/dev/null <<SQL
delete from public.players where team_id='$team'; delete from public.seasons where team_id='$team'; delete from public.team_members where team_id='$team'; delete from public.teams where id='$team'; delete from auth.users where id='$coach';
SQL
}
cleanup(){ cleanup_db; rm -rf "$result_dir"; }; trap cleanup EXIT; cleanup_db
docker exec -i "$db_container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 >/dev/null <<SQL
insert into auth.users(id,email) values('$coach','player-concurrency@example.test'); insert into teams(id,name,slug) values('$team','Player concurrency','player-concurrency'); insert into team_members(team_id,user_id) values('$team','$coach'); insert into seasons(id,team_id,name,starts_on,ends_on) values('$season','$team','Season','2026-08-01','2027-05-31');
SQL
run_create(){ local name="$1" request="$2" app="$3" output="$4"; docker exec -i "$db_container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 >"$output" 2>&1 <<SQL &
begin; set application_name='$app'; set local role service_role; set local request.jwt.claims='{"role":"service_role"}'; select create_player('$coach','$team','$season','$name','',2,'$request'); select pg_sleep(2); commit;
SQL
 first_pid=$!; for _ in {1..50}; do ready="$(docker exec -i "$db_container" psql -U postgres -d postgres -Atq -c "select count(*) from pg_stat_activity where application_name='$app' and state='active' and query like 'select pg_sleep%';")"; [[ "$ready" == 1 ]] && break; sleep .05; done; [[ "${ready:-0}" == 1 ]] || exit 1; }
same="e7100000-0000-4000-8000-000000000001"; run_create Same "$same" player_same_first "$result_dir/same1"
docker exec -i "$db_container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 >/dev/null <<SQL
begin; set local role service_role; set local request.jwt.claims='{"role":"service_role"}'; select create_player('$coach','$team','$season','Same','',2,'$same'); commit;
SQL
wait "$first_pid"; [[ "$(docker exec -i "$db_container" psql -U postgres -d postgres -Atq -c "select count(*) from players where team_id='$team';")" == 1 ]] || { echo 'Identical create produced duplicates.'; exit 1; }
run_create Alpha e7100000-0000-4000-8000-000000000002 player_different_first "$result_dir/different1"
docker exec -i "$db_container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 >/dev/null <<SQL
begin; set local role service_role; set local request.jwt.claims='{"role":"service_role"}'; select create_player('$coach','$team','$season','Beta','',2,'e7100000-0000-4000-8000-000000000003'); commit;
SQL
wait "$first_pid"; orders="$(docker exec -i "$db_container" psql -U postgres -d postgres -Atq -c "select string_agg(rotation_order::text,',' order by rotation_order) from players where team_id='$team';")"; [[ "$orders" == "1,2,3" ]] || { echo "Unexpected rotations: $orders"; exit 1; }
echo 'Concurrent player creates converge and receive unique permanent rotations.'
