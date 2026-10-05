#!/usr/bin/env bash
# Synthetic fixtures only. Run against the disposable local Supabase database.
set -euo pipefail
db_container="${SUPABASE_DB_CONTAINER:-supabase_db_Innebandy}"
coach_id="ec000000-0000-4000-8000-000000000001"
team_id="ec000000-0000-4000-8000-000000000002"
season_id="ec000000-0000-4000-8000-000000000003"
match_id="ec000000-0000-4000-8000-000000000004"
player_id="ec000000-0000-4000-8000-000000000005"
request_id="ec000000-0000-4000-8000-000000000006"
result_dir="$(mktemp -d)"
psql_local() { docker exec -i "$db_container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 "$@"; }
cleanup_db() {
  psql_local >/dev/null <<SQL
-- Frozen plans are intentionally immutable; remove the synthetic workflow first.
delete from public.match_workflows where team_id='$team_id';
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
psql_local >/dev/null <<SQL
insert into auth.users(id,email) values('$coach_id','workflow-concurrency@example.test');
insert into public.teams(id,name,slug) values('$team_id','Workflow concurrency','workflow-concurrency');
insert into public.team_members(team_id,user_id,role) values('$team_id','$coach_id','coach');
insert into public.seasons(id,team_id,name,starts_on,ends_on) values('$season_id','$team_id','Synthetic','2026-01-01','2030-01-01');
insert into public.players(id,team_id,season_id,first_name,level,rotation_order) values('$player_id','$team_id','$season_id','Synthetic',1,1);
insert into public.matches(id,team_id,season_id,opponent,starts_at,target_players,request_id) values('$match_id','$team_id','$season_id','Synthetic',now()-interval '1 hour',1,'$match_id');
insert into public.match_players(team_id,season_id,match_id,player_id,selection_type,selection_source,selection_status) values('$team_id','$season_id','$match_id','$player_id','regular','automatic','selected');
begin; set local role service_role; set local request.jwt.claims='{"role":"service_role"}';
select public.save_match_workflow('$coach_id','$team_id','$season_id','$match_id',0,'ec000000-0000-4000-8000-000000000007','start','[]'); commit;
SQL
run_first() {
 local action="$1" revision="$2" changes="$3" application="$4"
 psql_local >"$result_dir/first" 2>&1 <<SQL &
begin; set application_name='$application'; set local statement_timeout='10s'; set local role service_role; set local request.jwt.claims='{"role":"service_role"}';
select public.save_match_workflow('$coach_id','$team_id','$season_id','$match_id',$revision,'$request_id','$action','$changes');
select pg_sleep(2); commit;
SQL
 first_pid=$!
 for _ in {1..50}; do
  ready="$(psql_local -Atq -c "select count(*) from pg_stat_activity where application_name='$application' and state='active' and query like 'select pg_sleep%';")"
  [[ "$ready" == "1" ]] && break
  sleep 0.05
 done
 [[ "${ready:-0}" == "1" ]] || { echo 'Workflow synchronization point not reached.'; exit 1; }
}
run_second() {
 local action="$1" revision="$2" changes="$3" request="$4"
 psql_local >"$result_dir/second" 2>&1 <<SQL
begin; set local statement_timeout='10s'; set local role service_role; set local request.jwt.claims='{"role":"service_role"}';
select public.save_match_workflow('$coach_id','$team_id','$season_id','$match_id',$revision,'$request','$action','$changes'); commit;
SQL
}
changes='[{"playerId":"'$player_id'","response":"accepted"}]'
run_first responses 1 "$changes" workflow_response_retry
run_second responses 1 "$changes" "$request_id"
wait "$first_pid"
state="$(psql_local -Atq -c "select revision || ':' || (select count(*) from public.match_workflow_events where match_id='$match_id') from public.match_workflows where match_id='$match_id';")"
[[ "$state" == '2:2' ]] || { echo 'Concurrent identical retry duplicated workflow or audit events.'; exit 1; }

request_id="ec000000-0000-4000-8000-000000000008"
run_first lock 2 '["'$player_id'"]' workflow_lock_response
set +e
run_second responses 2 '[{"playerId":"'$player_id'","response":"declined"}]' ec000000-0000-4000-8000-000000000009
second_status=$?
set -e
wait "$first_pid"
if [[ "$second_status" -eq 0 ]] || ! rg -q 'STALE_WORKFLOW' "$result_dir/second"; then
 echo 'Concurrent old response did not fail stale after locking.'; exit 1
fi
state="$(psql_local -Atq -c "select w.phase || ':' || w.revision || ':' || m.status || ':' || (select count(*) from public.match_participation where match_id=m.id) || ':' || (select response from public.match_calls where match_id=m.id and player_id='$player_id') from public.matches m join public.match_workflows w on w.match_id=m.id where m.id='$match_id';")"
[[ "$state" == 'locked:3:completed:1:accepted' ]] || { echo 'Locked winning participation was not preserved.'; exit 1; }
echo 'Workflow retries converge; concurrent stale responses cannot overwrite locked participation.'
