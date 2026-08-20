create function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = clock_timestamp();
  return new;
end;
$$;

revoke all on function private.set_updated_at() from public;

create table public.matches (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null,
  season_id uuid not null,
  opponent text not null check (length(trim(opponent)) between 1 and 100),
  starts_at timestamptz not null,
  location text check (location is null or length(trim(location)) between 1 and 200),
  target_players integer not null check (target_players > 0),
  status text not null default 'upcoming'
    check (status in ('upcoming', 'completed', 'cancelled')),
  request_id uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint matches_season_team_fk
    foreign key (season_id, team_id)
    references public.seasons(id, team_id)
    on delete cascade,
  constraint matches_id_team_unique unique (id, team_id),
  constraint matches_team_request_unique unique (team_id, request_id)
);

create index matches_season_starts_at_idx
  on public.matches (season_id, starts_at);

create index matches_upcoming_season_starts_at_idx
  on public.matches (season_id, starts_at)
  where status = 'upcoming';

create trigger matches_set_updated_at
before update on public.matches
for each row execute function private.set_updated_at();

alter table public.matches enable row level security;

create policy "Active members can read team matches"
on public.matches
for select
to authenticated
using ((select private.is_active_team_member(team_id)));

create policy "Active members can create upcoming matches in active seasons"
on public.matches
for insert
to authenticated
with check (
  status = 'upcoming'
  and (select private.is_active_team_member(team_id))
  and exists (
    select 1
    from public.seasons
    where seasons.id = matches.season_id
      and seasons.team_id = matches.team_id
      and seasons.is_active
  )
);

revoke all on table public.matches from anon, authenticated;
grant select on table public.matches to authenticated;
grant insert (
  team_id,
  season_id,
  opponent,
  starts_at,
  location,
  target_players,
  status,
  request_id
) on table public.matches to authenticated;
