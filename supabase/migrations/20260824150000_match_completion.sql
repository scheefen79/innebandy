create or replace function private.assert_manual_regular_pair(target_match_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1
    from public.match_players entry
    where entry.match_id = target_match_id
      and entry.selection_type = 'regular'
      and entry.selection_source = 'manual'
      and (
        entry.replaced_player_id is null
        or entry.replaced_player_id = entry.player_id
        or (entry.selection_status = 'removed' and entry.played)
        or 1 <> (
          select count(*)
          from public.match_players counterpart
          where counterpart.match_id = entry.match_id
            and counterpart.team_id = entry.team_id
            and counterpart.season_id = entry.season_id
            and counterpart.player_id = entry.replaced_player_id
            and counterpart.replaced_player_id = entry.player_id
            and counterpart.selection_type = 'regular'
            and counterpart.selection_source = 'manual'
            and counterpart.selection_status <> entry.selection_status
        )
      )
  ) then
    raise exception using errcode = '23514', message = 'INVALID_MANUAL_PAIR';
  end if;
end;
$$;

create or replace function private.assert_match_participation(target_match_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1
    from public.match_players
    join public.matches on matches.id = match_players.match_id
    where match_players.match_id = target_match_id
      and match_players.played
      and (
        matches.status <> 'completed'
        or match_players.selection_status <> 'selected'
      )
  ) then
    raise exception using errcode = '23514', message = 'INVALID_PARTICIPATION_STATE';
  end if;
end;
$$;

revoke all on function private.assert_match_participation(uuid) from public;

create or replace function private.validate_match_player_participation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op <> 'INSERT' then
    perform private.assert_match_participation(old.match_id);
  end if;
  if tg_op <> 'DELETE' and (tg_op <> 'UPDATE' or new.match_id is distinct from old.match_id) then
    perform private.assert_match_participation(new.match_id);
  end if;
  return null;
end;
$$;

revoke all on function private.validate_match_player_participation() from public;

create constraint trigger match_players_validate_participation
after insert or update or delete on public.match_players
deferrable initially deferred
for each row execute function private.validate_match_player_participation();

create or replace function private.validate_match_participation_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.assert_match_participation(new.id);
  return null;
end;
$$;

revoke all on function private.validate_match_participation_status() from public;

create constraint trigger matches_validate_participation
after update of status on public.matches
deferrable initially deferred
for each row execute function private.validate_match_participation_status();

create or replace function private.match_completion_source(
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
        'targetPlayers', matches.target_players,
        'updatedAt', matches.updated_at
      )
      from public.matches
      where matches.id = target_match_id
        and matches.team_id = target_team_id
        and matches.season_id = target_season_id
    ),
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

revoke all on function private.match_completion_source(uuid, uuid, uuid) from public;

create or replace function public.get_match_completion_source(
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
  source jsonb;
  participants jsonb;
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
  source := private.match_completion_source(target_team_id, target_season_id, target_match_id);
  if source -> 'match' = 'null'::jsonb then
    raise exception using errcode = 'P0001', message = 'MATCH_NOT_AVAILABLE';
  end if;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'playerId', match_players.player_id,
      'firstName', players.first_name,
      'lastName', players.last_name,
      'selectionType', match_players.selection_type,
      'played', match_players.played
    ) order by match_players.selection_type desc, players.rotation_order, players.id
  ), '[]'::jsonb)
  into participants
  from public.match_players
  join public.players on players.id = match_players.player_id
  where match_players.match_id = target_match_id
    and match_players.team_id = target_team_id
    and match_players.season_id = target_season_id
    and match_players.selection_status = 'selected';

  return jsonb_build_object(
    'fingerprint', md5(source::text),
    'participants', participants
  );
end;
$$;

revoke all on function public.get_match_completion_source(uuid, uuid, uuid) from public;
grant execute on function public.get_match_completion_source(uuid, uuid, uuid) to authenticated;

create or replace function public.complete_match(
  actor_user_id uuid,
  target_team_id uuid,
  target_season_id uuid,
  target_match_id uuid,
  expected_fingerprint text,
  participation jsonb
)
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  current_status text;
  current_starts_at timestamptz;
  current_target integer;
  source jsonb;
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
  if jsonb_typeof(participation) <> 'array'
    or exists (
      select 1 from jsonb_array_elements(participation) item
      where jsonb_typeof(item) <> 'object'
        or jsonb_typeof(item -> 'playerId') <> 'string'
        or (item ->> 'playerId') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
        or jsonb_typeof(item -> 'played') <> 'boolean'
    )
    or (select count(*) from jsonb_array_elements(participation)) <>
      (select count(distinct item ->> 'playerId') from jsonb_array_elements(participation) item)
  then
    raise exception using errcode = 'P0001', message = 'INVALID_PARTICIPATION';
  end if;

  perform 1 from public.seasons
  where id = target_season_id and team_id = target_team_id and is_active
  for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'MATCH_NOT_AVAILABLE';
  end if;

  select status, starts_at, target_players
  into current_status, current_starts_at, current_target
  from public.matches
  where id = target_match_id and team_id = target_team_id and season_id = target_season_id
  for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'MATCH_NOT_AVAILABLE';
  end if;

  perform 1 from public.match_players
  where match_id = target_match_id
  order by player_id
  for update;

  if current_status = 'completed' then
    if not exists (
      (select match_players.player_id::text, match_players.played
       from public.match_players
       where match_id = target_match_id and selection_status = 'selected')
      except
      (select item ->> 'playerId', (item ->> 'played')::boolean
       from jsonb_array_elements(participation) item)
    ) and not exists (
      (select item ->> 'playerId', (item ->> 'played')::boolean
       from jsonb_array_elements(participation) item)
      except
      (select match_players.player_id::text, match_players.played
       from public.match_players
       where match_id = target_match_id and selection_status = 'selected')
    ) then
      return true;
    end if;
    raise exception using errcode = 'P0001', message = 'MATCH_ALREADY_COMPLETED';
  end if;

  if current_status <> 'upcoming' or current_starts_at > now() or current_target <> (
    select count(*) from public.match_players
    where match_id = target_match_id
      and selection_type = 'regular'
      and selection_status = 'selected'
  ) then
    raise exception using errcode = 'P0001', message = 'MATCH_NOT_AVAILABLE';
  end if;

  source := private.match_completion_source(target_team_id, target_season_id, target_match_id);
  if md5(source::text) <> expected_fingerprint then
    raise exception using errcode = 'P0001', message = 'STALE_SELECTION';
  end if;

  if exists (
    (select player_id::text from public.match_players
     where match_id = target_match_id and selection_status = 'selected')
    except
    (select item ->> 'playerId' from jsonb_array_elements(participation) item)
  ) or exists (
    (select item ->> 'playerId' from jsonb_array_elements(participation) item)
    except
    (select player_id::text from public.match_players
     where match_id = target_match_id and selection_status = 'selected')
  ) then
    raise exception using errcode = 'P0001', message = 'INVALID_PARTICIPATION';
  end if;

  update public.match_players
  set played = (decision.item ->> 'played')::boolean
  from jsonb_array_elements(participation) decision(item)
  where match_players.match_id = target_match_id
    and match_players.player_id::text = decision.item ->> 'playerId'
    and match_players.selection_status = 'selected';

  update public.matches set status = 'completed' where id = target_match_id;
  return true;
end;
$$;

revoke all on function public.complete_match(uuid, uuid, uuid, uuid, text, jsonb) from public;
grant execute on function public.complete_match(uuid, uuid, uuid, uuid, text, jsonb) to service_role;
