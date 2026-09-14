create type public.training_attendance_status as enum ('coming','absent');

create table public.training_attendance (
  training_session_id uuid not null references public.training_sessions(id) on delete cascade,
  team_id uuid not null references public.teams(id) on delete cascade,
  season_id uuid not null references public.seasons(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  status public.training_attendance_status not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (training_session_id,user_id)
);

create index training_attendance_team_season_session_idx on public.training_attendance(team_id,season_id,training_session_id);
create trigger training_attendance_set_updated_at before update on public.training_attendance for each row execute function private.set_updated_at();

alter table public.training_attendance enable row level security;
revoke all on public.training_attendance from anon,authenticated;
grant select,insert,update,delete on public.training_attendance to service_role;

create or replace function public.get_training_attendance(target_team_id uuid,target_season_id uuid)
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare result jsonb;
begin
 if not (select private.is_active_team_member(target_team_id)) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 if not exists(select 1 from public.seasons where id=target_season_id and team_id=target_team_id and is_active) then raise exception using errcode='P0001',message='TRAININGS_NOT_AVAILABLE'; end if;
 select coalesce(jsonb_agg(jsonb_build_object(
   'id',s.id,'startsAt',s.starts_at,'endsAt',s.ends_at,'themeBlock',s.theme_block,
   'focus',s.focus,'status',s.status,
   'responses',coalesce((select jsonb_agg(jsonb_build_object(
     'userId',a.user_id,'name',coalesce(split_part(u.email,'@',1),'Lagmedlem'),'status',a.status
   ) order by split_part(u.email,'@',1),a.user_id)
   from public.training_attendance a
   join public.team_members m on m.team_id=a.team_id and m.user_id=a.user_id and m.is_active
   join auth.users u on u.id=a.user_id
   where a.training_session_id=s.id and a.team_id=target_team_id and a.season_id=target_season_id),'[]'::jsonb)
 ) order by s.starts_at,s.id),'[]'::jsonb) into result
 from public.training_sessions s
 where s.team_id=target_team_id and s.season_id=target_season_id;
 return result;
end $$;

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
 insert into public.training_attendance(training_session_id,team_id,season_id,user_id,status)
 values(target_training_id,target_team_id,target_season_id,actor_user_id,requested_status)
 on conflict(training_session_id,user_id) do update set status=excluded.status;
end $$;

revoke all on function public.get_training_attendance(uuid,uuid),public.save_training_attendance(uuid,uuid,uuid,uuid,public.training_attendance_status) from public;
grant execute on function public.get_training_attendance(uuid,uuid) to authenticated;
grant execute on function public.save_training_attendance(uuid,uuid,uuid,uuid,public.training_attendance_status) to service_role;
