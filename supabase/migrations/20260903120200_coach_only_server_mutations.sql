-- Preserve the established transactional implementations behind private, renamed entrypoints.
-- The public wrappers add one uniform coach check before any mutation can run.
alter function public.save_regular_allocation(uuid,uuid,uuid,timestamptz,text,jsonb) rename to save_regular_allocation_unchecked;
alter function public.create_manual_regular_adjustment(uuid,uuid,uuid,uuid,uuid,uuid,text) rename to create_manual_regular_adjustment_unchecked;
alter function public.restore_manual_regular_adjustment(uuid,uuid,uuid,uuid,uuid,uuid,text) rename to restore_manual_regular_adjustment_unchecked;
alter function public.add_extra_substitute(uuid,uuid,uuid,uuid,uuid,text) rename to add_extra_substitute_unchecked;
alter function public.remove_extra_substitute(uuid,uuid,uuid,uuid,uuid,text) rename to remove_extra_substitute_unchecked;
alter function public.complete_match(uuid,uuid,uuid,uuid,text,jsonb) rename to complete_match_unchecked;
alter function public.create_player(uuid,uuid,uuid,text,text,integer,uuid) rename to create_player_unchecked;
alter function public.update_player(uuid,uuid,uuid,uuid,text,text,integer,text) rename to update_player_unchecked;
alter function public.deactivate_player(uuid,uuid,uuid,uuid,text) rename to deactivate_player_unchecked;
alter function public.save_training_plan(uuid,uuid,uuid,uuid,integer,text,text,text,text,public.training_session_status,jsonb) rename to save_training_plan_unchecked;
alter function public.bootstrap_training_plan(uuid,uuid,uuid,jsonb) rename to bootstrap_training_plan_unchecked;

revoke all on function
 public.save_regular_allocation_unchecked(uuid,uuid,uuid,timestamptz,text,jsonb),
 public.create_manual_regular_adjustment_unchecked(uuid,uuid,uuid,uuid,uuid,uuid,text),
 public.restore_manual_regular_adjustment_unchecked(uuid,uuid,uuid,uuid,uuid,uuid,text),
 public.add_extra_substitute_unchecked(uuid,uuid,uuid,uuid,uuid,text),
 public.remove_extra_substitute_unchecked(uuid,uuid,uuid,uuid,uuid,text),
 public.complete_match_unchecked(uuid,uuid,uuid,uuid,text,jsonb),
 public.create_player_unchecked(uuid,uuid,uuid,text,text,integer,uuid),
 public.update_player_unchecked(uuid,uuid,uuid,uuid,text,text,integer,text),
 public.deactivate_player_unchecked(uuid,uuid,uuid,uuid,text),
 public.save_training_plan_unchecked(uuid,uuid,uuid,uuid,integer,text,text,text,text,public.training_session_status,jsonb),
 public.bootstrap_training_plan_unchecked(uuid,uuid,uuid,jsonb)
from public,anon,authenticated,service_role;

create function public.save_regular_allocation(actor_user_id uuid,target_team_id uuid,target_season_id uuid,expected_source_time timestamptz,request_id text,requested_matches jsonb)
returns integer language plpgsql volatile security definer set search_path=''
as $$ begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception using errcode='42501',message='SERVER_ONLY'; end if;
 if not private.is_active_team_coach(actor_user_id,target_team_id) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 return public.save_regular_allocation_unchecked(actor_user_id,target_team_id,target_season_id,expected_source_time,request_id,requested_matches);
end $$;

create function public.create_manual_regular_adjustment(actor_user_id uuid,target_team_id uuid,target_season_id uuid,target_match_id uuid,outgoing_player_id uuid,incoming_player_id uuid,expected_fingerprint text)
returns boolean language plpgsql volatile security definer set search_path=''
as $$ begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception using errcode='42501',message='SERVER_ONLY'; end if;
 if not private.is_active_team_coach(actor_user_id,target_team_id) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 return public.create_manual_regular_adjustment_unchecked(actor_user_id,target_team_id,target_season_id,target_match_id,outgoing_player_id,incoming_player_id,expected_fingerprint);
end $$;

create function public.restore_manual_regular_adjustment(actor_user_id uuid,target_team_id uuid,target_season_id uuid,target_match_id uuid,outgoing_player_id uuid,incoming_player_id uuid,expected_fingerprint text)
returns boolean language plpgsql volatile security definer set search_path=''
as $$ begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception using errcode='42501',message='SERVER_ONLY'; end if;
 if not private.is_active_team_coach(actor_user_id,target_team_id) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 return public.restore_manual_regular_adjustment_unchecked(actor_user_id,target_team_id,target_season_id,target_match_id,outgoing_player_id,incoming_player_id,expected_fingerprint);
end $$;

create function public.add_extra_substitute(actor_user_id uuid,target_team_id uuid,target_season_id uuid,target_match_id uuid,target_player_id uuid,expected_fingerprint text)
returns boolean language plpgsql volatile security definer set search_path=''
as $$ begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception using errcode='42501',message='SERVER_ONLY'; end if;
 if not private.is_active_team_coach(actor_user_id,target_team_id) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 return public.add_extra_substitute_unchecked(actor_user_id,target_team_id,target_season_id,target_match_id,target_player_id,expected_fingerprint);
end $$;

create function public.remove_extra_substitute(actor_user_id uuid,target_team_id uuid,target_season_id uuid,target_match_id uuid,target_player_id uuid,expected_fingerprint text)
returns boolean language plpgsql volatile security definer set search_path=''
as $$ begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception using errcode='42501',message='SERVER_ONLY'; end if;
 if not private.is_active_team_coach(actor_user_id,target_team_id) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 return public.remove_extra_substitute_unchecked(actor_user_id,target_team_id,target_season_id,target_match_id,target_player_id,expected_fingerprint);
end $$;

create function public.complete_match(actor_user_id uuid,target_team_id uuid,target_season_id uuid,target_match_id uuid,expected_fingerprint text,requested_participation jsonb)
returns boolean language plpgsql volatile security definer set search_path=''
as $$ begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception using errcode='42501',message='SERVER_ONLY'; end if;
 if not private.is_active_team_coach(actor_user_id,target_team_id) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 return public.complete_match_unchecked(actor_user_id,target_team_id,target_season_id,target_match_id,expected_fingerprint,requested_participation);
end $$;

create function public.create_player(actor_user_id uuid,target_team_id uuid,target_season_id uuid,requested_first_name text,requested_last_name text,requested_level integer,request_id uuid)
returns uuid language plpgsql volatile security definer set search_path=''
as $$ begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception using errcode='42501',message='SERVER_ONLY'; end if;
 if not private.is_active_team_coach(actor_user_id,target_team_id) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 return public.create_player_unchecked(actor_user_id,target_team_id,target_season_id,requested_first_name,requested_last_name,requested_level,request_id);
end $$;

create function public.update_player(actor_user_id uuid,target_team_id uuid,target_season_id uuid,target_player_id uuid,requested_first_name text,requested_last_name text,requested_level integer,expected_fingerprint text)
returns boolean language plpgsql volatile security definer set search_path=''
as $$ begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception using errcode='42501',message='SERVER_ONLY'; end if;
 if not private.is_active_team_coach(actor_user_id,target_team_id) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 return public.update_player_unchecked(actor_user_id,target_team_id,target_season_id,target_player_id,requested_first_name,requested_last_name,requested_level,expected_fingerprint);
end $$;

create function public.deactivate_player(actor_user_id uuid,target_team_id uuid,target_season_id uuid,target_player_id uuid,expected_fingerprint text)
returns boolean language plpgsql volatile security definer set search_path=''
as $$ begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception using errcode='42501',message='SERVER_ONLY'; end if;
 if not private.is_active_team_coach(actor_user_id,target_team_id) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 return public.deactivate_player_unchecked(actor_user_id,target_team_id,target_season_id,target_player_id,expected_fingerprint);
end $$;

create function public.save_training_plan(actor_user_id uuid,target_team_id uuid,target_season_id uuid,target_training_id uuid,expected_revision integer,request_id text,requested_focus text,requested_key_message text,requested_notes text,requested_status public.training_session_status,requested_items jsonb)
returns integer language plpgsql volatile security definer set search_path=''
as $$ begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception using errcode='42501',message='SERVER_ONLY'; end if;
 if not private.is_active_team_coach(actor_user_id,target_team_id) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 return public.save_training_plan_unchecked(actor_user_id,target_team_id,target_season_id,target_training_id,expected_revision,request_id,requested_focus,requested_key_message,requested_notes,requested_status,requested_items);
end $$;

create function public.bootstrap_training_plan(actor_user_id uuid,target_team_id uuid,target_season_id uuid,requested_sessions jsonb)
returns boolean language plpgsql volatile security definer set search_path=''
as $$ begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception using errcode='42501',message='SERVER_ONLY'; end if;
 if not private.is_active_team_coach(actor_user_id,target_team_id) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 return public.bootstrap_training_plan_unchecked(actor_user_id,target_team_id,target_season_id,requested_sessions);
end $$;

revoke all on function
 public.save_regular_allocation(uuid,uuid,uuid,timestamptz,text,jsonb),
 public.create_manual_regular_adjustment(uuid,uuid,uuid,uuid,uuid,uuid,text),
 public.restore_manual_regular_adjustment(uuid,uuid,uuid,uuid,uuid,uuid,text),
 public.add_extra_substitute(uuid,uuid,uuid,uuid,uuid,text),
 public.remove_extra_substitute(uuid,uuid,uuid,uuid,uuid,text),
 public.complete_match(uuid,uuid,uuid,uuid,text,jsonb),
 public.create_player(uuid,uuid,uuid,text,text,integer,uuid),
 public.update_player(uuid,uuid,uuid,uuid,text,text,integer,text),
 public.deactivate_player(uuid,uuid,uuid,uuid,text),
 public.save_training_plan(uuid,uuid,uuid,uuid,integer,text,text,text,text,public.training_session_status,jsonb),
 public.bootstrap_training_plan(uuid,uuid,uuid,jsonb)
from public,anon,authenticated;

grant execute on function
 public.save_regular_allocation(uuid,uuid,uuid,timestamptz,text,jsonb),
 public.create_manual_regular_adjustment(uuid,uuid,uuid,uuid,uuid,uuid,text),
 public.restore_manual_regular_adjustment(uuid,uuid,uuid,uuid,uuid,uuid,text),
 public.add_extra_substitute(uuid,uuid,uuid,uuid,uuid,text),
 public.remove_extra_substitute(uuid,uuid,uuid,uuid,uuid,text),
 public.complete_match(uuid,uuid,uuid,uuid,text,jsonb),
 public.create_player(uuid,uuid,uuid,text,text,integer,uuid),
 public.update_player(uuid,uuid,uuid,uuid,text,text,integer,text),
 public.deactivate_player(uuid,uuid,uuid,uuid,text),
 public.save_training_plan(uuid,uuid,uuid,uuid,integer,text,text,text,text,public.training_session_status,jsonb),
 public.bootstrap_training_plan(uuid,uuid,uuid,jsonb)
to service_role;
