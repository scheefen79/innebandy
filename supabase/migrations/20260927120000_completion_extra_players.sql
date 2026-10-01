-- Let coaches register one or more previously unplanned extra players while
-- completing a match. The extra rows and the completed status are committed
-- in the same transaction so statistics never observe a partial result.

create or replace function public.get_match_completion_source_unchecked(
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
  extra_candidates jsonb;
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

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'playerId', players.id,
      'firstName', players.first_name,
      'lastName', players.last_name
    ) order by players.rotation_order, players.id
  ), '[]'::jsonb)
  into extra_candidates
  from public.players
  where players.team_id = target_team_id
    and players.season_id = target_season_id
    and players.is_active
    and not exists (
      select 1
      from public.match_players
      where match_players.match_id = target_match_id
        and match_players.player_id = players.id
    );

  return jsonb_build_object(
    'fingerprint', md5(source::text),
    'participants', participants,
    'extraCandidates', extra_candidates
  );
end;
$$;
create or replace function public.complete_match_unchecked(
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

  -- Every existing selected row still needs an explicit decision.
  if exists (
    (select player_id::text from public.match_players
     where match_id = target_match_id and selection_status = 'selected')
    except
    (select item ->> 'playerId' from jsonb_array_elements(participation) item)
  ) then
    raise exception using errcode = 'P0001', message = 'INVALID_PARTICIPATION';
  end if;

  -- Additional decisions are valid only for active players without any row in
  -- this match, and a newly registered extra must actually have participated.
  if exists (
    select 1
    from jsonb_array_elements(participation) decision(item)
    where not exists (
      select 1 from public.match_players
      where match_id = target_match_id
        and player_id::text = decision.item ->> 'playerId'
        and selection_status = 'selected'
    ) and (
      not (decision.item ->> 'played')::boolean
      or exists (
        select 1 from public.match_players
        where match_id = target_match_id
          and player_id::text = decision.item ->> 'playerId'
      )
      or not exists (
        select 1 from public.players
        where id::text = decision.item ->> 'playerId'
          and team_id = target_team_id
          and season_id = target_season_id
          and is_active
      )
    )
  ) then
    raise exception using errcode = 'P0001', message = 'INVALID_PARTICIPATION';
  end if;

  insert into public.match_players (
    team_id, season_id, match_id, player_id, selection_type,
    selection_source, selection_status, played, replaced_player_id
  )
  select
    target_team_id, target_season_id, target_match_id,
    (decision.item ->> 'playerId')::uuid,
    'extra', 'manual', 'selected', true, null
  from jsonb_array_elements(participation) decision(item)
  where not exists (
    select 1 from public.match_players
    where match_id = target_match_id
      and player_id::text = decision.item ->> 'playerId'
  );

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
