alter table public.players
  add constraint players_id_team_season_unique unique (id, team_id, season_id);

alter table public.matches
  add constraint matches_id_team_season_unique unique (id, team_id, season_id);

create table public.match_players (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null,
  season_id uuid not null,
  match_id uuid not null,
  player_id uuid not null,
  selection_type text not null check (selection_type in ('regular', 'extra')),
  selection_source text not null check (selection_source in ('automatic', 'manual')),
  selection_status text not null check (selection_status in ('selected', 'removed')),
  played boolean not null default false,
  replaced_player_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint match_players_match_team_season_fk
    foreign key (match_id, team_id, season_id)
    references public.matches(id, team_id, season_id)
    on delete cascade,
  constraint match_players_player_team_season_fk
    foreign key (player_id, team_id, season_id)
    references public.players(id, team_id, season_id),
  constraint match_players_replaced_player_team_season_fk
    foreign key (replaced_player_id, team_id, season_id)
    references public.players(id, team_id, season_id),
  constraint match_players_match_player_unique unique (match_id, player_id)
);

create index match_players_team_season_match_idx
  on public.match_players (team_id, season_id, match_id);

create index match_players_player_history_idx
  on public.match_players (player_id, selection_type, played);

create trigger match_players_set_updated_at
before update on public.match_players
for each row execute function private.set_updated_at();

alter table public.match_players enable row level security;

create policy "Active members can read team selections"
on public.match_players
for select
to authenticated
using ((select private.is_active_team_member(team_id)));

revoke all on table public.match_players from anon, authenticated;
grant select on table public.match_players to authenticated;

create or replace function private.regular_allocation_source(
  target_team_id uuid,
  target_season_id uuid,
  boundary timestamptz
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
    'players', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', players.id,
          'level', players.level,
          'rotationOrder', players.rotation_order,
          'baselineRegularCount', (
            select count(*)
            from public.match_players history
            join public.matches history_match on history_match.id = history.match_id
            where history.player_id = players.id
              and history.selection_type = 'regular'
              and history.selection_status = 'selected'
              and (
                (history_match.status = 'completed' and history.played)
                or (history_match.status = 'upcoming' and history_match.starts_at < boundary)
              )
          ),
          'baselineLastRegularMatchOrder', (
            select max(ordered_history.match_order)
            from (
              select id, row_number() over (order by starts_at, id)::integer as match_order
              from public.matches
              where team_id = target_team_id and season_id = target_season_id
            ) ordered_history
            join public.match_players history on history.match_id = ordered_history.id
            join public.matches history_match on history_match.id = history.match_id
            where history.player_id = players.id
              and history.selection_type = 'regular'
              and history.selection_status = 'selected'
              and (
                (history_match.status = 'completed' and history.played)
                or (history_match.status = 'upcoming' and history_match.starts_at < boundary)
              )
          )
        ) order by players.rotation_order, players.id
      )
      from public.players
      where players.team_id = target_team_id
        and players.season_id = target_season_id
        and players.is_active
    ), '[]'::jsonb),
    'matches', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', matches.id,
          'order', ordered_matches.match_order,
          'targetSize', matches.target_players
        ) order by ordered_matches.match_order
      )
      from (
        select id, match_order
        from (
          select
            id,
            status,
            starts_at,
            row_number() over (order by starts_at, id)::integer as match_order
          from public.matches
          where team_id = target_team_id
            and season_id = target_season_id
        ) season_matches
        where status = 'upcoming'
          and starts_at >= boundary
      ) ordered_matches
      join public.matches on matches.id = ordered_matches.id
    ), '[]'::jsonb),
    'manualSelections', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'matchId', match_players.match_id,
          'playerId', match_players.player_id,
          'decision', case when match_players.selection_status = 'selected' then 'include' else 'exclude' end
        ) order by match_players.match_id, match_players.player_id
      )
      from public.match_players
      join public.matches on matches.id = match_players.match_id
      where match_players.team_id = target_team_id
        and match_players.season_id = target_season_id
        and match_players.selection_type = 'regular'
        and match_players.selection_source = 'manual'
        and matches.status = 'upcoming'
        and matches.starts_at >= boundary
    ), '[]'::jsonb),
    'automaticSelections', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'matchId', match_players.match_id,
          'playerId', match_players.player_id,
          'updatedAt', match_players.updated_at
        ) order by match_players.match_id, match_players.player_id
      )
      from public.match_players
      join public.matches on matches.id = match_players.match_id
      where match_players.team_id = target_team_id
        and match_players.season_id = target_season_id
        and match_players.selection_type = 'regular'
        and match_players.selection_source = 'automatic'
        and matches.status = 'upcoming'
        and matches.starts_at >= boundary
    ), '[]'::jsonb)
  );
$$;

revoke all on function private.regular_allocation_source(uuid, uuid, timestamptz) from public;

create or replace function public.get_regular_allocation_source(
  target_team_id uuid,
  target_season_id uuid,
  boundary timestamptz
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
    raise exception using errcode = 'P0001', message = 'ACTIVE_SEASON_NOT_FOUND';
  end if;

  source := private.regular_allocation_source(target_team_id, target_season_id, boundary);
  return jsonb_build_object('source', source, 'fingerprint', md5(source::text));
end;
$$;

revoke all on function public.get_regular_allocation_source(uuid, uuid, timestamptz) from public;
grant execute on function public.get_regular_allocation_source(uuid, uuid, timestamptz) to authenticated;

create or replace function public.save_regular_allocation(
  actor_user_id uuid,
  target_team_id uuid,
  target_season_id uuid,
  boundary timestamptz,
  expected_fingerprint text,
  allocations jsonb
)
returns integer
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  source jsonb;
  source_match jsonb;
  allocation jsonb;
  allocation_match_id uuid;
  expected_target integer;
  saved_count integer;
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then
    raise exception using errcode = '42501', message = 'SERVER_ONLY';
  end if;

  if not exists (
    select 1 from public.team_members
    where team_id = target_team_id
      and user_id = actor_user_id
      and is_active
  ) then
    raise exception using errcode = '42501', message = 'NOT_AUTHORIZED';
  end if;

  perform 1
  from public.seasons
  where id = target_season_id and team_id = target_team_id and is_active
  for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'ACTIVE_SEASON_NOT_FOUND';
  end if;

  perform 1
  from public.matches
  where team_id = target_team_id
    and season_id = target_season_id
    and status = 'upcoming'
    and starts_at >= boundary
  order by starts_at, id
  for update;

  perform 1
  from public.players
  where team_id = target_team_id and season_id = target_season_id and is_active
  order by rotation_order, id
  for update;

  source := private.regular_allocation_source(target_team_id, target_season_id, boundary);
  if md5(source::text) <> expected_fingerprint then
    raise exception using errcode = 'P0001', message = 'STALE_PREVIEW';
  end if;

  if jsonb_typeof(allocations) <> 'array'
    or jsonb_array_length(allocations) <> jsonb_array_length(source -> 'matches') then
    raise exception using errcode = 'P0001', message = 'INVALID_ALLOCATION';
  end if;

  if (
    select count(distinct item ->> 'matchId') <> count(*)
    from jsonb_array_elements(allocations) item
  ) then
    raise exception using errcode = 'P0001', message = 'INVALID_ALLOCATION';
  end if;

  for source_match in select value from jsonb_array_elements(source -> 'matches') loop
    allocation_match_id := (source_match ->> 'id')::uuid;
    expected_target := (source_match ->> 'targetSize')::integer;

    select item into allocation
    from jsonb_array_elements(allocations) item
    where item ->> 'matchId' = allocation_match_id::text;

    if allocation is null
      or jsonb_typeof(allocation -> 'playerIds') <> 'array'
      or jsonb_array_length(allocation -> 'playerIds') <> expected_target
      or (select count(distinct value) from jsonb_array_elements_text(allocation -> 'playerIds')) <> expected_target
      or exists (
        select 1
        from jsonb_array_elements_text(allocation -> 'playerIds') selected(player_id)
        where not exists (
          select 1 from public.players
          where players.id = selected.player_id::uuid
            and players.team_id = target_team_id
            and players.season_id = target_season_id
            and players.is_active
        )
      )
    then
      raise exception using errcode = 'P0001', message = 'INVALID_ALLOCATION';
    end if;
  end loop;

  delete from public.match_players
  using public.matches
  where match_players.match_id = matches.id
    and match_players.team_id = target_team_id
    and match_players.season_id = target_season_id
    and match_players.selection_type = 'regular'
    and match_players.selection_source = 'automatic'
    and matches.status = 'upcoming'
    and matches.starts_at >= boundary;

  insert into public.match_players (
    team_id, season_id, match_id, player_id,
    selection_type, selection_source, selection_status, played
  )
  select
    target_team_id,
    target_season_id,
    (item ->> 'matchId')::uuid,
    player_id::uuid,
    'regular',
    'automatic',
    'selected',
    false
  from jsonb_array_elements(allocations) item
  cross join lateral jsonb_array_elements_text(item -> 'playerIds') selected(player_id)
  where not exists (
    select 1
    from public.match_players preserved
    where preserved.match_id = (item ->> 'matchId')::uuid
      and preserved.player_id = player_id::uuid
      and preserved.selection_type = 'regular'
      and preserved.selection_source = 'manual'
      and preserved.selection_status = 'selected'
  );

  get diagnostics saved_count = row_count;
  return saved_count;
end;
$$;

revoke all on function public.save_regular_allocation(uuid, uuid, uuid, timestamptz, text, jsonb) from public;
grant execute on function public.save_regular_allocation(uuid, uuid, uuid, timestamptz, text, jsonb) to service_role;
