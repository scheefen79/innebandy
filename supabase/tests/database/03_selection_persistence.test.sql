begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(26);

insert into auth.users (id, email)
values
  ('91000000-0000-4000-8000-000000000001', 'selection-coach@example.test'),
  ('91000000-0000-4000-8000-000000000002', 'selection-outsider@example.test'),
  ('91000000-0000-4000-8000-000000000003', 'selection-other@example.test'),
  ('91000000-0000-4000-8000-000000000004', 'selection-inactive@example.test');

insert into public.teams (id, name, slug)
values
  ('92000000-0000-4000-8000-000000000001', 'Uttagningslag ett', 'uttagning-ett'),
  ('92000000-0000-4000-8000-000000000002', 'Uttagningslag två', 'uttagning-tva');

insert into public.team_members (team_id, user_id)
values
  ('92000000-0000-4000-8000-000000000001', '91000000-0000-4000-8000-000000000001'),
  ('92000000-0000-4000-8000-000000000002', '91000000-0000-4000-8000-000000000003');

insert into public.team_members (team_id, user_id, is_active)
values ('92000000-0000-4000-8000-000000000001', '91000000-0000-4000-8000-000000000004', false);

insert into public.seasons (id, team_id, name, starts_on, ends_on)
values
  ('93000000-0000-4000-8000-000000000001', '92000000-0000-4000-8000-000000000001', 'Uttagningssäsong ett', '2026-08-01', '2027-05-31'),
  ('93000000-0000-4000-8000-000000000002', '92000000-0000-4000-8000-000000000002', 'Uttagningssäsong två', '2026-08-01', '2027-05-31');

insert into public.players (id, team_id, season_id, first_name, level, rotation_order)
values
  ('94000000-0000-4000-8000-000000000001', '92000000-0000-4000-8000-000000000001', '93000000-0000-4000-8000-000000000001', 'Spelare ett', 1, 1),
  ('94000000-0000-4000-8000-000000000002', '92000000-0000-4000-8000-000000000002', '93000000-0000-4000-8000-000000000002', 'Spelare två', 2, 1);

insert into public.matches (id, team_id, season_id, opponent, starts_at, target_players, request_id)
values
  ('95000000-0000-4000-8000-000000000001', '92000000-0000-4000-8000-000000000001', '93000000-0000-4000-8000-000000000001', 'Exempel ett', '2026-09-01 10:00+00', 1, '96000000-0000-4000-8000-000000000001'),
  ('95000000-0000-4000-8000-000000000002', '92000000-0000-4000-8000-000000000002', '93000000-0000-4000-8000-000000000002', 'Exempel två', '2026-09-01 10:00+00', 1, '96000000-0000-4000-8000-000000000002');

insert into public.matches (id, team_id, season_id, opponent, starts_at, target_players, status, request_id)
values
  ('95000000-0000-4000-8000-000000000003', '92000000-0000-4000-8000-000000000001', '93000000-0000-4000-8000-000000000001', 'Genomförd historik', '2026-08-01 10:00+00', 1, 'completed', '96000000-0000-4000-8000-000000000003'),
  ('95000000-0000-4000-8000-000000000004', '92000000-0000-4000-8000-000000000001', '93000000-0000-4000-8000-000000000001', 'Bevarad planerad', '2026-08-10 10:00+00', 1, 'upcoming', '96000000-0000-4000-8000-000000000004');

insert into public.match_players (
  team_id, season_id, match_id, player_id,
  selection_type, selection_source, selection_status, played
)
values
  ('92000000-0000-4000-8000-000000000001', '93000000-0000-4000-8000-000000000001', '95000000-0000-4000-8000-000000000003', '94000000-0000-4000-8000-000000000001', 'regular', 'automatic', 'selected', true),
  ('92000000-0000-4000-8000-000000000001', '93000000-0000-4000-8000-000000000001', '95000000-0000-4000-8000-000000000004', '94000000-0000-4000-8000-000000000001', 'regular', 'automatic', 'selected', false);

select throws_ok(
  $$
    insert into public.match_players (
      team_id, season_id, match_id, player_id,
      selection_type, selection_source, selection_status
    ) values (
      '92000000-0000-4000-8000-000000000001',
      '93000000-0000-4000-8000-000000000001',
      '95000000-0000-4000-8000-000000000001',
      '94000000-0000-4000-8000-000000000002',
      'regular', 'automatic', 'selected'
    )
  $$,
  '23503',
  null,
  'a selection cannot connect a player from another team'
);

set local role authenticated;
set local request.jwt.claim.sub = '91000000-0000-4000-8000-000000000001';

select results_eq(
  $$
    select (player ->> 'baselineRegularCount') || ':' || (player ->> 'baselineLastRegularMatchOrder')
    from jsonb_array_elements(
      public.get_regular_allocation_source(
        '92000000-0000-4000-8000-000000000001',
        '93000000-0000-4000-8000-000000000001',
        '2026-08-20 00:00+00'
      ) -> 'source' -> 'players'
    ) player
  $$,
  array['2:2'::text],
  'completed and preserved regular selections form the fairness baseline'
);

select results_eq(
  $$
    select (match ->> 'order')::integer
    from jsonb_array_elements(
      public.get_regular_allocation_source(
        '92000000-0000-4000-8000-000000000001',
        '93000000-0000-4000-8000-000000000001',
        '2026-08-20 00:00+00'
      ) -> 'source' -> 'matches'
    ) match
  $$,
  array[3],
  'future matches retain their global season order after historical matches'
);

do $$
begin
  perform set_config(
    'test.preview_before_first_save',
    public.get_regular_allocation_source(
      '92000000-0000-4000-8000-000000000001',
      '93000000-0000-4000-8000-000000000001',
      '2026-08-20 00:00+00'
    ) ->> 'fingerprint',
    true
  );
end
$$;

do $$
begin
  perform set_config(
    'test.first_save_envelope',
    public.get_regular_allocation_source(
      '92000000-0000-4000-8000-000000000001',
      '93000000-0000-4000-8000-000000000001',
      '2026-08-20 00:00+00'
    )::text,
    true
  );
end
$$;

reset role;
set local role service_role;
set local request.jwt.claims = '{"role":"service_role"}';

select lives_ok(
  $$
    do $block$
    declare envelope jsonb;
    begin
      envelope := current_setting('test.first_save_envelope')::jsonb;
      perform public.save_regular_allocation(
        '91000000-0000-4000-8000-000000000001',
        '92000000-0000-4000-8000-000000000001',
        '93000000-0000-4000-8000-000000000001',
        '2026-08-20 00:00+00',
        envelope ->> 'fingerprint',
        '[{"matchId":"95000000-0000-4000-8000-000000000001","playerIds":["94000000-0000-4000-8000-000000000001"]}]'::jsonb
      );
    end
    $block$
  $$,
  'an active coach can atomically save a valid regular allocation'
);

reset role;
set local role authenticated;
set local request.jwt.claim.sub = '91000000-0000-4000-8000-000000000001';

select results_eq(
  $$
    select selection_type || ':' || selection_source || ':' || selection_status || ':' || played::text
    from match_players
    where match_id = '95000000-0000-4000-8000-000000000001'
  $$,
  array['regular:automatic:selected:false'::text],
  'the saved row has only the automatic regular state'
);

select results_eq('select count(*) from match_players', array[3::bigint], 'the coach sees their team selections');
select isnt(
  public.get_regular_allocation_source(
    '92000000-0000-4000-8000-000000000001',
    '93000000-0000-4000-8000-000000000001',
    '2026-08-20 00:00+00'
  ) ->> 'fingerprint',
  current_setting('test.preview_before_first_save'),
  'changing an automatic selection invalidates an earlier preview'
);
select results_eq(
  $$
    select jsonb_array_length(
      public.get_regular_allocation_source(
        '92000000-0000-4000-8000-000000000001',
        '93000000-0000-4000-8000-000000000001',
        '2026-08-20 00:00+00'
      ) -> 'source' -> 'automaticSelections'
    )
  $$,
  array[1],
  'the canonical source includes existing future automatic selections'
);

do $$
begin
  perform set_config(
    'test.idempotent_envelope',
    public.get_regular_allocation_source(
      '92000000-0000-4000-8000-000000000001',
      '93000000-0000-4000-8000-000000000001',
      '2026-08-20 00:00+00'
    )::text,
    true
  );
end
$$;

reset role;
set local role service_role;
set local request.jwt.claims = '{"role":"service_role"}';

select lives_ok(
  $$
    do $block$
    declare envelope jsonb;
    begin
      envelope := current_setting('test.idempotent_envelope')::jsonb;
      perform public.save_regular_allocation(
        '91000000-0000-4000-8000-000000000001',
        '92000000-0000-4000-8000-000000000001',
        '93000000-0000-4000-8000-000000000001',
        '2026-08-20 00:00+00',
        envelope ->> 'fingerprint',
        '[{"matchId":"95000000-0000-4000-8000-000000000001","playerIds":["94000000-0000-4000-8000-000000000001"]}]'::jsonb
      );
    end
    $block$
  $$,
  'saving the same current allocation is idempotent'
);

reset role;
set local role authenticated;
set local request.jwt.claim.sub = '91000000-0000-4000-8000-000000000001';

select results_eq('select count(*) from match_players', array[3::bigint], 'idempotent save creates no duplicate');

do $$
begin
  perform set_config(
    'test.selection_fingerprint',
    public.get_regular_allocation_source(
      '92000000-0000-4000-8000-000000000001',
      '93000000-0000-4000-8000-000000000001',
      '2026-08-20 00:00+00'
    ) ->> 'fingerprint',
    true
  );
end
$$;

reset role;
update public.players set level = 3 where id = '94000000-0000-4000-8000-000000000001';
set local role service_role;
set local request.jwt.claims = '{"role":"service_role"}';

select throws_ok(
  $$
    select public.save_regular_allocation(
      '91000000-0000-4000-8000-000000000001',
      '92000000-0000-4000-8000-000000000001',
      '93000000-0000-4000-8000-000000000001',
      '2026-08-20 00:00+00',
      current_setting('test.selection_fingerprint'),
      '[{"matchId":"95000000-0000-4000-8000-000000000001","playerIds":["94000000-0000-4000-8000-000000000001"]}]'::jsonb
    )
  $$,
  'P0001', 'STALE_PREVIEW', 'changed source data invalidates an old preview'
);
reset role;
set local role authenticated;
set local request.jwt.claim.sub = '91000000-0000-4000-8000-000000000001';
select results_eq('select count(*) from match_players', array[3::bigint], 'a stale save leaves the existing allocation unchanged');

select throws_ok(
  $$insert into match_players (team_id, season_id, match_id, player_id, selection_type, selection_source, selection_status) values ('92000000-0000-4000-8000-000000000001', '93000000-0000-4000-8000-000000000001', '95000000-0000-4000-8000-000000000001', '94000000-0000-4000-8000-000000000001', 'regular', 'manual', 'selected')$$,
  '42501', 'permission denied for table match_players', 'authenticated clients cannot insert selections directly'
);
select throws_ok($$update match_players set played = true$$, '42501', 'permission denied for table match_players', 'authenticated clients cannot update selections directly');
select throws_ok($$delete from match_players$$, '42501', 'permission denied for table match_players', 'authenticated clients cannot delete selections directly');

select throws_ok(
  $$select public.save_regular_allocation('91000000-0000-4000-8000-000000000001', '92000000-0000-4000-8000-000000000001', '93000000-0000-4000-8000-000000000001', '2026-08-20 00:00+00', 'invalid', '[]'::jsonb)$$,
  '42501', 'permission denied for function save_regular_allocation', 'authenticated clients cannot call the server-only save boundary'
);

reset role;
set local role service_role;
set local request.jwt.claims = '{"role":"service_role"}';
select throws_ok(
  $$select public.save_regular_allocation('91000000-0000-4000-8000-000000000002', '92000000-0000-4000-8000-000000000001', '93000000-0000-4000-8000-000000000001', '2026-08-20 00:00+00', 'invalid', '[]'::jsonb)$$,
  '42501', 'NOT_AUTHORIZED', 'the server boundary rejects a forwarded outsider user id'
);
select throws_ok(
  $$select public.save_regular_allocation('91000000-0000-4000-8000-000000000004', '92000000-0000-4000-8000-000000000001', '93000000-0000-4000-8000-000000000001', '2026-08-20 00:00+00', 'invalid', '[]'::jsonb)$$,
  '42501', 'NOT_AUTHORIZED', 'the server boundary rejects a forwarded inactive member id'
);
reset role;
set local role authenticated;
set local request.jwt.claim.sub = '91000000-0000-4000-8000-000000000001';
select results_eq('select count(*) from public.match_players', array[3::bigint], 'rejected forwarded identities leave selections unchanged');

do $$
begin
  perform set_config(
    'test.invalid_envelope',
    public.get_regular_allocation_source(
      '92000000-0000-4000-8000-000000000001',
      '93000000-0000-4000-8000-000000000001',
      '2026-08-20 00:00+00'
    )::text,
    true
  );
end
$$;

reset role;
set local role service_role;
set local request.jwt.claims = '{"role":"service_role"}';
select throws_ok(
  $$
    select public.save_regular_allocation(
      '91000000-0000-4000-8000-000000000001',
      '92000000-0000-4000-8000-000000000001',
      '93000000-0000-4000-8000-000000000001',
      '2026-08-20 00:00+00',
      (current_setting('test.invalid_envelope')::jsonb ->> 'fingerprint'),
      '[]'::jsonb
    )
  $$,
  'P0001', 'INVALID_ALLOCATION', 'an invalid result is rejected atomically'
);
reset role;
set local role authenticated;
set local request.jwt.claim.sub = '91000000-0000-4000-8000-000000000001';
select results_eq('select count(*) from match_players', array[3::bigint], 'a rejected save leaves the existing allocation unchanged');

set local request.jwt.claim.sub = '91000000-0000-4000-8000-000000000002';

select results_eq('select count(*) from match_players', array[0::bigint], 'an outsider sees no selections');
select throws_ok(
  $$select public.get_regular_allocation_source('92000000-0000-4000-8000-000000000001', '93000000-0000-4000-8000-000000000001', '2026-08-20 00:00+00')$$,
  '42501', 'NOT_AUTHORIZED', 'an outsider cannot read allocation source'
);
select throws_ok(
  $$select public.save_regular_allocation('91000000-0000-4000-8000-000000000002', '92000000-0000-4000-8000-000000000001', '93000000-0000-4000-8000-000000000001', '2026-08-20 00:00+00', 'invalid', '[]'::jsonb)$$,
  '42501', 'permission denied for function save_regular_allocation', 'an outsider cannot call the server-only save boundary'
);

set local request.jwt.claim.sub = '91000000-0000-4000-8000-000000000003';
select results_eq('select count(*) from match_players', array[0::bigint], 'another team coach cannot see the first team selection');

set local role anon;
select throws_ok('select count(*) from match_players', '42501', 'permission denied for table match_players', 'anonymous users cannot read selections');

select * from finish();
rollback;
