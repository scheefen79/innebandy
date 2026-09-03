begin;
create extension if not exists pgtap with schema extensions;
select plan(22);

insert into auth.users(id,email) values
 ('b1000000-0000-4000-8000-000000000001','role-coach@example.test'),
 ('b1000000-0000-4000-8000-000000000002','role-viewer@example.test');
insert into public.teams(id,name,slug) values('b2000000-0000-4000-8000-000000000001','Role team','role-team');
insert into public.team_members(team_id,user_id,role) values
 ('b2000000-0000-4000-8000-000000000001','b1000000-0000-4000-8000-000000000001','coach'),
 ('b2000000-0000-4000-8000-000000000001','b1000000-0000-4000-8000-000000000002','viewer');
insert into public.seasons(id,team_id,name,starts_on,ends_on) values('b3000000-0000-4000-8000-000000000001','b2000000-0000-4000-8000-000000000001','Rollsäsong','2026-01-01','2027-12-31');
insert into public.players(id,team_id,season_id,first_name,last_name,level,rotation_order) values
 ('b4000000-0000-4000-8000-000000000001','b2000000-0000-4000-8000-000000000001','b3000000-0000-4000-8000-000000000001','Ada','Ett',1,1),
 ('b4000000-0000-4000-8000-000000000002','b2000000-0000-4000-8000-000000000001','b3000000-0000-4000-8000-000000000001','Bea','Två',3,2);
insert into public.matches(id,team_id,season_id,opponent,starts_at,target_players,request_id) values
 ('b5000000-0000-4000-8000-000000000001','b2000000-0000-4000-8000-000000000001','b3000000-0000-4000-8000-000000000001','Motstånd','2027-02-01 10:00+00',1,'b6000000-0000-4000-8000-000000000001');
insert into public.match_players(team_id,season_id,match_id,player_id,selection_type,selection_source,selection_status) values
 ('b2000000-0000-4000-8000-000000000001','b3000000-0000-4000-8000-000000000001','b5000000-0000-4000-8000-000000000001','b4000000-0000-4000-8000-000000000001','regular','automatic','selected');

set local role authenticated;
set local request.jwt.claim.sub='b1000000-0000-4000-8000-000000000002';

select is(public.get_team_context()->>'role','viewer','viewer context exposes the verified membership role');
select is(public.get_home_overview()->>'role','viewer','atomic home overview exposes the verified membership role');
select results_eq('select count(*) from matches',array[1::bigint],'viewer reads team matches');
select results_eq('select count(*) from players',array[0::bigint],'viewer cannot read the player table');
select results_eq('select count(*) from match_players',array[0::bigint],'viewer cannot read the participation table');
select is((public.get_match_roster('b2000000-0000-4000-8000-000000000001','b3000000-0000-4000-8000-000000000001','b5000000-0000-4000-8000-000000000001')->0->>'name'),'Ada Ett','viewer sees a player name in a match roster');
select is((public.get_match_roster('b2000000-0000-4000-8000-000000000001','b3000000-0000-4000-8000-000000000001','b5000000-0000-4000-8000-000000000001')->0->>'rosterGroup'),'team','viewer receives only the current match grouping');
select ok(not (public.get_match_roster('b2000000-0000-4000-8000-000000000001','b3000000-0000-4000-8000-000000000001','b5000000-0000-4000-8000-000000000001')->0 ? 'level'),'viewer roster has no player level field');
select ok(not (public.get_match_roster('b2000000-0000-4000-8000-000000000001','b3000000-0000-4000-8000-000000000001','b5000000-0000-4000-8000-000000000001')->0 ? 'played'),'viewer roster has no participation history field');
select ok(not (public.get_match_roster('b2000000-0000-4000-8000-000000000001','b3000000-0000-4000-8000-000000000001','b5000000-0000-4000-8000-000000000001')->0 ? 'selectionSource'),'viewer roster has no administrative selection source');
select ok(not (public.get_match_roster('b2000000-0000-4000-8000-000000000001','b3000000-0000-4000-8000-000000000001','b5000000-0000-4000-8000-000000000001')->0 ? 'isActive'),'viewer roster has no player activity status');
select results_eq($$select jsonb_array_length(public.get_overview('b2000000-0000-4000-8000-000000000001')->'players')$$,array[0],'viewer overview omits player fairness history');
select throws_ok($$select public.get_player_list('b2000000-0000-4000-8000-000000000001')$$,'42501','NOT_AUTHORIZED','viewer cannot call the player list');
select throws_ok($$select public.get_player_profile('b2000000-0000-4000-8000-000000000001','b3000000-0000-4000-8000-000000000001','b4000000-0000-4000-8000-000000000001')$$,'42501','NOT_AUTHORIZED','viewer cannot call a player profile');
select throws_ok($$select public.get_regular_allocation_source('b2000000-0000-4000-8000-000000000001','b3000000-0000-4000-8000-000000000001',now())$$,'42501','NOT_AUTHORIZED','viewer cannot read the level-bearing allocation source');
select throws_ok($$select public.get_manual_adjustment_source('b2000000-0000-4000-8000-000000000001','b3000000-0000-4000-8000-000000000001','b5000000-0000-4000-8000-000000000001')$$,'42501','NOT_AUTHORIZED','viewer cannot read manual adjustment metadata');
select throws_ok($$select public.get_extra_substitute_source('b2000000-0000-4000-8000-000000000001','b3000000-0000-4000-8000-000000000001','b5000000-0000-4000-8000-000000000001')$$,'42501','NOT_AUTHORIZED','viewer cannot read extra substitute history');
select throws_ok($$select public.get_match_completion_source('b2000000-0000-4000-8000-000000000001','b3000000-0000-4000-8000-000000000001','b5000000-0000-4000-8000-000000000001')$$,'42501','NOT_AUTHORIZED','viewer cannot read completion mutation metadata');
select throws_ok($$insert into matches(team_id,season_id,opponent,starts_at,target_players,request_id) values('b2000000-0000-4000-8000-000000000001','b3000000-0000-4000-8000-000000000001','Otillåten','2027-03-01',1,'b6000000-0000-4000-8000-000000000002')$$,'42501','new row violates row-level security policy for table "matches"','viewer cannot create a match directly');

reset role;
set local role service_role;
set local request.jwt.claims='{"role":"service_role"}';
select throws_ok($$select public.create_player('b1000000-0000-4000-8000-000000000002','b2000000-0000-4000-8000-000000000001','b3000000-0000-4000-8000-000000000001','Otillåten',null,2,'b6000000-0000-4000-8000-000000000003')$$,'42501','NOT_AUTHORIZED','server mutation rejects a forwarded viewer identity');

reset role;
set local role authenticated;
set local request.jwt.claim.sub='b1000000-0000-4000-8000-000000000001';
select results_eq('select count(*) from players',array[2::bigint],'coach retains player table read access');
select is((public.get_match_roster('b2000000-0000-4000-8000-000000000001','b3000000-0000-4000-8000-000000000001','b5000000-0000-4000-8000-000000000001')->0->>'level'),'1','coach roster includes player level');

select * from finish();
rollback;
