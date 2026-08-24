begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(52);

select has_table('public', 'teams', 'teams exists');
select has_table('public', 'team_members', 'team_members exists');
select has_table('public', 'seasons', 'seasons exists');
select has_table('public', 'players', 'players exists');
select has_table('public', 'matches', 'matches exists');
select has_table('public', 'match_players', 'match_players exists');

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
select col_not_null('public', 'matches', 'starts_at', 'match start is required');
select col_not_null('public', 'matches', 'target_players', 'match target is required');

select results_eq(
  $$
    select pg_get_constraintdef(oid)
    from pg_constraint
    where conname = 'matches_season_team_fk'
  $$,
  array[
    'FOREIGN KEY (season_id, team_id) REFERENCES seasons(id, team_id) ON DELETE CASCADE'::text
  ],
  'matches season and team pair references the same season team pair'
);
select results_eq(
  $$
    select pg_get_constraintdef(oid)
    from pg_constraint
    where conname = 'matches_id_team_unique'
  $$,
  array['UNIQUE (id, team_id)'::text],
  'matches exposes a composite match and team key'
);
select results_eq(
  $$
    select pg_get_constraintdef(oid)
    from pg_constraint
    where conname = 'players_id_team_season_unique'
  $$,
  array['UNIQUE (id, team_id, season_id)'::text],
  'players exposes a strong player, team and season key'
);
select results_eq(
  $$
    select pg_get_constraintdef(oid)
    from pg_constraint
    where conname = 'matches_id_team_season_unique'
  $$,
  array['UNIQUE (id, team_id, season_id)'::text],
  'matches exposes a strong match, team and season key'
);
select results_eq(
  $$
    select pg_get_constraintdef(oid)
    from pg_constraint
    where conname = 'matches_team_request_unique'
  $$,
  array['UNIQUE (team_id, request_id)'::text],
  'match request ids are unique inside a team'
);
select has_trigger(
  'public',
  'matches',
  'matches_set_updated_at',
  'matches maintains updated_at through a trigger'
);
select results_eq(
  $$select pg_get_constraintdef(oid) from pg_constraint where conname = 'match_players_match_team_season_fk'$$,
  array['FOREIGN KEY (match_id, team_id, season_id) REFERENCES matches(id, team_id, season_id) ON DELETE CASCADE'::text],
  'match selections reference a match in the same team and season'
);
select results_eq(
  $$select pg_get_constraintdef(oid) from pg_constraint where conname = 'match_players_player_team_season_fk'$$,
  array['FOREIGN KEY (player_id, team_id, season_id) REFERENCES players(id, team_id, season_id)'::text],
  'match selections reference a player in the same team and season'
);
select results_eq(
  $$select pg_get_constraintdef(oid) from pg_constraint where conname = 'match_players_replaced_player_team_season_fk'$$,
  array['FOREIGN KEY (replaced_player_id, team_id, season_id) REFERENCES players(id, team_id, season_id)'::text],
  'replacement references a player in the same team and season'
);
select results_eq(
  $$select pg_get_constraintdef(oid) from pg_constraint where conname = 'match_players_match_player_unique'$$,
  array['UNIQUE (match_id, player_id)'::text],
  'a player has at most one selection row per match'
);
select has_trigger('public', 'match_players', 'match_players_set_updated_at', 'selections maintain updated_at');
select has_function('public', 'get_regular_allocation_source', array['uuid', 'uuid', 'timestamp with time zone'], 'source function exists');
select has_function('public', 'save_regular_allocation', array['uuid', 'uuid', 'uuid', 'timestamp with time zone', 'text', 'jsonb'], 'server-only atomic save function exists');
select has_function('public', 'get_manual_adjustment_source', array['uuid', 'uuid', 'uuid'], 'manual adjustment source function exists');
select has_function('public', 'create_manual_regular_adjustment', array['uuid', 'uuid', 'uuid', 'uuid', 'uuid', 'uuid', 'text'], 'manual adjustment create function exists');
select has_function('public', 'restore_manual_regular_adjustment', array['uuid', 'uuid', 'uuid', 'uuid', 'uuid', 'uuid', 'text'], 'manual adjustment restore function exists');
select has_function('public', 'get_extra_substitute_source', array['uuid', 'uuid', 'uuid'], 'extra candidate source function exists');
select has_function('public', 'add_extra_substitute', array['uuid', 'uuid', 'uuid', 'uuid', 'uuid', 'text'], 'server-only extra add function exists');
select has_function('public', 'remove_extra_substitute', array['uuid', 'uuid', 'uuid', 'uuid', 'uuid', 'text'], 'server-only extra remove function exists');
select has_function('public', 'get_match_completion_source', array['uuid', 'uuid', 'uuid'], 'match completion source function exists');
select has_function('public', 'complete_match', array['uuid', 'uuid', 'uuid', 'uuid', 'text', 'jsonb'], 'server-only completion function exists');
select has_column('public', 'players', 'updated_at', 'players track updates for stale protection');
select has_column('public', 'players', 'create_request_id', 'players retain create idempotency key');
select has_function('public', 'get_player_profile', array['uuid','uuid','uuid'], 'player profile source exists');
select has_function('public', 'create_player', array['uuid','uuid','uuid','text','text','integer','uuid'], 'server-only player create exists');
select has_function('public', 'update_player', array['uuid','uuid','uuid','uuid','text','text','integer','text'], 'server-only player update exists');
select has_function('public', 'deactivate_player', array['uuid','uuid','uuid','uuid','text'], 'server-only player deactivate exists');
select results_eq(
  $$select tgdeferrable::text || ':' || tginitdeferred::text from pg_trigger where tgname = 'match_players_validate_participation'$$,
  array['true:true'::text], 'selection participation validation is deferred'
);
select results_eq(
  $$select tgdeferrable::text || ':' || tginitdeferred::text from pg_trigger where tgname = 'matches_validate_participation'$$,
  array['true:true'::text], 'match participation validation is deferred'
);
select results_eq(
  $$select pg_get_constraintdef(oid) from pg_constraint where conname = 'match_players_extra_shape_check'$$,
  array[format('CHECK (((selection_type <> %L::text) OR ((selection_source = %L::text) AND (selection_status = %L::text) AND (replaced_player_id IS NULL))))', 'extra', 'manual', 'selected')],
  'extra rows use the canonical shape'
);
select results_eq(
  $$select tgdeferrable::text || ':' || tginitdeferred::text from pg_trigger where tgname = 'match_players_validate_manual_pair'$$,
  array['true:true'::text],
  'manual pair validation is deferred until transaction end'
);

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
select ok(
  (select relrowsecurity from pg_class where oid = 'public.matches'::regclass),
  'RLS is enabled for matches'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.match_players'::regclass),
  'RLS is enabled for match selections'
);

select * from finish();
rollback;
