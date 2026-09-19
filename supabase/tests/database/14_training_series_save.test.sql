begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(33);

-- Tidpunkterna byggs relativt now() och förankras i lokal väggklocka, till skillnad från de fasta
-- datumen i 09_training_planning.test.sql. Urvalet jämför mot now(), så fasta datum skulle ruttna.
-- Offset i hela veckor ger samma veckodag; +3 dygn ger en annan.
create function pg_temp.at_day(days integer,clock text) returns timestamptz language sql stable as $$
 select ((date_trunc('day',now() at time zone 'Europe/Stockholm')+make_interval(days=>days)+clock::interval) at time zone 'Europe/Stockholm');
$$;

insert into auth.users(id,email) values
 ('a1000000-0000-4000-8000-000000000001','series-coach@example.test'),
 ('a1000000-0000-4000-8000-000000000002','series-viewer@example.test');
insert into teams(id,name,slug) values('a2000000-0000-4000-8000-000000000001','Series team','series-team');
insert into team_members(team_id,user_id,role) values
 ('a2000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000001','coach'),
 ('a2000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000002','viewer');
insert into seasons(id,team_id,name,starts_on,ends_on) values('a3000000-0000-4000-8000-000000000001','a2000000-0000-4000-8000-000000000001','Series season','2026-08-01','2027-05-31');

-- Alla pass ligger i block 1 om inget annat anges. "primary" är passet som redigeras.
insert into training_sessions(id,team_id,season_id,starts_at,ends_at,theme_block,focus,key_message,status,updated_by) values
 ('a4000000-0000-4000-8000-00000000000a','a2000000-0000-4000-8000-000000000001','a3000000-0000-4000-8000-000000000001',pg_temp.at_day(7,'16:15'),pg_temp.at_day(7,'17:30'),1,'Start','START','planned','a1000000-0000-4000-8000-000000000001'),
 ('a4000000-0000-4000-8000-00000000000b','a2000000-0000-4000-8000-000000000001','a3000000-0000-4000-8000-000000000001',pg_temp.at_day(14,'16:15'),pg_temp.at_day(14,'17:30'),1,'Start','START','draft','a1000000-0000-4000-8000-000000000001'),
 ('a4000000-0000-4000-8000-00000000000c','a2000000-0000-4000-8000-000000000001','a3000000-0000-4000-8000-000000000001',pg_temp.at_day(-7,'16:15'),pg_temp.at_day(-7,'17:30'),1,'Start','START','planned','a1000000-0000-4000-8000-000000000001'),
 ('a4000000-0000-4000-8000-00000000000d','a2000000-0000-4000-8000-000000000001','a3000000-0000-4000-8000-000000000001',pg_temp.at_day(10,'10:00'),pg_temp.at_day(10,'11:00'),1,'Start','START','planned','a1000000-0000-4000-8000-000000000001'),
 ('a4000000-0000-4000-8000-00000000000e','a2000000-0000-4000-8000-000000000001','a3000000-0000-4000-8000-000000000001',pg_temp.at_day(14,'18:00'),pg_temp.at_day(14,'19:00'),2,'Start','START','planned','a1000000-0000-4000-8000-000000000001'),
 ('a4000000-0000-4000-8000-00000000000f','a2000000-0000-4000-8000-000000000001','a3000000-0000-4000-8000-000000000001',pg_temp.at_day(21,'16:15'),pg_temp.at_day(21,'17:30'),1,'Start','START','completed','a1000000-0000-4000-8000-000000000001'),
 ('a4000000-0000-4000-8000-000000000010','a2000000-0000-4000-8000-000000000001','a3000000-0000-4000-8000-000000000001',pg_temp.at_day(28,'16:15'),pg_temp.at_day(28,'17:30'),1,'Start','START','cancelled','a1000000-0000-4000-8000-000000000001'),
 ('a4000000-0000-4000-8000-000000000011','a2000000-0000-4000-8000-000000000001','a3000000-0000-4000-8000-000000000001',pg_temp.at_day(35,'16:15'),pg_temp.at_day(35,'17:30'),1,'Start','START','draft','a1000000-0000-4000-8000-000000000001'),
 ('a4000000-0000-4000-8000-000000000012','a2000000-0000-4000-8000-000000000001','a3000000-0000-4000-8000-000000000001',pg_temp.at_day(17,'10:00'),pg_temp.at_day(17,'11:00'),1,'Start','START','draft','a1000000-0000-4000-8000-000000000001');
insert into training_items(training_session_id,team_id,season_id,section,position,title,coaching_points)
select id,'a2000000-0000-4000-8000-000000000001','a3000000-0000-4000-8000-000000000001','technique',1,'Gammal övning','[]'::jsonb from training_sessions;

select has_function('public','save_training_plan_series','series save RPC exists');

set local role authenticated;set local request.jwt.claim.sub='a1000000-0000-4000-8000-000000000001';
select throws_ok($$select save_training_plan_series('a1000000-0000-4000-8000-000000000001','a2000000-0000-4000-8000-000000000001','a3000000-0000-4000-8000-000000000001','a4000000-0000-4000-8000-00000000000a',1,'denied','X','X','','planned','[]')$$,'42501','permission denied for function save_training_plan_series','authenticated cannot call the series RPC');

reset role;set local role service_role;set local request.jwt.claims='{"role":"service_role"}';
select throws_ok($$select save_training_plan_series('a1000000-0000-4000-8000-000000000002','a2000000-0000-4000-8000-000000000001','a3000000-0000-4000-8000-000000000001','a4000000-0000-4000-8000-00000000000a',1,'viewer','X','X','','planned','[]')$$,'42501','NOT_AUTHORIZED','an active viewer is not allowed to save a series');

-- Serieparning: ett kommande syskon med samma veckodag ska träffas, inget annat.
select results_eq($$select save_training_plan_series('a1000000-0000-4000-8000-000000000001','a2000000-0000-4000-8000-000000000001','a3000000-0000-4000-8000-000000000001','a4000000-0000-4000-8000-00000000000a',1,'series-1','Nytt fokus','NYTT','Anteckning','planned','[{"section":"technique","title":"Ny övning","coachingPoints":["Titta upp"]},{"section":"closing","title":"Avslut","coachingPoints":[]}]')$$,array[2],'series save reports both updated siblings');
select results_eq($$select focus||':'||revision from training_sessions where id='a4000000-0000-4000-8000-00000000000a'$$,array['Nytt fokus:2'],'edited session is saved through the single-session contract');
select results_eq($$select focus||':'||key_message||':'||coach_notes from training_sessions where id='a4000000-0000-4000-8000-00000000000b'$$,array['Nytt fokus:NYTT:Anteckning'],'sibling receives focus, key message and notes');
select results_eq($$select title from training_items where training_session_id='a4000000-0000-4000-8000-00000000000b' order by position$$,array['Ny övning','Avslut'],'sibling items are replaced in order');
select results_eq($$select string_agg(position::text,',' order by position) from training_items where training_session_id='a4000000-0000-4000-8000-00000000000b'$$,array['1,2'],'sibling item positions are renumbered from one');
select results_eq($$select status::text from training_sessions where id='a4000000-0000-4000-8000-00000000000b'$$,array['draft'],'sibling keeps its own status');
select results_eq($$select revision from training_sessions where id='a4000000-0000-4000-8000-00000000000b'$$,array[2],'sibling revision is bumped so an open form goes stale');
select results_eq($$select updated_by from training_sessions where id='a4000000-0000-4000-8000-00000000000b'$$,array['a1000000-0000-4000-8000-000000000001'::uuid],'sibling records the acting coach');
select results_eq($$select count(*) from training_sessions where id='a4000000-0000-4000-8000-00000000000b' and starts_at=pg_temp.at_day(14,'16:15') and ends_at=pg_temp.at_day(14,'17:30') and theme_block=1$$,array[1::bigint],'sibling times and theme block are untouched');

-- Allt utanför målmängden ska stå kvar orört.
select results_eq($$select focus||':'||revision from training_sessions where id='a4000000-0000-4000-8000-00000000000d'$$,array['Start:1'],'another weekday in the same block is untouched');
select results_eq($$select focus||':'||revision from training_sessions where id='a4000000-0000-4000-8000-00000000000e'$$,array['Start:1'],'the same weekday in another block is untouched');
select results_eq($$select focus||':'||revision from training_sessions where id='a4000000-0000-4000-8000-00000000000c'$$,array['Start:1'],'a past session is kept as history');
select results_eq($$select focus||':'||revision from training_sessions where id='a4000000-0000-4000-8000-00000000000f'$$,array['Start:1'],'a completed session is untouched');
select results_eq($$select focus||':'||revision from training_sessions where id='a4000000-0000-4000-8000-000000000010'$$,array['Start:1'],'a cancelled session is untouched');
select results_eq($$select focus||':'||revision from training_sessions where id='a4000000-0000-4000-8000-000000000011'$$,array['Nytt fokus:2'],'the second sibling is updated too, so the loop runs more than once');
select results_eq($$select string_agg(position::text,',' order by position) from training_items where training_session_id='a4000000-0000-4000-8000-000000000011'$$,array['1,2'],'the second sibling also gets renumbered positions');
select results_eq($$select count(*) from training_items where title='Gammal övning'$$,array[6::bigint],'only the edited session and its two siblings had items replaced');
select results_eq($$select count(distinct focus) from training_sessions where theme_block=1 and extract(isodow from (starts_at at time zone 'Europe/Stockholm'))=extract(isodow from (pg_temp.at_day(7,'16:15') at time zone 'Europe/Stockholm')) and status in ('draft','planned') and (starts_at at time zone 'Europe/Stockholm')::date>=(now() at time zone 'Europe/Stockholm')::date$$,array[1::bigint],'M2: upcoming sessions on this weekday converge to one focus');

-- Idempotens och konflikter.
select results_eq($$select save_training_plan_series('a1000000-0000-4000-8000-000000000001','a2000000-0000-4000-8000-000000000001','a3000000-0000-4000-8000-000000000001','a4000000-0000-4000-8000-00000000000a',1,'series-1','Nytt fokus','NYTT','Anteckning','planned','[{"section":"technique","title":"Ny övning","coachingPoints":["Titta upp"]},{"section":"closing","title":"Avslut","coachingPoints":[]}]')$$,array[0],'exact retry writes nothing and reports nothing written');
select results_eq($$select revision from training_sessions where id='a4000000-0000-4000-8000-00000000000b'$$,array[2],'retry does not bump the sibling revision again');
select throws_ok($$select save_training_plan_series('a1000000-0000-4000-8000-000000000001','a2000000-0000-4000-8000-000000000001','a3000000-0000-4000-8000-000000000001','a4000000-0000-4000-8000-00000000000a',1,'series-1','Annat fokus','NYTT','Anteckning','planned','[]')$$,'P0001','REQUEST_CONFLICT','a reused request id with new content is rejected');
select throws_ok($$select save_training_plan_series('a1000000-0000-4000-8000-000000000001','a2000000-0000-4000-8000-000000000001','a3000000-0000-4000-8000-000000000001','a4000000-0000-4000-8000-00000000000a',1,'series-stale','Stale','X','','planned','[]')$$,'P0001','STALE_TRAINING_PLAN','a stale expected revision is rejected');
select results_eq($$select focus||':'||revision from training_sessions where id='a4000000-0000-4000-8000-00000000000b'$$,array['Nytt fokus:2'],'a rejected series save writes nothing to the siblings');


-- Symmetri: samma operation från den andra veckodagen ska bete sig spegelvänt och aldrig nå måndagsserien.
select results_eq($$select save_training_plan_series('a1000000-0000-4000-8000-000000000001','a2000000-0000-4000-8000-000000000001','a3000000-0000-4000-8000-000000000001','a4000000-0000-4000-8000-00000000000d',1,'series-other-weekday','Lördagsfokus','LÖR','','planned','[{"section":"technique","title":"Lördagsövning","coachingPoints":[]}]')$$,array[1],'the other weekday forms its own series');
select results_eq($$select focus from training_sessions where id='a4000000-0000-4000-8000-000000000012'$$,array['Lördagsfokus'],'the other weekday sibling receives the plan');
select results_eq($$select count(*) from training_sessions where id in ('a4000000-0000-4000-8000-00000000000b','a4000000-0000-4000-8000-000000000011') and focus='Nytt fokus'$$,array[2::bigint],'saving one weekday never touches the other weekday series');

-- Regression: en repris efter att en kollega hunnit redigera ett syskon får inte skriva om syskonet.
update training_sessions set focus='Kollegans ändring',revision=revision+1,last_save_request_id='colleague',last_save_payload_hash='x' where id='a4000000-0000-4000-8000-00000000000b';
select results_eq($$select save_training_plan_series('a1000000-0000-4000-8000-000000000001','a2000000-0000-4000-8000-000000000001','a3000000-0000-4000-8000-000000000001','a4000000-0000-4000-8000-00000000000a',1,'series-1','Nytt fokus','NYTT','Anteckning','planned','[{"section":"technique","title":"Ny övning","coachingPoints":["Titta upp"]},{"section":"closing","title":"Avslut","coachingPoints":[]}]')$$,array[0],'a replayed series reports that nothing was written');
select results_eq($$select focus from training_sessions where id='a4000000-0000-4000-8000-00000000000b'$$,array['Kollegans ändring'],'a replayed series does not overwrite a colleague edit made since');

-- Regression: ett inställt pass får inte spridas till serien.
select throws_ok($$select save_training_plan_series('a1000000-0000-4000-8000-000000000001','a2000000-0000-4000-8000-000000000001','a3000000-0000-4000-8000-000000000001','a4000000-0000-4000-8000-000000000010',1,'series-cancelled','X','X','','planned','[]')$$,'P0001','TRAINING_CANCELLED','a cancelled session cannot seed the series');

-- Den okontrollerade varianten ska inte gå att nå ens som service_role.
select throws_ok($$select save_training_plan_series_unchecked('a1000000-0000-4000-8000-000000000001','a2000000-0000-4000-8000-000000000001','a3000000-0000-4000-8000-000000000001','a4000000-0000-4000-8000-00000000000a',1,'unchecked','X','X','','planned','[]')$$,'42501','permission denied for function save_training_plan_series_unchecked','the unchecked variant is unreachable');

select * from finish();rollback;
