-- En tränare ska kunna spara en träningsplan för hela blockets veckodagsserie i stället för ett pass i taget.
-- Beslutet är dokumenterat i docs/architecture/decisions/ADR-020-training-series-updates.md och är den
-- uttryckliga globala malländring med egen konfliktmodell som ADR-013 förutsåg.
--
-- Serien är veckodagsscopad: en måndag sprids till blockets övriga kommande måndagar, en lördag till
-- lördagarna. Måndagar (75 min) och lördagar (60 min) har olika upplägg och blandas aldrig.

create function public.save_training_plan_series_unchecked(
 actor_user_id uuid,target_team_id uuid,target_season_id uuid,target_training_id uuid,
 expected_revision integer,request_id text,requested_focus text,requested_key_message text,requested_notes text,
 requested_status public.training_session_status,requested_items jsonb
) returns integer language plpgsql volatile security definer set search_path=''
as $$
declare current_session public.training_sessions%rowtype; series_hash text; sibling public.training_sessions%rowtype; updated_count integer:=0; next_revision integer;
begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception using errcode='42501',message='SERVER_ONLY'; end if;
 select * into current_session from public.training_sessions where id=target_training_id and team_id=target_team_id and season_id=target_season_id;
 if not found then raise exception using errcode='P0001',message='TRAINING_NOT_AVAILABLE'; end if;

 -- Lås hela blocket i en deterministisk ordning innan någon skrivning. Två tränare som sparar var sin
 -- serie i samma block skulle annars ta raderna i olika ordning och kunna låsa varandra, jfr
 -- 20260903140000_team_membership_lock_ordering.sql. Förlåset täcker även det redigerade passet.
 perform 1 from public.training_sessions
  where team_id=target_team_id and season_id=target_season_id and theme_block=current_session.theme_block
  order by id for update;

 -- Läs om efter låset. Den första läsningen är olåst och kan vara inaktuell; theme_block är däremot
 -- oföränderligt efter bootstrap, så det duger för att avgöra vilka rader som ska låsas.
 select * into current_session from public.training_sessions where id=target_training_id;

 -- Ett inställt pass får aldrig spridas till serien. save_training_plan_unchecked saknar den kontrollen,
 -- så den görs här innan något skrivs.
 if current_session.status='cancelled' then raise exception using errcode='P0001',message='TRAINING_CANCELLED'; end if;

 -- Det redigerade passet sparas genom det etablerade enskilda kontraktet: fältvalidering, revisionskontroll,
 -- statusövergångar, TRAINING_COMPLETED och idempotens. Allt det körs alltså före varje syskonskrivning.
 next_revision:=public.save_training_plan_unchecked(actor_user_id,target_team_id,target_season_id,target_training_id,expected_revision,request_id,requested_focus,requested_key_message,requested_notes,requested_status,requested_items);

 -- Repris av en redan committad serie. save_training_plan_unchecked returnerar oförändrad revision när
 -- request_id och payload matchar, och gör det utan revisionskontroll. Hela serien skrevs i samma
 -- transaktion, så ingenting återstår att göra. Utan den här genvägen skulle syskonloopen skriva om ett
 -- syskon som en kollega hunnit redigera enskilt sedan serien sparades.
 if next_revision=current_session.revision then return 0; end if;

 -- requested_status ingår medvetet inte: status propageras inte till syskonen.
 series_hash:=md5(jsonb_build_array('series',target_training_id,expected_revision,requested_focus,requested_key_message,requested_notes,requested_items)::text);

 for sibling in
  select * from public.training_sessions
  where team_id=target_team_id and season_id=target_season_id and theme_block=current_session.theme_block
    and id<>current_session.id and status in ('draft','planned')
    -- isodow och datum läses i Stockholm-tid, annars skulle sommar- och vintertid hamna på olika veckodagar.
    and extract(isodow from (starts_at at time zone 'Europe/Stockholm'))=extract(isodow from (current_session.starts_at at time zone 'Europe/Stockholm'))
    and (starts_at at time zone 'Europe/Stockholm')::date>=(now() at time zone 'Europe/Stockholm')::date
  order by starts_at,id
 loop
  -- Ingen omvalidering här: save_training_plan_unchecked har redan avvisat ogiltiga requested_items i samma
  -- transaktion. Kolumnlistan speglar den funktionens insert exakt så att de hålls i synk.
  delete from public.training_items where training_session_id=sibling.id;
  insert into public.training_items(training_session_id,team_id,season_id,section,position,title,guide_minutes,purpose,instructions,coaching_points,source_title,source_url,source_image_url)
  select sibling.id,target_team_id,target_season_id,(item->>'section')::public.training_item_section,item_position::integer,item->>'title',nullif(item->>'guideMinutes','')::integer,nullif(trim(item->>'purpose'),''),nullif(trim(item->>'instructions'),''),coalesce(item->'coachingPoints','[]'::jsonb),nullif(trim(item->>'sourceTitle'),''),nullif(trim(item->>'sourceUrl'),''),nullif(trim(item->>'sourceImageUrl'),'')
  from jsonb_array_elements(requested_items) with ordinality as source(item,item_position);
  -- starts_at, ends_at, status och theme_block rörs aldrig. Varje träning behåller sin egen tid och status,
  -- och unique(team_id,starts_at) kan därför inte brytas av en serieparning.
  update public.training_sessions
   set focus=trim(requested_focus),key_message=trim(requested_key_message),coach_notes=nullif(trim(requested_notes),''),
       revision=sibling.revision+1,updated_by=actor_user_id,last_save_request_id=request_id,last_save_payload_hash=series_hash
   where id=sibling.id;
  updated_count:=updated_count+1;
 end loop;
 return updated_count;
end $$;

create function public.save_training_plan_series(
 actor_user_id uuid,target_team_id uuid,target_season_id uuid,target_training_id uuid,
 expected_revision integer,request_id text,requested_focus text,requested_key_message text,requested_notes text,
 requested_status public.training_session_status,requested_items jsonb
) returns integer language plpgsql volatile security definer set search_path=''
as $$ begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception using errcode='42501',message='SERVER_ONLY'; end if;
 if not private.is_active_team_coach(actor_user_id,target_team_id) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 return public.save_training_plan_series_unchecked(actor_user_id,target_team_id,target_season_id,target_training_id,expected_revision,request_id,requested_focus,requested_key_message,requested_notes,requested_status,requested_items);
end $$;

revoke all on function public.save_training_plan_series_unchecked(uuid,uuid,uuid,uuid,integer,text,text,text,text,public.training_session_status,jsonb) from public,anon,authenticated,service_role;
revoke all on function public.save_training_plan_series(uuid,uuid,uuid,uuid,integer,text,text,text,text,public.training_session_status,jsonb) from public,anon,authenticated;
grant execute on function public.save_training_plan_series(uuid,uuid,uuid,uuid,integer,text,text,text,text,public.training_session_status,jsonb) to service_role;
