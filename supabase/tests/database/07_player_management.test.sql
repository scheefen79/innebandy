begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(32);

insert into auth.users(id,email) values
 ('f1000000-0000-4000-8000-000000000001','player-coach@example.test'),
 ('f1000000-0000-4000-8000-000000000002','player-outsider@example.test'),
 ('f1000000-0000-4000-8000-000000000003','player-inactive@example.test');
insert into teams(id,name,slug) values('f2000000-0000-4000-8000-000000000001','Player team','player-team');
insert into team_members(team_id,user_id,is_active) values
 ('f2000000-0000-4000-8000-000000000001','f1000000-0000-4000-8000-000000000001',true),
 ('f2000000-0000-4000-8000-000000000001','f1000000-0000-4000-8000-000000000003',false);
insert into seasons(id,team_id,name,starts_on,ends_on) values('f3000000-0000-4000-8000-000000000001','f2000000-0000-4000-8000-000000000001','Player season','2026-08-01','2027-05-31');
insert into players(id,team_id,season_id,first_name,level,rotation_order) values
 ('f4000000-0000-4000-8000-000000000001','f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','Automatic',1,1),
 ('f4000000-0000-4000-8000-000000000002','f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','Manual in',2,2),
 ('f4000000-0000-4000-8000-000000000003','f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','Manual out',3,3),
 ('f4000000-0000-4000-8000-000000000004','f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','Extra',1,4);
insert into matches(id,team_id,season_id,opponent,starts_at,target_players,status,request_id) values
 ('f5000000-0000-4000-8000-000000000001','f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','Future auto','2027-01-01',1,'upcoming','f6000000-0000-4000-8000-000000000001'),
 ('f5000000-0000-4000-8000-000000000002','f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','Future manual','2027-01-02',1,'upcoming','f6000000-0000-4000-8000-000000000002'),
 ('f5000000-0000-4000-8000-000000000003','f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','Future extra','2027-01-03',1,'upcoming','f6000000-0000-4000-8000-000000000003'),
 ('f5000000-0000-4000-8000-000000000004','f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','Completed','2026-08-01',1,'completed','f6000000-0000-4000-8000-000000000004');
insert into match_players(team_id,season_id,match_id,player_id,selection_type,selection_source,selection_status,replaced_player_id,played) values
 ('f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','f5000000-0000-4000-8000-000000000001','f4000000-0000-4000-8000-000000000001','regular','automatic','selected',null,false),
 ('f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','f5000000-0000-4000-8000-000000000002','f4000000-0000-4000-8000-000000000002','regular','manual','selected','f4000000-0000-4000-8000-000000000003',false),
 ('f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','f5000000-0000-4000-8000-000000000002','f4000000-0000-4000-8000-000000000003','regular','manual','removed','f4000000-0000-4000-8000-000000000002',false),
 ('f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','f5000000-0000-4000-8000-000000000003','f4000000-0000-4000-8000-000000000001','regular','automatic','selected',null,false),
 ('f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','f5000000-0000-4000-8000-000000000003','f4000000-0000-4000-8000-000000000004','extra','manual','selected',null,false),
 ('f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','f5000000-0000-4000-8000-000000000004','f4000000-0000-4000-8000-000000000001','regular','automatic','selected',null,true),
 ('f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','f5000000-0000-4000-8000-000000000004','f4000000-0000-4000-8000-000000000004','extra','manual','selected',null,false);

set local role authenticated; set local request.jwt.claim.sub='f1000000-0000-4000-8000-000000000001';
select lives_ok($$select get_player_profile('f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','f4000000-0000-4000-8000-000000000001')$$,'coach reads player profile');
select results_eq($$select jsonb_array_length(get_player_profile('f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','f4000000-0000-4000-8000-000000000001')->'matches')$$,array[3],'profile contains canonical match decisions');
select results_eq($$select get_player_list('f2000000-0000-4000-8000-000000000001')->>'seasonName'$$,array['Player season'::text],'coach reads atomic player list');
select results_eq($$select (jsonb_path_query_first(get_player_list('f2000000-0000-4000-8000-000000000001')->'players', '$[*] ? (@.id == "f4000000-0000-4000-8000-000000000001")')->>'completedRegular')::integer$$,array[1],'atomic list reports completed regular count');
select throws_ok($$insert into players(team_id,season_id,first_name,level,rotation_order) values('f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','Direct',1,20)$$,'42501','permission denied for table players','authenticated cannot insert player');
select throws_ok($$update players set level=3 where id='f4000000-0000-4000-8000-000000000001'$$,'42501','permission denied for table players','authenticated cannot update player');
select throws_ok($$select create_player('f1000000-0000-4000-8000-000000000001','f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','New','',1,'f7000000-0000-4000-8000-000000000001')$$,'42501','permission denied for function create_player','authenticated cannot call create RPC');
do $$ begin perform set_config('test.auto_fp',get_player_profile('f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','f4000000-0000-4000-8000-000000000001')->>'fingerprint',true); perform set_config('test.manual_in_fp',get_player_profile('f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','f4000000-0000-4000-8000-000000000002')->>'fingerprint',true); perform set_config('test.manual_out_fp',get_player_profile('f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','f4000000-0000-4000-8000-000000000003')->>'fingerprint',true); perform set_config('test.extra_fp',get_player_profile('f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','f4000000-0000-4000-8000-000000000004')->>'fingerprint',true); end $$;
reset role; set local role anon;
select throws_ok($$select get_player_profile('f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','f4000000-0000-4000-8000-000000000001')$$,'42501','permission denied for function get_player_profile','anon cannot read profile');
reset role; set local role service_role; set local request.jwt.claims='{"role":"service_role"}';
select throws_ok($$select create_player('f1000000-0000-4000-8000-000000000002','f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','New','',1,'f7000000-0000-4000-8000-000000000001')$$,'42501','NOT_AUTHORIZED','outsider is rejected');
select throws_ok($$select create_player('f1000000-0000-4000-8000-000000000003','f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','New','',1,'f7000000-0000-4000-8000-000000000001')$$,'42501','NOT_AUTHORIZED','inactive member is rejected');
select throws_ok($$select create_player('f1000000-0000-4000-8000-000000000001','f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','','',4,'f7000000-0000-4000-8000-000000000001')$$,'P0001','INVALID_PLAYER','invalid player is rejected');
select throws_ok($$select create_player('f1000000-0000-4000-8000-000000000001','f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','No request','',1,null)$$,'P0001','INVALID_PLAYER','null create request id is rejected');
select lives_ok($$select create_player('f1000000-0000-4000-8000-000000000001','f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001',' New ',' Player ',2,'f7000000-0000-4000-8000-000000000001')$$,'valid player is created');
select results_eq($$select first_name||':'||last_name||':'||rotation_order from players where create_request_id='f7000000-0000-4000-8000-000000000001'$$,array['New:Player:5'::text],'created player is normalized with next permanent rotation');
select lives_ok($$select create_player('f1000000-0000-4000-8000-000000000001','f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','New','Player',2,'f7000000-0000-4000-8000-000000000001')$$,'identical create retry converges');
select results_eq($$select count(*) from players where create_request_id='f7000000-0000-4000-8000-000000000001'$$,array[1::bigint],'create retry has one row');
select throws_ok($$select create_player('f1000000-0000-4000-8000-000000000001','f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','Different','Player',2,'f7000000-0000-4000-8000-000000000001')$$,'P0001','REQUEST_CONFLICT','request id cannot create different input');
select lives_ok($$select create_player('f1000000-0000-4000-8000-000000000001','f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','Second','',3,'f7000000-0000-4000-8000-000000000002')$$,'second player creation succeeds');
select results_eq($$select rotation_order from players where create_request_id='f7000000-0000-4000-8000-000000000002'$$,array[6],'next creation advances rotation');
select throws_ok($$select update_player('f1000000-0000-4000-8000-000000000001','f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','f4000000-0000-4000-8000-000000000001','Changed','',2,'stale')$$,'P0001','STALE_PLAYER','stale update is rejected');
select lives_ok($$select update_player('f1000000-0000-4000-8000-000000000001','f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','f4000000-0000-4000-8000-000000000001','Changed','Name',2,current_setting('test.auto_fp'))$$,'valid update succeeds');
select results_eq($$select first_name||':'||last_name||':'||level from players where id='f4000000-0000-4000-8000-000000000001'$$,array['Changed:Name:2'::text],'update changes only editable player fields');
select results_eq($$select count(*) from match_players where player_id='f4000000-0000-4000-8000-000000000001'$$,array[3::bigint],'update preserves all selections');
select lives_ok($$select update_player('f1000000-0000-4000-8000-000000000001','f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','f4000000-0000-4000-8000-000000000001','Changed','Name',2,'old')$$,'identical update retry converges');
reset role; set local role authenticated; set local request.jwt.claim.sub='f1000000-0000-4000-8000-000000000001';
do $$ begin perform set_config('test.auto_deactivate_fp',get_player_profile('f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','f4000000-0000-4000-8000-000000000001')->>'fingerprint',true); end $$;
reset role; set local role service_role; set local request.jwt.claims='{"role":"service_role"}';
select throws_ok($$select deactivate_player('f1000000-0000-4000-8000-000000000001','f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','f4000000-0000-4000-8000-000000000002',current_setting('test.manual_in_fp'))$$,'P0001','PLAYER_HAS_PLANNED_DECISIONS','manual selected blocks deactivation');
select throws_ok($$select deactivate_player('f1000000-0000-4000-8000-000000000001','f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','f4000000-0000-4000-8000-000000000003',current_setting('test.manual_out_fp'))$$,'P0001','PLAYER_HAS_PLANNED_DECISIONS','manual removed blocks deactivation');
select throws_ok($$select deactivate_player('f1000000-0000-4000-8000-000000000001','f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','f4000000-0000-4000-8000-000000000004',current_setting('test.extra_fp'))$$,'P0001','PLAYER_HAS_PLANNED_DECISIONS','future extra blocks deactivation');
select lives_ok($$select deactivate_player('f1000000-0000-4000-8000-000000000001','f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','f4000000-0000-4000-8000-000000000001',current_setting('test.auto_deactivate_fp'))$$,'automatic future rows allow deactivation');
select results_eq($$select is_active::text||':'||(select count(*) from match_players where player_id=players.id) from players where id='f4000000-0000-4000-8000-000000000001'$$,array['false:3'::text],'soft delete preserves selections');
select lives_ok($$select deactivate_player('f1000000-0000-4000-8000-000000000001','f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','f4000000-0000-4000-8000-000000000001','old')$$,'identical deactivate retry converges');
select throws_ok($$select update_player('f1000000-0000-4000-8000-000000000001','f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','f4000000-0000-4000-8000-000000000001','Again','',1,'old')$$,'P0001','PLAYER_NOT_AVAILABLE','inactive player cannot be edited');
select results_eq($$select count(*) from match_players where player_id='f4000000-0000-4000-8000-000000000004' and played and selection_type='extra'$$,array[0::bigint],'extra absence does not count as completed extra');
select * from finish(); rollback;
