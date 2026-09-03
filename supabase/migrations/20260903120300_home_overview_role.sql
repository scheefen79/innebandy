create or replace function public.get_home_overview()
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare target_team_id uuid; member_role text;
begin
 select team_id,role into target_team_id,member_role from public.team_members
 where user_id=(select auth.uid()) and is_active order by team_id limit 1;
 if target_team_id is null then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 return public.get_overview(target_team_id)||jsonb_build_object('role',member_role);
end $$;
