-- ============================================================================
-- Bastion v2 — 03_verify_rls.sql   (demo2 · schema: bastion_v2)
-- Invariants: auth.users lookups BEFORE role drops; never grant auth.users
-- to authenticated. Run the ENTIRE file at once, one fresh tab.
-- ============================================================================

select current_user as must_be_postgres;

do $$ declare v_members int;
begin
  select count(*) into v_members from bastion_v2.members;
  if v_members <> 2 then
    raise exception 'bastion_v2.members has % rows, expected 2 — re-run 02_seed.sql.', v_members;
  end if;
end $$;

-- 1) ada → expect 15 / 4 / 11 / 12 / 22 / 1
begin;
select set_config('request.jwt.claims',
  json_build_object('sub', (select id from auth.users where email = 'ada@apex.test'),
    'role','authenticated','aud','authenticated',
    'exp', extract(epoch from now()) + 60)::text, true);
select set_config('role','authenticated', true);

select
  (select count(*) from bastion_v2.findings)     as findings,
  (select count(*) from bastion_v2.departments)  as departments,
  (select count(*) from bastion_v2.projects)     as projects,
  (select count(*) from bastion_v2.teams)        as teams,
  (select count(*) from bastion_v2.root_causes)  as root_causes,
  (select count(distinct org_id) from bastion_v2.findings) as orgs_in_findings;

rollback;

-- 2) sam → expect 13 / 3 / 8 / 8 / 22 / 1
begin;
select set_config('request.jwt.claims',
  json_build_object('sub', (select id from auth.users where email = 'sam@meridian.test'),
    'role','authenticated','aud','authenticated',
    'exp', extract(epoch from now()) + 60)::text, true);
select set_config('role','authenticated', true);

select
  (select count(*) from bastion_v2.findings)     as findings,
  (select count(*) from bastion_v2.departments)  as departments,
  (select count(*) from bastion_v2.projects)     as projects,
  (select count(*) from bastion_v2.teams)        as teams,
  (select count(*) from bastion_v2.root_causes)  as root_causes,
  (select count(distinct org_id) from bastion_v2.findings) as orgs_in_findings;

rollback;

-- 3) anon → expect 0 / 0
begin;
select set_config('role','anon', true);
select
  (select count(*) from bastion_v2.findings)    as anon_findings,
  (select count(*) from bastion_v2.root_causes) as anon_root_causes;
rollback;

-- 4) Team boundary honesty: expect 2 / 3 / 15
begin;
select set_config('request.jwt.claims',
  json_build_object('sub', (select id from auth.users where email = 'ada@apex.test'),
    'role','authenticated','aud','authenticated',
    'exp', extract(epoch from now()) + 60)::text, true);
select set_config('role','authenticated', true);

select
  (select count(*) from bastion_v2.team_members)  as my_teams,
  (select count(*) from bastion_v2.findings f
     join bastion_v2.team_members tm on tm.team_id = f.team_id) as findings_in_my_teams,
  (select count(*) from bastion_v2.findings) as findings_visible;

rollback;
