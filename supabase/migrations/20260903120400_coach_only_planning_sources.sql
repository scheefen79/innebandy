-- Planning sources contain levels, fairness history, fingerprints, or mutation metadata.
-- Keep them available to coaches only; viewers use the minimized match roster instead.
alter function public.get_regular_allocation_source(uuid,uuid,timestamptz) rename to get_regular_allocation_source_unchecked;
alter function public.get_manual_adjustment_source(uuid,uuid,uuid) rename to get_manual_adjustment_source_unchecked;
alter function public.get_extra_substitute_source(uuid,uuid,uuid) rename to get_extra_substitute_source_unchecked;
alter function public.get_match_completion_source(uuid,uuid,uuid) rename to get_match_completion_source_unchecked;

revoke all on function
 public.get_regular_allocation_source_unchecked(uuid,uuid,timestamptz),
 public.get_manual_adjustment_source_unchecked(uuid,uuid,uuid),
 public.get_extra_substitute_source_unchecked(uuid,uuid,uuid),
 public.get_match_completion_source_unchecked(uuid,uuid,uuid)
from public,anon,authenticated,service_role;

create function public.get_regular_allocation_source(target_team_id uuid,target_season_id uuid,requested_now timestamptz)
returns jsonb language plpgsql stable security definer set search_path=''
as $$ begin
 if not private.is_active_team_coach(target_team_id) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 return public.get_regular_allocation_source_unchecked(target_team_id,target_season_id,requested_now);
end $$;

create function public.get_manual_adjustment_source(target_team_id uuid,target_season_id uuid,target_match_id uuid)
returns jsonb language plpgsql stable security definer set search_path=''
as $$ begin
 if not private.is_active_team_coach(target_team_id) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 return public.get_manual_adjustment_source_unchecked(target_team_id,target_season_id,target_match_id);
end $$;

create function public.get_extra_substitute_source(target_team_id uuid,target_season_id uuid,target_match_id uuid)
returns jsonb language plpgsql stable security definer set search_path=''
as $$ begin
 if not private.is_active_team_coach(target_team_id) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 return public.get_extra_substitute_source_unchecked(target_team_id,target_season_id,target_match_id);
end $$;

create function public.get_match_completion_source(target_team_id uuid,target_season_id uuid,target_match_id uuid)
returns jsonb language plpgsql stable security definer set search_path=''
as $$ begin
 if not private.is_active_team_coach(target_team_id) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 return public.get_match_completion_source_unchecked(target_team_id,target_season_id,target_match_id);
end $$;

revoke all on function
 public.get_regular_allocation_source(uuid,uuid,timestamptz),
 public.get_manual_adjustment_source(uuid,uuid,uuid),
 public.get_extra_substitute_source(uuid,uuid,uuid),
 public.get_match_completion_source(uuid,uuid,uuid)
from public,anon;

grant execute on function
 public.get_regular_allocation_source(uuid,uuid,timestamptz),
 public.get_manual_adjustment_source(uuid,uuid,uuid),
 public.get_extra_substitute_source(uuid,uuid,uuid),
 public.get_match_completion_source(uuid,uuid,uuid)
to authenticated;
