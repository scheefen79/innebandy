begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(33);

insert into auth.users (id, email)
values
  ('a0000000-0000-4000-8000-000000000001', 'pgtap-coach-1@example.test'),
  ('a0000000-0000-4000-8000-000000000002', 'pgtap-coach-2@example.test'),
  ('a0000000-0000-4000-8000-000000000003', 'pgtap-coach-3@example.test'),
  ('a0000000-0000-4000-8000-000000000004', 'pgtap-outsider@example.test'),
  ('a0000000-0000-4000-8000-000000000005', 'pgtap-other-team@example.test'),
  ('a0000000-0000-4000-8000-000000000006', 'pgtap-inactive@example.test');

insert into public.teams (id, name, slug)
values
  ('b0000000-0000-4000-8000-000000000001', 'Testlag ett', 'testlag-ett'),
  ('b0000000-0000-4000-8000-000000000002', 'Testlag två', 'testlag-tva');

insert into public.team_members (team_id, user_id, is_active)
values
  ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000001', true),
  ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000002', true),
  ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000003', true),
  ('b0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000005', true),
  ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000006', false);

insert into public.seasons (id, team_id, name, starts_on, ends_on, is_active)
values
  (
    'c0000000-0000-4000-8000-000000000001',
    'b0000000-0000-4000-8000-000000000001',
    'Säsong ett',
    '2026-08-01',
    '2027-05-31',
    true
  ),
  (
    'c0000000-0000-4000-8000-000000000002',
    'b0000000-0000-4000-8000-000000000002',
    'Säsong två',
    '2026-08-01',
    '2027-05-31',
    true
  ),
  (
    'c0000000-0000-4000-8000-000000000003',
    'b0000000-0000-4000-8000-000000000001',
    'Inaktiv säsong',
    '2025-08-01',
    '2026-05-31',
    false
  );

insert into public.players (
  id,
  team_id,
  season_id,
  first_name,
  last_name,
  level,
  rotation_order
)
values
  (
    'd0000000-0000-4000-8000-000000000001',
    'b0000000-0000-4000-8000-000000000001',
    'c0000000-0000-4000-8000-000000000001',
    'Testspelare',
    'Ett',
    1,
    1
  ),
  (
    'd0000000-0000-4000-8000-000000000002',
    'b0000000-0000-4000-8000-000000000002',
    'c0000000-0000-4000-8000-000000000002',
    'Testspelare',
    'Två',
    2,
    1
  );

insert into public.matches (
  id,
  team_id,
  season_id,
  opponent,
  starts_at,
  target_players,
  request_id
)
values
  (
    'e0000000-0000-4000-8000-000000000001',
    'b0000000-0000-4000-8000-000000000001',
    'c0000000-0000-4000-8000-000000000001',
    'Motstånd ett',
    '2026-09-01 10:00:00+00',
    10,
    'f0000000-0000-4000-8000-000000000001'
  ),
  (
    'e0000000-0000-4000-8000-000000000002',
    'b0000000-0000-4000-8000-000000000002',
    'c0000000-0000-4000-8000-000000000002',
    'Motstånd två',
    '2026-09-02 10:00:00+00',
    10,
    'f0000000-0000-4000-8000-000000000001'
  );

select results_eq(
  $$
    select count(*)
    from matches
    where request_id = 'f0000000-0000-4000-8000-000000000001'
  $$,
  array[2::bigint],
  'the same request id is independent between teams'
);

update public.matches
set location = 'Uppdaterad testplats'
where id = 'e0000000-0000-4000-8000-000000000001';

select ok(
  (
    select updated_at > created_at
    from public.matches
    where id = 'e0000000-0000-4000-8000-000000000001'
  ),
  'the trigger advances updated_at on administrative update'
);

set local role authenticated;
set local request.jwt.claim.sub = 'a0000000-0000-4000-8000-000000000001';

select results_eq(
  'select count(*) from teams',
  array[1::bigint],
  'a coach sees only their team'
);
select results_eq(
  'select count(*) from team_members',
  array[1::bigint],
  'a coach sees only their own membership'
);
select results_eq(
  'select count(*) from seasons',
  array[2::bigint],
  'a coach sees only seasons belonging to their team'
);
select results_eq(
  'select count(*) from players',
  array[1::bigint],
  'a coach sees only their team players'
);
select results_eq(
  'select count(*) from matches',
  array[1::bigint],
  'a coach sees only their team matches'
);
select lives_ok(
  $$
    insert into matches (
      team_id, season_id, opponent, starts_at, target_players, request_id
    ) values (
      'b0000000-0000-4000-8000-000000000001',
      'c0000000-0000-4000-8000-000000000001',
      'Tillåten match',
      '2026-10-01 10:00:00+00',
      10,
      'f0000000-0000-4000-8000-000000000002'
    )
  $$,
  'a coach can create an upcoming match in their active season'
);
select throws_ok(
  $$
    insert into matches (
      team_id, season_id, opponent, starts_at, target_players, request_id, created_at, updated_at
    ) values (
      'b0000000-0000-4000-8000-000000000001',
      'c0000000-0000-4000-8000-000000000001',
      'Match med falska revisionsdatum',
      '2026-10-01 11:00:00+00',
      10,
      'f0000000-0000-4000-8000-000000000009',
      '2000-01-01 00:00:00+00',
      '2000-01-01 00:00:00+00'
    )
  $$,
  '42501',
  'permission denied for table matches',
  'a coach cannot provide created_at or updated_at directly'
);
select throws_ok(
  $$
    insert into matches (
      team_id, season_id, opponent, starts_at, target_players, status, request_id
    ) values (
      'b0000000-0000-4000-8000-000000000001',
      'c0000000-0000-4000-8000-000000000001',
      'Otillåten genomförd match',
      '2026-10-02 10:00:00+00',
      10,
      'completed',
      'f0000000-0000-4000-8000-000000000003'
    )
  $$,
  '42501',
  'new row violates row-level security policy for table "matches"',
  'a coach cannot create a completed match directly'
);
select throws_ok(
  $$
    insert into matches (
      team_id, season_id, opponent, starts_at, target_players, status, request_id
    ) values (
      'b0000000-0000-4000-8000-000000000001',
      'c0000000-0000-4000-8000-000000000001',
      'Otillåten inställd match',
      '2026-10-03 10:00:00+00',
      10,
      'cancelled',
      'f0000000-0000-4000-8000-000000000004'
    )
  $$,
  '42501',
  'new row violates row-level security policy for table "matches"',
  'a coach cannot create a cancelled match directly'
);
select throws_ok(
  $$
    insert into matches (
      team_id, season_id, opponent, starts_at, target_players, request_id
    ) values (
      'b0000000-0000-4000-8000-000000000001',
      'c0000000-0000-4000-8000-000000000003',
      'Match i inaktiv säsong',
      '2026-10-04 10:00:00+00',
      10,
      'f0000000-0000-4000-8000-000000000005'
    )
  $$,
  '42501',
  'new row violates row-level security policy for table "matches"',
  'a coach cannot create a match in an inactive season'
);
select throws_ok(
  $$
    insert into players (
      team_id,
      season_id,
      first_name,
      last_name,
      level,
      rotation_order
    ) values (
      'b0000000-0000-4000-8000-000000000001',
      'c0000000-0000-4000-8000-000000000001',
      'Coachens',
      'Nya testspelare',
      3,
      2
    )
  $$,
  '42501',
  'permission denied for table players',
  'a coach cannot create a player directly'
);
select throws_ok(
  $$
    update players
    set first_name = 'Otillåten ändring'
    where id = 'd0000000-0000-4000-8000-000000000002'
  $$,
  '42501',
  'permission denied for table players',
  'a coach cannot update players directly'
);

set local request.jwt.claim.sub = 'a0000000-0000-4000-8000-000000000004';

select results_eq(
  'select count(*) from teams',
  array[0::bigint],
  'a user without membership sees no teams'
);
select results_eq(
  'select count(*) from players',
  array[0::bigint],
  'a user without membership sees no players'
);
select results_eq(
  'select count(*) from matches',
  array[0::bigint],
  'a user without membership sees no matches'
);
select throws_ok(
  $$
    insert into matches (
      team_id, season_id, opponent, starts_at, target_players, request_id
    ) values (
      'b0000000-0000-4000-8000-000000000001',
      'c0000000-0000-4000-8000-000000000001',
      'Otillåten match',
      '2026-10-05 10:00:00+00',
      10,
      'f0000000-0000-4000-8000-000000000006'
    )
  $$,
  '42501',
  'new row violates row-level security policy for table "matches"',
  'a user without membership cannot create matches'
);
select throws_ok(
  $$
    insert into players (
      team_id,
      season_id,
      first_name,
      last_name,
      level,
      rotation_order
    ) values (
      'b0000000-0000-4000-8000-000000000001',
      'c0000000-0000-4000-8000-000000000001',
      'Otillåten',
      'Testspelare',
      2,
      3
    )
  $$,
  '42501',
  'permission denied for table players',
  'a user without membership cannot create players'
);

set local request.jwt.claim.sub = 'a0000000-0000-4000-8000-000000000005';

select results_eq(
  'select name from teams',
  array['Testlag två'::text],
  'a coach in another team sees only that team'
);
select results_eq(
  $$select concat_ws(' ', first_name, last_name) from players$$,
  array['Testspelare Två'::text],
  'a coach in another team sees only that team players'
);
select results_eq(
  'select opponent from matches',
  array['Motstånd två'::text],
  'a coach in another team sees only that team matches'
);
select throws_ok(
  $$
    insert into matches (
      team_id, season_id, opponent, starts_at, target_players, request_id
    ) values (
      'b0000000-0000-4000-8000-000000000001',
      'c0000000-0000-4000-8000-000000000001',
      'Match i fel lag',
      '2026-10-06 10:00:00+00',
      10,
      'f0000000-0000-4000-8000-000000000007'
    )
  $$,
  '42501',
  'new row violates row-level security policy for table "matches"',
  'a coach cannot create a match in another team'
);

set local request.jwt.claim.sub = 'a0000000-0000-4000-8000-000000000006';

select results_eq(
  'select count(*) from teams',
  array[0::bigint],
  'an inactive member sees no teams'
);
select results_eq(
  'select count(*) from players',
  array[0::bigint],
  'an inactive member sees no players'
);
select results_eq(
  'select count(*) from matches',
  array[0::bigint],
  'an inactive member sees no matches'
);
select throws_ok(
  $$
    insert into team_members (team_id, user_id)
    values (
      'b0000000-0000-4000-8000-000000000001',
      'a0000000-0000-4000-8000-000000000004'
    )
  $$,
  '42501',
  'permission denied for table team_members',
  'authenticated users cannot grant team membership'
);
select throws_ok(
  $$delete from players where id = 'd0000000-0000-4000-8000-000000000001'$$,
  '42501',
  'permission denied for table players',
  'authenticated users cannot permanently delete players'
);
select throws_ok(
  $$delete from seasons where id = 'c0000000-0000-4000-8000-000000000001'$$,
  '42501',
  'permission denied for table seasons',
  'authenticated users cannot permanently delete seasons'
);
select throws_ok(
  $$update matches set opponent = 'Otillåten ändring'$$,
  '42501',
  'permission denied for table matches',
  'authenticated users cannot update matches'
);
select throws_ok(
  $$delete from matches$$,
  '42501',
  'permission denied for table matches',
  'authenticated users cannot delete matches'
);

set local role anon;

select throws_ok(
  $$select count(*) from matches$$,
  '42501',
  'permission denied for table matches',
  'anonymous users cannot read matches'
);
select throws_ok(
  $$
    insert into matches (
      team_id, season_id, opponent, starts_at, target_players, request_id
    ) values (
      'b0000000-0000-4000-8000-000000000001',
      'c0000000-0000-4000-8000-000000000001',
      'Anonym match',
      '2026-10-07 10:00:00+00',
      10,
      'f0000000-0000-4000-8000-000000000008'
    )
  $$,
  '42501',
  'permission denied for table matches',
  'anonymous users cannot create matches'
);

select * from finish();
rollback;
