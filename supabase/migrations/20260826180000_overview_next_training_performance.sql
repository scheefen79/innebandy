create or replace function public.get_overview(target_team_id uuid)
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare result jsonb;
begin
 if not (select private.is_active_team_member(target_team_id)) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 select jsonb_build_object(
  'seasonName',seasons.name,'serverNow',now(),
  'nextTraining',(
   select jsonb_build_object('id',t.id,'startsAt',t.starts_at,'endsAt',t.ends_at,'themeBlock',t.theme_block,'focus',t.focus,'keyMessage',t.key_message,'status',t.status)
   from public.training_sessions t
   where t.team_id=target_team_id and t.season_id=seasons.id and t.starts_at>now()
   order by t.starts_at,t.id limit 1
  ),
  'upcomingMatches',coalesce((
   select jsonb_agg(jsonb_build_object(
    'id',future_matches.id,'opponent',future_matches.opponent,'startsAt',future_matches.starts_at,
    'location',future_matches.location,'targetPlayers',future_matches.target_players,
    'selectedPlayers',(select count(*)::integer from public.match_players where match_players.match_id=future_matches.id and match_players.selection_status='selected')
   ) order by future_matches.starts_at,future_matches.id)
   from (select matches.* from public.matches where matches.team_id=target_team_id and matches.season_id=seasons.id and matches.status='upcoming' and matches.starts_at>now() order by matches.starts_at,matches.id limit 5) future_matches
  ),'[]'::jsonb),
  'players',coalesce((
   select jsonb_agg(jsonb_build_object(
    'id',players.id,'name',concat_ws(' ',players.first_name,players.last_name),
    'regularCount',(select count(*)::integer from public.match_players join public.matches on matches.id=match_players.match_id where match_players.player_id=players.id and match_players.selection_type='regular' and match_players.selection_status='selected' and (matches.status='upcoming' or (matches.status='completed' and match_players.played)))
   ) order by players.rotation_order,players.id)
   from public.players where players.team_id=target_team_id and players.season_id=seasons.id and players.is_active
  ),'[]'::jsonb)
 ) into result from public.seasons where seasons.team_id=target_team_id and seasons.is_active;
 if result is null then raise exception using errcode='P0001',message='OVERVIEW_NOT_AVAILABLE'; end if;
 return result;
end $$;

create or replace function public.get_home_overview()
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare target_team_id uuid;
begin
 select team_id into target_team_id from public.team_members
 where user_id=(select auth.uid()) and is_active order by team_id limit 1;
 if target_team_id is null then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 return public.get_overview(target_team_id);
end $$;

create or replace function public.get_team_context()
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare result jsonb;
begin
 select jsonb_build_object('teamId',tm.team_id,'seasonId',s.id,'seasonName',s.name) into result
 from public.team_members tm join public.seasons s on s.team_id=tm.team_id and s.is_active
 where tm.user_id=(select auth.uid()) and tm.is_active order by tm.team_id limit 1;
 if result is null then raise exception using errcode='P0001',message='TEAM_CONTEXT_NOT_AVAILABLE'; end if;
 return result;
end $$;

revoke all on function public.get_home_overview(),public.get_team_context() from public;
grant execute on function public.get_home_overview(),public.get_team_context() to authenticated;
