create type public.training_session_status as enum ('draft','planned','completed');
create type public.training_item_section as enum ('gathering','warmup','technique','match_exercise','closing');

create table public.training_sessions (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  season_id uuid not null references public.seasons(id) on delete cascade,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  theme_block smallint not null check(theme_block between 1 and 20),
  focus text not null check(length(trim(focus)) between 1 and 500),
  key_message text not null check(length(trim(key_message)) between 1 and 300),
  coach_notes text check(coach_notes is null or length(coach_notes)<=5000),
  status public.training_session_status not null default 'draft',
  revision integer not null default 1 check(revision>0),
  updated_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint training_session_time_check check(ends_at>starts_at),
  constraint training_session_team_time_unique unique(team_id,starts_at)
);

create table public.training_items (
  id uuid primary key default gen_random_uuid(),
  training_session_id uuid not null references public.training_sessions(id) on delete cascade,
  team_id uuid not null references public.teams(id) on delete cascade,
  season_id uuid not null references public.seasons(id) on delete cascade,
  section public.training_item_section not null,
  position integer not null check(position between 1 and 50),
  title text not null check(length(trim(title)) between 1 and 200),
  guide_minutes integer check(guide_minutes between 1 and 120),
  purpose text check(purpose is null or length(purpose)<=2000),
  instructions text check(instructions is null or length(instructions)<=5000),
  coaching_points jsonb not null default '[]'::jsonb check(jsonb_typeof(coaching_points)='array'),
  source_url text check(source_url is null or (length(source_url)<=1000 and source_url~'^https://')),
  source_image_url text check(source_image_url is null or (length(source_image_url)<=1000 and source_image_url~'^https://')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint training_item_position_unique unique(training_session_id,position)
);

create index training_sessions_team_season_start_idx on public.training_sessions(team_id,season_id,starts_at);
create index training_items_session_position_idx on public.training_items(training_session_id,position);
create trigger training_sessions_set_updated_at before update on public.training_sessions for each row execute function private.set_updated_at();
create trigger training_items_set_updated_at before update on public.training_items for each row execute function private.set_updated_at();

alter table public.training_sessions enable row level security;
alter table public.training_items enable row level security;
create policy "Members can read training sessions" on public.training_sessions for select using(private.is_active_team_member(team_id));
create policy "Members can read training items" on public.training_items for select using(private.is_active_team_member(team_id));

revoke all on public.training_sessions,public.training_items from anon,authenticated;
grant select on public.training_sessions,public.training_items to authenticated;
grant select,insert,update,delete on public.training_sessions,public.training_items to service_role;

create or replace function public.get_training_list(target_team_id uuid,target_season_id uuid)
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare result jsonb;
begin
 if not (select private.is_active_team_member(target_team_id)) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 if not exists(select 1 from public.seasons where id=target_season_id and team_id=target_team_id and is_active) then raise exception using errcode='P0001',message='TRAININGS_NOT_AVAILABLE'; end if;
 select coalesce(jsonb_agg(jsonb_build_object(
   'id',s.id,'startsAt',s.starts_at,'endsAt',s.ends_at,'themeBlock',s.theme_block,
   'focus',s.focus,'keyMessage',s.key_message,'status',s.status,'revision',s.revision,
   'updatedAt',s.updated_at,'updatedBy',coalesce(split_part(u.email,'@',1),'Tränare')
 ) order by s.starts_at,s.id),'[]'::jsonb) into result
 from public.training_sessions s left join auth.users u on u.id=s.updated_by
 where s.team_id=target_team_id and s.season_id=target_season_id;
 return result;
end $$;

create or replace function public.get_training_plan(target_team_id uuid,target_season_id uuid,target_training_id uuid)
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare result jsonb;
begin
 if not (select private.is_active_team_member(target_team_id)) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
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

create or replace function public.save_training_plan(
 actor_user_id uuid,target_team_id uuid,target_season_id uuid,target_training_id uuid,
 expected_revision integer,requested_focus text,requested_key_message text,requested_notes text,
 requested_status public.training_session_status,requested_items jsonb
) returns integer language plpgsql volatile security definer set search_path=''
as $$
declare current_session public.training_sessions%rowtype; item jsonb; item_position integer:=0; next_revision integer;
begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception using errcode='42501',message='SERVER_ONLY'; end if;
 if not exists(select 1 from public.team_members where team_id=target_team_id and user_id=actor_user_id and is_active) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 select * into current_session from public.training_sessions where id=target_training_id and team_id=target_team_id and season_id=target_season_id for update;
 if not found then raise exception using errcode='P0001',message='TRAINING_NOT_AVAILABLE'; end if;
 if current_session.status='completed' then raise exception using errcode='P0001',message='TRAINING_COMPLETED'; end if;
 if current_session.revision<>expected_revision then raise exception using errcode='P0001',message='STALE_TRAINING_PLAN'; end if;
 if trim(requested_focus)='' or length(requested_focus)>500 or trim(requested_key_message)='' or length(requested_key_message)>300 or length(coalesce(requested_notes,''))>5000 or jsonb_typeof(requested_items)<>'array' or jsonb_array_length(requested_items)>50 then raise exception using errcode='P0001',message='INVALID_TRAINING_PLAN'; end if;
 if current_session.status='draft' and requested_status not in ('draft','planned') or current_session.status='planned' and requested_status not in ('planned','completed') then raise exception using errcode='P0001',message='INVALID_TRAINING_STATUS'; end if;
 delete from public.training_items where training_session_id=target_training_id;
 for item in select value from jsonb_array_elements(requested_items) loop
  item_position:=item_position+1;
  if trim(coalesce(item->>'title',''))='' or length(item->>'title')>200 or coalesce(jsonb_typeof(item->'coachingPoints'),'null')<>'array' then raise exception using errcode='P0001',message='INVALID_TRAINING_PLAN'; end if;
  insert into public.training_items(training_session_id,team_id,season_id,section,position,title,guide_minutes,purpose,instructions,coaching_points,source_url,source_image_url)
  values(target_training_id,target_team_id,target_season_id,(item->>'section')::public.training_item_section,item_position,item->>'title',nullif(item->>'guideMinutes','')::integer,nullif(trim(item->>'purpose'),''),nullif(trim(item->>'instructions'),''),coalesce(item->'coachingPoints','[]'::jsonb),nullif(trim(item->>'sourceUrl'),''),nullif(trim(item->>'sourceImageUrl'),''));
 end loop;
 next_revision:=current_session.revision+1;
 update public.training_sessions set focus=trim(requested_focus),key_message=trim(requested_key_message),coach_notes=nullif(trim(requested_notes),''),status=requested_status,revision=next_revision,updated_by=actor_user_id where id=target_training_id;
 return next_revision;
end $$;

revoke all on function public.get_training_list(uuid,uuid),public.get_training_plan(uuid,uuid,uuid),public.save_training_plan(uuid,uuid,uuid,uuid,integer,text,text,text,public.training_session_status,jsonb) from public;
grant execute on function public.get_training_list(uuid,uuid),public.get_training_plan(uuid,uuid,uuid) to authenticated;
grant execute on function public.save_training_plan(uuid,uuid,uuid,uuid,integer,text,text,text,public.training_session_status,jsonb) to service_role;
