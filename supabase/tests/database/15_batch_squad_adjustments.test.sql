begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(27);

insert into auth.users (id, email) values
  ('d1000000-0000-4000-8000-000000000001', 'batch-coach@example.test'),
  ('d1000000-0000-4000-8000-000000000002', 'batch-viewer@example.test'),
  ('d1000000-0000-4000-8000-000000000003', 'batch-outsider@example.test');
insert into public.teams (id, name, slug) values ('d2000000-0000-4000-8000-000000000001', 'Batch team', 'batch-team');
insert into public.team_members (team_id, user_id, role) values
  ('d2000000-0000-4000-8000-000000000001', 'd1000000-0000-4000-8000-000000000001', 'coach'),
  ('d2000000-0000-4000-8000-000000000001', 'd1000000-0000-4000-8000-000000000002', 'viewer');
insert into public.seasons (id, team_id, name, starts_on, ends_on)
values ('d3000000-0000-4000-8000-000000000001', 'd2000000-0000-4000-8000-000000000001', 'Batch season', '2026-08-01', '2027-05-31');
insert into public.players (id, team_id, season_id, first_name, level, rotation_order) values
  ('d4000000-0000-4000-8000-000000000001', 'd2000000-0000-4000-8000-000000000001', 'd3000000-0000-4000-8000-000000000001', 'RegularA', 1, 1),
  ('d4000000-0000-4000-8000-000000000002', 'd2000000-0000-4000-8000-000000000001', 'd3000000-0000-4000-8000-000000000001', 'RegularB', 2, 2),
  ('d4000000-0000-4000-8000-000000000003', 'd2000000-0000-4000-8000-000000000001', 'd3000000-0000-4000-8000-000000000001', 'BenchC', 2, 3),
  ('d4000000-0000-4000-8000-000000000004', 'd2000000-0000-4000-8000-000000000001', 'd3000000-0000-4000-8000-000000000001', 'BenchD', 3, 4),
  ('d4000000-0000-4000-8000-000000000005', 'd2000000-0000-4000-8000-000000000001', 'd3000000-0000-4000-8000-000000000001', 'BenchE', 3, 5),
  ('d4000000-0000-4000-8000-000000000006', 'd2000000-0000-4000-8000-000000000001', 'd3000000-0000-4000-8000-000000000001', 'Inactive', 3, 6);
update public.players set is_active = false where id = 'd4000000-0000-4000-8000-000000000006';
insert into public.matches (id, team_id, season_id, opponent, starts_at, target_players, request_id) values
  ('d5000000-0000-4000-8000-000000000001', 'd2000000-0000-4000-8000-000000000001', 'd3000000-0000-4000-8000-000000000001', 'Swap', '2027-03-01 10:00+00', 2, 'd6000000-0000-4000-8000-000000000001'),
  ('d5000000-0000-4000-8000-000000000002', 'd2000000-0000-4000-8000-000000000001', 'd3000000-0000-4000-8000-000000000001', 'Extras', '2027-03-08 10:00+00', 2, 'd6000000-0000-4000-8000-000000000002');
insert into public.match_players (team_id, season_id, match_id, player_id, selection_type, selection_source, selection_status) values
  ('d2000000-0000-4000-8000-000000000001', 'd3000000-0000-4000-8000-000000000001', 'd5000000-0000-4000-8000-000000000001', 'd4000000-0000-4000-8000-000000000001', 'regular', 'automatic', 'selected'),
  ('d2000000-0000-4000-8000-000000000001', 'd3000000-0000-4000-8000-000000000001', 'd5000000-0000-4000-8000-000000000001', 'd4000000-0000-4000-8000-000000000002', 'regular', 'automatic', 'selected'),
  ('d2000000-0000-4000-8000-000000000001', 'd3000000-0000-4000-8000-000000000001', 'd5000000-0000-4000-8000-000000000002', 'd4000000-0000-4000-8000-000000000001', 'regular', 'automatic', 'selected'),
  ('d2000000-0000-4000-8000-000000000001', 'd3000000-0000-4000-8000-000000000001', 'd5000000-0000-4000-8000-000000000002', 'd4000000-0000-4000-8000-000000000002', 'regular', 'automatic', 'selected');

set local role authenticated;
set local request.jwt.claim.sub = 'd1000000-0000-4000-8000-000000000001';
select throws_ok(
  $$select public.create_manual_regular_adjustments('d1000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000001','[]'::jsonb,'x')$$,
  '42501', 'permission denied for function create_manual_regular_adjustments', 'authenticated cannot call batch swap directly'
);
select throws_ok(
  $$select public.add_extra_substitutes('d1000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000002',array['d4000000-0000-4000-8000-000000000003']::uuid[],'x')$$,
  '42501', 'permission denied for function add_extra_substitutes', 'authenticated cannot call batch extras directly'
);
do $$ begin
  perform set_config('test.swap_fp', public.get_manual_adjustment_source('d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000001')->>'fingerprint', true);
  perform set_config('test.extra_fp', public.get_extra_substitute_source('d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000002')->>'fingerprint', true);
end $$;
set local role anon;
select throws_ok(
  $$select public.add_extra_substitutes('d1000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000002',array['d4000000-0000-4000-8000-000000000003']::uuid[],'x')$$,
  '42501', 'permission denied for function add_extra_substitutes', 'anonymous cannot call batch extras'
);

reset role;
set local role service_role;
set local request.jwt.claims = '{"role":"service_role"}';

-- Swap batch: authorization
select throws_ok(
  $$select public.create_manual_regular_adjustments('d1000000-0000-4000-8000-000000000002','d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000001','[{"outgoingPlayerId":"d4000000-0000-4000-8000-000000000001","incomingPlayerId":"d4000000-0000-4000-8000-000000000003"}]'::jsonb,current_setting('test.swap_fp'))$$,
  '42501', 'NOT_AUTHORIZED', 'viewer cannot batch swap'
);
select throws_ok(
  $$select public.create_manual_regular_adjustments('d1000000-0000-4000-8000-000000000003','d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000001','[{"outgoingPlayerId":"d4000000-0000-4000-8000-000000000001","incomingPlayerId":"d4000000-0000-4000-8000-000000000003"}]'::jsonb,current_setting('test.swap_fp'))$$,
  '42501', 'NOT_AUTHORIZED', 'outsider cannot batch swap'
);
-- Swap batch: invalid input
select throws_ok(
  $$select public.create_manual_regular_adjustments('d1000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000001','[]'::jsonb,current_setting('test.swap_fp'))$$,
  'P0001', 'INVALID_ADJUSTMENT', 'empty swap batch is rejected'
);
select throws_ok(
  $$select public.create_manual_regular_adjustments('d1000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000001','[{"outgoingPlayerId":"d4000000-0000-4000-8000-000000000001","incomingPlayerId":"d4000000-0000-4000-8000-000000000003"},{"outgoingPlayerId":"d4000000-0000-4000-8000-000000000002","incomingPlayerId":"d4000000-0000-4000-8000-000000000003"}]'::jsonb,current_setting('test.swap_fp'))$$,
  'P0001', 'INVALID_ADJUSTMENT', 'same incoming player twice is rejected'
);
select throws_ok(
  $$select public.create_manual_regular_adjustments('d1000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000001','[{"outgoingPlayerId":"d4000000-0000-4000-8000-000000000001","incomingPlayerId":"d4000000-0000-4000-8000-000000000002"}]'::jsonb,current_setting('test.swap_fp'))$$,
  'P0001', 'INVALID_ADJUSTMENT', 'incoming player already in the match is rejected'
);
select throws_ok(
  $$select public.create_manual_regular_adjustments('d1000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000001','[{"outgoingPlayerId":"d4000000-0000-4000-8000-000000000001","incomingPlayerId":"d4000000-0000-4000-8000-000000000006"}]'::jsonb,current_setting('test.swap_fp'))$$,
  'P0001', 'INVALID_ADJUSTMENT', 'inactive incoming player is rejected'
);
select throws_ok(
  $$select public.create_manual_regular_adjustments('d1000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000001','[{"outgoingPlayerId":"not-a-uuid","incomingPlayerId":"d4000000-0000-4000-8000-000000000003"}]'::jsonb,current_setting('test.swap_fp'))$$,
  'P0001', 'INVALID_ADJUSTMENT', 'malformed ids are rejected'
);
select throws_ok(
  $$select public.create_manual_regular_adjustments('d1000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000001','[{"outgoingPlayerId":"d4000000-0000-4000-8000-000000000001","incomingPlayerId":"d4000000-0000-4000-8000-000000000003"}]'::jsonb,'stale')$$,
  'P0001', 'STALE_SELECTION', 'stale swap batch is rejected'
);
-- A valid first pair plus an invalid second pair leaves everything unchanged.
select throws_ok(
  $$select public.create_manual_regular_adjustments('d1000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000001','[{"outgoingPlayerId":"d4000000-0000-4000-8000-000000000001","incomingPlayerId":"d4000000-0000-4000-8000-000000000003"},{"outgoingPlayerId":"d4000000-0000-4000-8000-000000000002","incomingPlayerId":"d4000000-0000-4000-8000-000000000006"}]'::jsonb,current_setting('test.swap_fp'))$$,
  'P0001', 'INVALID_ADJUSTMENT', 'one invalid pair rejects the whole batch'
);
reset role;
select results_eq(
  $$select count(*) from public.match_players where match_id='d5000000-0000-4000-8000-000000000001' and selection_source='automatic'$$,
  array[2::bigint], 'rejected batch leaves the automatic roster untouched'
);
set local role service_role;
set local request.jwt.claims = '{"role":"service_role"}';
select lives_ok(
  $$select public.create_manual_regular_adjustments('d1000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000001','[{"outgoingPlayerId":"d4000000-0000-4000-8000-000000000001","incomingPlayerId":"d4000000-0000-4000-8000-000000000003"},{"outgoingPlayerId":"d4000000-0000-4000-8000-000000000002","incomingPlayerId":"d4000000-0000-4000-8000-000000000004"}]'::jsonb,current_setting('test.swap_fp'))$$,
  'two swaps are saved atomically'
);
select lives_ok(
  $$select public.create_manual_regular_adjustments('d1000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000001','[{"outgoingPlayerId":"d4000000-0000-4000-8000-000000000001","incomingPlayerId":"d4000000-0000-4000-8000-000000000003"},{"outgoingPlayerId":"d4000000-0000-4000-8000-000000000002","incomingPlayerId":"d4000000-0000-4000-8000-000000000004"}]'::jsonb,'old')$$,
  'identical swap retry converges before stale comparison'
);
reset role;
select results_eq(
  $$select count(*) from public.match_players where match_id='d5000000-0000-4000-8000-000000000001' and selection_type='regular' and selection_source='manual'$$,
  array[4::bigint], 'two linked pairs exist after the batch'
);
select results_eq(
  $$select count(*) from public.match_players where match_id='d5000000-0000-4000-8000-000000000001' and selection_type='regular' and selection_status='selected'$$,
  array[2::bigint], 'selected regular count still equals the target'
);

-- Extra batch
set local role service_role;
set local request.jwt.claims = '{"role":"service_role"}';
select throws_ok(
  $$select public.add_extra_substitutes('d1000000-0000-4000-8000-000000000002','d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000002',array['d4000000-0000-4000-8000-000000000003','d4000000-0000-4000-8000-000000000004']::uuid[],current_setting('test.extra_fp'))$$,
  '42501', 'NOT_AUTHORIZED', 'viewer cannot batch add extras'
);
select throws_ok(
  $$select public.add_extra_substitutes('d1000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000002',array['d4000000-0000-4000-8000-000000000003','d4000000-0000-4000-8000-000000000003']::uuid[],current_setting('test.extra_fp'))$$,
  'P0001', 'INVALID_EXTRA_SELECTION', 'duplicate extra ids are rejected'
);
select throws_ok(
  $$select public.add_extra_substitutes('d1000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000002',array['d4000000-0000-4000-8000-000000000003','d4000000-0000-4000-8000-000000000001']::uuid[],current_setting('test.extra_fp'))$$,
  'P0001', 'INVALID_EXTRA_SELECTION', 'regular selected player in the batch rejects the whole batch'
);
select throws_ok(
  $$select public.add_extra_substitutes('d1000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000002',array['d4000000-0000-4000-8000-000000000003','d4000000-0000-4000-8000-000000000006']::uuid[],current_setting('test.extra_fp'))$$,
  'P0001', 'INVALID_EXTRA_SELECTION', 'inactive player in the batch rejects the whole batch'
);
select throws_ok(
  $$select public.add_extra_substitutes('d1000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000002',array['d4000000-0000-4000-8000-000000000003','d4000000-0000-4000-8000-000000000004']::uuid[],'stale')$$,
  'P0001', 'STALE_SELECTION', 'stale extra batch is rejected'
);
select lives_ok(
  $$select public.add_extra_substitutes('d1000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000002',array['d4000000-0000-4000-8000-000000000003','d4000000-0000-4000-8000-000000000004','d4000000-0000-4000-8000-000000000005']::uuid[],current_setting('test.extra_fp'))$$,
  'three extra substitutes are saved atomically'
);
select lives_ok(
  $$select public.add_extra_substitutes('d1000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000002',array['d4000000-0000-4000-8000-000000000003','d4000000-0000-4000-8000-000000000004','d4000000-0000-4000-8000-000000000005']::uuid[],'old')$$,
  'identical extra retry converges before stale comparison'
);
reset role;
select results_eq(
  $$select count(*) from public.match_players where match_id='d5000000-0000-4000-8000-000000000002' and selection_type='extra' and selection_status='selected' and not played$$,
  array[3::bigint], 'extra rows have the planned shape and leave regular rows untouched'
);

set local role service_role;
set local request.jwt.claims = '{"role":"service_role"}';
select throws_ok(
  $$select public.add_extra_substitutes('d1000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000001',array['d4000000-0000-4000-8000-000000000001']::uuid[],'old')$$,
  'P0001', 'INVALID_EXTRA_SELECTION', 'manually removed player cannot become extra in the same match'
);
select throws_ok(
  $$select public.create_manual_regular_adjustments('d1000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000001','[null]'::jsonb,'old')$$,
  'P0001', 'INVALID_ADJUSTMENT', 'null batch element is rejected'
);
reset role;

select * from finish();
rollback;
