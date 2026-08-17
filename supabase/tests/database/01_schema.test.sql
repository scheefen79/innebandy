begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(15);

select has_table('public', 'teams', 'teams exists');
select has_table('public', 'team_members', 'team_members exists');
select has_table('public', 'seasons', 'seasons exists');
select has_table('public', 'players', 'players exists');

select col_is_pk('public', 'teams', 'id', 'teams.id is the primary key');
select col_is_pk(
  'public',
  'team_members',
  array['team_id', 'user_id'],
  'team_members uses a composite primary key'
);
select results_eq(
  $$
    select pg_get_constraintdef(oid)
    from pg_constraint
    where conname = 'team_members_team_fk'
  $$,
  array['FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE'::text],
  'team_members.team_id references teams.id'
);
select results_eq(
  $$
    select pg_get_constraintdef(oid)
    from pg_constraint
    where conname = 'team_members_user_fk'
  $$,
  array['FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE'::text],
  'team_members.user_id references auth.users.id'
);
select results_eq(
  $$
    select pg_get_constraintdef(oid)
    from pg_constraint
    where conname = 'seasons_team_fk'
  $$,
  array['FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE'::text],
  'seasons.team_id references teams.id'
);
select results_eq(
  $$
    select pg_get_constraintdef(oid)
    from pg_constraint
    where conname = 'players_season_team_fk'
  $$,
  array[
    'FOREIGN KEY (season_id, team_id) REFERENCES seasons(id, team_id) ON DELETE CASCADE'::text
  ],
  'players season and team pair references the same season team pair'
);

select col_not_null('public', 'players', 'level', 'player level is required');
select col_not_null('public', 'players', 'rotation_order', 'rotation order is required');

select ok(
  exists (
    select 1
    from pg_index
    join pg_class on pg_class.oid = pg_index.indexrelid
    where pg_class.relname = 'seasons_one_active_per_team_idx'
      and pg_index.indisunique
      and pg_get_expr(pg_index.indpred, pg_index.indrelid) = 'is_active'
  ),
  'a team can only have one active season'
);

select ok(
  (select relrowsecurity from pg_class where oid = 'public.players'::regclass),
  'RLS is enabled for players'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.team_members'::regclass),
  'RLS is enabled for team_members'
);

select * from finish();
rollback;
