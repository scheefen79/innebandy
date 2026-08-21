begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(34);

insert into auth.users (id, email) values
  ('a1000000-0000-4000-8000-000000000001', 'manual-coach@example.test'),
  ('a1000000-0000-4000-8000-000000000002', 'manual-outsider@example.test'),
  ('a1000000-0000-4000-8000-000000000003', 'manual-inactive@example.test');
insert into public.teams (id, name, slug)
values ('a2000000-0000-4000-8000-000000000001', 'Manual team', 'manual-team');
insert into public.team_members (team_id, user_id) values
  ('a2000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001');
insert into public.team_members (team_id, user_id, is_active) values
  ('a2000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000003', false);
insert into public.seasons (id, team_id, name, starts_on, ends_on)
values ('a3000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'Manual season', '2026-08-01', '2027-05-31');
insert into public.players (id, team_id, season_id, first_name, level, rotation_order) values
  ('a4000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000001', 'Outgoing', 1, 1),
  ('a4000000-0000-4000-8000-000000000002', 'a2000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000001', 'Incoming', 2, 2),
  ('a4000000-0000-4000-8000-000000000003', 'a2000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000001', 'Third', 3, 3);
insert into public.matches (id, team_id, season_id, opponent, starts_at, target_players, request_id)
values
  ('a5000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000001', 'Manual opponent', '2027-02-01 10:00+00', 1, 'a6000000-0000-4000-8000-000000000001'),
  ('a5000000-0000-4000-8000-000000000002', 'a2000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000001', 'Other match', '2027-02-08 10:00+00', 1, 'a6000000-0000-4000-8000-000000000002');
insert into public.match_players (team_id, season_id, match_id, player_id, selection_type, selection_source, selection_status)
values ('a2000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000001', 'regular', 'automatic', 'selected');

select throws_ok(
  $$do $b$ begin
    insert into public.match_players (team_id, season_id, match_id, player_id, selection_type, selection_source, selection_status, replaced_player_id)
    values ('a2000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000002', 'regular', 'manual', 'selected', 'a4000000-0000-4000-8000-000000000003');
    set constraints match_players_validate_manual_pair immediate;
  end $b$;$$,
  '23514', 'INVALID_MANUAL_PAIR', 'a single manual row cannot be committed'
);

select throws_ok(
  $$do $b$ begin
    delete from public.match_players where match_id = 'a5000000-0000-4000-8000-000000000001';
    insert into public.match_players (team_id, season_id, match_id, player_id, selection_type, selection_source, selection_status, replaced_player_id) values
      ('a2000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000001', 'regular', 'manual', 'removed', 'a4000000-0000-4000-8000-000000000002'),
      ('a2000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000002', 'regular', 'manual', 'selected', 'a4000000-0000-4000-8000-000000000003');
    set constraints match_players_validate_manual_pair immediate;
  end $b$;$$,
  '23514', 'INVALID_MANUAL_PAIR', 'cross-linked manual rows cannot be committed'
);

set local role authenticated;
set local request.jwt.claim.sub = 'a1000000-0000-4000-8000-000000000001';
select lives_ok($$select public.get_manual_adjustment_source('a2000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000001')$$, 'active coach can read adjustment source');
select throws_ok(
  $$select public.create_manual_regular_adjustment('a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000002', 'invalid')$$,
  '42501', 'permission denied for function create_manual_regular_adjustment', 'authenticated cannot call create directly'
);
select throws_ok(
  $$select public.restore_manual_regular_adjustment('a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000002', 'invalid')$$,
  '42501', 'permission denied for function restore_manual_regular_adjustment', 'authenticated cannot call restore directly'
);

do $$ begin
  perform set_config('test.manual_fp', public.get_manual_adjustment_source('a2000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000001')->>'fingerprint', true);
end $$;
reset role;
set local role service_role;
set local request.jwt.claims = '{"role":"service_role"}';

select throws_ok(
  $$select public.create_manual_regular_adjustment('a1000000-0000-4000-8000-000000000002', 'a2000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000002', current_setting('test.manual_fp'))$$,
  '42501', 'NOT_AUTHORIZED', 'server rejects outsider actor id'
);
select throws_ok(
  $$select public.create_manual_regular_adjustment('a1000000-0000-4000-8000-000000000003', 'a2000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000002', current_setting('test.manual_fp'))$$,
  '42501', 'NOT_AUTHORIZED', 'server rejects inactive actor id'
);
select lives_ok(
  $$select public.create_manual_regular_adjustment('a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000002', current_setting('test.manual_fp'))$$,
  'valid manual adjustment is atomic'
);
reset role;
select throws_ok(
  $$do $b$ begin
    delete from public.match_players
    where match_id = 'a5000000-0000-4000-8000-000000000001'
      and player_id = 'a4000000-0000-4000-8000-000000000002';
    set constraints match_players_validate_manual_pair immediate;
  end $b$;$$,
  '23514', 'INVALID_MANUAL_PAIR', 'one half of a manual pair cannot be deleted alone'
);
select throws_ok(
  $$do $b$ begin
    update public.match_players set replaced_player_id = 'a4000000-0000-4000-8000-000000000003'
    where match_id = 'a5000000-0000-4000-8000-000000000001'
      and player_id = 'a4000000-0000-4000-8000-000000000002';
    set constraints match_players_validate_manual_pair immediate;
  end $b$;$$,
  '23514', 'INVALID_MANUAL_PAIR', 'one half of a manual pair cannot be updated alone'
);
select results_eq(
  $$select player_id::text || ':' || selection_status from public.match_players where match_id = 'a5000000-0000-4000-8000-000000000001' order by selection_status$$,
  array['a4000000-0000-4000-8000-000000000001:removed'::text, 'a4000000-0000-4000-8000-000000000002:selected'::text],
  'manual pair records outgoing and incoming players'
);
select results_eq(
  $$select count(*) from public.match_players where match_id = 'a5000000-0000-4000-8000-000000000001' and selection_type = 'regular' and selection_status = 'selected'$$,
  array[1::bigint], 'manual adjustment preserves regular target'
);
select results_eq(
  $$select jsonb_array_length(private.regular_allocation_source('a2000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000001', '2026-08-20 00:00+00')->'manualSelections')$$,
  array[2], 'allocation source preserves include and exclude decisions'
);

select lives_ok(
  $$select public.create_manual_regular_adjustment('a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000002', 'replayed')$$,
  'repeating the same create converges to the existing pair'
);
select throws_ok(
  $$do $b$ begin
    insert into public.match_players (team_id, season_id, match_id, player_id, selection_type, selection_source, selection_status, replaced_player_id)
    values ('a2000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000002', 'a4000000-0000-4000-8000-000000000001', 'regular', 'manual', 'removed', 'a4000000-0000-4000-8000-000000000002');
    update public.match_players set match_id = 'a5000000-0000-4000-8000-000000000002'
    where match_id = 'a5000000-0000-4000-8000-000000000001' and player_id = 'a4000000-0000-4000-8000-000000000002';
    set constraints match_players_validate_manual_pair immediate;
  end $b$;$$,
  '23514', 'INVALID_MANUAL_PAIR', 'moving half a pair cannot orphan the old match'
);
select throws_ok(
  $$do $b$ begin
    insert into public.match_players (team_id, season_id, match_id, player_id, selection_type, selection_source, selection_status, replaced_player_id)
    values ('a2000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000003', 'regular', 'manual', 'removed', 'a4000000-0000-4000-8000-000000000002');
    set constraints match_players_validate_manual_pair immediate;
  end $b$;$$,
  '23514', 'INVALID_MANUAL_PAIR', 'multiple manual rows cannot claim the same counterpart'
);
select throws_ok(
  $$select public.create_manual_regular_adjustment('a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000002', 'a4000000-0000-4000-8000-000000000003', md5(private.manual_adjustment_source('a2000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000001')::text))$$,
  'P0001', 'INVALID_ADJUSTMENT', 'a manually selected player cannot be chained into another adjustment'
);

set local role authenticated;
set local request.jwt.claim.sub = 'a1000000-0000-4000-8000-000000000001';
do $$ begin
  perform set_config('test.restore_fp', public.get_manual_adjustment_source('a2000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000001')->>'fingerprint', true);
end $$;
reset role;
select throws_ok(
  $$do $b$ begin
    update public.players set is_active = false where id = 'a4000000-0000-4000-8000-000000000001';
    perform set_config('request.jwt.claims', '{"role":"service_role"}', true);
    perform public.restore_manual_regular_adjustment('a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000002', md5(private.manual_adjustment_source('a2000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000001')::text));
  end $b$;$$,
  'P0001', 'INVALID_ADJUSTMENT', 'restore rejects an inactive original player'
);
set local role service_role;
set local request.jwt.claims = '{"role":"service_role"}';
select lives_ok(
  $$select public.restore_manual_regular_adjustment('a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000002', current_setting('test.restore_fp'))$$,
  'valid manual adjustment can be restored'
);
reset role;
select results_eq(
  $$select player_id::text || ':' || selection_source from public.match_players where match_id = 'a5000000-0000-4000-8000-000000000001'$$,
  array['a4000000-0000-4000-8000-000000000001:automatic'::text], 'restore recreates the original automatic place'
);
set local request.jwt.claims = '{"role":"service_role"}';
select lives_ok(
  $$select public.restore_manual_regular_adjustment('a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000002', 'replayed')$$,
  'repeating restore converges to the automatic place'
);

select throws_ok(
  $$do $b$ begin
    update public.players set is_active = false where id = 'a4000000-0000-4000-8000-000000000002';
    perform set_config('request.jwt.claims', '{"role":"service_role"}', true);
    perform public.create_manual_regular_adjustment('a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000002', md5(private.manual_adjustment_source('a2000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000001')::text));
  end $b$;$$,
  'P0001', 'INVALID_ADJUSTMENT', 'inactive incoming player is rejected'
);
select throws_ok(
  $$do $b$ begin
    insert into public.match_players (team_id, season_id, match_id, player_id, selection_type, selection_source, selection_status)
    values ('a2000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000002', 'regular', 'automatic', 'selected');
    perform set_config('request.jwt.claims', '{"role":"service_role"}', true);
    perform public.create_manual_regular_adjustment('a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000002', md5(private.manual_adjustment_source('a2000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000001')::text));
  end $b$;$$,
  'P0001', 'INVALID_ADJUSTMENT', 'already regular incoming player is rejected'
);
select throws_ok(
  $$do $b$ begin
    insert into public.match_players (team_id, season_id, match_id, player_id, selection_type, selection_source, selection_status)
    values ('a2000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000002', 'extra', 'manual', 'selected');
    perform set_config('request.jwt.claims', '{"role":"service_role"}', true);
    perform public.create_manual_regular_adjustment('a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000002', md5(private.manual_adjustment_source('a2000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000001')::text));
  end $b$;$$,
  'P0001', 'INVALID_ADJUSTMENT', 'extra selected incoming player is rejected'
);

select throws_ok(
  $$select public.create_manual_regular_adjustment('a1000000-0000-4000-8000-000000000001', 'ffffffff-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000002', 'x')$$,
  '42501', 'NOT_AUTHORIZED', 'another team is rejected'
);
select throws_ok(
  $$select public.create_manual_regular_adjustment('a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'ffffffff-0000-4000-8000-000000000002', 'a5000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000002', 'x')$$,
  'P0001', 'MATCH_NOT_AVAILABLE', 'another season is rejected'
);
select throws_ok(
  $$do $b$ begin update public.matches set status='completed' where id='a5000000-0000-4000-8000-000000000001'; perform set_config('request.jwt.claims','{"role":"service_role"}',true); perform public.create_manual_regular_adjustment('a1000000-0000-4000-8000-000000000001','a2000000-0000-4000-8000-000000000001','a3000000-0000-4000-8000-000000000001','a5000000-0000-4000-8000-000000000001','a4000000-0000-4000-8000-000000000001','a4000000-0000-4000-8000-000000000002','x'); end $b$;$$,
  'P0001', 'MATCH_NOT_AVAILABLE', 'completed match is rejected'
);
select throws_ok(
  $$do $b$ begin update public.matches set status='cancelled' where id='a5000000-0000-4000-8000-000000000001'; perform set_config('request.jwt.claims','{"role":"service_role"}',true); perform public.create_manual_regular_adjustment('a1000000-0000-4000-8000-000000000001','a2000000-0000-4000-8000-000000000001','a3000000-0000-4000-8000-000000000001','a5000000-0000-4000-8000-000000000001','a4000000-0000-4000-8000-000000000001','a4000000-0000-4000-8000-000000000002','x'); end $b$;$$,
  'P0001', 'MATCH_NOT_AVAILABLE', 'cancelled match is rejected'
);
select throws_ok(
  $$do $b$ begin update public.matches set starts_at='2026-01-01 10:00+00' where id='a5000000-0000-4000-8000-000000000001'; perform set_config('request.jwt.claims','{"role":"service_role"}',true); perform public.create_manual_regular_adjustment('a1000000-0000-4000-8000-000000000001','a2000000-0000-4000-8000-000000000001','a3000000-0000-4000-8000-000000000001','a5000000-0000-4000-8000-000000000001','a4000000-0000-4000-8000-000000000001','a4000000-0000-4000-8000-000000000002','x'); end $b$;$$,
  'P0001', 'MATCH_NOT_AVAILABLE', 'past match is rejected'
);
select results_eq(
  $$select player_id::text || ':' || selection_source || ':' || selection_status from public.match_players where match_id = 'a5000000-0000-4000-8000-000000000001'$$,
  array['a4000000-0000-4000-8000-000000000001:automatic:selected'::text],
  'rejected candidate and match mutations leave the selection unchanged'
);

set local role service_role;
set local request.jwt.claims = '{"role":"service_role"}';
select throws_ok(
  $$select public.create_manual_regular_adjustment('a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000002', 'old')$$,
  'P0001', 'STALE_SELECTION', 'stale create leaves current selection unchanged'
);
reset role;
select results_eq($$select count(*) from public.match_players where match_id = 'a5000000-0000-4000-8000-000000000001'$$, array[1::bigint], 'stale create is atomic');

set local role service_role;
set local request.jwt.claims = '{"role":"service_role"}';
select throws_ok(
  $$select public.create_manual_regular_adjustment('a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000001', 'old')$$,
  'P0001', 'INVALID_ADJUSTMENT', 'self replacement is rejected'
);

set local role anon;
select throws_ok(
  $$select public.get_manual_adjustment_source('a2000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000001')$$,
  '42501', 'permission denied for function get_manual_adjustment_source', 'anonymous cannot read adjustment source'
);

select * from finish();
rollback;
