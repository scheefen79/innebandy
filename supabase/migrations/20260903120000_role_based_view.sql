alter table public.team_members drop constraint team_members_role_check;
alter table public.team_members add constraint team_members_role_check check (role in ('coach', 'viewer'));

create or replace function private.is_active_team_coach(target_team_id uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.team_members
    where team_id=target_team_id and user_id=(select auth.uid()) and is_active and role='coach'
  );
$$;

create or replace function private.is_active_team_coach(target_user_id uuid,target_team_id uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.team_members
    where team_id=target_team_id and user_id=target_user_id and is_active and role='coach'
  );
$$;

revoke all on function private.is_active_team_coach(uuid),private.is_active_team_coach(uuid,uuid) from public;
grant execute on function private.is_active_team_coach(uuid) to authenticated;

drop policy if exists "Active members can update their teams" on public.teams;
create policy "Coaches can update their teams" on public.teams for update to authenticated
using ((select private.is_active_team_coach(id))) with check ((select private.is_active_team_coach(id)));

drop policy if exists "Active members can create team seasons" on public.seasons;
drop policy if exists "Active members can update team seasons" on public.seasons;
create policy "Coaches can create team seasons" on public.seasons for insert to authenticated
with check ((select private.is_active_team_coach(team_id)));
create policy "Coaches can update team seasons" on public.seasons for update to authenticated
using ((select private.is_active_team_coach(team_id))) with check ((select private.is_active_team_coach(team_id)));

drop policy if exists "Active members can read team players" on public.players;
drop policy if exists "Active members can create team players" on public.players;
drop policy if exists "Active members can update team players" on public.players;
create policy "Coaches can read team players" on public.players for select to authenticated
using ((select private.is_active_team_coach(team_id)));
create policy "Coaches can create team players" on public.players for insert to authenticated
with check ((select private.is_active_team_coach(team_id)));
create policy "Coaches can update team players" on public.players for update to authenticated
using ((select private.is_active_team_coach(team_id))) with check ((select private.is_active_team_coach(team_id)));

drop policy if exists "Active members can create upcoming matches in active seasons" on public.matches;
create policy "Coaches can create upcoming matches in active seasons" on public.matches for insert to authenticated
with check (
  status='upcoming' and (select private.is_active_team_coach(team_id))
  and exists(select 1 from public.seasons where seasons.id=matches.season_id and seasons.team_id=matches.team_id and seasons.is_active)
);

drop policy if exists "Active members can read team selections" on public.match_players;
create policy "Coaches can read team selections" on public.match_players for select to authenticated
using ((select private.is_active_team_coach(team_id)));

drop policy if exists "Members can read active-season training sessions" on public.training_sessions;
drop policy if exists "Members can read active-season training items" on public.training_items;
create policy "Members can read active-season training sessions" on public.training_sessions for select to authenticated
using ((select private.is_active_team_member(team_id)) and exists(select 1 from public.seasons where seasons.id=training_sessions.season_id and seasons.team_id=training_sessions.team_id and seasons.is_active));
create policy "Members can read active-season training items" on public.training_items for select to authenticated
using ((select private.is_active_team_member(team_id)) and exists(select 1 from public.seasons where seasons.id=training_items.season_id and seasons.team_id=training_items.team_id and seasons.is_active));

create or replace function public.get_team_context()
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare result jsonb;
begin
 select jsonb_build_object('teamId',tm.team_id,'seasonId',s.id,'seasonName',s.name,'role',tm.role) into result
 from public.team_members tm join public.seasons s on s.team_id=tm.team_id and s.is_active
 where tm.user_id=(select auth.uid()) and tm.is_active order by tm.team_id limit 1;
 if result is null then raise exception using errcode='P0001',message='TEAM_CONTEXT_NOT_AVAILABLE'; end if;
 return result;
end $$;

create or replace function public.get_overview(target_team_id uuid)
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare result jsonb; member_role text;
begin
 select role into member_role from public.team_members where team_id=target_team_id and user_id=(select auth.uid()) and is_active;
 if member_role is null then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 select jsonb_build_object(
  'seasonName',seasons.name,'serverNow',now(),'role',member_role,
  'nextTraining',(select jsonb_build_object('id',t.id,'startsAt',t.starts_at,'endsAt',t.ends_at,'themeBlock',t.theme_block,'focus',t.focus,'keyMessage',t.key_message,'status',t.status) from public.training_sessions t where t.team_id=target_team_id and t.season_id=seasons.id and t.starts_at>now() order by t.starts_at,t.id limit 1),
  'upcomingMatches',coalesce((select jsonb_agg(jsonb_build_object('id',m.id,'opponent',m.opponent,'startsAt',m.starts_at,'location',m.location,'targetPlayers',m.target_players,'selectedPlayers',(select count(*)::integer from public.match_players mp where mp.match_id=m.id and mp.selection_status='selected')) order by m.starts_at,m.id) from (select matches.* from public.matches where team_id=target_team_id and season_id=seasons.id and status='upcoming' and starts_at>now() order by starts_at,id limit 5) m),'[]'::jsonb),
  'players',case when member_role='coach' then coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'name',concat_ws(' ',p.first_name,p.last_name),'regularCount',(select count(*)::integer from public.match_players mp join public.matches m on m.id=mp.match_id where mp.player_id=p.id and mp.selection_type='regular' and mp.selection_status='selected' and (m.status='upcoming' or (m.status='completed' and mp.played)))) order by p.rotation_order,p.id) from public.players p where p.team_id=target_team_id and p.season_id=seasons.id and p.is_active),'[]'::jsonb) else '[]'::jsonb end
 ) into result from public.seasons where seasons.team_id=target_team_id and seasons.is_active;
 if result is null then raise exception using errcode='P0001',message='OVERVIEW_NOT_AVAILABLE'; end if;
 return result;
end $$;

create or replace function public.get_match_list(target_team_id uuid,target_season_id uuid,requested_filter text,requested_now timestamptz)
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare result jsonb;
begin
 if not (select private.is_active_team_member(target_team_id)) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 if requested_filter not in ('upcoming','all') then raise exception using errcode='P0001',message='INVALID_MATCH_FILTER'; end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',m.id,'opponent',m.opponent,'startsAt',m.starts_at,'location',m.location,'targetPlayers',m.target_players,'status',m.status,'selectedPlayers',(select count(*)::integer from public.match_players mp where mp.match_id=m.id and mp.selection_type='regular' and mp.selection_status='selected')) order by case when requested_filter='upcoming' then m.starts_at end asc,case when requested_filter='all' then m.starts_at end desc,m.id),'[]'::jsonb) into result
 from public.matches m where m.team_id=target_team_id and m.season_id=target_season_id and (requested_filter='all' or (m.status='upcoming' and m.starts_at>=requested_now));
 return result;
end $$;

create or replace function public.get_match_roster(target_team_id uuid,target_season_id uuid,target_match_id uuid)
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare result jsonb; member_role text;
begin
 select role into member_role from public.team_members where team_id=target_team_id and user_id=(select auth.uid()) and is_active;
 if member_role is null then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 if not exists(select 1 from public.matches where id=target_match_id and team_id=target_team_id and season_id=target_season_id) then raise exception using errcode='P0001',message='MATCH_NOT_AVAILABLE'; end if;
 select coalesce(jsonb_agg(case when member_role='coach' then jsonb_build_object(
  'id',p.id,'name',concat_ws(' ',p.first_name,p.last_name),'level',p.level,'isActive',p.is_active,
  'selected',coalesce(mp.selection_status='selected',false),'selectionSource',mp.selection_source,
  'selectionStatus',mp.selection_status,'selectionType',mp.selection_type,
  'replacedPlayerId',mp.replaced_player_id,'played',coalesce(mp.played,false)
 ) else jsonb_build_object(
  'id',p.id,'name',concat_ws(' ',p.first_name,p.last_name),'rosterGroup',case
   when mp.selection_status='selected' and mp.selection_type='extra' then 'extra'
   when mp.selection_status='selected' and mp.selection_type='regular' then 'team'
   else 'resting' end
 ) end order by p.rotation_order,p.id),'[]'::jsonb) into result
 from public.players p left join public.match_players mp on mp.player_id=p.id and mp.match_id=target_match_id
 where p.team_id=target_team_id and p.season_id=target_season_id and (p.is_active or mp.player_id is not null);
 return result;
end $$;

create or replace function public.get_player_profile(target_team_id uuid,target_season_id uuid,target_player_id uuid)
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare source jsonb;
begin
 if not (select private.is_active_team_coach(target_team_id)) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 if not exists(select 1 from public.seasons where id=target_season_id and team_id=target_team_id and is_active) then raise exception using errcode='P0001',message='PLAYER_NOT_AVAILABLE'; end if;
 source:=private.player_source(target_team_id,target_season_id,target_player_id);
 if source is null then raise exception using errcode='P0001',message='PLAYER_NOT_AVAILABLE'; end if;
 return source||jsonb_build_object('fingerprint',md5(source::text),'serverNow',now());
end $$;

create or replace function public.get_player_list(target_team_id uuid)
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare result jsonb;
begin
 if not (select private.is_active_team_coach(target_team_id)) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 select jsonb_build_object('seasonName',s.name,'players',coalesce(jsonb_agg(jsonb_build_object('id',p.id,'firstName',p.first_name,'lastName',p.last_name,'level',p.level,'plannedRegular',c.planned_regular,'completedRegular',c.completed_regular,'plannedExtra',c.planned_extra,'completedExtra',c.completed_extra) order by p.rotation_order) filter(where p.id is not null),'[]'::jsonb)) into result
 from public.seasons s left join public.players p on p.season_id=s.id and p.team_id=s.team_id and p.is_active
 left join lateral(select count(*) filter(where m.status='upcoming' and mp.selection_type='regular')::integer planned_regular,count(*) filter(where m.status='completed' and mp.played and mp.selection_type='regular')::integer completed_regular,count(*) filter(where m.status='upcoming' and mp.selection_type='extra')::integer planned_extra,count(*) filter(where m.status='completed' and mp.played and mp.selection_type='extra')::integer completed_extra from public.match_players mp join public.matches m on m.id=mp.match_id where mp.player_id=p.id and mp.selection_status='selected') c on true
 where s.team_id=target_team_id and s.is_active group by s.id,s.name;
 if result is null then raise exception using errcode='P0001',message='ACTIVE_SEASON_NOT_AVAILABLE'; end if;
 return result;
end $$;

revoke all on function public.get_match_list(uuid,uuid,text,timestamptz),public.get_match_roster(uuid,uuid,uuid) from public;
grant execute on function public.get_match_list(uuid,uuid,text,timestamptz),public.get_match_roster(uuid,uuid,uuid) to authenticated;
