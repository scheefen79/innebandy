alter type public.training_session_status add value if not exists 'cancelled';

create or replace function public.save_training_attendance(
 actor_user_id uuid,target_team_id uuid,target_season_id uuid,target_training_id uuid,requested_status public.training_attendance_status
) returns void language plpgsql volatile security definer set search_path=''
as $$
declare session_status public.training_session_status;
begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception using errcode='42501',message='SERVER_ONLY'; end if;
 if not exists(select 1 from public.team_members where team_id=target_team_id and user_id=actor_user_id and is_active) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 select status into session_status from public.training_sessions where id=target_training_id and team_id=target_team_id and season_id=target_season_id;
 if not found then raise exception using errcode='P0001',message='TRAINING_NOT_AVAILABLE'; end if;
 if session_status='completed' then raise exception using errcode='P0001',message='TRAINING_COMPLETED'; end if;
 if session_status='cancelled' then raise exception using errcode='P0001',message='TRAINING_CANCELLED'; end if;
 insert into public.training_attendance(training_session_id,team_id,season_id,user_id,status)
 values(target_training_id,target_team_id,target_season_id,actor_user_id,requested_status)
 on conflict(training_session_id,user_id) do update set status=excluded.status;
end;
$$;

create function public.cancel_training_session(
 actor_user_id uuid,target_team_id uuid,target_season_id uuid,target_training_id uuid
) returns void language plpgsql volatile security definer set search_path=''
as $$
declare session_status public.training_session_status; session_date date;
begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception using errcode='42501',message='SERVER_ONLY'; end if;
 if not private.is_active_team_coach(actor_user_id,target_team_id) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 select status,(starts_at at time zone 'Europe/Stockholm')::date into session_status,session_date
 from public.training_sessions where id=target_training_id and team_id=target_team_id and season_id=target_season_id for update;
 if not found then raise exception using errcode='P0001',message='TRAINING_NOT_AVAILABLE'; end if;
 if session_status='completed' then raise exception using errcode='P0001',message='TRAINING_COMPLETED'; end if;
 if session_status='cancelled' then raise exception using errcode='P0001',message='TRAINING_CANCELLED'; end if;
 if session_date < (now() at time zone 'Europe/Stockholm')::date then raise exception using errcode='P0001',message='TRAINING_PAST'; end if;
 update public.training_sessions set status='cancelled',revision=revision+1,updated_by=actor_user_id where id=target_training_id;
end;
$$;

revoke all on function public.save_training_attendance(uuid,uuid,uuid,uuid,public.training_attendance_status),public.cancel_training_session(uuid,uuid,uuid,uuid) from public,anon,authenticated;
grant execute on function public.save_training_attendance(uuid,uuid,uuid,uuid,public.training_attendance_status),public.cancel_training_session(uuid,uuid,uuid,uuid) to service_role;
