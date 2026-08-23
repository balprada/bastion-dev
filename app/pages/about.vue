<script setup lang="ts">
useHead({ title: 'About this build — Bastion' })

// ---- schema cards -----------------------------------------------------------

interface ColumnDef {
  name: string
  type: string
  key?: 'PK' | 'FK' | 'PK · FK' | 'unique'
}
interface TableDef {
  name: string
  tag: string
  columns: ColumnDef[]
  note: string
}

const tables: TableDef[] = [
  {
    name: 'organizations',
    tag: 'tenant root',
    columns: [
      { name: 'id', type: 'uuid', key: 'PK' },
      { name: 'slug', type: 'text', key: 'unique' },
      { name: 'name', type: 'text' },
      { name: 'created_at', type: 'timestamptz' }
    ],
    note: 'slug is the natural key the seed resolves orgs by'
  },
  {
    name: 'members',
    tag: 'membership join',
    columns: [
      { name: 'org_id', type: 'uuid', key: 'PK · FK' },
      { name: 'user_id', type: 'uuid', key: 'PK · FK' },
      { name: 'role', type: 'text' }
    ],
    note: 'pk (org_id, user_id) · role: viewer | admin'
  },
  {
    name: 'findings',
    tag: 'tenant data',
    columns: [
      { name: 'id', type: 'uuid', key: 'PK' },
      { name: 'org_id', type: 'uuid', key: 'FK' },
      { name: 'title', type: 'text' },
      { name: 'severity', type: 'severity' },
      { name: 'status', type: 'finding_status' },
      { name: 'cvss', type: 'numeric(3,1)' },
      { name: 'description', type: 'text' },
      { name: 'asset', type: 'text' },
      { name: 'detected_at', type: 'timestamptz' },
      { name: 'created_at', type: 'timestamptz' }
    ],
    note: 'check (cvss 0–10) · unique (org_id, title)'
  }
]

const stack = [
  'nuxt 4 · static SPA',
  'typescript',
  'supabase · postgres + auth',
  'postgres row-level security',
  'cloudflare pages',
  'ibm plex sans / mono'
]

// ---- SQL artifacts -----------------------------------------------------------

// Verbatim from supabase/01_schema.sql — only the idempotent
// `drop policy if exists` re-run guards are omitted for readability.
const policySql = `-- Enable RLS. Without this line, policies are ignored entirely.
alter table public.organizations enable row level security;
alter table public.members      enable row level security;
alter table public.findings     enable row level security;

-- organizations: members can see only the orgs they belong to.
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
create policy members_select_own
  on public.members
  for select
  to authenticated
  using ( user_id = (select auth.uid()) );
comment on policy members_select_own on public.members is
  'SELECT: a user can read only their own membership rows.';

-- findings: the core tenant-isolation policy. Each statement resolves the
-- caller's org memberships once, then returns only matching rows.
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

-- This app is read-only: no INSERT/UPDATE/DELETE policies exist. Write
-- policies would follow the identical (select auth.uid()) pattern with
-- USING / WITH CHECK.`

const naiveSql = `using (
  org_id in (
    select m.org_id
    from public.members m
    where m.user_id = auth.uid()
  )
)`

const shippedSql = `using (
  org_id in (
    select m.org_id
    from public.members m
    where m.user_id = (select auth.uid())
  )
)`
</script>

<template>
  <div class="about">
    <!-- ---- intro ---- -->
    <header class="intro">
      <p class="mark mono">// about this build</p>
      <h1>A multi-tenant findings console, isolated at the database</h1>
      <p class="lede">
        Bastion is a miniature tenant-facing security console: two organizations,
        two users, 28 synthetic findings — and one rule that decides who sees
        what. The client never filters by tenant; it can't. Every request
        carries the user's JWT, Postgres resolves membership through the
        <code>members</code> table, and only that organization's rows ever
        leave the database. Switch demo accounts on the sign-in screen and
        watch the dataset change — that's row-level security, not UI logic.
      </p>
      <ul class="stack mono">
        <li v-for="item in stack" :key="item">{{ item }}</li>
      </ul>
    </header>

    <!-- ---- 01 schema ---- -->
    <section class="sec">
      <header class="sec-head">
        <span class="sec-num mono">01</span>
        <h2>Schema</h2>
      </header>
      <p class="sec-intro">
        Three tables, one join, every query path indexed.
        <code>findings</code> is the tenant data;
        <code>members</code> is the table every isolation policy resolves
        through.
      </p>

      <div class="tables">
        <article v-for="t in tables" :key="t.name" class="tcard panel">
          <header class="tcard-head">
            <span class="tname mono">{{ t.name }}</span>
            <span class="ttag mono">{{ t.tag }}</span>
          </header>
          <ul class="cols">
            <li v-for="col in t.columns" :key="col.name" class="col">
              <span class="cname mono">{{ col.name }}</span>
              <span class="ctype mono">{{ col.type }}</span>
              <span v-if="col.key" class="ckey mono" :class="{ pk: col.key.includes('PK') }">
                {{ col.key }}
              </span>
              <span v-else class="ckey-spacer" aria-hidden="true" />
            </li>
          </ul>
          <footer class="tfoot mono">{{ t.note }}</footer>
        </article>
      </div>

      <p class="meta-line mono">
        members.org_id → organizations.id · members.user_id → auth.users.id ·
        findings.org_id → organizations.id
      </p>
      <p class="meta-line mono">
        enum severity: low · medium · high · critical &nbsp;/&nbsp; enum
        finding_status: open · in_progress · resolved
      </p>
    </section>

    <!-- ---- 02 RLS ---- -->
    <section class="sec">
      <header class="sec-head">
        <span class="sec-num mono">02</span>
        <h2>Row-level security</h2>
      </header>
      <p class="sec-intro">
        RLS is the product decision in this build. Policies below are verbatim
        from <code>supabase/01_schema.sql</code> (the idempotent
        <code>drop policy if exists</code> guards are omitted for readability —
        the repo file is the source of truth). Each policy also carries a
        <code>comment on policy</code> statement, so its documentation lives
        in the database itself and is queryable from the catalog.
      </p>

      <CodeBlock filename="supabase/01_schema.sql — policies" :code="policySql" />

      <h3 class="sub-head">
        Why <code>(select auth.uid())</code> and not <code>auth.uid()</code>?
      </h3>
      <p class="sec-intro">
        In a policy, a bare <code>auth.uid()</code> is planned as a per-row
        expression: Postgres calls the function for every row it scans.
        Wrapped in a scalar subquery, the planner hoists it into an
        <strong>InitPlan</strong> — evaluated exactly once per statement, the
        result cached for every row. The membership lookup gets the same
        treatment: <code>in (select …)</code> executes once and is hashed into
        a semi-join, instead of a correlated <code>exists (…)</code>
        re-checked per row.
      </p>

      <div class="duo">
        <div class="duo-item">
          <p class="duo-label bad mono">✕ naive — evaluated per row</p>
          <CodeBlock :code="naiveSql" />
          <p class="duo-note">
            The function is called once per row scanned, and the membership
            subquery can degrade into a correlated re-check per row.
          </p>
        </div>
        <div class="duo-item">
          <p class="duo-label good mono">✓ shipped — evaluated per statement</p>
          <CodeBlock :code="shippedSql" />
          <p class="duo-note">
            Hoisted into an InitPlan: one evaluation, cached. The membership
            set is computed once and hashed. The entire difference is a pair
            of parentheses.
          </p>
        </div>
      </div>

      <p class="sec-intro">
        Identical rows, identical semantics, identical security. On 28 demo
        rows the difference is invisible; on a production findings table it's
        the difference between an index scan and a function call per row. This
        is exactly the pattern Supabase's own RLS performance guidance
        recommends.
      </p>

      <aside class="callout">
        <p>
          <strong>The anon key ships in the browser bundle — public by design.</strong>
          The <code>anon</code> role holds table-level SELECT on all three
          tables, but no policy matches it, so every query it makes returns
          zero rows. Enforcement lives in the database, not in the client.
          <code>supabase/03_verify_rls.sql</code> proves all three access
          levels from the SQL editor: <strong>15 rows</strong> for
          <code>ada@apex.test</code>, <strong>13 rows</strong> for
          <code>sam@meridian.test</code>, <strong>0</strong> for anon.
        </p>
      </aside>
    </section>

    <!-- ---- 03 build notes ---- -->
    <section class="sec">
      <header class="sec-head">
        <span class="sec-num mono">03</span>
        <h2>Notes from the build</h2>
      </header>
      <p class="sec-intro">
        Two incidents from building this demo that shaped how it verifies
        itself.
      </p>

      <div class="notes">
        <article class="note-card panel">
          <h4>The database's own error hint proposed the insecure fix</h4>
          <p>
            While wiring up the RLS verification script, a query failed with
            <code>permission denied for table users</code> — and Postgres's
            hint suggested <code>GRANT SELECT ON auth.users TO authenticated</code>.
            Granting it would have made the error vanish, and created a
            cross-tenant PII leak: <code>authenticated</code> means
            <em>any signed-in user of any tenant</em>, so every user could
            have read every other user's email and ID. The actual bug was
            ordering — a privileged lookup ran after the role had already
            dropped. Fixed by reading privileged data before dropping
            privileges, never by widening the grant.
          </p>
          <p class="rule mono">// rule: read an error hint as telemetry about which check failed — not as security advice</p>
        </article>

        <article class="note-card panel">
          <h4>A test that could pass while broken</h4>
          <p>
            The first verification script built a JWT claim with a user-ID
            lookup. When the lookup silently returned null,
            <code>auth.uid()</code> returned null too — and both tenants saw
            zero rows, which looks exactly like a passing isolation test. The
            rewrite asserts its preconditions (both users exist, memberships
            = 2) and raises loudly on violation, so the script can never pass
            vacuously.
          </p>
          <p class="rule mono">// rule: verification must fail loudly when its assumptions break — a test that passes while broken is worse than no test</p>
        </article>
      </div>
    </section>

    <!-- ---- 04 setup ---- -->
    <section class="sec">
      <header class="sec-head">
        <span class="sec-num mono">04</span>
        <h2>Run it locally</h2>
      </header>
      <p class="sec-intro">
        Fresh clone to running app. Free tiers throughout; only env vars
        needed.
      </p>

      <ol class="steps">
        <li class="step">
          <div>
            <p class="step-title">Clone and install</p>
            <p class="step-body">
              <code>git clone &lt;repo-url&gt; bastion</code> then
              <code>npm install</code>. Node 20.19+ or 22.12+.
            </p>
          </div>
        </li>
        <li class="step">
          <div>
            <p class="step-title">Create a Supabase project</p>
            <p class="step-body">
              Free tier, any region. Create it at supabase.com → New project.
            </p>
          </div>
        </li>
        <li class="step">
          <div>
            <p class="step-title">Create the two demo users</p>
            <p class="step-body">
              Authentication → Sign In / Up: switch off
              <code>Confirm email</code> <em>before</em> creating users. Then
              Users → Add user → Create new user:
              <code>ada@apex.test</code> and <code>sam@meridian.test</code>,
              password <code>demo1234</code> each.
            </p>
          </div>
        </li>
        <li class="step">
          <div>
            <p class="step-title">Run the SQL files in order</p>
            <p class="step-body">
              SQL Editor: <code>01_schema.sql</code> →
              <code>02_seed.sql</code> → <code>03_verify_rls.sql</code>.
              Expected verify results: 15 rows (Apex only) · 13 rows
              (Meridian only) · 0 (anon).
            </p>
          </div>
        </li>
        <li class="step">
          <div>
            <p class="step-title">Configure env vars</p>
            <p class="step-body">
              Copy <code>.env.example</code> to <code>.env</code> and fill
              <code>NUXT_PUBLIC_SUPABASE_URL</code> and
              <code>NUXT_PUBLIC_SUPABASE_ANON_KEY</code> from Project
              Settings → API. Values are read at server start — restart
              <code>npm run dev</code> after any change. <code>.env</code> is
              gitignored.
            </p>
          </div>
        </li>
        <li class="step">
          <div>
            <p class="step-title">Run</p>
            <p class="step-body">
              <code>npm run dev</code> → <code>http://localhost:3000</code>.
            </p>
          </div>
        </li>
        <li class="step">
          <div>
            <p class="step-title">Deploy (optional)</p>
            <p class="step-body">
              Cloudflare Pages, build command <code>npm run generate</code>,
              output directory <code>.output/public</code>. Set both
              <code>NUXT_PUBLIC_*</code> env vars <em>before</em> the first
              build — a static bundle bakes them in at build time.
            </p>
          </div>
        </li>
      </ol>
    </section>
  </div>
</template>

<style scoped>
.about {
  max-width: 62rem;
  display: grid;
  gap: 2.5rem;
}

/* ---- intro ---- */

.mark {
  color: var(--accent);
  font-size: var(--text-xs);
  letter-spacing: 0.18em;
  margin-bottom: 0.75rem;
}

h1 {
  font-size: var(--text-xl);
  font-weight: 600;
  line-height: 1.3;
  max-width: 40rem;
}

.lede {
  margin-top: 1rem;
  color: var(--text-muted);
  font-size: var(--text-base);
  line-height: 1.7;
  max-width: 46rem;
}

.stack {
  list-style: none;
  padding: 0;
  margin-top: 1.25rem;
  display: flex;
  flex-wrap: wrap;
  gap: 0.45rem;
}
.stack li {
  font-size: var(--text-2xs);
  color: var(--text-muted);
  border: 1px solid var(--border);
  border-radius: 999px;
  padding: 0.28rem 0.7rem;
  white-space: nowrap;
}

/* ---- sections ---- */

.sec {
  border-top: 1px solid var(--border);
  padding-top: 2rem;
}

.sec-head {
  display: flex;
  align-items: baseline;
  gap: 0.8rem;
  margin-bottom: 0.9rem;
}
.sec-num {
  color: var(--accent);
  font-size: var(--text-xs);
  letter-spacing: 0.1em;
}
h2 {
  font-size: var(--text-lg);
  font-weight: 600;
}

.sec-intro {
  color: var(--text-muted);
  font-size: var(--text-sm);
  line-height: 1.7;
  max-width: 46rem;
  margin-bottom: 1.25rem;
}

.sub-head {
  font-size: var(--text-base);
  font-weight: 600;
  margin: 2rem 0 0.75rem;
}

/* inline code in prose (scoped — CodeBlock's internals are unaffected) */
.about :deep(code) {
  font-family: var(--font-mono);
  font-size: 0.85em;
  background: var(--bg);
  border: 1px solid var(--border);
  border-radius: 5px;
  padding: 0.08rem 0.38rem;
  color: var(--text);
}

/* ---- schema cards ---- */

.tables {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(16.5rem, 1fr));
  gap: 0.9rem;
  margin-bottom: 1rem;
}

.tcard {
  display: flex;
  flex-direction: column;
  overflow: hidden;
}
.tcard-head {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 0.75rem;
  padding: 0.75rem 1rem;
  border-bottom: 1px solid var(--border);
  background: var(--bg);
}
.tname {
  font-size: var(--text-sm);
  color: var(--text);
}
.ttag {
  font-size: var(--text-2xs);
  color: var(--text-faint);
  text-transform: uppercase;
  letter-spacing: 0.1em;
  white-space: nowrap;
}

.cols {
  list-style: none;
  margin: 0;
  padding: 0.5rem 0.4rem 0.65rem;
}
.col {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto auto;
  gap: 0.6rem;
  align-items: baseline;
  padding: 0.26rem 0.6rem;
  border-radius: 6px;
}
.col:hover {
  background: var(--bg-hover);
}
.cname {
  font-size: var(--text-xs);
  color: var(--text);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.ctype {
  font-size: var(--text-2xs);
  color: var(--text-muted);
  white-space: nowrap;
}
.ckey {
  font-size: var(--text-2xs);
  color: var(--text-muted);
  border: 1px solid var(--border-strong);
  border-radius: 4px;
  padding: 0.02rem 0.32rem;
  white-space: nowrap;
}
.ckey.pk {
  color: var(--accent);
  border-color: var(--accent-border);
}
.ckey-spacer { width: 1px; }

.tfoot {
  margin-top: auto;
  padding: 0.55rem 1rem;
  border-top: 1px solid var(--border);
  font-size: var(--text-2xs);
  color: var(--text-faint);
}

.meta-line {
  font-size: var(--text-2xs);
  color: var(--text-faint);
  line-height: 1.8;
  overflow-wrap: anywhere;
}
.meta-line + .meta-line { margin-top: 0.15rem; }

/* ---- RLS extras ---- */

.duo {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.9rem;
  margin-bottom: 1.25rem;
}
.duo-label {
  font-size: var(--text-2xs);
  letter-spacing: 0.06em;
  text-transform: uppercase;
  margin-bottom: 0.5rem;
}
.duo-label.bad { color: var(--sev-critical); }
.duo-label.good { color: var(--accent); }
.duo-note {
  margin-top: 0.6rem;
  font-size: var(--text-xs);
  color: var(--text-muted);
  line-height: 1.6;
}

.callout {
  margin-top: 1.25rem;
  padding: 1rem 1.25rem;
  border-left: 2px solid var(--accent);
  background: var(--bg-raised);
  border-radius: 0 var(--radius) var(--radius) 0;
}
.callout p {
  font-size: var(--text-sm);
  color: var(--text-muted);
  line-height: 1.7;
}
.callout strong { color: var(--text); }

/* ---- build notes ---- */

.notes {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.9rem;
}
.note-card {
  padding: 1.25rem 1.35rem;
  display: grid;
  gap: 0.7rem;
  align-content: start;
}
.note-card h4 {
  font-size: var(--text-sm);
  font-weight: 600;
  line-height: 1.4;
}
.note-card p {
  font-size: var(--text-xs);
  color: var(--text-muted);
  line-height: 1.7;
}
.rule {
  color: var(--accent);
  font-size: var(--text-2xs);
  line-height: 1.6;
  padding-top: 0.7rem;
  border-top: 1px dashed var(--border-strong);
  overflow-wrap: anywhere;
}

/* ---- steps ---- */

.steps {
  list-style: none;
  margin: 0;
  padding: 0;
  counter-reset: step;
  display: grid;
  gap: 1.05rem;
}
.step {
  counter-increment: step;
  display: grid;
  grid-template-columns: 2.2rem minmax(0, 1fr);
  gap: 0.9rem;
}
.step::before {
  content: counter(step, decimal-leading-zero);
  font-family: var(--font-mono);
  font-size: var(--text-xs);
  color: var(--accent);
  padding-top: 0.1rem;
}
.step-title {
  font-size: var(--text-sm);
  font-weight: 600;
}
.step-body {
  margin-top: 0.25rem;
  font-size: var(--text-xs);
  color: var(--text-muted);
  line-height: 1.75;
  max-width: 44rem;
}

/* ---- responsive ---- */

@media (max-width: 900px) {
  .duo,
  .notes {
    grid-template-columns: 1fr;
  }
}
</style>
