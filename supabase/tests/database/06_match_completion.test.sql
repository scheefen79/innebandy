begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(25);

insert into auth.users (id, email) values
  ('d1000000-0000-4000-8000-000000000001', 'completion-coach@example.test'),
  ('d1000000-0000-4000-8000-000000000002', 'completion-outsider@example.test'),
  ('d1000000-0000-4000-8000-000000000003', 'completion-inactive@example.test');
insert into public.teams (id, name, slug) values ('d2000000-0000-4000-8000-000000000001', 'Completion team', 'completion-team');
insert into public.team_members (team_id, user_id, is_active) values
  ('d2000000-0000-4000-8000-000000000001', 'd1000000-0000-4000-8000-000000000001', true),
  ('d2000000-0000-4000-8000-000000000001', 'd1000000-0000-4000-8000-000000000003', false);
insert into public.seasons (id, team_id, name, starts_on, ends_on) values ('d3000000-0000-4000-8000-000000000001', 'd2000000-0000-4000-8000-000000000001', 'Completion season', '2026-08-01', '2027-05-31');
insert into public.players (id, team_id, season_id, first_name, level, rotation_order) values
  ('d4000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','Removed',1,1),
  ('d4000000-0000-4000-8000-000000000002','d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','Manual',2,2),
  ('d4000000-0000-4000-8000-000000000003','d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','Regular absent',3,3),
  ('d4000000-0000-4000-8000-000000000004','d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','Extra',1,4);
insert into public.matches (id, team_id, season_id, opponent, starts_at, target_players, request_id, status) values
  ('d5000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','Past','2026-08-23 10:00+00',2,'d6000000-0000-4000-8000-000000000001','upcoming'),
  ('d5000000-0000-4000-8000-000000000002','d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','Future','2027-01-01 10:00+00',1,'d6000000-0000-4000-8000-000000000002','upcoming'),
  ('d5000000-0000-4000-8000-000000000003','d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','Incomplete','2026-08-22 10:00+00',2,'d6000000-0000-4000-8000-000000000003','upcoming');
insert into public.match_players (team_id, season_id, match_id, player_id, selection_type, selection_source, selection_status, replaced_player_id) values
  ('d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000001','d4000000-0000-4000-8000-000000000001','regular','manual','removed','d4000000-0000-4000-8000-000000000002'),
  ('d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000001','d4000000-0000-4000-8000-000000000002','regular','manual','selected','d4000000-0000-4000-8000-000000000001'),
  ('d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000001','d4000000-0000-4000-8000-000000000003','regular','automatic','selected',null),
  ('d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000001','d4000000-0000-4000-8000-000000000004','extra','manual','selected',null),
  ('d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000002','d4000000-0000-4000-8000-000000000003','regular','automatic','selected',null),
  ('d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000003','d4000000-0000-4000-8000-000000000003','regular','automatic','selected',null);

set local role authenticated;
set local request.jwt.claim.sub = 'd1000000-0000-4000-8000-000000000001';
select lives_ok($$select public.get_match_completion_source('d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000001')$$, 'active coach can read completion source');
select results_eq($$select jsonb_array_length(public.get_match_completion_source('d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000001')->'participants')$$, array[3], 'source contains exactly selected rows');
select results_eq($$select count(*) from jsonb_array_elements(public.get_match_completion_source('d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000001')->'participants') p where p->>'playerId'='d4000000-0000-4000-8000-000000000001'$$, array[0::bigint], 'manual removed player is excluded');
do $$ begin
  perform set_config('test.completion_fp', public.get_match_completion_source('d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000001')->>'fingerprint', true);
  perform set_config('test.future_completion_fp', public.get_match_completion_source('d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000002')->>'fingerprint', true);
  perform set_config('test.incomplete_completion_fp', public.get_match_completion_source('d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000003')->>'fingerprint', true);
end $$;
select throws_ok($$select public.complete_match('d1000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000001','x','[]')$$, '42501', 'permission denied for function complete_match', 'authenticated cannot complete directly');
reset role;
set local role anon;
select throws_ok($$select public.get_match_completion_source('d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000001')$$, '42501', 'permission denied for function get_match_completion_source', 'anonymous cannot read completion source');
reset role;

select throws_ok($$do $b$ begin update public.match_players set played=true where match_id='d5000000-0000-4000-8000-000000000001' and player_id='d4000000-0000-4000-8000-000000000003'; set constraints match_players_validate_participation immediate; end $b$;$$, '23514', 'INVALID_PARTICIPATION_STATE', 'played cannot be set on upcoming match');
select throws_ok($$do $b$ begin update public.matches set status='cancelled' where id='d5000000-0000-4000-8000-000000000002'; update public.match_players set played=true where match_id='d5000000-0000-4000-8000-000000000002'; set constraints match_players_validate_participation immediate; end $b$;$$, '23514', 'INVALID_PARTICIPATION_STATE', 'played cannot be set on cancelled match');
select throws_ok($$do $b$ begin update public.matches set status='completed' where id='d5000000-0000-4000-8000-000000000001'; update public.match_players set played=true where match_id='d5000000-0000-4000-8000-000000000001' and selection_status='removed'; set constraints match_players_validate_participation immediate; end $b$;$$, '23514', 'INVALID_PARTICIPATION_STATE', 'manual removed player can never be played');

set local role service_role;
set local request.jwt.claims = '{"role":"service_role"}';
select throws_ok($$select public.complete_match('d1000000-0000-4000-8000-000000000002','d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000001','x','[]')$$, '42501', 'NOT_AUTHORIZED', 'outsider actor is rejected');
select throws_ok($$select public.complete_match('d1000000-0000-4000-8000-000000000003','d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000001','x','[]')$$, '42501', 'NOT_AUTHORIZED', 'inactive actor is rejected');
select throws_ok($$select public.complete_match('d1000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000001','x','{}')$$, 'P0001', 'INVALID_PARTICIPATION', 'participation must be an array');
select throws_ok($$select public.complete_match('d1000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000001','x','[{"playerId":"d4000000-0000-4000-8000-000000000002","played":"yes"}]')$$, 'P0001', 'INVALID_PARTICIPATION', 'played must be boolean');
select throws_ok($$select public.complete_match('d1000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000001','x','[{"playerId":"d4000000-0000-4000-8000-000000000002","played":true},{"playerId":"d4000000-0000-4000-8000-000000000002","played":false}]')$$, 'P0001', 'INVALID_PARTICIPATION', 'duplicate player is rejected');
select throws_ok($$select public.complete_match('d1000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000002',current_setting('test.future_completion_fp'),'[{"playerId":"d4000000-0000-4000-8000-000000000003","played":true}]')$$, 'P0001', 'MATCH_NOT_AVAILABLE', 'future match is rejected');
select throws_ok($$select public.complete_match('d1000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000003',current_setting('test.incomplete_completion_fp'),'[{"playerId":"d4000000-0000-4000-8000-000000000003","played":true}]')$$, 'P0001', 'MATCH_NOT_AVAILABLE', 'incomplete regular roster is rejected');
select throws_ok($$select public.complete_match('d1000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000001','stale','[{"playerId":"d4000000-0000-4000-8000-000000000002","played":true},{"playerId":"d4000000-0000-4000-8000-000000000003","played":false},{"playerId":"d4000000-0000-4000-8000-000000000004","played":true}]')$$, 'P0001', 'STALE_SELECTION', 'stale source is rejected');
select throws_ok($$select public.complete_match('d1000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000001',current_setting('test.completion_fp'),'[{"playerId":"d4000000-0000-4000-8000-000000000002","played":true}]')$$, 'P0001', 'INVALID_PARTICIPATION', 'missing selected players are rejected');
select throws_ok($$select public.complete_match('d1000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000001',current_setting('test.completion_fp'),'[{"playerId":"d4000000-0000-4000-8000-000000000002","played":true},{"playerId":"d4000000-0000-4000-8000-000000000003","played":false},{"playerId":"d4000000-0000-4000-8000-000000000004","played":true},{"playerId":"d4000000-0000-4000-8000-000000000001","played":false}]')$$, 'P0001', 'INVALID_PARTICIPATION', 'manual removed player is rejected as an extra decision');
select lives_ok($$select public.complete_match('d1000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000001',current_setting('test.completion_fp'),'[{"playerId":"d4000000-0000-4000-8000-000000000002","played":true},{"playerId":"d4000000-0000-4000-8000-000000000003","played":false},{"playerId":"d4000000-0000-4000-8000-000000000004","played":true}]')$$, 'valid completion updates match and participation atomically');
reset role;
select results_eq($$select status from public.matches where id='d5000000-0000-4000-8000-000000000001'$$, array['completed'::text], 'match is completed');
select results_eq($$select player_id::text || ':' || played::text from public.match_players where match_id='d5000000-0000-4000-8000-000000000001' order by player_id$$, array['d4000000-0000-4000-8000-000000000001:false'::text,'d4000000-0000-4000-8000-000000000002:true'::text,'d4000000-0000-4000-8000-000000000003:false'::text,'d4000000-0000-4000-8000-000000000004:true'::text], 'all saved decisions and removed state are preserved');
select results_eq($$select (p->>'baselineRegularCount')::integer from jsonb_array_elements(private.regular_allocation_source('d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','2026-08-01 00:00+00')->'players') p where p->>'id' in ('d4000000-0000-4000-8000-000000000002','d4000000-0000-4000-8000-000000000003') order by p->>'id'$$, array[1,0], 'regular history counts played and excludes absence');
select results_eq($$select count(*) from public.match_players mp join public.matches m on m.id=mp.match_id where mp.player_id='d4000000-0000-4000-8000-000000000004' and mp.selection_type='extra' and mp.played and m.status='completed'$$, array[1::bigint], 'extra history counts played separately');
set local role service_role;
set local request.jwt.claims = '{"role":"service_role"}';
select lives_ok($$select public.complete_match('d1000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000001','old','[{"playerId":"d4000000-0000-4000-8000-000000000002","played":true},{"playerId":"d4000000-0000-4000-8000-000000000003","played":false},{"playerId":"d4000000-0000-4000-8000-000000000004","played":true}]')$$, 'identical retry converges before fingerprint check');
select throws_ok($$select public.complete_match('d1000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001','d3000000-0000-4000-8000-000000000001','d5000000-0000-4000-8000-000000000001','old','[{"playerId":"d4000000-0000-4000-8000-000000000002","played":false},{"playerId":"d4000000-0000-4000-8000-000000000003","played":false},{"playerId":"d4000000-0000-4000-8000-000000000004","played":true}]')$$, 'P0001', 'MATCH_ALREADY_COMPLETED', 'different retry cannot overwrite first result');

select * from finish();
rollback;
