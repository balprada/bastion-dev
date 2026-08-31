-- ============================================================================
-- Bastion v2 — 01_schema.sql   (branch: demo2 · schema: bastion_v2)
-- Runs against the EXISTING bastion-demo project. v1 (public.*) untouched.
--
-- Design decisions:
--   1. org_id on every tenant-owned row → one flat RLS predicate everywhere.
--   2. Composite FKs (child_id, org_id) → parent (id, org_id): cross-org
--      references are structurally impossible, not filtered.
--   3. root_causes = GLOBAL catalog (no org_id): reference data, readable
--      across tenants by design — data classification, not an oversight.
--   4. Org is the only authorization boundary; the team-level policy is
--      written out at the bottom, documented but deliberately NOT applied.
--   5. v2 is status-free: remediation ownership is the client's workflow.
--
-- RULE: every statement is schema-qualified. Never run unqualified DDL here.
-- Idempotent: safe to re-run.
-- ============================================================================

create schema if not exists bastion_v2;

-- ----------------------------------------------------------------------------
-- Enums (schema-local — no collision with v1's public enums)
-- ----------------------------------------------------------------------------
do $$ begin
  create type bastion_v2.severity as enum ('low','medium','high','critical');
exception when duplicate_object then null; end $$;

do $$ begin
  create type bastion_v2.fix_method as enum
    ('version_upgrade','patch_install','configuration_change','code_change','credential_rotation');
exception when duplicate_object then null; end $$;

do $$ begin
  create type bastion_v2.fix_effort as enum ('low','medium','high');
exception when duplicate_object then null; end $$;

-- ----------------------------------------------------------------------------
-- Tenant structure
-- ----------------------------------------------------------------------------
create table if not exists bastion_v2.organizations (
  id          uuid primary key default gen_random_uuid(),
  slug        text not null unique,
  name        text not null,
  created_at  timestamptz not null default now()
);

create table if not exists bastion_v2.members (
  org_id    uuid not null references bastion_v2.organizations (id) on delete cascade,
  user_id   uuid not null references auth.users (id) on delete cascade,
  role      text not null default 'viewer',
  primary key (org_id, user_id)
);

create table if not exists bastion_v2.departments (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references bastion_v2.organizations (id) on delete cascade,
  slug        text not null,
  name        text not null,
  created_at  timestamptz not null default now(),
  unique (org_id, slug),
  unique (id, org_id)
);

create table if not exists bastion_v2.projects (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references bastion_v2.organizations (id) on delete cascade,
  department_id uuid not null,
  slug          text not null,
  name          text not null,
  created_at    timestamptz not null default now(),
  foreign key (department_id, org_id)
    references bastion_v2.departments (id, org_id) on delete cascade,
  unique (org_id, slug),
  unique (id, org_id)
);

create table if not exists bastion_v2.teams (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references bastion_v2.organizations (id) on delete cascade,
  project_id  uuid not null,
  slug        text not null,
  name        text not null,
  created_at  timestamptz not null default now(),
  foreign key (project_id, org_id)
    references bastion_v2.projects (id, org_id) on delete cascade,
  unique (org_id, slug),
  unique (id, org_id)
);

create table if not exists bastion_v2.team_members (
  team_id   uuid not null,
  org_id    uuid not null,
  user_id   uuid not null references auth.users (id) on delete cascade,
  role      text not null default 'viewer',
  primary key (team_id, user_id),
  foreign key (team_id, org_id)
    references bastion_v2.teams (id, org_id) on delete cascade
);

-- ----------------------------------------------------------------------------
-- Global root-cause catalog (NO org_id — shared reference data)
-- ----------------------------------------------------------------------------
create table if not exists bastion_v2.root_causes (
  id               uuid primary key default gen_random_uuid(),
  code             text not null unique,
  title            text not null,
  severity         bastion_v2.severity not null,
  first_discovered date not null,
  fix_available    boolean not null default true,
  fix_method       bastion_v2.fix_method,
  fix_effort       bastion_v2.fix_effort,
  workaround       text not null default ''
);

-- ----------------------------------------------------------------------------
-- Findings
-- ----------------------------------------------------------------------------
create table if not exists bastion_v2.findings (
  id                 uuid primary key default gen_random_uuid(),
  org_id             uuid not null references bastion_v2.organizations (id) on delete cascade,
  department_id      uuid not null,
  project_id         uuid not null,
  team_id            uuid not null,
  root_cause_id      uuid not null references bastion_v2.root_causes (id) on delete restrict,
  title              text not null,
  severity           bastion_v2.severity not null,
  cvss               numeric(3,1) not null check (cvss between 0 and 10),
  asset              text not null default '',
  affected_component text not null default '',
  description        text not null default '',
  detected_at        timestamptz not null default now(),
  created_at         timestamptz not null default now(),
  foreign key (department_id, org_id) references bastion_v2.departments (id, org_id) on delete cascade,
  foreign key (project_id,    org_id) references bastion_v2.projects    (id, org_id) on delete cascade,
  foreign key (team_id,       org_id) references bastion_v2.teams       (id, org_id) on delete cascade,
  unique (org_id, title)
);

-- ----------------------------------------------------------------------------
-- Indexes (names are schema-local — no collision with v1's)
-- ----------------------------------------------------------------------------
create index if not exists members_user_id_idx     on bastion_v2.members (user_id);
create index if not exists departments_org_idx     on bastion_v2.departments (org_id);
create index if not exists projects_org_idx        on bastion_v2.projects (org_id);
create index if not exists projects_dept_idx       on bastion_v2.projects (department_id);
create index if not exists teams_org_idx           on bastion_v2.teams (org_id);
create index if not exists teams_project_idx       on bastion_v2.teams (project_id);
create index if not exists team_members_user_idx   on bastion_v2.team_members (user_id);
create index if not exists findings_org_idx        on bastion_v2.findings (org_id);
create index if not exists findings_root_cause_idx on bastion_v2.findings (root_cause_id);
create index if not exists findings_org_cvss_idx   on bastion_v2.findings (org_id, cvss desc);

-- ----------------------------------------------------------------------------
-- Row-level security — enabled on every table; org-level on every tenant
-- table; the same flat (select auth.uid()) initplan pattern as v1.
-- ----------------------------------------------------------------------------
alter table bastion_v2.organizations enable row level security;
alter table bastion_v2.members      enable row level security;
alter table bastion_v2.departments  enable row level security;
alter table bastion_v2.projects     enable row level security;
alter table bastion_v2.teams        enable row level security;
alter table bastion_v2.team_members enable row level security;
alter table bastion_v2.root_causes  enable row level security;
alter table bastion_v2.findings     enable row level security;

drop policy if exists orgs_select_own on bastion_v2.organizations;
create policy orgs_select_own on bastion_v2.organizations
  for select to authenticated
  using ( id in (select m.org_id from bastion_v2.members m
                 where m.user_id = (select auth.uid())) );
comment on policy orgs_select_own on bastion_v2.organizations is
  'SELECT: members can read only organizations they belong to.';

drop policy if exists members_select_own on bastion_v2.members;
create policy members_select_own on bastion_v2.members
  for select to authenticated
  using ( user_id = (select auth.uid()) );
comment on policy members_select_own on bastion_v2.members is
  'SELECT: a user can read only their own membership rows.';

drop policy if exists departments_select_own on bastion_v2.departments;
create policy departments_select_own on bastion_v2.departments
  for select to authenticated
  using ( org_id in (select m.org_id from bastion_v2.members m
                     where m.user_id = (select auth.uid())) );
comment on policy departments_select_own on bastion_v2.departments is
  'SELECT: org-level isolation — only departments of the caller''s organizations.';

drop policy if exists projects_select_own on bastion_v2.projects;
create policy projects_select_own on bastion_v2.projects
  for select to authenticated
  using ( org_id in (select m.org_id from bastion_v2.members m
                     where m.user_id = (select auth.uid())) );
comment on policy projects_select_own on bastion_v2.projects is
  'SELECT: org-level isolation — only projects of the caller''s organizations.';

drop policy if exists teams_select_own on bastion_v2.teams;
create policy teams_select_own on bastion_v2.teams
  for select to authenticated
  using ( org_id in (select m.org_id from bastion_v2.members m
                     where m.user_id = (select auth.uid())) );
comment on policy teams_select_own on bastion_v2.teams is
  'SELECT: org-level isolation — only teams of the caller''s organizations.';

drop policy if exists team_members_select_own on bastion_v2.team_members;
create policy team_members_select_own on bastion_v2.team_members
  for select to authenticated
  using ( org_id in (select m.org_id from bastion_v2.members m
                     where m.user_id = (select auth.uid())) );
comment on policy team_members_select_own on bastion_v2.team_members is
  'SELECT: org-level isolation — membership rows of the caller''s organizations only.';

-- Intentionally permissive: global catalog, zero tenant data. Classification.
drop policy if exists root_causes_select_all on bastion_v2.root_causes;
create policy root_causes_select_all on bastion_v2.root_causes
  for select to authenticated
  using ( true );
comment on policy root_causes_select_all on bastion_v2.root_causes is
  'SELECT: global catalog — readable by all authenticated users across tenants by design (contains no tenant data).';

drop policy if exists findings_select_own_org on bastion_v2.findings;
create policy findings_select_own_org on bastion_v2.findings
  for select to authenticated
  using ( org_id in (select m.org_id from bastion_v2.members m
                     where m.user_id = (select auth.uid())) );
comment on policy findings_select_own_org on bastion_v2.findings is
  'SELECT: the tenant isolation boundary — findings of the caller''s organizations only.';

-- ----------------------------------------------------------------------------
-- DOCUMENTED, NOT APPLIED — the team-level boundary. One statement away;
-- requires the org-admin override so security teams keep org-wide visibility:
--
--   create policy findings_select_team_scoped on bastion_v2.findings
--     for select to authenticated
--     using (
--       org_id in (select m.org_id from bastion_v2.members m
--                  where m.user_id = (select auth.uid()) and m.role = 'admin')
--       or team_id in (select tm.team_id from bastion_v2.team_members tm
--                      where tm.user_id = (select auth.uid()))
--     );
--
-- Enabling it is a business decision (it changes what the client's own
-- security team can see) — which is why it ships documented, not enabled.
-- ----------------------------------------------------------------------------

-- ----------------------------------------------------------------------------
-- Grants. USAGE on the schema is REQUIRED for PostgREST — table grants alone
-- are not enough for a non-public schema. anon may query; no policy matches
-- anon, so it reads zero rows (anon key public by design, safe by policy).
-- ----------------------------------------------------------------------------
grant usage on schema bastion_v2 to anon, authenticated;
grant select on all tables in schema bastion_v2 to anon, authenticated;
