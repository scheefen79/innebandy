begin;
create extension if not exists pgtap with schema extensions;
select plan(23);

insert into auth.users(id,email) values
 ('d1000000-0000-4000-8000-000000000001','member-coach-1@example.test'),
 ('d1000000-0000-4000-8000-000000000002','member-coach-2@example.test'),
 ('d1000000-0000-4000-8000-000000000003','member-viewer@example.test'),
 ('d1000000-0000-4000-8000-000000000004','member-inactive@example.test'),
 ('d1000000-0000-4000-8000-000000000005','member-new@example.test'),
 ('d1000000-0000-4000-8000-000000000006','member-outsider-coach@example.test');
insert into public.teams(id,name,slug) values
 ('d2000000-0000-4000-8000-000000000001','Member team','member-team'),
 ('d2000000-0000-4000-8000-000000000002','Other team','other-team');
insert into public.team_members(team_id,user_id,role,is_active) values
 ('d2000000-0000-4000-8000-000000000001','d1000000-0000-4000-8000-000000000001','coach',true),
 ('d2000000-0000-4000-8000-000000000001','d1000000-0000-4000-8000-000000000002','coach',true),
 ('d2000000-0000-4000-8000-000000000001','d1000000-0000-4000-8000-000000000003','viewer',true),
 ('d2000000-0000-4000-8000-000000000001','d1000000-0000-4000-8000-000000000004','viewer',false),
 ('d2000000-0000-4000-8000-000000000002','d1000000-0000-4000-8000-000000000006','coach',true);

set local role authenticated;
set local request.jwt.claim.sub='d1000000-0000-4000-8000-000000000001';

select is(jsonb_array_length(public.get_team_member_list('d2000000-0000-4000-8000-000000000001')),4,'coach sees all four memberships for the team');
select is((select member->>'email' from jsonb_array_elements(public.get_team_member_list('d2000000-0000-4000-8000-000000000001')) member where member->>'userId'='d1000000-0000-4000-8000-000000000003'),'member-viewer@example.test','coach sees a member email in the list');
select throws_ok($$select public.get_team_member_list('d2000000-0000-4000-8000-000000000002')$$,'42501','NOT_AUTHORIZED','coach cannot list another team''s members');

set local request.jwt.claim.sub='d1000000-0000-4000-8000-000000000003';
select throws_ok($$select public.get_team_member_list('d2000000-0000-4000-8000-000000000001')$$,'42501','NOT_AUTHORIZED','viewer cannot list team members');

set local request.jwt.claim.sub='d1000000-0000-4000-8000-000000000006';
select throws_ok($$select public.get_team_member_list('d2000000-0000-4000-8000-000000000001')$$,'42501','NOT_AUTHORIZED','another team''s coach cannot list this team''s members');

set local request.jwt.claim.sub='d1000000-0000-4000-8000-000000000004';
select throws_ok($$select public.get_team_member_list('d2000000-0000-4000-8000-000000000001')$$,'42501','NOT_AUTHORIZED','an inactive member cannot list team members');

reset role;
set local role anon;
select throws_ok($$select public.get_team_member_list('d2000000-0000-4000-8000-000000000001')$$,'42501','permission denied for function get_team_member_list','anonymous users cannot list team members');

reset role;
set local role service_role;
set local request.jwt.claims='{"role":"service_role"}';

select throws_ok(
  $$select public.upsert_team_member('d1000000-0000-4000-8000-000000000003','d2000000-0000-4000-8000-000000000001','d1000000-0000-4000-8000-000000000005','viewer')$$,
  '42501','NOT_AUTHORIZED','server mutation rejects a forwarded viewer identity for invite'
);
select throws_ok(
  $$select public.upsert_team_member('d1000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001','d1000000-0000-4000-8000-000000000005','owner')$$,
  'P0001','INVALID_ROLE','an unknown role is rejected on invite'
);
select ok(public.upsert_team_member('d1000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001','d1000000-0000-4000-8000-000000000005','viewer'),'coach can add a new member via the server mutation');
select throws_ok(
  $$select public.upsert_team_member('d1000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001','d1000000-0000-4000-8000-000000000005','coach')$$,
  'P0001','ALREADY_MEMBER','inviting an email that is already a member is rejected'
);

select throws_ok(
  $$select public.update_team_member_role('d1000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001','d1000000-0000-4000-8000-000000000003','coach','stale-fingerprint')$$,
  'P0001','STALE_MEMBER','a stale fingerprint is rejected on role change'
);
select ok(
  public.update_team_member_role('d1000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001','d1000000-0000-4000-8000-000000000003','coach',md5('viewer'||true::text)),
  'coach can promote a viewer to coach'
);
select is((select role from public.team_members where team_id='d2000000-0000-4000-8000-000000000001' and user_id='d1000000-0000-4000-8000-000000000003'),'coach','the promotion persisted');

select throws_ok(
  $$select public.update_team_member_role('d1000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001','d1000000-0000-4000-8000-000000000001','owner','irrelevant')$$,
  'P0001','INVALID_ROLE','an unknown role is rejected on role change'
);

-- three active coaches now: 1, 2, and the promoted 3. Demoting two of them should still be safe.
select ok(
  public.update_team_member_role('d1000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001','d1000000-0000-4000-8000-000000000003','viewer',md5('coach'||true::text)),
  'coach can demote a coach back to viewer while another coach remains'
);
select ok(
  public.deactivate_team_member('d1000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001','d1000000-0000-4000-8000-000000000002',md5('coach'||true::text)),
  'coach can deactivate another active coach while one remains'
);
select throws_ok(
  $$select public.update_team_member_role('d1000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001','d1000000-0000-4000-8000-000000000001','viewer',md5('coach'||true::text))$$,
  'P0001','LAST_ACTIVE_COACH','the last active coach cannot be demoted'
);
select throws_ok(
  $$select public.deactivate_team_member('d1000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001','d1000000-0000-4000-8000-000000000001',md5('coach'||true::text))$$,
  'P0001','LAST_ACTIVE_COACH','the last active coach cannot be deactivated'
);
select is((select role from public.team_members where team_id='d2000000-0000-4000-8000-000000000001' and user_id='d1000000-0000-4000-8000-000000000001'),'coach','the sole remaining coach is untouched after the rejected attempts');

select ok(
  public.reactivate_team_member('d1000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001','d1000000-0000-4000-8000-000000000004',md5('viewer'||false::text)),
  'coach can reactivate a previously deactivated member'
);
select is((select is_active from public.team_members where team_id='d2000000-0000-4000-8000-000000000001' and user_id='d1000000-0000-4000-8000-000000000004'),true,'the reactivation persisted');

select throws_ok(
  $$select public.deactivate_team_member('d1000000-0000-4000-8000-000000000006','d2000000-0000-4000-8000-000000000001','d1000000-0000-4000-8000-000000000004',md5('viewer'||true::text))$$,
  '42501','NOT_AUTHORIZED','another team''s coach cannot deactivate this team''s members'
);

select * from finish();
rollback;
