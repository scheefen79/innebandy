alter table public.match_players
  add constraint match_players_extra_shape_check check (
    selection_type <> 'extra'
    or (
      selection_source = 'manual'
      and selection_status = 'selected'
      and replaced_player_id is null
    )
  );

create or replace function private.extra_substitute_mutation_source(
  target_team_id uuid,
  target_season_id uuid,
  target_match_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'version', 1,
    'teamId', target_team_id,
    'seasonId', target_season_id,
    'match', (
      select jsonb_build_object(
        'id', matches.id,
        'status', matches.status,
        'startsAt', matches.starts_at,
        'updatedAt', matches.updated_at
      )
      from public.matches
      where matches.id = target_match_id
        and matches.team_id = target_team_id
        and matches.season_id = target_season_id
    ),
    'players', coalesce((
      select jsonb_agg(
        jsonb_build_object('id', players.id, 'isActive', players.is_active)
        order by players.id
      )
      from public.players
      where players.team_id = target_team_id
        and players.season_id = target_season_id
    ), '[]'::jsonb),
    'selections', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'playerId', match_players.player_id,
          'selectionType', match_players.selection_type,
          'selectionSource', match_players.selection_source,
          'selectionStatus', match_players.selection_status,
          'played', match_players.played,
          'replacedPlayerId', match_players.replaced_player_id,
          'updatedAt', match_players.updated_at
        ) order by match_players.player_id
      )
      from public.match_players
      where match_players.match_id = target_match_id
        and match_players.team_id = target_team_id
        and match_players.season_id = target_season_id
    ), '[]'::jsonb)
  );
$$;

revoke all on function private.extra_substitute_mutation_source(uuid, uuid, uuid) from public;

create or replace function public.get_extra_substitute_source(
  target_team_id uuid,
  target_season_id uuid,
  target_match_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  mutation_source jsonb;
  candidates jsonb;
begin
  if not (select private.is_active_team_member(target_team_id)) then
    raise exception using errcode = '42501', message = 'NOT_AUTHORIZED';
  end if;
  if not exists (
    select 1 from public.seasons
    where id = target_season_id and team_id = target_team_id and is_active
  ) then
    raise exception using errcode = 'P0001', message = 'MATCH_NOT_AVAILABLE';
  end if;

  mutation_source := private.extra_substitute_mutation_source(
    target_team_id, target_season_id, target_match_id
  );
  if mutation_source -> 'match' = 'null'::jsonb then
    raise exception using errcode = 'P0001', message = 'MATCH_NOT_AVAILABLE';
  end if;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', eligible.id,
      'firstName', eligible.first_name,
      'lastName', eligible.last_name,
      'rotationOrder', eligible.rotation_order,
      'completedExtraCount', eligible.completed_extra_count,
      'lastCompletedExtraAt', eligible.last_completed_extra_at
    ) order by eligible.rotation_order, eligible.id
  ), '[]'::jsonb)
  into candidates
  from (
    select
      players.id,
      players.first_name,
      players.last_name,
      players.rotation_order,
      count(history_match.id)::integer as completed_extra_count,
      case
        when max(history_match.starts_at) is null then null
        else to_char(max(history_match.starts_at) at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
      end as last_completed_extra_at
    from public.players
    left join public.match_players history
      on history.player_id = players.id
      and history.team_id = players.team_id
      and history.season_id = players.season_id
      and history.selection_type = 'extra'
      and history.selection_status = 'selected'
      and history.played
    left join public.matches history_match
      on history_match.id = history.match_id
      and history_match.status = 'completed'
    where players.team_id = target_team_id
      and players.season_id = target_season_id
      and players.is_active
      and not exists (
        select 1 from public.match_players current_selection
        where current_selection.match_id = target_match_id
          and current_selection.player_id = players.id
      )
    group by players.id, players.first_name, players.last_name, players.rotation_order
  ) eligible;

  return jsonb_build_object(
    'fingerprint', md5(mutation_source::text),
    'candidates', candidates
  );
end;
$$;

revoke all on function public.get_extra_substitute_source(uuid, uuid, uuid) from public;
grant execute on function public.get_extra_substitute_source(uuid, uuid, uuid) to authenticated;

create or replace function public.add_extra_substitute(
  actor_user_id uuid,
  target_team_id uuid,
  target_season_id uuid,
  target_match_id uuid,
  target_player_id uuid,
  expected_fingerprint text
)
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  mutation_source jsonb;
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then
    raise exception using errcode = '42501', message = 'SERVER_ONLY';
  end if;
  if not exists (
    select 1 from public.team_members
    where team_id = target_team_id and user_id = actor_user_id and is_active
  ) then
    raise exception using errcode = '42501', message = 'NOT_AUTHORIZED';
  end if;

  perform 1 from public.seasons
  where id = target_season_id and team_id = target_team_id and is_active
  for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'MATCH_NOT_AVAILABLE';
  end if;
  perform 1 from public.matches
  where id = target_match_id and team_id = target_team_id and season_id = target_season_id
    and status = 'upcoming' and starts_at > now()
    and target_players = (
      select count(*)
      from public.match_players regular_selection
      where regular_selection.match_id = target_match_id
        and regular_selection.selection_type = 'regular'
        and regular_selection.selection_status = 'selected'
    )
  for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'MATCH_NOT_AVAILABLE';
  end if;
  perform 1 from public.players
  where id = target_player_id and team_id = target_team_id
    and season_id = target_season_id and is_active
  for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'INVALID_EXTRA_SELECTION';
  end if;

  if exists (
    select 1 from public.match_players
    where match_id = target_match_id and player_id = target_player_id
      and team_id = target_team_id and season_id = target_season_id
      and selection_type = 'extra' and selection_source = 'manual'
      and selection_status = 'selected' and not played and replaced_player_id is null
  ) then
    return true;
  end if;
  if exists (
    select 1 from public.match_players
    where match_id = target_match_id and player_id = target_player_id
  ) then
    raise exception using errcode = 'P0001', message = 'INVALID_EXTRA_SELECTION';
  end if;

  mutation_source := private.extra_substitute_mutation_source(
    target_team_id, target_season_id, target_match_id
  );
  if md5(mutation_source::text) <> expected_fingerprint then
    raise exception using errcode = 'P0001', message = 'STALE_SELECTION';
  end if;

  insert into public.match_players (
    team_id, season_id, match_id, player_id, selection_type,
    selection_source, selection_status, played, replaced_player_id
  ) values (
    target_team_id, target_season_id, target_match_id, target_player_id,
    'extra', 'manual', 'selected', false, null
  );
  return true;
end;
$$;

revoke all on function public.add_extra_substitute(uuid, uuid, uuid, uuid, uuid, text) from public;
grant execute on function public.add_extra_substitute(uuid, uuid, uuid, uuid, uuid, text) to service_role;

create or replace function public.remove_extra_substitute(
  actor_user_id uuid,
  target_team_id uuid,
  target_season_id uuid,
  target_match_id uuid,
  target_player_id uuid,
  expected_fingerprint text
)
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  mutation_source jsonb;
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then
    raise exception using errcode = '42501', message = 'SERVER_ONLY';
  end if;
  if not exists (
    select 1 from public.team_members
    where team_id = target_team_id and user_id = actor_user_id and is_active
  ) then
    raise exception using errcode = '42501', message = 'NOT_AUTHORIZED';
  end if;

  perform 1 from public.seasons
  where id = target_season_id and team_id = target_team_id and is_active
  for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'MATCH_NOT_AVAILABLE';
  end if;
  perform 1 from public.matches
  where id = target_match_id and team_id = target_team_id and season_id = target_season_id
    and status = 'upcoming' and starts_at > now()
  for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'MATCH_NOT_AVAILABLE';
  end if;
  perform 1 from public.players
  where id = target_player_id and team_id = target_team_id and season_id = target_season_id
  for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'INVALID_EXTRA_SELECTION';
  end if;

  if not exists (
    select 1 from public.match_players
    where match_id = target_match_id and player_id = target_player_id
  ) then
    return true;
  end if;
  if not exists (
    select 1 from public.match_players
    where match_id = target_match_id and player_id = target_player_id
      and team_id = target_team_id and season_id = target_season_id
      and selection_type = 'extra' and selection_source = 'manual'
      and selection_status = 'selected' and not played and replaced_player_id is null
  ) then
    raise exception using errcode = 'P0001', message = 'INVALID_EXTRA_SELECTION';
  end if;

  mutation_source := private.extra_substitute_mutation_source(
    target_team_id, target_season_id, target_match_id
  );
  if md5(mutation_source::text) <> expected_fingerprint then
    raise exception using errcode = 'P0001', message = 'STALE_SELECTION';
  end if;

  delete from public.match_players
  where match_id = target_match_id and player_id = target_player_id
    and selection_type = 'extra' and selection_source = 'manual'
    and selection_status = 'selected' and not played;
  return true;
end;
$$;

revoke all on function public.remove_extra_substitute(uuid, uuid, uuid, uuid, uuid, text) from public;
grant execute on function public.remove_extra_substitute(uuid, uuid, uuid, uuid, uuid, text) to service_role;
