-- Formalizes a grant that already exists in production (applied manually, outside migrations)
-- so a fresh environment can run the team/season lookups in scripts/bootstrap-training-plan.mjs
-- and scripts/enrich-training-plan.mjs, which query these tables directly with the service role.
grant select on table public.teams to service_role;
grant select on table public.seasons to service_role;
