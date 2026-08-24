alter table public.players
  add column updated_at timestamptz not null default now(),
  add column create_request_id uuid;

create unique index players_create_request_unique
  on public.players (team_id, season_id, create_request_id)
  where create_request_id is not null;

create trigger players_set_updated_at
before update on public.players
for each row execute function private.set_updated_at();

revoke insert, update on table public.players from authenticated;
grant select on table public.players, public.match_players to service_role;

create or replace function private.player_source(target_team_id uuid, target_season_id uuid, target_player_id uuid)
returns jsonb
language sql stable security definer set search_path = ''
as $$
  select jsonb_build_object(
    'version', 1,
    'player', jsonb_build_object(
      'id', players.id, 'teamId', players.team_id, 'seasonId', players.season_id,
      'firstName', players.first_name, 'lastName', players.last_name,
      'level', players.level, 'rotationOrder', players.rotation_order,
      'isActive', players.is_active, 'updatedAt', players.updated_at
    ),
    'matches', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', matches.id, 'opponent', matches.opponent, 'startsAt', matches.starts_at,
        'location', matches.location, 'status', matches.status,
        'selectionType', match_players.selection_type,
        'selectionSource', match_players.selection_source,
        'selectionStatus', match_players.selection_status,
        'played', match_players.played
      ) order by matches.starts_at, matches.id)
      from public.match_players join public.matches on matches.id = match_players.match_id
      where match_players.team_id = target_team_id
        and match_players.season_id = target_season_id
        and match_players.player_id = target_player_id
    ), '[]'::jsonb)
  )
  from public.players
  where players.id = target_player_id and players.team_id = target_team_id and players.season_id = target_season_id;
$$;

revoke all on function private.player_source(uuid, uuid, uuid) from public;

create or replace function public.get_player_profile(target_team_id uuid, target_season_id uuid, target_player_id uuid)
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare source jsonb;
begin
  if not (select private.is_active_team_member(target_team_id)) then
    raise exception using errcode='42501', message='NOT_AUTHORIZED';
  end if;
  if not exists (select 1 from public.seasons where id=target_season_id and team_id=target_team_id and is_active) then
    raise exception using errcode='P0001', message='PLAYER_NOT_AVAILABLE';
  end if;
  source := private.player_source(target_team_id, target_season_id, target_player_id);
  if source is null then raise exception using errcode='P0001', message='PLAYER_NOT_AVAILABLE'; end if;
  return source || jsonb_build_object('fingerprint', md5(source::text), 'serverNow', now());
end;
$$;

revoke all on function public.get_player_profile(uuid, uuid, uuid) from public;
grant execute on function public.get_player_profile(uuid, uuid, uuid) to authenticated;

create or replace function public.get_player_list(target_team_id uuid)
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare result jsonb;
begin
  if not (select private.is_active_team_member(target_team_id)) then
    raise exception using errcode='42501', message='NOT_AUTHORIZED';
  end if;

  select jsonb_build_object(
    'seasonName', seasons.name,
    'players', coalesce(jsonb_agg(jsonb_build_object(
      'id', players.id,
      'firstName', players.first_name,
      'lastName', players.last_name,
      'level', players.level,
      'plannedRegular', counts.planned_regular,
      'completedRegular', counts.completed_regular,
      'plannedExtra', counts.planned_extra,
      'completedExtra', counts.completed_extra
    ) order by players.rotation_order) filter (where players.id is not null), '[]'::jsonb)
  ) into result
  from public.seasons
  left join public.players on players.season_id=seasons.id and players.team_id=seasons.team_id and players.is_active
  left join lateral (
    select
      count(*) filter (where matches.status='upcoming' and match_players.selection_type='regular')::integer as planned_regular,
      count(*) filter (where matches.status='completed' and match_players.played and match_players.selection_type='regular')::integer as completed_regular,
      count(*) filter (where matches.status='upcoming' and match_players.selection_type='extra')::integer as planned_extra,
      count(*) filter (where matches.status='completed' and match_players.played and match_players.selection_type='extra')::integer as completed_extra
    from public.match_players
    join public.matches on matches.id=match_players.match_id
    where match_players.player_id=players.id and match_players.selection_status='selected'
  ) counts on true
  where seasons.team_id=target_team_id and seasons.is_active
  group by seasons.id, seasons.name;

  if result is null then raise exception using errcode='P0001', message='ACTIVE_SEASON_NOT_AVAILABLE'; end if;
  return result;
end;
$$;

revoke all on function public.get_player_list(uuid) from public;
grant execute on function public.get_player_list(uuid) to authenticated;

create or replace function public.create_player(
  actor_user_id uuid, target_team_id uuid, target_season_id uuid,
  requested_first_name text, requested_last_name text, requested_level integer, request_id uuid
)
returns uuid
language plpgsql volatile security definer set search_path = ''
as $$
declare normalized_first text := trim(requested_first_name);
declare normalized_last text := nullif(trim(requested_last_name), '');
declare existing public.players%rowtype;
declare next_rotation integer;
declare created_id uuid;
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then raise exception using errcode='42501', message='SERVER_ONLY'; end if;
  if not exists (select 1 from public.team_members where team_id=target_team_id and user_id=actor_user_id and is_active) then raise exception using errcode='42501', message='NOT_AUTHORIZED'; end if;
  if request_id is null or normalized_first = '' or length(normalized_first) > 100 or (normalized_last is not null and length(normalized_last) > 100) or requested_level not between 1 and 3 then
    raise exception using errcode='P0001', message='INVALID_PLAYER';
  end if;
  perform 1 from public.seasons where id=target_season_id and team_id=target_team_id and is_active for update;
  if not found then raise exception using errcode='P0001', message='PLAYER_NOT_AVAILABLE'; end if;
  select * into existing from public.players where team_id=target_team_id and season_id=target_season_id and create_request_id=request_id for update;
  if found then
    if existing.first_name=normalized_first and existing.last_name is not distinct from normalized_last and existing.level=requested_level then return existing.id; end if;
    raise exception using errcode='P0001', message='REQUEST_CONFLICT';
  end if;
  select coalesce(max(rotation_order),0)+1 into next_rotation from public.players where season_id=target_season_id;
  insert into public.players(team_id,season_id,first_name,last_name,level,rotation_order,create_request_id)
  values(target_team_id,target_season_id,normalized_first,normalized_last,requested_level,next_rotation,request_id)
  returning id into created_id;
  return created_id;
end;
$$;

create or replace function public.update_player(
  actor_user_id uuid, target_team_id uuid, target_season_id uuid, target_player_id uuid,
  requested_first_name text, requested_last_name text, requested_level integer, expected_fingerprint text
)
returns boolean
language plpgsql volatile security definer set search_path = ''
as $$
declare normalized_first text := trim(requested_first_name);
declare normalized_last text := nullif(trim(requested_last_name), '');
declare current_player public.players%rowtype;
declare source jsonb;
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then raise exception using errcode='42501', message='SERVER_ONLY'; end if;
  if not exists (select 1 from public.team_members where team_id=target_team_id and user_id=actor_user_id and is_active) then raise exception using errcode='42501', message='NOT_AUTHORIZED'; end if;
  if normalized_first = '' or length(normalized_first)>100 or (normalized_last is not null and length(normalized_last)>100) or requested_level not between 1 and 3 then raise exception using errcode='P0001', message='INVALID_PLAYER'; end if;
  perform 1 from public.seasons where id=target_season_id and team_id=target_team_id and is_active for update;
  if not found then raise exception using errcode='P0001', message='PLAYER_NOT_AVAILABLE'; end if;
  select * into current_player from public.players where id=target_player_id and team_id=target_team_id and season_id=target_season_id for update;
  if not found or not current_player.is_active then raise exception using errcode='P0001', message='PLAYER_NOT_AVAILABLE'; end if;
  if current_player.first_name=normalized_first and current_player.last_name is not distinct from normalized_last and current_player.level=requested_level then return true; end if;
  source := private.player_source(target_team_id,target_season_id,target_player_id);
  if md5(source::text) <> expected_fingerprint then raise exception using errcode='P0001', message='STALE_PLAYER'; end if;
  update public.players set first_name=normalized_first,last_name=normalized_last,level=requested_level where id=target_player_id;
  return true;
end;
$$;

create or replace function public.deactivate_player(
  actor_user_id uuid, target_team_id uuid, target_season_id uuid, target_player_id uuid, expected_fingerprint text
)
returns boolean
language plpgsql volatile security definer set search_path = ''
as $$
declare current_player public.players%rowtype;
declare source jsonb;
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then raise exception using errcode='42501', message='SERVER_ONLY'; end if;
  if not exists (select 1 from public.team_members where team_id=target_team_id and user_id=actor_user_id and is_active) then raise exception using errcode='42501', message='NOT_AUTHORIZED'; end if;
  perform 1 from public.seasons where id=target_season_id and team_id=target_team_id and is_active for update;
  if not found then raise exception using errcode='P0001', message='PLAYER_NOT_AVAILABLE'; end if;
  select * into current_player from public.players where id=target_player_id and team_id=target_team_id and season_id=target_season_id for update;
  if not found then raise exception using errcode='P0001', message='PLAYER_NOT_AVAILABLE'; end if;
  if not current_player.is_active then return true; end if;
  if exists (
    select 1 from public.match_players join public.matches on matches.id=match_players.match_id
    where match_players.player_id=target_player_id and match_players.team_id=target_team_id
      and matches.status='upcoming' and matches.starts_at>now()
      and (match_players.selection_source='manual' or match_players.selection_type='extra')
  ) then raise exception using errcode='P0001', message='PLAYER_HAS_PLANNED_DECISIONS'; end if;
  source := private.player_source(target_team_id,target_season_id,target_player_id);
  if md5(source::text) <> expected_fingerprint then raise exception using errcode='P0001', message='STALE_PLAYER'; end if;
  update public.players set is_active=false where id=target_player_id;
  return true;
end;
$$;

revoke all on function public.create_player(uuid,uuid,uuid,text,text,integer,uuid) from public;
revoke all on function public.update_player(uuid,uuid,uuid,uuid,text,text,integer,text) from public;
revoke all on function public.deactivate_player(uuid,uuid,uuid,uuid,text) from public;
grant execute on function public.create_player(uuid,uuid,uuid,text,text,integer,uuid) to service_role;
grant execute on function public.update_player(uuid,uuid,uuid,uuid,text,text,integer,text) to service_role;
grant execute on function public.deactivate_player(uuid,uuid,uuid,uuid,text) to service_role;
