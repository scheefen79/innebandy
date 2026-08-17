create unique index seasons_one_active_per_team_idx
  on public.seasons (team_id)
  where is_active;
