-- Same class of bug as 20260903150000: the coach-only wrappers created in
-- 20260903120200_coach_only_server_mutations.sql renamed parameters on two functions relative
-- to their pre-existing signatures. PostgREST matches RPC calls by parameter name, and the app's
-- .rpc() calls still use the original names, so every real call to these two functions failed in
-- production with a function-not-found error while positional calls (psql, pgTAP) hid it.
-- Audited every function in that migration against its pre-existing signature; these two were the
-- only mismatches (save_regular_allocation: boundary/expected_fingerprint/allocations renamed to
-- expected_source_time/request_id/requested_matches; complete_match: participation renamed to
-- requested_participation). All other functions in that migration already matched.
drop function if exists public.save_regular_allocation(uuid,uuid,uuid,timestamptz,text,jsonb);

create function public.save_regular_allocation(actor_user_id uuid,target_team_id uuid,target_season_id uuid,boundary timestamptz,expected_fingerprint text,allocations jsonb)
returns integer language plpgsql volatile security definer set search_path=''
as $$ begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception using errcode='42501',message='SERVER_ONLY'; end if;
 if not private.is_active_team_coach(actor_user_id,target_team_id) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 return public.save_regular_allocation_unchecked(actor_user_id,target_team_id,target_season_id,boundary,expected_fingerprint,allocations);
end $$;

revoke all on function public.save_regular_allocation(uuid,uuid,uuid,timestamptz,text,jsonb) from public,anon,authenticated;
grant execute on function public.save_regular_allocation(uuid,uuid,uuid,timestamptz,text,jsonb) to service_role;

drop function if exists public.complete_match(uuid,uuid,uuid,uuid,text,jsonb);

create function public.complete_match(actor_user_id uuid,target_team_id uuid,target_season_id uuid,target_match_id uuid,expected_fingerprint text,participation jsonb)
returns boolean language plpgsql volatile security definer set search_path=''
as $$ begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception using errcode='42501',message='SERVER_ONLY'; end if;
 if not private.is_active_team_coach(actor_user_id,target_team_id) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 return public.complete_match_unchecked(actor_user_id,target_team_id,target_season_id,target_match_id,expected_fingerprint,participation);
end $$;

revoke all on function public.complete_match(uuid,uuid,uuid,uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.complete_match(uuid,uuid,uuid,uuid,text,jsonb) to service_role;
