begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(7);

insert into auth.users(id,email) values('f1000000-0000-4000-8000-000000000001','content-coach@example.test');
insert into teams(id,name,slug) values('f2000000-0000-4000-8000-000000000001','Content team','content-team');
insert into team_members(team_id,user_id) values('f2000000-0000-4000-8000-000000000001','f1000000-0000-4000-8000-000000000001');
insert into seasons(id,team_id,name,starts_on,ends_on) values('f3000000-0000-4000-8000-000000000001','f2000000-0000-4000-8000-000000000001','Content season','2026-08-01','2026-12-31');
insert into training_sessions(id,team_id,season_id,starts_at,ends_at,theme_block,focus,key_message,updated_by) values
 ('f4000000-0000-4000-8000-000000000001','f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','2026-09-05 08:00+00','2026-09-05 09:00+00',1,'Passning','PASSA','f1000000-0000-4000-8000-000000000001'),
 ('f4000000-0000-4000-8000-000000000002','f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','2026-09-07 14:15+00','2026-09-07 15:30+00',1,'Passning','PASSA','f1000000-0000-4000-8000-000000000001');
update training_sessions set revision=2 where id='f4000000-0000-4000-8000-000000000002';
insert into training_items(training_session_id,team_id,season_id,section,position,title,instructions,coaching_points) values
 ('f4000000-0000-4000-8000-000000000001','f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','technique',1,'Dragpassningar','Anpassa övningen efter gruppen och dagens förutsättningar.','["PASSA"]'),
 ('f4000000-0000-4000-8000-000000000002','f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','technique',1,'Dragpassningar','Tränarens egen text','["Eget fokus"]');

set local role authenticated;set local request.jwt.claim.sub='f1000000-0000-4000-8000-000000000001';
select throws_ok($$select enrich_training_items('f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','[]')$$,'42501','permission denied for function enrich_training_items','client cannot enrich content');

reset role;set local role service_role;set local request.jwt.claims='{"role":"service_role"}';
select results_eq($$select enrich_training_items('f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','[{"title":"Dragpassningar","purpose":"Säkra passningar och mottagningar.","instructions":"Arbeta parvis med passningar längs golvet och flytta efter varje passning.","coachingPoints":["Blicken upp","Mjuk mottagning"],"sourceUrl":"https://innebandy.se/ovningsbanken/dragpassningar","sourceImageUrl":"https://innebandy.se/media/test.png"}]')$$,array[1],'one untouched item enriched');
select results_eq($$select purpose from training_items where training_session_id='f4000000-0000-4000-8000-000000000001'$$,array['Säkra passningar och mottagningar.'],'purpose updated');
select results_eq($$select source_image_url from training_items where training_session_id='f4000000-0000-4000-8000-000000000001'$$,array['https://innebandy.se/media/test.png'],'image source updated');
select results_eq($$select instructions from training_items where training_session_id='f4000000-0000-4000-8000-000000000002'$$,array['Tränarens egen text'],'edited plan is preserved');
select results_eq($$select enrich_training_items('f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','[{"title":"Dragpassningar","purpose":"Säkra passningar och mottagningar.","instructions":"Arbeta parvis med passningar längs golvet och flytta efter varje passning.","coachingPoints":["Blicken upp","Mjuk mottagning"],"sourceUrl":"https://innebandy.se/ovningsbanken/dragpassningar","sourceImageUrl":"https://innebandy.se/media/test.png"}]')$$,array[0],'repeat is idempotent');
select throws_ok($$select enrich_training_items('f2000000-0000-4000-8000-000000000001','f3000000-0000-4000-8000-000000000001','[{"title":"X","purpose":"X","instructions":"X","coachingPoints":[],"sourceUrl":"https://example.com/x","sourceImageUrl":""}]')$$,'P0001','INVALID_TRAINING_CONTENT','untrusted source rejected');
select * from finish();rollback;
