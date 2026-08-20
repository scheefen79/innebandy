insert into public.teams (id, name, slug)
values (
  '10000000-0000-4000-8000-000000000001',
  'FBC Sollentuna P17',
  'fbc-sollentuna-p17'
)
on conflict (id) do update
set name = excluded.name,
    slug = excluded.slug;

insert into public.seasons (id, team_id, name, starts_on, ends_on, is_active)
values (
  '20000000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000001',
  'Exempelsäsong',
  '2026-08-01',
  '2027-05-31',
  true
)
on conflict (id) do update
set name = excluded.name,
    starts_on = excluded.starts_on,
    ends_on = excluded.ends_on,
    is_active = excluded.is_active;

insert into public.players (
  id,
  team_id,
  season_id,
  first_name,
  last_name,
  level,
  rotation_order,
  is_active
)
values
  (
    '30000000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000001',
    'Exempelspelare',
    'Nivå 1',
    1,
    1,
    true
  ),
  (
    '30000000-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000001',
    'Exempelspelare',
    'Nivå 2',
    2,
    2,
    true
  ),
  (
    '30000000-0000-4000-8000-000000000003',
    '10000000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000001',
    'Exempelspelare',
    'Nivå 3',
    3,
    3,
    true
  )
on conflict (id) do update
set first_name = excluded.first_name,
    last_name = excluded.last_name,
    level = excluded.level,
    rotation_order = excluded.rotation_order,
    is_active = excluded.is_active;

insert into public.matches (
  id,
  team_id,
  season_id,
  opponent,
  starts_at,
  location,
  target_players,
  status,
  request_id
)
values (
  '40000000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000001',
  'Exempelmotstånd',
  '2026-09-20 10:00:00+00',
  'Exempelhall',
  2,
  'upcoming',
  '50000000-0000-4000-8000-000000000001'
)
on conflict (id) do update
set opponent = excluded.opponent,
    starts_at = excluded.starts_at,
    location = excluded.location,
    target_players = excluded.target_players,
    status = excluded.status,
    request_id = excluded.request_id;
