-- Lock the target member and the team's active coaches in one consistently ordered statement
-- instead of two separate lock acquisitions. Two coaches concurrently changing each other's
-- status previously acquired their own row first and the coach set second, in opposite orders,
-- which could deadlock. Locking the full union up front, ordered by user_id, removes that cycle.
create or replace function public.update_team_member_role(actor_user_id uuid,target_team_id uuid,target_user_id uuid,requested_role text,expected_fingerprint text)
returns boolean language plpgsql volatile security definer set search_path=''
as $$
declare current_member public.team_members%rowtype;
begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception using errcode='42501',message='SERVER_ONLY'; end if;
 if not private.is_active_team_coach(actor_user_id,target_team_id) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 if requested_role not in ('coach','viewer') then raise exception using errcode='P0001',message='INVALID_ROLE'; end if;
 perform 1 from public.team_members where team_id=target_team_id and (user_id=target_user_id or (role='coach' and is_active)) order by user_id for update;
 select * into current_member from public.team_members where team_id=target_team_id and user_id=target_user_id;
 if not found then raise exception using errcode='P0001',message='MEMBER_NOT_AVAILABLE'; end if;
 if md5(current_member.role||current_member.is_active::text)<>expected_fingerprint then raise exception using errcode='P0001',message='STALE_MEMBER'; end if;
 if current_member.role=requested_role then return true; end if;
 if current_member.is_active and current_member.role='coach' and requested_role<>'coach' and private.team_would_lack_active_coach(target_team_id,target_user_id) then
   raise exception using errcode='P0001',message='LAST_ACTIVE_COACH';
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
 perform 1 from public.team_members where team_id=target_team_id and (user_id=target_user_id or (role='coach' and is_active)) order by user_id for update;
 select * into current_member from public.team_members where team_id=target_team_id and user_id=target_user_id;
 if not found then raise exception using errcode='P0001',message='MEMBER_NOT_AVAILABLE'; end if;
 if md5(current_member.role||current_member.is_active::text)<>expected_fingerprint then raise exception using errcode='P0001',message='STALE_MEMBER'; end if;
 if not current_member.is_active then return true; end if;
 if current_member.role='coach' and private.team_would_lack_active_coach(target_team_id,target_user_id) then
   raise exception using errcode='P0001',message='LAST_ACTIVE_COACH';
 end if;
 update public.team_members set is_active=false where team_id=target_team_id and user_id=target_user_id;
 return true;
end $$;
