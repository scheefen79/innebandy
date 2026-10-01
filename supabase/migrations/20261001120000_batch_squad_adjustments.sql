-- ADR-022: atomic batches for manual regular swaps and planned extra substitutes.
-- The single-item functions stay as they are. Each batch uses one fingerprint and one transaction,
-- so a stale or invalid element rejects the whole batch.

create or replace function public.create_manual_regular_adjustments(
  actor_user_id uuid,
  target_team_id uuid,
  target_season_id uuid,
  target_match_id uuid,
  requested_adjustments jsonb,
  expected_fingerprint text
)
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  uuid_pattern constant text := '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
  pair_count integer;
  outgoing_ids uuid[];
  incoming_ids uuid[];
  source jsonb;
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then
    raise exception using errcode = '42501', message = 'SERVER_ONLY';
  end if;
  if not private.is_active_team_coach(actor_user_id, target_team_id) then
    raise exception using errcode = '42501', message = 'NOT_AUTHORIZED';
  end if;

  if requested_adjustments is null or jsonb_typeof(requested_adjustments) <> 'array' then
    raise exception using errcode = 'P0001', message = 'INVALID_ADJUSTMENT';
  end if;
  pair_count := jsonb_array_length(requested_adjustments);
  if pair_count < 1 or pair_count > 20 then
    raise exception using errcode = 'P0001', message = 'INVALID_ADJUSTMENT';
  end if;
  if exists (
    select 1 from jsonb_array_elements(requested_adjustments) element
    where jsonb_typeof(element) <> 'object'
      or jsonb_typeof(element -> 'outgoingPlayerId') is distinct from 'string'
      or jsonb_typeof(element -> 'incomingPlayerId') is distinct from 'string'
      or (element ->> 'outgoingPlayerId') !~ uuid_pattern
      or (element ->> 'incomingPlayerId') !~ uuid_pattern
  ) then
    raise exception using errcode = 'P0001', message = 'INVALID_ADJUSTMENT';
  end if;

  select array_agg((element ->> 'outgoingPlayerId')::uuid order by ordinality),
         array_agg((element ->> 'incomingPlayerId')::uuid order by ordinality)
  into outgoing_ids, incoming_ids
  from jsonb_array_elements(requested_adjustments) with ordinality as t(element, ordinality);

  -- Every player appears at most once across both sides.
  if (select count(distinct id) from unnest(outgoing_ids || incoming_ids) id) <> pair_count * 2 then
    raise exception using errcode = 'P0001', message = 'INVALID_ADJUSTMENT';
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
  where id = any(outgoing_ids || incoming_ids)
    and team_id = target_team_id and season_id = target_season_id
  order by id for update;

  -- Identical retry: every pair already exists as a complete manual pair.
  if (
    select count(*)
    from unnest(outgoing_ids, incoming_ids) as pair(outgoing_id, incoming_id)
    where exists (
      select 1 from public.match_players outgoing
      join public.match_players incoming
        on incoming.match_id = outgoing.match_id
        and incoming.player_id = outgoing.replaced_player_id
        and incoming.replaced_player_id = outgoing.player_id
      where outgoing.match_id = target_match_id
        and outgoing.player_id = pair.outgoing_id
        and outgoing.replaced_player_id = pair.incoming_id
        and outgoing.selection_type = 'regular' and outgoing.selection_source = 'manual'
        and outgoing.selection_status = 'removed'
        and incoming.selection_type = 'regular' and incoming.selection_source = 'manual'
        and incoming.selection_status = 'selected'
    )
  ) = pair_count then
    return true;
  end if;

  source := private.manual_adjustment_source(target_team_id, target_season_id, target_match_id);
  if md5(source::text) <> expected_fingerprint then
    raise exception using errcode = 'P0001', message = 'STALE_SELECTION';
  end if;

  if (
    select count(*) from public.players
    where id = any(incoming_ids) and team_id = target_team_id
      and season_id = target_season_id and is_active
  ) <> pair_count
  or (
    select count(*) from public.match_players
    where match_id = target_match_id and player_id = any(outgoing_ids)
      and team_id = target_team_id and season_id = target_season_id
      and selection_type = 'regular' and selection_source = 'automatic'
      and selection_status = 'selected' and not played
  ) <> pair_count
  or exists (
    select 1 from public.match_players
    where match_id = target_match_id and player_id = any(incoming_ids)
  ) then
    raise exception using errcode = 'P0001', message = 'INVALID_ADJUSTMENT';
  end if;

  delete from public.match_players
  where match_id = target_match_id and player_id = any(outgoing_ids)
    and selection_type = 'regular' and selection_source = 'automatic'
    and selection_status = 'selected' and not played;

  insert into public.match_players (
    team_id, season_id, match_id, player_id, selection_type,
    selection_source, selection_status, played, replaced_player_id
  )
  select target_team_id, target_season_id, target_match_id, pair.outgoing_id,
    'regular', 'manual', 'removed', false, pair.incoming_id
  from unnest(outgoing_ids, incoming_ids) as pair(outgoing_id, incoming_id)
  union all
  select target_team_id, target_season_id, target_match_id, pair.incoming_id,
    'regular', 'manual', 'selected', false, pair.outgoing_id
  from unnest(outgoing_ids, incoming_ids) as pair(outgoing_id, incoming_id);
  return true;
end;
$$;

revoke all on function public.create_manual_regular_adjustments(uuid, uuid, uuid, uuid, jsonb, text) from public, anon, authenticated;
grant execute on function public.create_manual_regular_adjustments(uuid, uuid, uuid, uuid, jsonb, text) to service_role;

create or replace function public.add_extra_substitutes(
  actor_user_id uuid,
  target_team_id uuid,
  target_season_id uuid,
  target_match_id uuid,
  target_player_ids uuid[],
  expected_fingerprint text
)
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  player_count integer;
  mutation_source jsonb;
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then
    raise exception using errcode = '42501', message = 'SERVER_ONLY';
  end if;
  if not private.is_active_team_coach(actor_user_id, target_team_id) then
    raise exception using errcode = '42501', message = 'NOT_AUTHORIZED';
  end if;

  player_count := coalesce(cardinality(target_player_ids), 0);
  if player_count < 1 or player_count > 20
    or exists (select 1 from unnest(target_player_ids) id where id is null)
    or (select count(distinct id) from unnest(target_player_ids) id) <> player_count then
    raise exception using errcode = 'P0001', message = 'INVALID_EXTRA_SELECTION';
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
  where id = any(target_player_ids) and team_id = target_team_id
    and season_id = target_season_id and is_active
  order by id for update;
  if (
    select count(*) from public.players
    where id = any(target_player_ids) and team_id = target_team_id
      and season_id = target_season_id and is_active
  ) <> player_count then
    raise exception using errcode = 'P0001', message = 'INVALID_EXTRA_SELECTION';
  end if;

  -- Identical retry: every requested player is already a planned extra substitute.
  if (
    select count(*) from public.match_players
    where match_id = target_match_id and player_id = any(target_player_ids)
      and team_id = target_team_id and season_id = target_season_id
      and selection_type = 'extra' and selection_source = 'manual'
      and selection_status = 'selected' and not played and replaced_player_id is null
  ) = player_count then
    return true;
  end if;
  if exists (
    select 1 from public.match_players
    where match_id = target_match_id and player_id = any(target_player_ids)
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
  )
  select target_team_id, target_season_id, target_match_id, id,
    'extra', 'manual', 'selected', false, null
  from unnest(target_player_ids) id;
  return true;
end;
$$;

revoke all on function public.add_extra_substitutes(uuid, uuid, uuid, uuid, uuid[], text) from public, anon, authenticated;
grant execute on function public.add_extra_substitutes(uuid, uuid, uuid, uuid, uuid[], text) to service_role;
