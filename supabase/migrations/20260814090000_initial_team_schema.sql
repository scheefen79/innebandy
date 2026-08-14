create schema if not exists private;

revoke all on schema private from public;

create table public.teams (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) between 1 and 100),
  slug text not null unique check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  created_at timestamptz not null default now()
);

create table public.team_members (
  team_id uuid not null,
  user_id uuid not null,
  role text not null default 'coach' check (role = 'coach'),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  primary key (team_id, user_id),
  constraint team_members_team_fk
    foreign key (team_id) references public.teams(id) on delete cascade,
  constraint team_members_user_fk
    foreign key (user_id) references auth.users(id) on delete cascade
);

create table public.seasons (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null,
  name text not null check (length(trim(name)) between 1 and 100),
  starts_on date not null,
  ends_on date not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint seasons_valid_date_range check (starts_on <= ends_on),
  constraint seasons_team_fk
    foreign key (team_id) references public.teams(id) on delete cascade,
  constraint seasons_id_team_unique unique (id, team_id),
  constraint seasons_team_name_unique unique (team_id, name)
);

create table public.players (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null,
  season_id uuid not null,
  first_name text not null check (length(trim(first_name)) between 1 and 100),
  last_name text check (last_name is null or length(trim(last_name)) between 1 and 100),
  level smallint not null check (level between 1 and 3),
  rotation_order integer not null check (rotation_order > 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint players_season_team_fk
    foreign key (season_id, team_id)
    references public.seasons(id, team_id)
    on delete cascade,
  constraint players_season_rotation_unique unique (season_id, rotation_order)
);

create index team_members_active_user_idx
  on public.team_members (user_id, team_id)
  where is_active;

create index seasons_active_team_idx
  on public.seasons (team_id)
  where is_active;

create index players_active_team_season_idx
  on public.players (team_id, season_id)
  where is_active;

create function private.is_active_team_member(target_team_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.team_members
    where team_members.team_id = target_team_id
      and team_members.user_id = (select auth.uid())
      and team_members.is_active
  );
$$;

revoke all on function private.is_active_team_member(uuid) from public;
grant usage on schema private to authenticated;
grant execute on function private.is_active_team_member(uuid) to authenticated;

alter table public.teams enable row level security;
alter table public.team_members enable row level security;
alter table public.seasons enable row level security;
alter table public.players enable row level security;

create policy "Active members can read their teams"
on public.teams
for select
to authenticated
using ((select private.is_active_team_member(id)));

create policy "Active members can update their teams"
on public.teams
for update
to authenticated
using ((select private.is_active_team_member(id)))
with check ((select private.is_active_team_member(id)));

create policy "Members can read their own active memberships"
on public.team_members
for select
to authenticated
using (user_id = (select auth.uid()) and is_active);

create policy "Active members can read team seasons"
on public.seasons
for select
to authenticated
using ((select private.is_active_team_member(team_id)));

create policy "Active members can create team seasons"
on public.seasons
for insert
to authenticated
with check ((select private.is_active_team_member(team_id)));

create policy "Active members can update team seasons"
on public.seasons
for update
to authenticated
using ((select private.is_active_team_member(team_id)))
with check ((select private.is_active_team_member(team_id)));

create policy "Active members can read team players"
on public.players
for select
to authenticated
using ((select private.is_active_team_member(team_id)));

create policy "Active members can create team players"
on public.players
for insert
to authenticated
with check ((select private.is_active_team_member(team_id)));

create policy "Active members can update team players"
on public.players
for update
to authenticated
using ((select private.is_active_team_member(team_id)))
with check ((select private.is_active_team_member(team_id)));

revoke all on table public.teams from anon, authenticated;
revoke all on table public.team_members from anon, authenticated;
revoke all on table public.seasons from anon, authenticated;
revoke all on table public.players from anon, authenticated;

grant select, update on table public.teams to authenticated;
grant select on table public.team_members to authenticated;
grant select, insert, update on table public.seasons to authenticated;
grant select, insert, update on table public.players to authenticated;
