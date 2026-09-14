alter table public.team_members
  add column display_name text check (display_name is null or length(trim(display_name)) between 1 and 80);

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
     'userId',a.user_id,'name',coalesce(nullif(trim(m.display_name),''),split_part(u.email,'@',1),'Lagmedlem'),'status',a.status
   ) order by coalesce(nullif(trim(m.display_name),''),split_part(u.email,'@',1)),a.user_id)
   from public.training_attendance a
   join public.team_members m on m.team_id=a.team_id and m.user_id=a.user_id and m.is_active
   join auth.users u on u.id=a.user_id
   where a.training_session_id=s.id and a.team_id=target_team_id and a.season_id=target_season_id),'[]'::jsonb)
 ) order by s.starts_at,s.id),'[]'::jsonb) into result
 from public.training_sessions s
 where s.team_id=target_team_id and s.season_id=target_season_id;
 return result;
end;
$$;

revoke all on function public.get_training_attendance(uuid,uuid) from public;
grant execute on function public.get_training_attendance(uuid,uuid) to authenticated;
