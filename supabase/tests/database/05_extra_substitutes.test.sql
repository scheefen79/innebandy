begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(27);

insert into auth.users (id, email) values
  ('c1000000-0000-4000-8000-000000000001', 'extra-coach@example.test'),
  ('c1000000-0000-4000-8000-000000000002', 'extra-outsider@example.test'),
  ('c1000000-0000-4000-8000-000000000003', 'extra-inactive@example.test');
insert into public.teams (id, name, slug)
values ('c2000000-0000-4000-8000-000000000001', 'Extra team', 'extra-team');
insert into public.team_members (team_id, user_id) values
  ('c2000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000001');
insert into public.team_members (team_id, user_id, is_active) values
  ('c2000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000003', false);
insert into public.seasons (id, team_id, name, starts_on, ends_on)
values ('c3000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000001', 'Extra season', '2026-08-01', '2027-05-31');
insert into public.players (id, team_id, season_id, first_name, level, rotation_order) values
  ('c4000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000001', 'Regular', 1, 1),
  ('c4000000-0000-4000-8000-000000000002', 'c2000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000001', 'Candidate', 2, 2),
  ('c4000000-0000-4000-8000-000000000003', 'c2000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000001', 'History', 3, 3),
  ('c4000000-0000-4000-8000-000000000004', 'c2000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000001', 'Inactive', 1, 4);
update public.players set is_active = false where id = 'c4000000-0000-4000-8000-000000000004';
insert into public.matches (id, team_id, season_id, opponent, starts_at, target_players, request_id, status) values
  ('c5000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000001', 'Future', '2027-03-01 10:00+00', 1, 'c6000000-0000-4000-8000-000000000001', 'upcoming'),
  ('c5000000-0000-4000-8000-000000000002', 'c2000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000001', 'Completed', '2026-08-01 10:00+00', 1, 'c6000000-0000-4000-8000-000000000002', 'completed'),
  ('c5000000-0000-4000-8000-000000000003', 'c2000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000001', 'Planned history', '2027-02-01 10:00+00', 1, 'c6000000-0000-4000-8000-000000000003', 'upcoming');
insert into public.match_players (team_id, season_id, match_id, player_id, selection_type, selection_source, selection_status, played, created_at, updated_at) values
  ('c2000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000001', 'c5000000-0000-4000-8000-000000000001', 'c4000000-0000-4000-8000-000000000001', 'regular', 'automatic', 'selected', false, now(), now()),
  ('c2000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000001', 'c5000000-0000-4000-8000-000000000002', 'c4000000-0000-4000-8000-000000000003', 'extra', 'manual', 'selected', true, '2026-08-20', '2026-08-21'),
  ('c2000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000001', 'c5000000-0000-4000-8000-000000000003', 'c4000000-0000-4000-8000-000000000002', 'extra', 'manual', 'selected', false, now(), now());

select throws_ok(
  $$insert into public.match_players (team_id, season_id, match_id, player_id, selection_type, selection_source, selection_status) values ('c2000000-0000-4000-8000-000000000001','c3000000-0000-4000-8000-000000000001','c5000000-0000-4000-8000-000000000001','c4000000-0000-4000-8000-000000000002','extra','automatic','selected')$$,
  '23514', null, 'extra rows cannot be automatic'
);

set local role authenticated;
set local request.jwt.claim.sub = 'c1000000-0000-4000-8000-000000000001';
select lives_ok($$select public.get_extra_substitute_source('c2000000-0000-4000-8000-000000000001','c3000000-0000-4000-8000-000000000001','c5000000-0000-4000-8000-000000000001')$$, 'active coach can read extra candidates');
select results_eq(
  $$select jsonb_array_length(public.get_extra_substitute_source('c2000000-0000-4000-8000-000000000001','c3000000-0000-4000-8000-000000000001','c5000000-0000-4000-8000-000000000001')->'candidates')$$,
  array[2], 'only active players without a current match decision are candidates'
);
select results_eq(
  $$select candidate->>'lastCompletedExtraAt' from jsonb_array_elements(public.get_extra_substitute_source('c2000000-0000-4000-8000-000000000001','c3000000-0000-4000-8000-000000000001','c5000000-0000-4000-8000-000000000001')->'candidates') candidate where candidate->>'id'='c4000000-0000-4000-8000-000000000003'$$,
  array['2026-08-01T10:00:00.000Z'::text], 'last completed extra uses match starts_at rather than row timestamps'
);
select results_eq(
  $$select (candidate->>'completedExtraCount')::integer from jsonb_array_elements(public.get_extra_substitute_source('c2000000-0000-4000-8000-000000000001','c3000000-0000-4000-8000-000000000001','c5000000-0000-4000-8000-000000000001')->'candidates') candidate where candidate->>'id'='c4000000-0000-4000-8000-000000000002'$$,
  array[0], 'planned extra rows do not count as completed history'
);
select throws_ok(
  $$select public.add_extra_substitute('c1000000-0000-4000-8000-000000000001','c2000000-0000-4000-8000-000000000001','c3000000-0000-4000-8000-000000000001','c5000000-0000-4000-8000-000000000001','c4000000-0000-4000-8000-000000000002','x')$$,
  '42501', 'permission denied for function add_extra_substitute', 'authenticated cannot call add directly'
);
select throws_ok(
  $$select public.remove_extra_substitute('c1000000-0000-4000-8000-000000000001','c2000000-0000-4000-8000-000000000001','c3000000-0000-4000-8000-000000000001','c5000000-0000-4000-8000-000000000001','c4000000-0000-4000-8000-000000000002','x')$$,
  '42501', 'permission denied for function remove_extra_substitute', 'authenticated cannot call remove directly'
);
do $$ begin perform set_config('test.extra_fp', public.get_extra_substitute_source('c2000000-0000-4000-8000-000000000001','c3000000-0000-4000-8000-000000000001','c5000000-0000-4000-8000-000000000001')->>'fingerprint', true); end $$;

reset role;
set local role service_role;
set local request.jwt.claims = '{"role":"service_role"}';
select throws_ok(
  $$select public.add_extra_substitute('c1000000-0000-4000-8000-000000000002','c2000000-0000-4000-8000-000000000001','c3000000-0000-4000-8000-000000000001','c5000000-0000-4000-8000-000000000001','c4000000-0000-4000-8000-000000000002',current_setting('test.extra_fp'))$$,
  '42501', 'NOT_AUTHORIZED', 'outsider actor is rejected'
);
select throws_ok(
  $$select public.add_extra_substitute('c1000000-0000-4000-8000-000000000003','c2000000-0000-4000-8000-000000000001','c3000000-0000-4000-8000-000000000001','c5000000-0000-4000-8000-000000000001','c4000000-0000-4000-8000-000000000002',current_setting('test.extra_fp'))$$,
  '42501', 'NOT_AUTHORIZED', 'inactive actor is rejected'
);
select throws_ok(
  $$select public.add_extra_substitute('c1000000-0000-4000-8000-000000000001','c2000000-0000-4000-8000-000000000001','c3000000-0000-4000-8000-000000000001','c5000000-0000-4000-8000-000000000001','c4000000-0000-4000-8000-000000000004',current_setting('test.extra_fp'))$$,
  'P0001', 'INVALID_EXTRA_SELECTION', 'inactive candidate is rejected'
);
select throws_ok(
  $$select public.add_extra_substitute('c1000000-0000-4000-8000-000000000001','c2000000-0000-4000-8000-000000000001','c3000000-0000-4000-8000-000000000001','c5000000-0000-4000-8000-000000000001','c4000000-0000-4000-8000-000000000001',current_setting('test.extra_fp'))$$,
  'P0001', 'INVALID_EXTRA_SELECTION', 'regular selected candidate is rejected'
);
reset role;
select throws_ok(
  $$do $b$ begin delete from public.match_players where match_id='c5000000-0000-4000-8000-000000000001' and selection_type='regular'; perform set_config('request.jwt.claims','{"role":"service_role"}',true); perform public.add_extra_substitute('c1000000-0000-4000-8000-000000000001','c2000000-0000-4000-8000-000000000001','c3000000-0000-4000-8000-000000000001','c5000000-0000-4000-8000-000000000001','c4000000-0000-4000-8000-000000000002','old'); end $b$;$$,
  'P0001', 'MATCH_NOT_AVAILABLE', 'extra cannot be added before the regular roster is complete'
);
set local role service_role;
set local request.jwt.claims = '{"role":"service_role"}';
select throws_ok(
  $$select public.add_extra_substitute('c1000000-0000-4000-8000-000000000001','c2000000-0000-4000-8000-000000000001','c3000000-0000-4000-8000-000000000001','c5000000-0000-4000-8000-000000000001','c4000000-0000-4000-8000-000000000002','stale')$$,
  'P0001', 'STALE_SELECTION', 'stale add is rejected'
);
select lives_ok(
  $$select public.add_extra_substitute('c1000000-0000-4000-8000-000000000001','c2000000-0000-4000-8000-000000000001','c3000000-0000-4000-8000-000000000001','c5000000-0000-4000-8000-000000000001','c4000000-0000-4000-8000-000000000002',current_setting('test.extra_fp'))$$,
  'valid extra substitute is added'
);
select lives_ok(
  $$select public.add_extra_substitute('c1000000-0000-4000-8000-000000000001','c2000000-0000-4000-8000-000000000001','c3000000-0000-4000-8000-000000000001','c5000000-0000-4000-8000-000000000001','c4000000-0000-4000-8000-000000000002','old')$$,
  'identical add retry converges before stale comparison'
);
reset role;
select results_eq(
  $$select selection_type || ':' || selection_source || ':' || selection_status || ':' || played::text from public.match_players where match_id='c5000000-0000-4000-8000-000000000001' and player_id='c4000000-0000-4000-8000-000000000002'$$,
  array['extra:manual:selected:false'::text], 'extra row has canonical planned shape'
);
select results_eq(
  $$select target_players from public.matches where id='c5000000-0000-4000-8000-000000000001'$$,
  array[1], 'adding extra does not change regular target'
);

set local role authenticated;
set local request.jwt.claim.sub = 'c1000000-0000-4000-8000-000000000001';
do $$ begin perform set_config('test.remove_fp', public.get_extra_substitute_source('c2000000-0000-4000-8000-000000000001','c3000000-0000-4000-8000-000000000001','c5000000-0000-4000-8000-000000000001')->>'fingerprint', true); end $$;
reset role;
set local role service_role;
set local request.jwt.claims = '{"role":"service_role"}';
select lives_ok(
  $$select public.remove_extra_substitute('c1000000-0000-4000-8000-000000000001','c2000000-0000-4000-8000-000000000001','c3000000-0000-4000-8000-000000000001','c5000000-0000-4000-8000-000000000001','c4000000-0000-4000-8000-000000000002',current_setting('test.remove_fp'))$$,
  'planned extra substitute can be removed'
);
select lives_ok(
  $$select public.remove_extra_substitute('c1000000-0000-4000-8000-000000000001','c2000000-0000-4000-8000-000000000001','c3000000-0000-4000-8000-000000000001','c5000000-0000-4000-8000-000000000001','c4000000-0000-4000-8000-000000000002','old')$$,
  'identical remove retry converges before stale comparison'
);
select throws_ok(
  $$select public.remove_extra_substitute('c1000000-0000-4000-8000-000000000001','c2000000-0000-4000-8000-000000000001','c3000000-0000-4000-8000-000000000001','c5000000-0000-4000-8000-000000000001','c4000000-0000-4000-8000-000000000001','old')$$,
  'P0001', 'INVALID_EXTRA_SELECTION', 'remove cannot touch a regular selection'
);
reset role;
select results_eq(
  $$select count(*) from public.match_players where match_id='c5000000-0000-4000-8000-000000000001' and selection_type='regular'$$,
  array[1::bigint], 'extra operations leave regular selection unchanged'
);
select throws_ok(
  $$do $b$ begin update public.matches set status='completed' where id='c5000000-0000-4000-8000-000000000001'; perform set_config('request.jwt.claims','{"role":"service_role"}',true); perform public.remove_extra_substitute('c1000000-0000-4000-8000-000000000001','c2000000-0000-4000-8000-000000000001','c3000000-0000-4000-8000-000000000001','c5000000-0000-4000-8000-000000000001','c4000000-0000-4000-8000-000000000002','old'); end $b$;$$,
  'P0001', 'MATCH_NOT_AVAILABLE', 'completed match is rejected before idempotent remove'
);
select throws_ok(
  $$do $b$ begin update public.matches set status='cancelled' where id='c5000000-0000-4000-8000-000000000001'; perform set_config('request.jwt.claims','{"role":"service_role"}',true); perform public.remove_extra_substitute('c1000000-0000-4000-8000-000000000001','c2000000-0000-4000-8000-000000000001','c3000000-0000-4000-8000-000000000001','c5000000-0000-4000-8000-000000000001','c4000000-0000-4000-8000-000000000002','old'); end $b$;$$,
  'P0001', 'MATCH_NOT_AVAILABLE', 'cancelled match is rejected before idempotent remove'
);
select throws_ok(
  $$do $b$ begin update public.matches set starts_at='2026-01-01 10:00+00' where id='c5000000-0000-4000-8000-000000000001'; perform set_config('request.jwt.claims','{"role":"service_role"}',true); perform public.remove_extra_substitute('c1000000-0000-4000-8000-000000000001','c2000000-0000-4000-8000-000000000001','c3000000-0000-4000-8000-000000000001','c5000000-0000-4000-8000-000000000001','c4000000-0000-4000-8000-000000000002','old'); end $b$;$$,
  'P0001', 'MATCH_NOT_AVAILABLE', 'past match is rejected before idempotent remove'
);
select throws_ok(
  $$select public.add_extra_substitute('c1000000-0000-4000-8000-000000000001','c2000000-0000-4000-8000-000000000001','ffffffff-0000-4000-8000-000000000001','c5000000-0000-4000-8000-000000000001','c4000000-0000-4000-8000-000000000002','old')$$,
  'P0001', 'MATCH_NOT_AVAILABLE', 'another season is rejected generically'
);
select throws_ok(
  $$do $b$ begin insert into public.match_players (team_id,season_id,match_id,player_id,selection_type,selection_source,selection_status) values ('c2000000-0000-4000-8000-000000000001','c3000000-0000-4000-8000-000000000001','c5000000-0000-4000-8000-000000000001','c4000000-0000-4000-8000-000000000002','extra','manual','selected'); update public.players set is_active=false where id='c4000000-0000-4000-8000-000000000002'; perform set_config('request.jwt.claims','{"role":"service_role"}',true); perform public.add_extra_substitute('c1000000-0000-4000-8000-000000000001','c2000000-0000-4000-8000-000000000001','c3000000-0000-4000-8000-000000000001','c5000000-0000-4000-8000-000000000001','c4000000-0000-4000-8000-000000000002','old'); end $b$;$$,
  'P0001', 'INVALID_EXTRA_SELECTION', 'inactive player is rejected before idempotent add'
);

set local role anon;
select throws_ok(
  $$select public.get_extra_substitute_source('c2000000-0000-4000-8000-000000000001','c3000000-0000-4000-8000-000000000001','c5000000-0000-4000-8000-000000000001')$$,
  '42501', 'permission denied for function get_extra_substitute_source', 'anonymous cannot read candidates'
);

select * from finish();
rollback;
