begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

insert into auth.users(id,email) values
 ('f1000000-0000-4000-8000-000000000001','attendance-coach@example.test'),
 ('f1000000-0000-4000-8000-000000000002','attendance-viewer@example.test'),
 ('f1000000-0000-4000-8000-000000000003','attendance-outsider@example.test'),
 ('f1000000-0000-4000-8000-000000000004','attendance-inactive@example.test');
insert into public.teams(id,name,slug) values
 ('f2000000-0000-4000-8000-000000000001','Attendance team','attendance-team'),
 ('f2000000-0000-4000-8000-000000000002','Attendance outsider team','attendance-outsider-team');
insert into public.team_members(team_id,user_id,role,is_active) values
 ('f2000000-0000-4000-8000-000000000001','f1000000-0000-4000-8000-000000000001','coach',true),
 ('f2000000-0000-4000-8000-000000000001','f1000000-0000-4000-8000-000000000002','viewer',true),
 ('f2000000-0000-4000-8000-000000000001','f1000000-0000-4000-8000-000000000004','viewer',false),
 ('f2000000-0000-4000-8000-000000000002','f1000000-0000-4000-8000-000000000003','coach',true);
insert into public.seasons(id,team_id,name,starts_on,ends_on) values('f3000000-0000-4000-8000-000000000001','f2000000-0000-4000-8000-000000000001','Attendance season','2026-01-01','2027-12-31');
insert into public.training_sessions(id,team_id,season_id,starts_at,ends_at,theme_block,focus,key_message,updated_by) values
 ('f4000000-0000-4000-8000-000000000001','f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','2027-02-01 09:00+00','2027-02-01 10:00+00',1,'Passning','PASSA','f1000000-0000-4000-8000-000000000001'),
 ('f4000000-0000-4000-8000-000000000002','f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','2027-02-08 09:00+00','2027-02-08 10:00+00',1,'Avslutat','KLART','f1000000-0000-4000-8000-000000000001');
update public.team_members set display_name='Tränare ett' where user_id='f1000000-0000-4000-8000-000000000001';

select has_table('public','training_attendance','training attendance table exists');
set local role authenticated;
set local request.jwt.claim.sub='f1000000-0000-4000-8000-000000000002';
select throws_ok($$select count(*) from public.training_attendance$$,'42501',null,'authenticated members cannot read attendance rows directly');
select is(jsonb_array_length(public.get_training_attendance('f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001')),2,'viewer can read attendance overview');
select throws_ok($$select public.save_training_attendance('f1000000-0000-4000-8000-000000000002','f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','f4000000-0000-4000-8000-000000000001','coming')$$,'42501','permission denied for function save_training_attendance','viewer cannot call server-only mutation directly');

reset role;
set local role service_role;
set local request.jwt.claims='{"role":"service_role"}';
select lives_ok($$select public.save_training_attendance('f1000000-0000-4000-8000-000000000002','f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','f4000000-0000-4000-8000-000000000001','coming')$$,'server saves a viewer response');
select is((select status::text from public.training_attendance where user_id='f1000000-0000-4000-8000-000000000002'),'coming','viewer response is persisted');
select lives_ok($$select public.save_training_attendance('f1000000-0000-4000-8000-000000000002','f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','f4000000-0000-4000-8000-000000000001','absent')$$,'server can update the same member response');
select is((select status::text from public.training_attendance where user_id='f1000000-0000-4000-8000-000000000002'),'absent','one response per member is updated in place');
select lives_ok($$select public.save_training_attendance('f1000000-0000-4000-8000-000000000001','f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','f4000000-0000-4000-8000-000000000001','coming')$$,'server saves a coach response');
select throws_ok($$select public.save_training_attendance('f1000000-0000-4000-8000-000000000003','f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','f4000000-0000-4000-8000-000000000001','coming')$$,'42501','NOT_AUTHORIZED','server rejects another team member');
select throws_ok($$select public.save_training_attendance('f1000000-0000-4000-8000-000000000004','f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','f4000000-0000-4000-8000-000000000001','coming')$$,'42501','NOT_AUTHORIZED','server rejects an inactive member');
update public.training_sessions set status='completed' where id='f4000000-0000-4000-8000-000000000002';
select throws_ok($$select public.save_training_attendance('f1000000-0000-4000-8000-000000000001','f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','f4000000-0000-4000-8000-000000000002','coming')$$,'P0001','TRAINING_COMPLETED','completed training rejects planned attendance changes');

reset role;
set local role authenticated;
set local request.jwt.claim.sub='f1000000-0000-4000-8000-000000000002';
select is((select response->>'name' from jsonb_array_elements(public.get_training_attendance('f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001')->0->'responses') response where response->>'userId'='f1000000-0000-4000-8000-000000000001'),'Tränare ett','viewer sees the configured name of a coming trainer in the overview');
select is((select response->>'status' from jsonb_array_elements(public.get_training_attendance('f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001')->0->'responses') response where response->>'userId'='f1000000-0000-4000-8000-000000000001'),'coming','viewer sees the coming status in the overview');

set local request.jwt.claim.sub='f1000000-0000-4000-8000-000000000003';
select throws_ok($$select public.get_training_attendance('f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001')$$,'42501','NOT_AUTHORIZED','outsider cannot read attendance overview');
reset role;
set local role anon;
select throws_ok($$select public.get_training_attendance('f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001')$$,'42501','permission denied for function get_training_attendance','anonymous user cannot read attendance overview');
select * from finish();
rollback;
