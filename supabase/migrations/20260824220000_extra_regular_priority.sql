create or replace function public.get_extra_substitute_source(
  target_team_id uuid,
  target_season_id uuid,
  target_match_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  mutation_source jsonb;
  candidates jsonb;
begin
  if not (select private.is_active_team_member(target_team_id)) then
    raise exception using errcode = '42501', message = 'NOT_AUTHORIZED';
  end if;
  if not exists (
    select 1 from public.seasons
    where id = target_season_id and team_id = target_team_id and is_active
  ) then
    raise exception using errcode = 'P0001', message = 'MATCH_NOT_AVAILABLE';
  end if;

  mutation_source := private.extra_substitute_mutation_source(
    target_team_id, target_season_id, target_match_id
  );
  if mutation_source -> 'match' = 'null'::jsonb then
    raise exception using errcode = 'P0001', message = 'MATCH_NOT_AVAILABLE';
  end if;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', eligible.id,
      'firstName', eligible.first_name,
      'lastName', eligible.last_name,
      'rotationOrder', eligible.rotation_order,
      'completedExtraCount', eligible.completed_extra_count,
      'regularCount', eligible.regular_count,
      'lastCompletedExtraAt', eligible.last_completed_extra_at
    ) order by eligible.rotation_order, eligible.id
  ), '[]'::jsonb)
  into candidates
  from (
    select
      players.id,
      players.first_name,
      players.last_name,
      players.rotation_order,
      (
        select count(*)::integer
        from public.match_players regular_history
        join public.matches regular_match on regular_match.id = regular_history.match_id
        where regular_history.player_id = players.id
          and regular_history.team_id = players.team_id
          and regular_history.season_id = players.season_id
          and regular_history.selection_type = 'regular'
          and regular_history.selection_status = 'selected'
          and (
            regular_match.status = 'upcoming'
            or (regular_match.status = 'completed' and regular_history.played)
          )
      ) as regular_count,
      extra_history.completed_extra_count,
      extra_history.last_completed_extra_at
    from public.players
    cross join lateral (
      select
        count(history_match.id)::integer as completed_extra_count,
        case
          when max(history_match.starts_at) is null then null
          else to_char(max(history_match.starts_at) at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
        end as last_completed_extra_at
      from public.match_players history
      join public.matches history_match
        on history_match.id = history.match_id
        and history_match.status = 'completed'
      where history.player_id = players.id
        and history.team_id = players.team_id
        and history.season_id = players.season_id
        and history.selection_type = 'extra'
        and history.selection_status = 'selected'
        and history.played
    ) extra_history
    where players.team_id = target_team_id
      and players.season_id = target_season_id
      and players.is_active
      and not exists (
        select 1 from public.match_players current_selection
        where current_selection.match_id = target_match_id
          and current_selection.player_id = players.id
      )
  ) eligible;

  return jsonb_build_object(
    'fingerprint', md5(mutation_source::text),
    'candidates', candidates
  );
end;
$$;

revoke all on function public.get_extra_substitute_source(uuid, uuid, uuid) from public;
grant execute on function public.get_extra_substitute_source(uuid, uuid, uuid) to authenticated;
