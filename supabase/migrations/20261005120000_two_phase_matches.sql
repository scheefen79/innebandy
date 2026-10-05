-- ADR-023: freeze the plan, track external invitations, then lock actual participation.
create table public.match_workflows (
  match_id uuid primary key,
  team_id uuid not null,
  season_id uuid not null,
  phase text not null check (phase in ('planning','week','locked','legacy')),
  revision integer not null default 0 check (revision >= 0),
  history_required boolean not null default false,
  history_reviewed_at timestamptz,
  foreign key (match_id,team_id,season_id) references public.matches(id,team_id,season_id) on delete cascade
);
create table public.match_calls (
  match_id uuid not null,
  team_id uuid not null,
  season_id uuid not null,
  player_id uuid not null,
  in_plan boolean not null default false,
  offered_regular boolean not null default false,
  response text not null default 'uninvited' check (response in ('uninvited','pending','accepted','declined','withdrawn')),
  primary key (match_id,player_id),
  foreign key (match_id,team_id,season_id) references public.matches(id,team_id,season_id) on delete cascade,
  foreign key (player_id,team_id,season_id) references public.players(id,team_id,season_id)
);
create table public.match_participation (
  match_id uuid not null,
  team_id uuid not null,
  season_id uuid not null,
  player_id uuid not null,
  selection_type text not null check (selection_type in ('regular','extra')),
  primary key (match_id,player_id),
  foreign key (match_id,team_id,season_id) references public.matches(id,team_id,season_id) on delete cascade,
  foreign key (player_id,team_id,season_id) references public.players(id,team_id,season_id)
);
create table public.match_workflow_events (
  id bigint generated always as identity primary key,
  match_id uuid not null references public.matches(id) on delete cascade,
  team_id uuid not null references public.teams(id),
  actor_user_id uuid not null references auth.users(id),
  request_id uuid not null,
  payload_hash text not null,
  action text not null,
  reason text,
  before_state jsonb not null,
  after_state jsonb not null,
  revision integer not null,
  created_at timestamptz not null default now(),
  unique(match_id,revision),
  unique(match_id,request_id)
);
create index match_calls_player_idx on public.match_calls(player_id,match_id);
create index match_participation_player_idx on public.match_participation(player_id,match_id);
alter table public.match_workflows enable row level security;
alter table public.match_calls enable row level security;
alter table public.match_participation enable row level security;
alter table public.match_workflow_events enable row level security;
create policy "Coach workflow reads" on public.match_workflows for select to authenticated using ((select private.is_active_team_coach(team_id)));
create policy "Coach call reads" on public.match_calls for select to authenticated using ((select private.is_active_team_coach(team_id)));
create policy "Coach participation reads" on public.match_participation for select to authenticated using ((select private.is_active_team_coach(team_id)));
create policy "Coach event reads" on public.match_workflow_events for select to authenticated using ((select private.is_active_team_coach(team_id)));
revoke all on public.match_workflows,public.match_calls,public.match_participation,public.match_workflow_events from public,anon,authenticated;
grant select on public.match_workflows,public.match_calls,public.match_participation,public.match_workflow_events to authenticated;
grant all on public.match_workflows,public.match_calls,public.match_participation,public.match_workflow_events to service_role;
grant usage,select on sequence public.match_workflow_events_id_seq to service_role;

-- No invitation is inferred from a historical selection. Coaches must confirm it.
insert into public.match_workflows(match_id,team_id,season_id,phase,history_required)
select id,team_id,season_id,'legacy',true from public.matches
where status <> 'cancelled' and (status='completed' or starts_at <= now());

create function private.match_workflow_state(target_match_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object(
   'match',(select jsonb_build_object('status',status,'startsAt',starts_at) from public.matches where id=target_match_id),
   'legacyParticipation',coalesce((select jsonb_agg(to_jsonb(mp) order by player_id) from public.match_players mp where match_id=target_match_id),'[]'::jsonb),
   'workflow',(select to_jsonb(w) from public.match_workflows w where match_id=target_match_id),
   'calls',coalesce((select jsonb_agg(to_jsonb(c) order by player_id) from public.match_calls c where match_id=target_match_id),'[]'::jsonb),
   'participation',coalesce((select jsonb_agg(to_jsonb(p) order by player_id) from public.match_participation p where match_id=target_match_id),'[]'::jsonb)
 );
$$;
revoke all on function private.match_workflow_state(uuid) from public;

create function private.player_match_totals(target_player_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object(
 'historyComplete',not exists(select 1 from public.match_workflows w join public.matches m on m.id=w.match_id join public.players subject on subject.id=target_player_id where w.team_id=subject.team_id and w.season_id=subject.season_id and w.history_required and w.history_reviewed_at is null and m.status<>'cancelled'),
 'offeredRegular',(select count(*) from public.match_calls c join public.matches m on m.id=c.match_id where c.player_id=target_player_id and c.offered_regular and m.status<>'cancelled'),
 'plannedRegular',(select count(*) from public.match_players mp join public.matches m on m.id=mp.match_id left join public.match_workflows w on w.match_id=m.id where mp.player_id=target_player_id and mp.selection_type='regular' and mp.selection_status='selected' and m.status='upcoming' and coalesce(w.phase,'planning')='planning')+(select count(*) from public.match_calls c join public.matches m on m.id=c.match_id join public.match_workflows w on w.match_id=m.id where c.player_id=target_player_id and c.in_plan and c.response='uninvited' and w.phase='week' and m.status='upcoming'),
 'plannedExtra',(select count(*) from public.match_players mp join public.matches m on m.id=mp.match_id left join public.match_workflows w on w.match_id=m.id where mp.player_id=target_player_id and mp.selection_type='extra' and mp.selection_status='selected' and m.status='upcoming' and coalesce(w.phase,'planning')='planning')+(select count(*) from public.match_calls c join public.matches m on m.id=c.match_id join public.match_workflows w on w.match_id=m.id where c.player_id=target_player_id and not c.in_plan and c.response in ('pending','accepted') and w.phase='week' and m.status='upcoming'),
 'completedRegular',
   (select count(*) from public.match_players mp join public.matches m on m.id=mp.match_id left join public.match_workflows w on w.match_id=m.id where mp.player_id=target_player_id and mp.selection_type='regular' and mp.selection_status='selected' and mp.played and m.status='completed' and coalesce(w.phase,'legacy')<>'locked')+
   (select count(*) from public.match_participation p join public.matches m on m.id=p.match_id where p.player_id=target_player_id and p.selection_type='regular' and m.status='completed'),
 'completedExtra',
   (select count(*) from public.match_players mp join public.matches m on m.id=mp.match_id left join public.match_workflows w on w.match_id=m.id where mp.player_id=target_player_id and mp.selection_type='extra' and mp.selection_status='selected' and mp.played and m.status='completed' and coalesce(w.phase,'legacy')<>'locked')+
   (select count(*) from public.match_participation p join public.matches m on m.id=p.match_id where p.player_id=target_player_id and p.selection_type='extra' and m.status='completed'),
 'lastExtraAt',(select max(starts_at) from (
   select m.starts_at from public.match_players mp join public.matches m on m.id=mp.match_id left join public.match_workflows w on w.match_id=m.id where mp.player_id=target_player_id and mp.selection_type='extra' and mp.played and mp.selection_status='selected' and m.status='completed' and coalesce(w.phase,'legacy')<>'locked'
   union all select m.starts_at from public.match_participation p join public.matches m on m.id=p.match_id where p.player_id=target_player_id and p.selection_type='extra' and m.status='completed'
 ) dates)
 );
$$;
revoke all on function private.player_match_totals(uuid) from public;

create function public.get_match_workflow(target_team_id uuid,target_season_id uuid,target_match_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if not private.is_active_team_coach(target_team_id) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 select jsonb_build_object('phase',coalesce(w.phase,'planning'),'revision',coalesce(w.revision,0),
 'historyRequired',coalesce(w.history_required and w.history_reviewed_at is null,false),'status',m.status,'startsAt',m.starts_at,
 'players',coalesce((select jsonb_agg(jsonb_build_object(
 'id',p.id,'name',concat_ws(' ',p.first_name,p.last_name),'level',p.level,'active',p.is_active,'rotationOrder',p.rotation_order,
 'inPlan',coalesce(c.in_plan,mp.selection_type='regular' and mp.selection_status='selected',false),
 'offeredRegular',coalesce(c.offered_regular,false),'response',coalesce(c.response,'uninvited'),
 'played',case when w.phase='locked' then part.player_id is not null else coalesce(mp.played and m.status='completed',false) end,
 'participationType',case when w.phase='locked' then part.selection_type else mp.selection_type end,
 'totals',private.player_match_totals(p.id)
 ) order by p.rotation_order,p.id) from public.players p
 left join public.match_calls c on c.match_id=m.id and c.player_id=p.id
 left join public.match_players mp on mp.match_id=m.id and mp.player_id=p.id
 left join public.match_participation part on part.match_id=m.id and part.player_id=p.id
 where p.team_id=target_team_id and p.season_id=target_season_id and (p.is_active or (w.history_required and w.history_reviewed_at is null) or c.player_id is not null or mp.player_id is not null or part.player_id is not null)),'[]'::jsonb),
 'events',coalesce((select jsonb_agg(jsonb_build_object('action',e.action,'reason',e.reason,'at',e.created_at,'revision',e.revision) order by e.revision desc) from public.match_workflow_events e where e.match_id=m.id),'[]'::jsonb)
 ) into result from public.matches m left join public.match_workflows w on w.match_id=m.id
 where m.id=target_match_id and m.team_id=target_team_id and m.season_id=target_season_id;
 if result is null then raise exception using errcode='P0001',message='MATCH_NOT_AVAILABLE'; end if;
 return result;
end $$;
revoke all on function public.get_match_workflow(uuid,uuid,uuid) from public,anon;
grant execute on function public.get_match_workflow(uuid,uuid,uuid) to authenticated;

create function public.save_match_workflow(
 actor_user_id uuid,target_team_id uuid,target_season_id uuid,target_match_id uuid,
 expected_revision integer,request_id uuid,requested_action text,changes jsonb,reason text default null
) returns integer language plpgsql volatile security definer set search_path='' as $$
declare
 w public.match_workflows%rowtype; m public.matches%rowtype; previous_event public.match_workflow_events%rowtype;
 before_snapshot jsonb; hash text; ids uuid[]; row_change jsonb; current_call public.match_calls%rowtype;
begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception using errcode='42501',message='SERVER_ONLY'; end if;
 if not private.is_active_team_coach(actor_user_id,target_team_id) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 if request_id is null or expected_revision is null or requested_action is null or requested_action not in ('start','responses','lock','correct','history','cancel') or changes is null or jsonb_typeof(changes)<>'array' then
   raise exception using errcode='P0001',message='INVALID_WORKFLOW'; end if;
 perform 1 from public.seasons where id=target_season_id and team_id=target_team_id and is_active for update;
 if not found then raise exception using errcode='P0001',message='MATCH_NOT_AVAILABLE'; end if;
 select * into m from public.matches where id=target_match_id and team_id=target_team_id and season_id=target_season_id for update;
 if not found then raise exception using errcode='P0001',message='MATCH_NOT_AVAILABLE'; end if;
 -- Recheck membership after waiting for locks.
 if not private.is_active_team_coach(actor_user_id,target_team_id) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 hash:=md5(jsonb_build_object('action',requested_action,'changes',changes,'reason',reason)::text);
 select * into previous_event from public.match_workflow_events e where e.match_id=target_match_id and e.request_id=save_match_workflow.request_id;
 if found then
   if previous_event.payload_hash<>hash or previous_event.actor_user_id<>save_match_workflow.actor_user_id then raise exception using errcode='P0001',message='REQUEST_CONFLICT'; end if;
   return previous_event.revision;
 end if;
 insert into public.match_workflows(match_id,team_id,season_id,phase)
 values(target_match_id,target_team_id,target_season_id,case when m.status='completed' or m.starts_at<=now() then 'legacy' else 'planning' end)
 on conflict(match_id) do nothing;
 select * into w from public.match_workflows where match_id=target_match_id;
 if w.revision<>expected_revision then raise exception using errcode='P0001',message='STALE_WORKFLOW'; end if;
 if m.status='cancelled' then raise exception using errcode='P0001',message='MATCH_NOT_AVAILABLE'; end if;
 perform 1 from public.players where team_id=target_team_id and season_id=target_season_id order by rotation_order,id for update;
 before_snapshot:=private.match_workflow_state(target_match_id);

 if requested_action='start' then
   if m.status<>'upcoming' or w.phase not in ('planning','legacy') or (w.history_required and w.history_reviewed_at is null) or jsonb_array_length(changes)<>0 then raise exception using errcode='P0001',message='INVALID_WORKFLOW'; end if;
   insert into public.match_calls(match_id,team_id,season_id,player_id,in_plan)
   select target_match_id,target_team_id,target_season_id,player_id,true from public.match_players
   where match_id=target_match_id and selection_type='regular' and selection_status='selected'
   on conflict(match_id,player_id) do update set in_plan=true;
   insert into public.match_calls(match_id,team_id,season_id,player_id,response)
   select target_match_id,target_team_id,target_season_id,player_id,'uninvited' from public.match_players
   where match_id=target_match_id and selection_type='extra' and selection_status='selected'
   on conflict(match_id,player_id) do nothing;
   if (select count(*) from public.match_calls where match_id=target_match_id and response in ('pending','accepted'))>10 then raise exception using errcode='P0001',message='ROSTER_CAPACITY'; end if;
   update public.match_workflows set phase='week' where match_id=target_match_id;
 elsif requested_action in ('responses','history') then
   if requested_action='responses' and (w.phase<>'week' or m.status<>'upcoming') then raise exception using errcode='P0001',message='INVALID_WORKFLOW'; end if;
   if requested_action='history' and (not w.history_required or w.history_reviewed_at is not null) then raise exception using errcode='P0001',message='INVALID_WORKFLOW'; end if;
   if exists(select 1 from jsonb_array_elements(changes) x where jsonb_typeof(x)<>'object' or jsonb_typeof(x->'playerId') is distinct from 'string' or (x->>'playerId') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' or x->>'response' not in ('pending','accepted','declined','withdrawn') or x->>'response' is null)
   or (select count(distinct lower(x->>'playerId')) from jsonb_array_elements(changes) x)<>jsonb_array_length(changes) then raise exception using errcode='P0001',message='INVALID_WORKFLOW'; end if;
   for row_change in select value from jsonb_array_elements(changes) loop
     perform 1 from public.players where id=(row_change->>'playerId')::uuid and team_id=target_team_id and season_id=target_season_id and (is_active or requested_action='history' or exists(select 1 from public.match_calls c where c.match_id=target_match_id and c.player_id=players.id));
     if not found then raise exception using errcode='P0001',message='INVALID_WORKFLOW'; end if;
     select * into current_call from public.match_calls where match_id=target_match_id and player_id=(row_change->>'playerId')::uuid;
     if requested_action='responses' and (current_call.player_id is null or current_call.response='uninvited') and row_change->>'response' in ('declined','withdrawn') then raise exception using errcode='P0001',message='INVALID_WORKFLOW'; end if;
     if requested_action='responses' and row_change->>'response' in ('pending','accepted') and not exists(select 1 from public.players where id=(row_change->>'playerId')::uuid and is_active) then raise exception using errcode='P0001',message='INVALID_WORKFLOW'; end if;
     insert into public.match_calls(match_id,team_id,season_id,player_id,in_plan,offered_regular,response)
     values(target_match_id,target_team_id,target_season_id,(row_change->>'playerId')::uuid,requested_action='history',requested_action='history',row_change->>'response')
     on conflict(match_id,player_id) do update set
       offered_regular=match_calls.offered_regular or match_calls.in_plan or requested_action='history',
       response=excluded.response;
   end loop;
   if requested_action='responses' and (select count(*) from public.match_calls where match_id=target_match_id and response in ('pending','accepted'))>10 then raise exception using errcode='P0001',message='ROSTER_CAPACITY'; end if;
   if requested_action='history' then
     update public.match_workflows set history_reviewed_at=now() where match_id=target_match_id;
   end if;
 elsif requested_action in ('lock','correct') then
   if requested_action='lock' and (w.phase<>'week' or m.status<>'upcoming' or m.starts_at>now()) then raise exception using errcode='P0001',message='INVALID_WORKFLOW'; end if;
   if requested_action='correct' and (m.status<>'completed' or w.phase not in ('locked','legacy') or length(trim(coalesce(reason,''))) not between 1 and 500 or (w.history_required and w.history_reviewed_at is null)) then raise exception using errcode='P0001',message='INVALID_WORKFLOW'; end if;
   if jsonb_array_length(changes) not between 1 and 10 or exists(select 1 from jsonb_array_elements(changes) x where jsonb_typeof(x) is distinct from 'string' or x#>>'{}' !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') then raise exception using errcode='P0001',message='INVALID_WORKFLOW'; end if;
   select array_agg(value::uuid order by value) into ids from jsonb_array_elements_text(changes);
   if (select count(distinct id) from unnest(ids) id)<>cardinality(ids) or exists(select 1 from unnest(ids) chosen(player_id) where not exists(select 1 from public.players p where p.id=chosen.player_id and p.team_id=target_team_id and p.season_id=target_season_id and (p.is_active or exists(select 1 from public.match_calls c where c.match_id=target_match_id and c.player_id=chosen.player_id) or exists(select 1 from public.match_players mp where mp.match_id=target_match_id and mp.player_id=chosen.player_id)))) then raise exception using errcode='P0001',message='INVALID_WORKFLOW'; end if;
   if requested_action='lock' and exists(select 1 from public.match_calls c where c.match_id=target_match_id and c.response='pending') then raise exception using errcode='P0001',message='UNRESOLVED_RESPONSES'; end if;
   delete from public.match_participation where match_id=target_match_id;
   insert into public.match_participation(match_id,team_id,season_id,player_id,selection_type)
   select target_match_id,target_team_id,target_season_id,id,case when exists(select 1 from public.match_calls c where c.match_id=target_match_id and c.player_id=id and c.offered_regular) then 'regular' else 'extra' end from unnest(ids) id;
   update public.match_workflows set phase='locked' where match_id=target_match_id;
   update public.matches set status='completed' where id=target_match_id;
 elsif requested_action='cancel' then
   if m.status<>'upcoming' or jsonb_array_length(changes)<>0 then raise exception using errcode='P0001',message='INVALID_WORKFLOW'; end if;
   update public.matches set status='cancelled' where id=target_match_id;
 end if;
 update public.match_workflows set revision=revision+1 where match_id=target_match_id returning revision into expected_revision;
 insert into public.match_workflow_events(match_id,team_id,actor_user_id,request_id,payload_hash,action,reason,before_state,after_state,revision)
 values(target_match_id,target_team_id,actor_user_id,request_id,hash,requested_action,nullif(trim(reason),''),before_snapshot,private.match_workflow_state(target_match_id),expected_revision);
 return expected_revision;
end $$;
revoke all on function public.save_match_workflow(uuid,uuid,uuid,uuid,integer,uuid,text,jsonb,text) from public,anon,authenticated;
grant execute on function public.save_match_workflow(uuid,uuid,uuid,uuid,integer,uuid,text,jsonb,text) to service_role;

-- Legacy editors must never mutate a frozen plan (including direct server RPCs).
create function private.guard_frozen_match_plan() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from public.match_workflows where match_id=coalesce(new.match_id,old.match_id) and phase in ('week','locked')) then raise exception using errcode='P0001',message='FROZEN_MATCH_PLAN'; end if;
 return coalesce(new,old);
end $$;
revoke all on function private.guard_frozen_match_plan() from public;
create trigger match_players_frozen_plan before insert or update or delete on public.match_players for each row execute function private.guard_frozen_match_plan();

create or replace function private.regular_allocation_source(
  target_team_id uuid,
  target_season_id uuid,
  boundary timestamptz
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'version', 1,
    'teamId', target_team_id,
    'seasonId', target_season_id,
    'players', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', players.id,
          'level', players.level,
          'rotationOrder', players.rotation_order,
          'baselineRegularCount', (
            select count(*) from public.matches h
            where h.team_id=target_team_id and h.season_id=target_season_id and h.status<>'cancelled'
            and (exists(select 1 from public.match_calls c where c.match_id=h.id and c.player_id=players.id and (c.offered_regular or (c.in_plan and c.response='uninvited' and h.status='upcoming' and h.starts_at>=now())))
              or (h.status='upcoming' and h.starts_at<boundary and not exists(select 1 from public.match_workflows w where w.match_id=h.id and w.phase<>'planning')
                and exists(select 1 from public.match_players mp where mp.match_id=h.id and mp.player_id=players.id and mp.selection_type='regular' and mp.selection_status='selected')))
          ),
          'baselineLastRegularMatchOrder', (
            select max(h.match_order) from (select m.*,row_number() over(order by starts_at,id)::integer match_order from public.matches m where team_id=target_team_id and season_id=target_season_id) h
            where h.status<>'cancelled' and (exists(select 1 from public.match_calls c where c.match_id=h.id and c.player_id=players.id and (c.offered_regular or (c.in_plan and c.response='uninvited' and h.status='upcoming' and h.starts_at>=now())))
              or (h.status='upcoming' and h.starts_at<boundary and not exists(select 1 from public.match_workflows w where w.match_id=h.id and w.phase<>'planning')
                and exists(select 1 from public.match_players mp where mp.match_id=h.id and mp.player_id=players.id and mp.selection_type='regular' and mp.selection_status='selected')))
          )
        ) order by players.rotation_order, players.id
      )
      from public.players
      where players.team_id = target_team_id
        and players.season_id = target_season_id
        and players.is_active
    ), '[]'::jsonb),
    'matches', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', matches.id,
          'order', ordered_matches.match_order,
          'targetSize', matches.target_players
        ) order by ordered_matches.match_order
      )
      from (
        select id, match_order
        from (
          select
            id,
            status,
            starts_at,
            row_number() over (order by starts_at, id)::integer as match_order
          from public.matches
          where team_id = target_team_id
            and season_id = target_season_id
        ) season_matches
        where status = 'upcoming'
          and starts_at >= boundary
          and not exists(select 1 from public.match_workflows w where w.match_id=season_matches.id and w.phase<>'planning')
      ) ordered_matches
      join public.matches on matches.id = ordered_matches.id
    ), '[]'::jsonb),
    'manualSelections', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'matchId', match_players.match_id,
          'playerId', match_players.player_id,
          'decision', case when match_players.selection_status = 'selected' then 'include' else 'exclude' end
        ) order by match_players.match_id, match_players.player_id
      )
      from public.match_players
      join public.matches on matches.id = match_players.match_id
      where match_players.team_id = target_team_id
        and match_players.season_id = target_season_id
        and match_players.selection_type = 'regular'
        and match_players.selection_source = 'manual'
        and matches.status = 'upcoming'
        and matches.starts_at >= boundary
        and not exists(select 1 from public.match_workflows w where w.match_id=matches.id and w.phase<>'planning')
    ), '[]'::jsonb),
    'automaticSelections', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'matchId', match_players.match_id,
          'playerId', match_players.player_id,
          'updatedAt', match_players.updated_at
        ) order by match_players.match_id, match_players.player_id
      )
      from public.match_players
      join public.matches on matches.id = match_players.match_id
      where match_players.team_id = target_team_id
        and match_players.season_id = target_season_id
        and match_players.selection_type = 'regular'
        and match_players.selection_source = 'automatic'
        and matches.status = 'upcoming'
        and matches.starts_at >= boundary
        and not exists(select 1 from public.match_workflows w where w.match_id=matches.id and w.phase<>'planning')
    ), '[]'::jsonb)
  );
$$;


create or replace function public.save_regular_allocation_unchecked(
  actor_user_id uuid,
  target_team_id uuid,
  target_season_id uuid,
  boundary timestamptz,
  expected_fingerprint text,
  allocations jsonb
)
returns integer
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  source jsonb;
  source_match jsonb;
  allocation jsonb;
  allocation_match_id uuid;
  expected_target integer;
  saved_count integer;
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then
    raise exception using errcode = '42501', message = 'SERVER_ONLY';
  end if;

  if not exists (
    select 1 from public.team_members
    where team_id = target_team_id
      and user_id = actor_user_id
      and is_active
  ) then
    raise exception using errcode = '42501', message = 'NOT_AUTHORIZED';
  end if;

  perform 1
  from public.seasons
  where id = target_season_id and team_id = target_team_id and is_active
  for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'ACTIVE_SEASON_NOT_FOUND';
  end if;

  perform 1
  from public.matches
  where team_id = target_team_id
    and season_id = target_season_id
    and status = 'upcoming'
    and starts_at >= boundary
  order by starts_at, id
  for update;

  perform 1
  from public.players
  where team_id = target_team_id and season_id = target_season_id and is_active
  order by rotation_order, id
  for update;

  source := private.regular_allocation_source(target_team_id, target_season_id, boundary);
  if md5(source::text) <> expected_fingerprint then
    raise exception using errcode = 'P0001', message = 'STALE_PREVIEW';
  end if;

  if jsonb_typeof(allocations) <> 'array'
    or jsonb_array_length(allocations) <> jsonb_array_length(source -> 'matches') then
    raise exception using errcode = 'P0001', message = 'INVALID_ALLOCATION';
  end if;

  if (
    select count(distinct item ->> 'matchId') <> count(*)
    from jsonb_array_elements(allocations) item
  ) then
    raise exception using errcode = 'P0001', message = 'INVALID_ALLOCATION';
  end if;

  for source_match in select value from jsonb_array_elements(source -> 'matches') loop
    allocation_match_id := (source_match ->> 'id')::uuid;
    expected_target := (source_match ->> 'targetSize')::integer;

    select item into allocation
    from jsonb_array_elements(allocations) item
    where item ->> 'matchId' = allocation_match_id::text;

    if allocation is null
      or jsonb_typeof(allocation -> 'playerIds') <> 'array'
      or jsonb_array_length(allocation -> 'playerIds') <> expected_target
      or (select count(distinct value) from jsonb_array_elements_text(allocation -> 'playerIds')) <> expected_target
      or exists (
        select 1
        from jsonb_array_elements_text(allocation -> 'playerIds') selected(player_id)
        where not exists (
          select 1 from public.players
          where players.id = selected.player_id::uuid
            and players.team_id = target_team_id
            and players.season_id = target_season_id
            and players.is_active
        )
      )
    then
      raise exception using errcode = 'P0001', message = 'INVALID_ALLOCATION';
    end if;
  end loop;

  delete from public.match_players
  using public.matches
  where match_players.match_id = matches.id
    and match_players.team_id = target_team_id
    and match_players.season_id = target_season_id
    and match_players.selection_type = 'regular'
    and match_players.selection_source = 'automatic'
    and matches.status = 'upcoming'
    and matches.starts_at >= boundary
    and not exists(select 1 from public.match_workflows w where w.match_id=matches.id and w.phase<>'planning');

  insert into public.match_players (
    team_id, season_id, match_id, player_id,
    selection_type, selection_source, selection_status, played
  )
  select
    target_team_id,
    target_season_id,
    (item ->> 'matchId')::uuid,
    player_id::uuid,
    'regular',
    'automatic',
    'selected',
    false
  from jsonb_array_elements(allocations) item
  cross join lateral jsonb_array_elements_text(item -> 'playerIds') selected(player_id)
  where not exists (
    select 1
    from public.match_players preserved
    where preserved.match_id = (item ->> 'matchId')::uuid
      and preserved.player_id = player_id::uuid
      and preserved.selection_type = 'regular'
      and preserved.selection_source = 'manual'
      and preserved.selection_status = 'selected'
  );

  get diagnostics saved_count = row_count;
  return saved_count;
end;
$$;

revoke all on function public.save_regular_allocation_unchecked(uuid, uuid, uuid, timestamptz, text, jsonb) from public;
grant execute on function public.save_regular_allocation_unchecked(uuid, uuid, uuid, timestamptz, text, jsonb) to service_role;

-- Shared source gate also protects stale direct saves.
alter function private.regular_allocation_source(uuid,uuid,timestamptz) rename to regular_allocation_source_reviewed;
create function private.regular_allocation_source(target_team_id uuid,target_season_id uuid,boundary timestamptz)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if exists(select 1 from public.match_workflows w join public.matches m on m.id=w.match_id where w.team_id=target_team_id and w.season_id=target_season_id and w.history_required and w.history_reviewed_at is null and m.status<>'cancelled') then raise exception using errcode='P0001',message='HISTORY_REVIEW_REQUIRED'; end if;
 if exists(select 1 from public.matches m where m.team_id=target_team_id and m.season_id=target_season_id and m.status='upcoming' and m.starts_at>=boundary and m.target_players>10 and not exists(select 1 from public.match_workflows w where w.match_id=m.id and w.phase<>'planning')) then raise exception using errcode='P0001',message='ROSTER_CAPACITY'; end if;
 return private.regular_allocation_source_reviewed(target_team_id,target_season_id,boundary);
end $$;
revoke all on function private.regular_allocation_source(uuid,uuid,timestamptz),private.regular_allocation_source_reviewed(uuid,uuid,timestamptz) from public;
-- The renamed unchecked implementation must remain inaccessible, including to service_role.
revoke all on function public.save_regular_allocation_unchecked(uuid,uuid,uuid,timestamptz,text,jsonb) from public,anon,authenticated,service_role;

-- One effective read model keeps legacy history intact while new locked attendance is authoritative.
create view private.effective_match_players as
select mp.match_id,mp.team_id,mp.season_id,mp.player_id,mp.selection_type,mp.selection_source,mp.selection_status,mp.played,mp.replaced_player_id
from public.match_players mp left join public.match_workflows w on w.match_id=mp.match_id
where coalesce(w.phase,'planning') in ('planning','legacy')
union all
select m.id,m.team_id,m.season_id,p.id,
 case when c.offered_regular then 'regular' else 'extra' end,
 'manual',case when (w.phase='locked' and part.player_id is not null) or (w.phase='week' and c.response in ('pending','accepted')) then 'selected' else 'removed' end,
 part.player_id is not null,null::uuid
from public.matches m join public.match_workflows w on w.match_id=m.id
join public.players p on p.team_id=m.team_id and p.season_id=m.season_id
left join public.match_calls c on c.match_id=m.id and c.player_id=p.id
left join public.match_participation part on part.match_id=m.id and part.player_id=p.id
where w.phase in ('week','locked') and (c.player_id is not null or part.player_id is not null);
revoke all on private.effective_match_players from public,anon,authenticated;

create or replace function public.get_match_roster(target_team_id uuid,target_season_id uuid,target_match_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb; member_role text;
begin
 select role into member_role from public.team_members where team_id=target_team_id and user_id=auth.uid() and is_active;
 if member_role is null then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 if not exists(select 1 from public.matches where id=target_match_id and team_id=target_team_id and season_id=target_season_id) then raise exception using errcode='P0001',message='MATCH_NOT_AVAILABLE'; end if;
 select coalesce(jsonb_agg(case when member_role='coach' then jsonb_build_object(
 'id',p.id,'name',concat_ws(' ',p.first_name,p.last_name),'level',p.level,'isActive',p.is_active,
 'selected',coalesce(mp.selection_status='selected',false),'selectionSource',mp.selection_source,'selectionStatus',mp.selection_status,
 'selectionType',mp.selection_type,'replacedPlayerId',mp.replaced_player_id,'played',coalesce(mp.played,false)
 ) else jsonb_build_object('id',p.id,'name',concat_ws(' ',p.first_name,p.last_name),'rosterGroup',case when mp.selection_status='selected' then case when mp.selection_type='extra' then 'extra' else 'team' end else 'resting' end) end order by p.rotation_order,p.id),'[]'::jsonb) into result
 from public.players p left join private.effective_match_players mp on mp.match_id=target_match_id and mp.player_id=p.id
 where p.team_id=target_team_id and p.season_id=target_season_id and (p.is_active or mp.player_id is not null);
 return result;
end $$;

create or replace function public.get_player_list(target_team_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if not private.is_active_team_coach(target_team_id) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 select jsonb_build_object('seasonName',s.name,'players',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'firstName',p.first_name,'lastName',p.last_name,'level',p.level)||private.player_match_totals(p.id) order by p.rotation_order) from public.players p where p.team_id=s.team_id and p.season_id=s.id and p.is_active),'[]'::jsonb)) into result from public.seasons s where s.team_id=target_team_id and s.is_active;
 if result is null then raise exception using errcode='P0001',message='ACTIVE_SEASON_NOT_AVAILABLE'; end if;
 return result;
end $$;

-- Retain the existing player-edit fingerprint; attendance is a separate transaction boundary.
create or replace function public.get_player_profile(target_team_id uuid,target_season_id uuid,target_player_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare source jsonb; history jsonb;
begin
 if not private.is_active_team_coach(target_team_id) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 if not exists(select 1 from public.seasons where id=target_season_id and team_id=target_team_id and is_active) then raise exception using errcode='P0001',message='PLAYER_NOT_AVAILABLE'; end if;
 source:=private.player_source(target_team_id,target_season_id,target_player_id);
 if source is null then raise exception using errcode='P0001',message='PLAYER_NOT_AVAILABLE'; end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',m.id,'opponent',m.opponent,'startsAt',m.starts_at,'location',m.location,'status',m.status,'selectionType',mp.selection_type,'selectionSource',mp.selection_source,'selectionStatus',mp.selection_status,'played',mp.played) order by m.starts_at,m.id),'[]'::jsonb) into history from private.effective_match_players mp join public.matches m on m.id=mp.match_id where mp.player_id=target_player_id and m.status<>'cancelled';
 return source||jsonb_build_object('matches',history,'totals',private.player_match_totals(target_player_id),'fingerprint',md5(source::text),'serverNow',now());
end $$;

create or replace function public.get_match_list(target_team_id uuid,target_season_id uuid,requested_filter text,requested_now timestamptz)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb; coach boolean;
begin
 if not private.is_active_team_member(target_team_id) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 if requested_filter not in ('upcoming','all') then raise exception using errcode='P0001',message='INVALID_MATCH_FILTER'; end if;
 coach:=private.is_active_team_coach(target_team_id);
 select coalesce(jsonb_agg(jsonb_build_object('id',m.id,'opponent',m.opponent,'startsAt',m.starts_at,'location',m.location,'targetPlayers',m.target_players,'status',m.status,
 'selectedPlayers',(select count(*) from private.effective_match_players mp where mp.match_id=m.id and mp.selection_status='selected'))
 || case when coach then jsonb_build_object('phase',coalesce(w.phase,'planning'),'acceptedPlayers',(select count(*) from public.match_calls c where c.match_id=m.id and response='accepted'),'pendingPlayers',(select count(*) from public.match_calls c where c.match_id=m.id and response='pending'),'historyRequired',coalesce(w.history_required and w.history_reviewed_at is null,false)) else '{}'::jsonb end
 order by case when requested_filter='upcoming' then m.starts_at end asc,case when requested_filter='all' then m.starts_at end desc,m.id),'[]'::jsonb) into result
 from public.matches m left join public.match_workflows w on w.match_id=m.id where m.team_id=target_team_id and m.season_id=target_season_id and (requested_filter='all' or m.status='upcoming');
 return result;
end $$;

-- Extend overview without exposing coach statistics to viewers.
alter function public.get_overview(uuid) rename to get_overview_before_workflow;
revoke all on function public.get_overview_before_workflow(uuid) from public,anon,authenticated,service_role;
create function public.get_overview(target_team_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 result:=public.get_overview_before_workflow(target_team_id);
 if private.is_active_team_coach(target_team_id) then
   result:=jsonb_set(result,'{players}',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'name',concat_ws(' ',p.first_name,p.last_name),'regularCount',((private.player_match_totals(p.id)->>'offeredRegular')::integer+(private.player_match_totals(p.id)->>'plannedRegular')::integer)) order by p.rotation_order) from public.players p join public.seasons s on s.id=p.season_id and s.is_active where p.team_id=target_team_id and p.is_active),'[]'::jsonb));
 end if;
 result:=jsonb_set(result,'{upcomingMatches}',coalesce((select jsonb_agg(item||jsonb_build_object('selectedPlayers',(select count(*) from private.effective_match_players mp where mp.match_id=(item->>'id')::uuid and mp.selection_status='selected'))) from jsonb_array_elements(result->'upcomingMatches') item),'[]'::jsonb));
 return result;
end $$;
revoke all on function public.get_overview(uuid) from public,anon;
grant execute on function public.get_overview(uuid) to authenticated;
