create or replace function public.enrich_training_items(
  target_team_id uuid,
  target_season_id uuid,
  requested_exercises jsonb
) returns integer
language plpgsql volatile security definer set search_path=''
as $$
declare exercise jsonb; changed integer:=0; affected integer;
begin
  if coalesce(auth.jwt()->>'role','')<>'service_role' then
    raise exception using errcode='42501',message='SERVER_ONLY';
  end if;
  if not exists(select 1 from public.seasons where id=target_season_id and team_id=target_team_id and is_active) then
    raise exception using errcode='P0001',message='TRAININGS_NOT_AVAILABLE';
  end if;
  if jsonb_typeof(requested_exercises)<>'array' or jsonb_array_length(requested_exercises)>100 then
    raise exception using errcode='P0001',message='INVALID_TRAINING_CONTENT';
  end if;
  for exercise in select value from jsonb_array_elements(requested_exercises) loop
    if trim(coalesce(exercise->>'title',''))='' or trim(coalesce(exercise->>'purpose',''))=''
      or trim(coalesce(exercise->>'instructions',''))='' or not private.valid_coaching_points(exercise->'coachingPoints')
      or coalesce(exercise->>'sourceUrl','') !~ '^https://innebandy\.se/'
      or (nullif(exercise->>'sourceImageUrl','') is not null and exercise->>'sourceImageUrl' !~ '^https://innebandy\.se/media/') then
      raise exception using errcode='P0001',message='INVALID_TRAINING_CONTENT';
    end if;
    update public.training_items i set
      purpose=exercise->>'purpose',
      instructions=exercise->>'instructions',
      coaching_points=exercise->'coachingPoints',
      source_url=exercise->>'sourceUrl',
      source_image_url=nullif(exercise->>'sourceImageUrl','')
    from public.training_sessions s
    where i.training_session_id=s.id
      and i.team_id=target_team_id and i.season_id=target_season_id
      and s.team_id=target_team_id and s.season_id=target_season_id
      and s.status='draft' and s.revision=1
      and i.title=exercise->>'title'
      and i.instructions='Anpassa övningen efter gruppen och dagens förutsättningar.';
    get diagnostics affected = row_count;
    changed:=changed+affected;
  end loop;
  return changed;
end $$;

revoke all on function public.enrich_training_items(uuid,uuid,jsonb) from public;
grant execute on function public.enrich_training_items(uuid,uuid,jsonb) to service_role;

create or replace function public.bootstrap_training_plan(actor_user_id uuid,target_team_id uuid,target_season_id uuid,requested_sessions jsonb)
returns boolean language plpgsql volatile security definer set search_path=''
as $$
declare session_data jsonb;item_data jsonb;created_session_id uuid;position_number integer;
begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception using errcode='42501',message='SERVER_ONLY';end if;
 if not exists(select 1 from public.team_members where team_id=target_team_id and user_id=actor_user_id and is_active) then raise exception using errcode='42501',message='NOT_AUTHORIZED';end if;
 perform 1 from public.seasons where id=target_season_id and team_id=target_team_id and is_active for update;if not found then raise exception using errcode='P0001',message='TRAININGS_NOT_AVAILABLE';end if;
 if jsonb_typeof(requested_sessions)<>'array' or jsonb_array_length(requested_sessions)<>27 then raise exception using errcode='P0001',message='INVALID_TRAINING_BOOTSTRAP';end if;
 if (select count(*) from public.training_sessions where team_id=target_team_id and season_id=target_season_id)>0 then
  if (select count(*) from public.training_sessions where team_id=target_team_id and season_id=target_season_id)=27 then return false;end if;
  raise exception using errcode='P0001',message='BOOTSTRAP_TRAINING_CONFLICT';
 end if;
 for session_data in select value from jsonb_array_elements(requested_sessions) loop
  insert into public.training_sessions(team_id,season_id,starts_at,ends_at,theme_block,focus,key_message,updated_by) values(target_team_id,target_season_id,(session_data->>'startsAt')::timestamptz,(session_data->>'endsAt')::timestamptz,(session_data->>'themeBlock')::smallint,session_data->>'focus',session_data->>'keyMessage',actor_user_id) returning id into created_session_id;
  position_number:=0;if jsonb_typeof(session_data->'items')<>'array' then raise exception using errcode='P0001',message='INVALID_TRAINING_BOOTSTRAP';end if;
  for item_data in select value from jsonb_array_elements(session_data->'items') loop position_number:=position_number+1;
   insert into public.training_items(training_session_id,team_id,season_id,section,position,title,guide_minutes,purpose,instructions,coaching_points,source_url,source_image_url) values(created_session_id,target_team_id,target_season_id,(item_data->>'section')::public.training_item_section,position_number,item_data->>'title',(item_data->>'guideMinutes')::integer,nullif(item_data->>'purpose',''),nullif(item_data->>'instructions',''),coalesce(item_data->'coachingPoints','[]'),nullif(item_data->>'sourceUrl',''),nullif(item_data->>'sourceImageUrl',''));
  end loop;
 end loop;return true;
end $$;
