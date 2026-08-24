begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(12);

insert into auth.users(id,email) values
 ('a1000000-0000-4000-8000-000000000001','overview-coach@example.test'),
 ('a1000000-0000-4000-8000-000000000002','overview-outsider@example.test'),
 ('a1000000-0000-4000-8000-000000000003','overview-inactive@example.test');
insert into teams(id,name,slug) values('a2000000-0000-4000-8000-000000000001','Overview team','overview-team');
insert into team_members(team_id,user_id,is_active) values
 ('a2000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000001',true),
 ('a2000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000003',false);
insert into seasons(id,team_id,name,starts_on,ends_on) values('a3000000-0000-4000-8000-000000000001','a2000000-0000-4000-8000-000000000001','Overview season','2026-01-01','2027-12-31');
insert into players(id,team_id,season_id,first_name,level,rotation_order,is_active) values
 ('a4000000-0000-4000-8000-000000000001','a2000000-0000-4000-8000-000000000001','a3000000-0000-4000-8000-000000000001','Active one',1,1,true),
 ('a4000000-0000-4000-8000-000000000002','a2000000-0000-4000-8000-000000000001','a3000000-0000-4000-8000-000000000001','Active zero',2,2,true),
 ('a4000000-0000-4000-8000-000000000003','a2000000-0000-4000-8000-000000000001','a3000000-0000-4000-8000-000000000001','Inactive',3,3,false);
insert into matches(id,team_id,season_id,opponent,starts_at,target_players,status,request_id) values
 ('a5000000-0000-4000-8000-000000000001','a2000000-0000-4000-8000-000000000001','a3000000-0000-4000-8000-000000000001','Future',now()+interval '1 day',2,'upcoming','a6000000-0000-4000-8000-000000000001'),
 ('a5000000-0000-4000-8000-000000000002','a2000000-0000-4000-8000-000000000001','a3000000-0000-4000-8000-000000000001','Past upcoming',now()-interval '1 day',2,'upcoming','a6000000-0000-4000-8000-000000000002'),
 ('a5000000-0000-4000-8000-000000000003','a2000000-0000-4000-8000-000000000001','a3000000-0000-4000-8000-000000000001','Completed',now()-interval '2 days',2,'completed','a6000000-0000-4000-8000-000000000003'),
 ('a5000000-0000-4000-8000-000000000004','a2000000-0000-4000-8000-000000000001','a3000000-0000-4000-8000-000000000001','Cancelled',now()+interval '2 days',2,'cancelled','a6000000-0000-4000-8000-000000000004');
insert into match_players(team_id,season_id,match_id,player_id,selection_type,selection_source,selection_status,played) values
 ('a2000000-0000-4000-8000-000000000001','a3000000-0000-4000-8000-000000000001','a5000000-0000-4000-8000-000000000001','a4000000-0000-4000-8000-000000000001','regular','automatic','selected',false),
 ('a2000000-0000-4000-8000-000000000001','a3000000-0000-4000-8000-000000000001','a5000000-0000-4000-8000-000000000001','a4000000-0000-4000-8000-000000000002','extra','manual','selected',false),
 ('a2000000-0000-4000-8000-000000000001','a3000000-0000-4000-8000-000000000001','a5000000-0000-4000-8000-000000000002','a4000000-0000-4000-8000-000000000001','regular','automatic','selected',false),
 ('a2000000-0000-4000-8000-000000000001','a3000000-0000-4000-8000-000000000001','a5000000-0000-4000-8000-000000000003','a4000000-0000-4000-8000-000000000001','regular','automatic','selected',true),
 ('a2000000-0000-4000-8000-000000000001','a3000000-0000-4000-8000-000000000001','a5000000-0000-4000-8000-000000000003','a4000000-0000-4000-8000-000000000002','regular','automatic','selected',false),
 ('a2000000-0000-4000-8000-000000000001','a3000000-0000-4000-8000-000000000001','a5000000-0000-4000-8000-000000000004','a4000000-0000-4000-8000-000000000001','regular','automatic','selected',false);

select has_function('public','get_overview',array['uuid'],'overview function exists');
set local role authenticated;set local request.jwt.claim.sub='a1000000-0000-4000-8000-000000000001';
select lives_ok($$select get_overview('a2000000-0000-4000-8000-000000000001')$$,'active coach reads overview');
select results_eq($$select get_overview('a2000000-0000-4000-8000-000000000001')->>'seasonName'$$,array['Overview season'::text],'active season is returned');
select results_eq($$select jsonb_array_length(get_overview('a2000000-0000-4000-8000-000000000001')->'upcomingMatches')$$,array[1],'only future upcoming matches are listed');
select results_eq($$select (get_overview('a2000000-0000-4000-8000-000000000001')->'upcomingMatches'->0->>'selectedPlayers')::integer$$,array[2],'regular and extra selected players are counted for roster size');
select results_eq($$select jsonb_array_length(get_overview('a2000000-0000-4000-8000-000000000001')->'players')$$,array[2],'only active players are included');
select results_eq($$select (jsonb_path_query_first(get_overview('a2000000-0000-4000-8000-000000000001')->'players','$[*] ? (@.id == "a4000000-0000-4000-8000-000000000001")')->>'regularCount')::integer$$,array[3],'played completed and selected upcoming regular rows count');
select results_eq($$select (jsonb_path_query_first(get_overview('a2000000-0000-4000-8000-000000000001')->'players','$[*] ? (@.id == "a4000000-0000-4000-8000-000000000002")')->>'regularCount')::integer$$,array[0],'extra and completed absence do not count as regular fairness');
reset role;set local role anon;
select throws_ok($$select get_overview('a2000000-0000-4000-8000-000000000001')$$,'42501','permission denied for function get_overview','anon cannot call overview');
reset role;set local role authenticated;set local request.jwt.claim.sub='a1000000-0000-4000-8000-000000000002';
select throws_ok($$select get_overview('a2000000-0000-4000-8000-000000000001')$$,'42501','NOT_AUTHORIZED','outsider is rejected');
set local request.jwt.claim.sub='a1000000-0000-4000-8000-000000000003';
select throws_ok($$select get_overview('a2000000-0000-4000-8000-000000000001')$$,'42501','NOT_AUTHORIZED','inactive member is rejected');
reset role;update seasons set is_active=false where id='a3000000-0000-4000-8000-000000000001';set local role authenticated;set local request.jwt.claim.sub='a1000000-0000-4000-8000-000000000001';
select throws_ok($$select get_overview('a2000000-0000-4000-8000-000000000001')$$,'P0001','OVERVIEW_NOT_AVAILABLE','missing active season is generic');
select * from finish();rollback;
