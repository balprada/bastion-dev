-- ============================================================================
-- Bastion — 03_verify_rls.sql (v2.1)
-- Prove tenant isolation from the SQL editor, before the app exists.
--
-- v2.1: adds a current_role check (0a). If you ever see
--       "permission denied for table users" again, look there first — it
--       means a statement ran with the wrong role, NOT that a grant is
--       missing. Postgres's HINT will suggest granting to `authenticated`;
--       the hint is generated from the failing ACL check and knows nothing
--       about the query's purpose. Never follow it here.
--
-- Standing invariants — do not break these when editing:
--   1. Every `select ... from auth.users` in this file executes BEFORE its
--      section's set_config('role', 'authenticated' / 'anon', true).
--   2. Never grant SELECT on auth.users to authenticated. It would let any
--      logged-in user of any tenant read every other tenant's users.
--
-- Run the ENTIRE file at once, in one fresh query tab. If you must run it in
-- pieces, always keep each section's begin…rollback pair in the same
-- selection — the claims lookup must never execute after its role drop.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0a) Environment: must return `postgres`
-- ----------------------------------------------------------------------------
select current_user as must_be_postgres;
-- If anything else comes back: run `reset role;` on its own, then start over.

-- ----------------------------------------------------------------------------
-- 0b) Preconditions (as postgres): demo users exist, memberships seeded
-- ----------------------------------------------------------------------------
do $$ declare
  v_ada     uuid;
  v_sam     uuid;
  v_members int;
begin
  select id into v_ada from auth.users where email = 'ada@apex.test';
  select id into v_sam from auth.users where email = 'sam@meridian.test';

  if v_ada is null or v_sam is null then
    raise exception 'Demo users missing from auth.users (ada: %, sam: %). Create both first: Authentication → Users → Add user → Create new user. Then re-run 02_seed.sql, then this script.',
      coalesce(v_ada::text, 'not found'), coalesce(v_sam::text, 'not found');
  end if;

  select count(*) into v_members from public.members;
  if v_members <> 2 then
    raise exception 'public.members has % row(s), expected 2 — 02_seed.sql probably ran before the users existed. Re-run it now (idempotent), then re-run this script.', v_members;
  end if;
end $$;

-- ----------------------------------------------------------------------------
-- 1) As ada@apex.test (Apex Financial) → expect 15 rows, every org = apex
--    Order matters: build the claims as postgres FIRST, drop the role AFTER.
-- ----------------------------------------------------------------------------
begin;

select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub',  (select id from auth.users where email = 'ada@apex.test'),  -- reads auth.users as postgres; role not dropped yet
    'role', 'authenticated',
    'aud',  'authenticated',
    'exp',  extract(epoch from now()) + 60
  )::text,
  true
);

select set_config('role', 'authenticated', true);  -- privileges drop AFTER the lookup

select o.slug as org, f.severity, f.status, f.cvss, f.title
from public.findings f
join public.organizations o on o.id = f.org_id
order by f.cvss desc;

rollback;  -- role and claims revert to postgres for the next section

-- ----------------------------------------------------------------------------
-- 2) As sam@meridian.test (Meridian Health) → expect 13 rows, all meridian
-- ----------------------------------------------------------------------------
begin;

select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub',  (select id from auth.users where email = 'sam@meridian.test'),
    'role', 'authenticated',
    'aud',  'authenticated',
    'exp',  extract(epoch from now()) + 60
  )::text,
  true
);

select set_config('role', 'authenticated', true);

select o.slug as org, f.severity, f.status, f.cvss, f.title
from public.findings f
join public.organizations o on o.id = f.org_id
order by f.cvss desc;

rollback;

-- ----------------------------------------------------------------------------
-- 3) As anonymous (no JWT) → expect 0. anon holds table-level SELECT (see
--    01_schema.sql), but RLS is enabled and no policy applies to anon —
--    it can issue queries and always sees zero rows. The anon key is public
--    by design; this is why that's safe.
-- ----------------------------------------------------------------------------
begin;

select set_config('role', 'anon', true);

select count(*) as anon_findings from public.findings;

rollback;
