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
        or entry.played
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
            and not counterpart.played
        )
      )
  ) then
    raise exception using errcode = '23514', message = 'INVALID_MANUAL_PAIR';
  end if;
end;
$$;

revoke all on function private.assert_manual_regular_pair(uuid) from public;

create or replace function private.validate_manual_regular_pair()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op <> 'INSERT' then
    perform private.assert_manual_regular_pair(old.match_id);
  end if;
  if tg_op <> 'DELETE' and (tg_op <> 'UPDATE' or new.match_id is distinct from old.match_id) then
    perform private.assert_manual_regular_pair(new.match_id);
  end if;
  return null;
end;
$$;

revoke all on function private.validate_manual_regular_pair() from public;

create constraint trigger match_players_validate_manual_pair
after insert or update or delete on public.match_players
deferrable initially deferred
for each row execute function private.validate_manual_regular_pair();

create or replace function private.manual_adjustment_source(
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

revoke all on function private.manual_adjustment_source(uuid, uuid, uuid) from public;

create or replace function public.get_manual_adjustment_source(
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
  source := private.manual_adjustment_source(target_team_id, target_season_id, target_match_id);
  if source -> 'match' = 'null'::jsonb then
    raise exception using errcode = 'P0001', message = 'MATCH_NOT_AVAILABLE';
  end if;
  return jsonb_build_object('source', source, 'fingerprint', md5(source::text));
end;
$$;

revoke all on function public.get_manual_adjustment_source(uuid, uuid, uuid) from public;
grant execute on function public.get_manual_adjustment_source(uuid, uuid, uuid) to authenticated;

create or replace function public.create_manual_regular_adjustment(
  actor_user_id uuid,
  target_team_id uuid,
  target_season_id uuid,
  target_match_id uuid,
  outgoing_player_id uuid,
  incoming_player_id uuid,
  expected_fingerprint text
)
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
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
  if outgoing_player_id = incoming_player_id then
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
  where id in (outgoing_player_id, incoming_player_id)
    and team_id = target_team_id and season_id = target_season_id
  order by id for update;

  if exists (
    select 1 from public.match_players outgoing
    join public.match_players incoming
      on incoming.match_id = outgoing.match_id
      and incoming.player_id = outgoing.replaced_player_id
      and incoming.replaced_player_id = outgoing.player_id
    where outgoing.match_id = target_match_id
      and outgoing.player_id = outgoing_player_id
      and outgoing.replaced_player_id = incoming_player_id
      and outgoing.selection_type = 'regular' and outgoing.selection_source = 'manual'
      and outgoing.selection_status = 'removed'
      and incoming.selection_type = 'regular' and incoming.selection_source = 'manual'
      and incoming.selection_status = 'selected'
  ) then
    return true;
  end if;

  source := private.manual_adjustment_source(target_team_id, target_season_id, target_match_id);
  if md5(source::text) <> expected_fingerprint then
    raise exception using errcode = 'P0001', message = 'STALE_SELECTION';
  end if;

  if not exists (
    select 1 from public.players
    where id = incoming_player_id and team_id = target_team_id
      and season_id = target_season_id and is_active
  ) or not exists (
    select 1 from public.match_players
    where match_id = target_match_id and player_id = outgoing_player_id
      and team_id = target_team_id and season_id = target_season_id
      and selection_type = 'regular' and selection_source = 'automatic'
      and selection_status = 'selected' and not played
  ) or exists (
    select 1 from public.match_players
    where match_id = target_match_id and player_id = incoming_player_id
  ) then
    raise exception using errcode = 'P0001', message = 'INVALID_ADJUSTMENT';
  end if;

  delete from public.match_players
  where match_id = target_match_id and player_id = outgoing_player_id
    and selection_type = 'regular' and selection_source = 'automatic'
    and selection_status = 'selected' and not played;

  insert into public.match_players (
    team_id, season_id, match_id, player_id, selection_type,
    selection_source, selection_status, played, replaced_player_id
  ) values
    (target_team_id, target_season_id, target_match_id, outgoing_player_id,
      'regular', 'manual', 'removed', false, incoming_player_id),
    (target_team_id, target_season_id, target_match_id, incoming_player_id,
      'regular', 'manual', 'selected', false, outgoing_player_id);
  return true;
end;
$$;

revoke all on function public.create_manual_regular_adjustment(uuid, uuid, uuid, uuid, uuid, uuid, text) from public;
grant execute on function public.create_manual_regular_adjustment(uuid, uuid, uuid, uuid, uuid, uuid, text) to service_role;

create or replace function public.restore_manual_regular_adjustment(
  actor_user_id uuid,
  target_team_id uuid,
  target_season_id uuid,
  target_match_id uuid,
  outgoing_player_id uuid,
  incoming_player_id uuid,
  expected_fingerprint text
)
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
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
  where id in (outgoing_player_id, incoming_player_id)
    and team_id = target_team_id and season_id = target_season_id
  order by id for update;

  if exists (
    select 1 from public.match_players
    where match_id = target_match_id and player_id = outgoing_player_id
      and selection_type = 'regular' and selection_source = 'automatic'
      and selection_status = 'selected'
  ) and not exists (
    select 1 from public.match_players
    where match_id = target_match_id and player_id = incoming_player_id
  ) then
    return true;
  end if;

  source := private.manual_adjustment_source(target_team_id, target_season_id, target_match_id);
  if md5(source::text) <> expected_fingerprint then
    raise exception using errcode = 'P0001', message = 'STALE_SELECTION';
  end if;

  if not exists (
    select 1 from public.players
    where id = outgoing_player_id and team_id = target_team_id
      and season_id = target_season_id and is_active
  ) or not exists (
    select 1 from public.match_players outgoing
    join public.match_players incoming
      on incoming.match_id = outgoing.match_id
      and incoming.player_id = outgoing.replaced_player_id
      and incoming.replaced_player_id = outgoing.player_id
    where outgoing.match_id = target_match_id
      and outgoing.player_id = outgoing_player_id
      and outgoing.replaced_player_id = incoming_player_id
      and outgoing.selection_type = 'regular' and outgoing.selection_source = 'manual'
      and outgoing.selection_status = 'removed'
      and incoming.selection_type = 'regular' and incoming.selection_source = 'manual'
      and incoming.selection_status = 'selected'
  ) then
    raise exception using errcode = 'P0001', message = 'INVALID_ADJUSTMENT';
  end if;

  delete from public.match_players
  where match_id = target_match_id and player_id in (outgoing_player_id, incoming_player_id)
    and selection_type = 'regular' and selection_source = 'manual';

  insert into public.match_players (
    team_id, season_id, match_id, player_id, selection_type,
    selection_source, selection_status, played
  ) values (
    target_team_id, target_season_id, target_match_id, outgoing_player_id,
    'regular', 'automatic', 'selected', false
  );
  return true;
end;
$$;

revoke all on function public.restore_manual_regular_adjustment(uuid, uuid, uuid, uuid, uuid, uuid, text) from public;
grant execute on function public.restore_manual_regular_adjustment(uuid, uuid, uuid, uuid, uuid, uuid, text) to service_role;
