begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(23);
select has_table('public','training_sessions','training_sessions exists');
select has_table('public','training_items','training_items exists');
select col_type_is('public','training_sessions','starts_at','timestamp with time zone','starts_at is timezone aware');
select col_type_is('public','training_sessions','revision','integer','revision exists');

insert into auth.users(id,email) values
 ('e1000000-0000-4000-8000-000000000001','training-coach@example.test'),
 ('e1000000-0000-4000-8000-000000000002','training-outsider@example.test');
insert into teams(id,name,slug) values('e2000000-0000-4000-8000-000000000001','Training team','training-team');
insert into team_members(team_id,user_id) values('e2000000-0000-4000-8000-000000000001','e1000000-0000-4000-8000-000000000001');
insert into seasons(id,team_id,name,starts_on,ends_on) values('e3000000-0000-4000-8000-000000000001','e2000000-0000-4000-8000-000000000001','Training season','2026-08-01','2027-05-31');
insert into training_sessions(id,team_id,season_id,starts_at,ends_at,theme_block,focus,key_message,updated_by) values('e4000000-0000-4000-8000-000000000001','e2000000-0000-4000-8000-000000000001','e3000000-0000-4000-8000-000000000001','2026-09-05 08:00+00','2026-09-05 09:00+00',1,'Passning','PASSA','e1000000-0000-4000-8000-000000000001');
insert into training_items(training_session_id,team_id,season_id,section,position,title,coaching_points) values('e4000000-0000-4000-8000-000000000001','e2000000-0000-4000-8000-000000000001','e3000000-0000-4000-8000-000000000001','technique',1,'Passa','["Blick upp"]');

set local role authenticated;set local request.jwt.claim.sub='e1000000-0000-4000-8000-000000000001';
select results_eq($$select count(*) from training_sessions$$,array[1::bigint],'coach reads own sessions');
select results_eq($$select count(*) from training_items$$,array[1::bigint],'coach reads own items');
select lives_ok($$select get_training_list('e2000000-0000-4000-8000-000000000001','e3000000-0000-4000-8000-000000000001')$$,'coach reads list RPC');
select lives_ok($$select get_training_plan('e2000000-0000-4000-8000-000000000001','e3000000-0000-4000-8000-000000000001','e4000000-0000-4000-8000-000000000001')$$,'coach reads detail RPC');
select throws_ok($$insert into training_sessions(team_id,season_id,starts_at,ends_at,theme_block,focus,key_message,updated_by) values('e2000000-0000-4000-8000-000000000001','e3000000-0000-4000-8000-000000000001',now(),now()+interval '1 hour',1,'X','X','e1000000-0000-4000-8000-000000000001')$$,'42501',null,'authenticated cannot insert directly');
select throws_ok($$select save_training_plan('e1000000-0000-4000-8000-000000000001','e2000000-0000-4000-8000-000000000001','e3000000-0000-4000-8000-000000000001','e4000000-0000-4000-8000-000000000001',1,'auth-denied','X','X','X','planned','[]')$$,'42501','permission denied for function save_training_plan','authenticated cannot call save RPC');

reset role;set local role authenticated;set local request.jwt.claim.sub='e1000000-0000-4000-8000-000000000002';
select results_eq($$select count(*) from training_sessions$$,array[0::bigint],'outsider sees no sessions');
select throws_ok($$select get_training_plan('e2000000-0000-4000-8000-000000000001','e3000000-0000-4000-8000-000000000001','e4000000-0000-4000-8000-000000000001')$$,'42501','NOT_AUTHORIZED','outsider RPC denied');

reset role;set local role service_role;set local request.jwt.claims='{"role":"service_role"}';
select results_eq($$select save_training_plan('e1000000-0000-4000-8000-000000000001','e2000000-0000-4000-8000-000000000001','e3000000-0000-4000-8000-000000000001','e4000000-0000-4000-8000-000000000001',1,'save-1','Nytt fokus','NYTT','Anteckning','planned','[{"section":"technique","title":"Ny övning","guideMinutes":15,"coachingPoints":["Titta upp"],"sourceTitle":"Originalövning"}]')$$,array[2],'valid save increments revision');
select results_eq($$select save_training_plan('e1000000-0000-4000-8000-000000000001','e2000000-0000-4000-8000-000000000001','e3000000-0000-4000-8000-000000000001','e4000000-0000-4000-8000-000000000001',1,'save-1','Nytt fokus','NYTT','Anteckning','planned','[{"section":"technique","title":"Ny övning","guideMinutes":15,"coachingPoints":["Titta upp"],"sourceTitle":"Originalövning"}]')$$,array[2],'exact retry is idempotent');
select results_eq($$select focus||':'||status::text||':'||revision from training_sessions where id='e4000000-0000-4000-8000-000000000001'$$,array['Nytt fokus:planned:2'],'save updates session');
select results_eq($$select title from training_items where training_session_id='e4000000-0000-4000-8000-000000000001'$$,array['Ny övning'],'save atomically replaces items');
select results_eq($$select source_title from training_items where training_session_id='e4000000-0000-4000-8000-000000000001'$$,array['Originalövning'],'save preserves source title');
select throws_ok($$select save_training_plan('e1000000-0000-4000-8000-000000000001','e2000000-0000-4000-8000-000000000001','e3000000-0000-4000-8000-000000000001','e4000000-0000-4000-8000-000000000001',1,'save-stale','Stale','X','','planned','[]')$$,'P0001','STALE_TRAINING_PLAN','stale revision rejected');
select throws_ok($$select save_training_plan('e1000000-0000-4000-8000-000000000001','e2000000-0000-4000-8000-000000000001','e3000000-0000-4000-8000-000000000001','e4000000-0000-4000-8000-000000000001',2,'save-invalid','X','X','','planned','[{"section":"technique","title":"X","coachingPoints":[{"bad":true}]}]')$$,'P0001','INVALID_TRAINING_PLAN','invalid coaching points rejected');
select results_eq($$select save_training_plan('e1000000-0000-4000-8000-000000000001','e2000000-0000-4000-8000-000000000001','e3000000-0000-4000-8000-000000000001','e4000000-0000-4000-8000-000000000001',2,'save-2','Nytt fokus','NYTT','Anteckning','completed','[]')$$,array[3],'planned can become completed');
select throws_ok($$select save_training_plan('e1000000-0000-4000-8000-000000000001','e2000000-0000-4000-8000-000000000001','e3000000-0000-4000-8000-000000000001','e4000000-0000-4000-8000-000000000001',3,'save-3','X','X','','completed','[]')$$,'P0001','TRAINING_COMPLETED','completed plan is locked');
reset role;update seasons set is_active=false where id='e3000000-0000-4000-8000-000000000001';set local role authenticated;set local request.jwt.claim.sub='e1000000-0000-4000-8000-000000000001';
select results_eq($$select count(*) from training_sessions$$,array[0::bigint],'inactive season sessions are hidden by RLS');
select throws_ok($$select get_training_plan('e2000000-0000-4000-8000-000000000001','e3000000-0000-4000-8000-000000000001','e4000000-0000-4000-8000-000000000001')$$,'P0001','TRAINING_NOT_AVAILABLE','inactive season detail is unavailable');
select * from finish();rollback;
