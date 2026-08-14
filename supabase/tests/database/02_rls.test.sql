begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(16);

insert into auth.users (id, email)
values
  ('a0000000-0000-4000-8000-000000000001', 'coach-1@example.test'),
  ('a0000000-0000-4000-8000-000000000002', 'coach-2@example.test'),
  ('a0000000-0000-4000-8000-000000000003', 'coach-3@example.test'),
  ('a0000000-0000-4000-8000-000000000004', 'outsider@example.test'),
  ('a0000000-0000-4000-8000-000000000005', 'other-team@example.test'),
  ('a0000000-0000-4000-8000-000000000006', 'inactive@example.test');

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

insert into public.seasons (id, team_id, name, starts_on, ends_on)
values
  (
    'c0000000-0000-4000-8000-000000000001',
    'b0000000-0000-4000-8000-000000000001',
    'Säsong ett',
    '2026-08-01',
    '2027-05-31'
  ),
  (
    'c0000000-0000-4000-8000-000000000002',
    'b0000000-0000-4000-8000-000000000002',
    'Säsong två',
    '2026-08-01',
    '2027-05-31'
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
  array[1::bigint],
  'a coach sees only their team season'
);
select results_eq(
  'select count(*) from players',
  array[1::bigint],
  'a coach sees only their team players'
);
select lives_ok(
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
  'a coach can create a player in their team'
);
select results_eq(
  $$
    update players
    set first_name = 'Otillåten ändring'
    where id = 'd0000000-0000-4000-8000-000000000002'
    returning 1
  $$,
  'select 1 where false',
  'a coach cannot update another team player'
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
  'new row violates row-level security policy for table "players"',
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

select * from finish();
rollback;
