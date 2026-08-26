create or replace function private.valid_coaching_points(points jsonb)
returns boolean language sql immutable set search_path=''
as $$
  select jsonb_typeof(points)='array'
    and jsonb_array_length(points)<=20
    and not exists (
      select 1 from jsonb_array_elements(points) value
      where jsonb_typeof(value)<>'string'
        or length(trim(value #>> '{}')) not between 1 and 300
    );
$$;

alter table public.training_items drop constraint training_items_coaching_points_check;
alter table public.training_items add constraint training_items_coaching_points_check
  check(private.valid_coaching_points(coaching_points));

drop policy "Members can read training sessions" on public.training_sessions;
create policy "Members can read active-season training sessions" on public.training_sessions
for select using(
  private.is_active_team_member(team_id)
  and exists(select 1 from public.seasons s where s.id=season_id and s.team_id=team_id and s.is_active)
);
drop policy "Members can read training items" on public.training_items;
create policy "Members can read active-season training items" on public.training_items
for select using(
  private.is_active_team_member(team_id)
  and exists(select 1 from public.seasons s where s.id=season_id and s.team_id=team_id and s.is_active)
);

create or replace function public.get_training_plan(target_team_id uuid,target_season_id uuid,target_training_id uuid)
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare result jsonb;
begin
 if not (select private.is_active_team_member(target_team_id)) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 if not exists(select 1 from public.seasons where id=target_season_id and team_id=target_team_id and is_active) then raise exception using errcode='P0001',message='TRAINING_NOT_AVAILABLE'; end if;
 select jsonb_build_object(
  'id',s.id,'startsAt',s.starts_at,'endsAt',s.ends_at,'themeBlock',s.theme_block,
  'focus',s.focus,'keyMessage',s.key_message,'coachNotes',s.coach_notes,'status',s.status,
  'revision',s.revision,'updatedAt',s.updated_at,'updatedBy',coalesce(split_part(u.email,'@',1),'Tränare'),
  'items',coalesce((select jsonb_agg(jsonb_build_object(
    'id',i.id,'section',i.section,'position',i.position,'title',i.title,'guideMinutes',i.guide_minutes,
    'purpose',i.purpose,'instructions',i.instructions,'coachingPoints',i.coaching_points,
    'sourceUrl',i.source_url,'sourceImageUrl',i.source_image_url
  ) order by i.position) from public.training_items i where i.training_session_id=s.id),'[]'::jsonb)
 ) into result from public.training_sessions s left join auth.users u on u.id=s.updated_by
 where s.id=target_training_id and s.team_id=target_team_id and s.season_id=target_season_id;
 if result is null then raise exception using errcode='P0001',message='TRAINING_NOT_AVAILABLE'; end if;
 return result;
end $$;

alter table public.training_sessions add column last_save_request_id text;
alter table public.training_sessions add column last_save_payload_hash text;

drop function public.save_training_plan(uuid,uuid,uuid,uuid,integer,text,text,text,public.training_session_status,jsonb);
create function public.save_training_plan(
 actor_user_id uuid,target_team_id uuid,target_season_id uuid,target_training_id uuid,
 expected_revision integer,request_id text,requested_focus text,requested_key_message text,requested_notes text,
 requested_status public.training_session_status,requested_items jsonb
) returns integer language plpgsql volatile security definer set search_path=''
as $$
declare current_session public.training_sessions%rowtype; item jsonb; item_position integer:=0; next_revision integer; payload_hash text;
begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception using errcode='42501',message='SERVER_ONLY'; end if;
 if not exists(select 1 from public.team_members where team_id=target_team_id and user_id=actor_user_id and is_active) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 if request_id is null or length(request_id)>200 then raise exception using errcode='P0001',message='INVALID_TRAINING_PLAN'; end if;
 payload_hash:=md5(jsonb_build_array(expected_revision,requested_focus,requested_key_message,requested_notes,requested_status,requested_items)::text);
 select * into current_session from public.training_sessions where id=target_training_id and team_id=target_team_id and season_id=target_season_id for update;
 if not found then raise exception using errcode='P0001',message='TRAINING_NOT_AVAILABLE'; end if;
 if current_session.last_save_request_id=request_id then
  if current_session.last_save_payload_hash=payload_hash then return current_session.revision; end if;
  raise exception using errcode='P0001',message='REQUEST_CONFLICT';
 end if;
 if current_session.status='completed' then raise exception using errcode='P0001',message='TRAINING_COMPLETED'; end if;
 if current_session.revision<>expected_revision then raise exception using errcode='P0001',message='STALE_TRAINING_PLAN'; end if;
 if trim(requested_focus)='' or length(requested_focus)>500 or trim(requested_key_message)='' or length(requested_key_message)>300 or length(coalesce(requested_notes,''))>5000 or jsonb_typeof(requested_items)<>'array' or jsonb_array_length(requested_items)>50 then raise exception using errcode='P0001',message='INVALID_TRAINING_PLAN'; end if;
 if current_session.status='draft' and requested_status not in ('draft','planned') or current_session.status='planned' and requested_status not in ('planned','completed') then raise exception using errcode='P0001',message='INVALID_TRAINING_STATUS'; end if;
 delete from public.training_items where training_session_id=target_training_id;
 for item in select value from jsonb_array_elements(requested_items) loop
  item_position:=item_position+1;
  if trim(coalesce(item->>'title',''))='' or length(item->>'title')>200 or not private.valid_coaching_points(coalesce(item->'coachingPoints','[]'::jsonb)) then raise exception using errcode='P0001',message='INVALID_TRAINING_PLAN'; end if;
  insert into public.training_items(training_session_id,team_id,season_id,section,position,title,guide_minutes,purpose,instructions,coaching_points,source_url,source_image_url)
  values(target_training_id,target_team_id,target_season_id,(item->>'section')::public.training_item_section,item_position,item->>'title',nullif(item->>'guideMinutes','')::integer,nullif(trim(item->>'purpose'),''),nullif(trim(item->>'instructions'),''),coalesce(item->'coachingPoints','[]'::jsonb),nullif(trim(item->>'sourceUrl'),''),nullif(trim(item->>'sourceImageUrl'),''));
 end loop;
 next_revision:=current_session.revision+1;
 update public.training_sessions set focus=trim(requested_focus),key_message=trim(requested_key_message),coach_notes=nullif(trim(requested_notes),''),status=requested_status,revision=next_revision,updated_by=actor_user_id,last_save_request_id=request_id,last_save_payload_hash=payload_hash where id=target_training_id;
 return next_revision;
end $$;

revoke all on function public.save_training_plan(uuid,uuid,uuid,uuid,integer,text,text,text,text,public.training_session_status,jsonb) from public;
grant execute on function public.save_training_plan(uuid,uuid,uuid,uuid,integer,text,text,text,text,public.training_session_status,jsonb) to service_role;
