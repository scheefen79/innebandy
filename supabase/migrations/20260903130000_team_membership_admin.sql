grant select on table public.team_members to service_role;

create or replace function private.team_would_lack_active_coach(target_team_id uuid,excluded_user_id uuid)
returns boolean language sql stable security definer set search_path=''
as $$
  select not exists (
    select 1 from public.team_members
    where team_id=target_team_id and role='coach' and is_active and user_id<>excluded_user_id
  );
$$;

revoke all on function private.team_would_lack_active_coach(uuid,uuid) from public;

create or replace function public.get_team_member_list(target_team_id uuid)
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare result jsonb;
begin
 if not (select private.is_active_team_coach(target_team_id)) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 select coalesce(jsonb_agg(jsonb_build_object(
   'userId',tm.user_id,'email',u.email,'role',tm.role,'isActive',tm.is_active,
   'invitedAt',tm.created_at,'fingerprint',md5(tm.role||tm.is_active::text)
  ) order by tm.is_active desc,u.email),'[]'::jsonb) into result
 from public.team_members tm join auth.users u on u.id=tm.user_id
 where tm.team_id=target_team_id;
 return result;
end $$;

revoke all on function public.get_team_member_list(uuid) from public;
grant execute on function public.get_team_member_list(uuid) to authenticated;

create or replace function public.upsert_team_member(actor_user_id uuid,target_team_id uuid,target_user_id uuid,requested_role text)
returns boolean language plpgsql volatile security definer set search_path=''
as $$
begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception using errcode='42501',message='SERVER_ONLY'; end if;
 if not private.is_active_team_coach(actor_user_id,target_team_id) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 if requested_role not in ('coach','viewer') then raise exception using errcode='P0001',message='INVALID_ROLE'; end if;
 begin
   insert into public.team_members(team_id,user_id,role,is_active) values(target_team_id,target_user_id,requested_role,true);
 exception when unique_violation then
   raise exception using errcode='P0001',message='ALREADY_MEMBER';
 end;
 return true;
end $$;

create or replace function public.update_team_member_role(actor_user_id uuid,target_team_id uuid,target_user_id uuid,requested_role text,expected_fingerprint text)
returns boolean language plpgsql volatile security definer set search_path=''
as $$
declare current_member public.team_members%rowtype;
begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception using errcode='42501',message='SERVER_ONLY'; end if;
 if not private.is_active_team_coach(actor_user_id,target_team_id) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 if requested_role not in ('coach','viewer') then raise exception using errcode='P0001',message='INVALID_ROLE'; end if;
 select * into current_member from public.team_members where team_id=target_team_id and user_id=target_user_id for update;
 if not found then raise exception using errcode='P0001',message='MEMBER_NOT_AVAILABLE'; end if;
 if md5(current_member.role||current_member.is_active::text)<>expected_fingerprint then raise exception using errcode='P0001',message='STALE_MEMBER'; end if;
 if current_member.role=requested_role then return true; end if;
 if current_member.is_active and current_member.role='coach' and requested_role<>'coach' then
   perform 1 from public.team_members where team_id=target_team_id and role='coach' and is_active for update;
   if private.team_would_lack_active_coach(target_team_id,target_user_id) then raise exception using errcode='P0001',message='LAST_ACTIVE_COACH'; end if;
 end if;
 update public.team_members set role=requested_role where team_id=target_team_id and user_id=target_user_id;
 return true;
end $$;

create or replace function public.deactivate_team_member(actor_user_id uuid,target_team_id uuid,target_user_id uuid,expected_fingerprint text)
returns boolean language plpgsql volatile security definer set search_path=''
as $$
declare current_member public.team_members%rowtype;
begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception using errcode='42501',message='SERVER_ONLY'; end if;
 if not private.is_active_team_coach(actor_user_id,target_team_id) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 select * into current_member from public.team_members where team_id=target_team_id and user_id=target_user_id for update;
 if not found then raise exception using errcode='P0001',message='MEMBER_NOT_AVAILABLE'; end if;
 if md5(current_member.role||current_member.is_active::text)<>expected_fingerprint then raise exception using errcode='P0001',message='STALE_MEMBER'; end if;
 if not current_member.is_active then return true; end if;
 if current_member.role='coach' then
   perform 1 from public.team_members where team_id=target_team_id and role='coach' and is_active for update;
   if private.team_would_lack_active_coach(target_team_id,target_user_id) then raise exception using errcode='P0001',message='LAST_ACTIVE_COACH'; end if;
 end if;
 update public.team_members set is_active=false where team_id=target_team_id and user_id=target_user_id;
 return true;
end $$;

create or replace function public.reactivate_team_member(actor_user_id uuid,target_team_id uuid,target_user_id uuid,expected_fingerprint text)
returns boolean language plpgsql volatile security definer set search_path=''
as $$
declare current_member public.team_members%rowtype;
begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception using errcode='42501',message='SERVER_ONLY'; end if;
 if not private.is_active_team_coach(actor_user_id,target_team_id) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 select * into current_member from public.team_members where team_id=target_team_id and user_id=target_user_id for update;
 if not found then raise exception using errcode='P0001',message='MEMBER_NOT_AVAILABLE'; end if;
 if md5(current_member.role||current_member.is_active::text)<>expected_fingerprint then raise exception using errcode='P0001',message='STALE_MEMBER'; end if;
 if current_member.is_active then return true; end if;
 update public.team_members set is_active=true where team_id=target_team_id and user_id=target_user_id;
 return true;
end $$;

revoke all on function
 public.upsert_team_member(uuid,uuid,uuid,text),
 public.update_team_member_role(uuid,uuid,uuid,text,text),
 public.deactivate_team_member(uuid,uuid,uuid,text),
 public.reactivate_team_member(uuid,uuid,uuid,text)
from public,anon,authenticated;

grant execute on function
 public.upsert_team_member(uuid,uuid,uuid,text),
 public.update_team_member_role(uuid,uuid,uuid,text,text),
 public.deactivate_team_member(uuid,uuid,uuid,text),
 public.reactivate_team_member(uuid,uuid,uuid,text)
to service_role;
