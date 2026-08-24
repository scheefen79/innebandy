#!/usr/bin/env bash
set -euo pipefail

db_container="${SUPABASE_DB_CONTAINER:-supabase_db_Innebandy}"
coach_id="e1000000-0000-4000-8000-000000000001"
team_id="e2000000-0000-4000-8000-000000000001"
season_id="e3000000-0000-4000-8000-000000000001"
player_id="e4000000-0000-4000-8000-000000000001"
same_match="e5000000-0000-4000-8000-000000000001"
different_match="e5000000-0000-4000-8000-000000000002"
result_dir="$(mktemp -d)"

cleanup_db() {
  docker exec -i "$db_container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 >/dev/null <<SQL
delete from public.match_players where team_id='$team_id';
delete from public.matches where team_id='$team_id';
delete from public.players where team_id='$team_id';
delete from public.seasons where team_id='$team_id';
delete from public.team_members where team_id='$team_id';
delete from public.teams where id='$team_id';
delete from auth.users where id='$coach_id';
SQL
}
cleanup() { cleanup_db; rm -rf "$result_dir"; }
trap cleanup EXIT
cleanup_db

docker exec -i "$db_container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 >/dev/null <<SQL
insert into auth.users (id,email) values ('$coach_id','completion-concurrency@example.test');
insert into public.teams (id,name,slug) values ('$team_id','Completion concurrency','completion-concurrency');
insert into public.team_members (team_id,user_id) values ('$team_id','$coach_id');
insert into public.seasons (id,team_id,name,starts_on,ends_on) values ('$season_id','$team_id','Season','2026-08-01','2027-05-31');
insert into public.players (id,team_id,season_id,first_name,level,rotation_order) values ('$player_id','$team_id','$season_id','Player',1,1);
insert into public.matches (id,team_id,season_id,opponent,starts_at,target_players,request_id) values
  ('$same_match','$team_id','$season_id','Same',now()-interval '1 day',1,'e6000000-0000-4000-8000-000000000001'),
  ('$different_match','$team_id','$season_id','Different',now()-interval '1 day',1,'e6000000-0000-4000-8000-000000000002');
insert into public.match_players (team_id,season_id,match_id,player_id,selection_type,selection_source,selection_status) values
  ('$team_id','$season_id','$same_match','$player_id','regular','automatic','selected'),
  ('$team_id','$season_id','$different_match','$player_id','regular','automatic','selected');
SQL

fingerprint() {
  docker exec -i "$db_container" psql -U postgres -d postgres -Atq -v ON_ERROR_STOP=1 <<SQL
begin; set local role authenticated; set local request.jwt.claim.sub='$coach_id';
select public.get_match_completion_source('$team_id','$season_id','$1')->>'fingerprint'; rollback;
SQL
}

run_first() {
  local match_id="$1" played="$2" fp="$3" application="$4" output="$5"
  docker exec -i "$db_container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 >"$output" 2>&1 <<SQL &
begin; set application_name='$application'; set local role service_role; set local request.jwt.claims='{"role":"service_role"}';
select public.complete_match('$coach_id','$team_id','$season_id','$match_id','$fp','[{"playerId":"$player_id","played":$played}]');
select pg_sleep(2); commit;
SQL
  first_pid=$!
  for _ in {1..50}; do
    ready="$(docker exec -i "$db_container" psql -U postgres -d postgres -Atq -c "select count(*) from pg_stat_activity where application_name='$application' and state='active' and query like 'select pg_sleep%';")"
    [[ "$ready" == "1" ]] && break
    sleep 0.05
  done
  [[ "${ready:-0}" == "1" ]] || { echo "First completion never reached synchronization point."; exit 1; }
}

same_fp="$(fingerprint "$same_match")"
run_first "$same_match" true "$same_fp" completion_same_first "$result_dir/same-first"
docker exec -i "$db_container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 >"$result_dir/same-second" 2>&1 <<SQL
begin; set local role service_role; set local request.jwt.claims='{"role":"service_role"}';
select public.complete_match('$coach_id','$team_id','$season_id','$same_match','$same_fp','[{"playerId":"$player_id","played":true}]'); commit;
SQL
wait "$first_pid"

different_fp="$(fingerprint "$different_match")"
run_first "$different_match" true "$different_fp" completion_different_first "$result_dir/different-first"
set +e
docker exec -i "$db_container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 >"$result_dir/different-second" 2>&1 <<SQL
begin; set local role service_role; set local request.jwt.claims='{"role":"service_role"}';
select public.complete_match('$coach_id','$team_id','$season_id','$different_match','$different_fp','[{"playerId":"$player_id","played":false}]'); commit;
SQL
different_status=$?
set -e
wait "$first_pid"
if [[ "$different_status" -eq 0 ]] || ! rg -q "MATCH_ALREADY_COMPLETED" "$result_dir/different-second"; then
  echo "Different concurrent completion did not preserve first-write-wins."; exit 1
fi
saved="$(docker exec -i "$db_container" psql -U postgres -d postgres -Atq -c "select status || ':' || mp.played::text from public.matches m join public.match_players mp on mp.match_id=m.id where m.id='$different_match';")"
[[ "$saved" == "completed:true" ]] || { echo "Winning participation was not preserved."; exit 1; }
echo "Concurrent match completions converge for identical decisions and preserve first-write-wins for different decisions."
