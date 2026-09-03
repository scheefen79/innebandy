-- The authenticated role needs execute permission when RLS evaluates the private coach predicate.
grant execute on function private.is_active_team_coach(uuid) to authenticated;
