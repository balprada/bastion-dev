-- ============================================================================
-- Bastion — 01_schema.sql
-- Tables, indexes, row-level security policies, grants, organizations.
--
-- Run order:  01_schema.sql  →  create the two demo users in Studio  →  02_seed.sql
-- Idempotent: safe to re-run at any time.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Enums
-- ----------------------------------------------------------------------------
do $$ begin
  create type public.severity as enum ('low', 'medium', 'high', 'critical');
exception
  when duplicate_object then null;  -- already exists on a re-run
end $$;

do $$ begin
  create type public.finding_status as enum ('open', 'in_progress', 'resolved');
exception
  when duplicate_object then null;
end $$;

-- ----------------------------------------------------------------------------
-- Tables
-- ----------------------------------------------------------------------------
create table if not exists public.organizations (
  id          uuid primary key default gen_random_uuid(),
  slug        text not null unique,
  name        text not null,
  created_at  timestamptz not null default now()
);

-- Membership join table: which authenticated user belongs to which org.
-- Every tenant-isolation policy in this schema resolves through this table.
create table if not exists public.members (
  org_id    uuid not null references public.organizations (id) on delete cascade,
  user_id   uuid not null references auth.users (id) on delete cascade,
  role      text not null default 'viewer',   -- org-level role (viewer | admin); display only
  primary key (org_id, user_id)
);

create table if not exists public.findings (
  id           uuid primary key default gen_random_uuid(),
  org_id       uuid not null references public.organizations (id) on delete cascade,
  title        text not null,
  severity     public.severity not null,
  status       public.finding_status not null default 'open',
  cvss         numeric(3,1) not null check (cvss between 0 and 10),
  description  text not null default '',
  asset        text not null default '',      -- where the finding lives (host / repo / bucket)
  detected_at  timestamptz not null default now(),
  created_at   timestamptz not null default now(),
  unique (org_id, title)                      -- natural key → makes the seed re-runnable
);

-- ----------------------------------------------------------------------------
-- Indexes (match real query paths: resolve membership by user, fetch by org,
-- sort by cvss inside an org)
-- ----------------------------------------------------------------------------
create index if not exists members_user_id_idx   on public.members (user_id);
create index if not exists findings_org_id_idx   on public.findings (org_id);
create index if not exists findings_org_cvss_idx on public.findings (org_id, cvss desc);

-- ----------------------------------------------------------------------------
-- Row-level security
-- ----------------------------------------------------------------------------
alter table public.organizations enable row level security;
alter table public.members      enable row level security;
alter table public.findings     enable row level security;

-- POLICY PATTERN — read before touching anything below.
--
-- Every policy wraps auth.uid() in a scalar subquery:   (select auth.uid())
--
-- Bare auth.uid() is planned as a per-row expression: Postgres calls the
-- function once for every row scanned. Wrapped in (select ...), the planner
-- hoists it into an InitPlan that is evaluated exactly once per statement.
-- On a large findings table that is the difference between a sequential scan
-- with N function calls and a plain index scan. Same semantics, very
-- different cost.
--
-- The  org_id in (select ...)  form lets Postgres run the membership subquery
-- once and hash it, instead of a correlated EXISTS re-checked per row.
--
-- Cross-table note: policy subqueries are themselves subject to the
-- referenced table's RLS. The members policies below reference only
-- auth.uid(), never members itself — so there is no policy recursion
-- anywhere in this schema.

-- organizations: members can see only the orgs they belong to.
drop policy if exists orgs_select_own on public.organizations;
create policy orgs_select_own
  on public.organizations
  for select
  to authenticated
  using (
    id in (
      select m.org_id
      from public.members m
      where m.user_id = (select auth.uid())
    )
  );
comment on policy orgs_select_own on public.organizations is
  'SELECT: members can read only the organizations they belong to.';

-- members: users can see only their own membership rows.
drop policy if exists members_select_own on public.members;
create policy members_select_own
  on public.members
  for select
  to authenticated
  using ( user_id = (select auth.uid()) );
comment on policy members_select_own on public.members is
  'SELECT: a user can read only their own membership rows.';

-- findings: the core tenant-isolation policy. Each statement resolves the
-- caller's org memberships once, then returns only matching rows.
drop policy if exists findings_select_own_org on public.findings;
create policy findings_select_own_org
  on public.findings
  for select
  to authenticated
  using (
    org_id in (
      select m.org_id
      from public.members m
      where m.user_id = (select auth.uid())
    )
  );
comment on policy findings_select_own_org on public.findings is
  'SELECT: users can read only findings belonging to an org they are a member of. Tenant isolation boundary.';

-- This app is read-only: no INSERT/UPDATE/DELETE policies exist because the
-- dashboard never writes. Write policies would follow the identical
-- (select auth.uid()) pattern with USING / WITH CHECK.

-- ----------------------------------------------------------------------------
-- Grants (explicit, even though Supabase defaults cover them)
-- ----------------------------------------------------------------------------
grant select on public.organizations to authenticated;
grant select on public.members      to authenticated;
grant select on public.findings     to authenticated;

-- ----------------------------------------------------------------------------
-- Organizations (seed)
-- ----------------------------------------------------------------------------
insert into public.organizations (slug, name) values
  ('apex',     'Apex Financial'),
  ('meridian', 'Meridian Health')
on conflict (slug) do nothing;
