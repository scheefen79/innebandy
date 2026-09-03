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
