-- The coach-only wrapper created in 20260903120400_coach_only_planning_sources.sql renamed this
-- function's third parameter from "boundary" to "requested_now". PostgREST resolves RPC calls by
-- matching JSON body keys to parameter names, and the app calls this function with a "boundary"
-- key — so every call failed with a function-not-found error via the real HTTP API, even though
-- calling it positionally (as in psql or pgTAP) worked fine and hid the mismatch. Recreate the
-- wrapper with the original parameter name so it matches the app's call again.
drop function if exists public.get_regular_allocation_source(uuid,uuid,timestamptz);

create function public.get_regular_allocation_source(target_team_id uuid,target_season_id uuid,boundary timestamptz)
returns jsonb language plpgsql stable security definer set search_path=''
as $$ begin
 if not private.is_active_team_coach(target_team_id) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 return public.get_regular_allocation_source_unchecked(target_team_id,target_season_id,boundary);
end $$;

revoke all on function public.get_regular_allocation_source(uuid,uuid,timestamptz) from public,anon;
grant execute on function public.get_regular_allocation_source(uuid,uuid,timestamptz) to authenticated;
