<script setup lang="ts">
useHead({ title: 'About this build — Bastion' })

// ---- schema cards -----------------------------------------------------------

interface ColumnDef {
  name: string
  type: string
  key?: 'PK' | 'FK' | 'PK · FK' | 'unique' | 'unique (global)'
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
      { name: 'slug', type: 'text', key: 'unique (global)' },
      { name: 'name', type: 'text' },
      { name: 'created_at', type: 'timestamptz' }
    ],
    note: 'slug globally unique — the org itself is the tenant'
  },
  {
    name: 'members',
    tag: 'org membership',
    columns: [
      { name: 'org_id', type: 'uuid', key: 'PK · FK' },
      { name: 'user_id', type: 'uuid', key: 'PK · FK' },
      { name: 'role', type: 'text' }
    ],
    note: 'every isolation policy resolves through this table'
  },
  {
    name: 'departments',
    tag: 'structure',
    columns: [
      { name: 'id', type: 'uuid', key: 'PK' },
      { name: 'org_id', type: 'uuid', key: 'FK' },
      { name: 'slug', type: 'text' },
      { name: 'name', type: 'text' }
    ],
    note: 'unique (org_id, slug) — per-tenant namespace, like GitHub'
  },
  {
    name: 'projects',
    tag: 'structure',
    columns: [
      { name: 'id', type: 'uuid', key: 'PK' },
      { name: 'org_id', type: 'uuid', key: 'FK' },
      { name: 'department_id', type: 'uuid', key: 'FK' },
      { name: 'slug', type: 'text' },
      { name: 'name', type: 'text' }
    ],
    note: 'composite FK → parent must be in the same org'
  },
  {
    name: 'teams',
    tag: 'structure',
    columns: [
      { name: 'id', type: 'uuid', key: 'PK' },
      { name: 'org_id', type: 'uuid', key: 'FK' },
      { name: 'project_id', type: 'uuid', key: 'FK' },
      { name: 'slug', type: 'text' },
      { name: 'name', type: 'text' }
    ],
    note: 'project-scoped teams'
  },
  {
    name: 'team_members',
    tag: 'membership',
    columns: [
      { name: 'team_id', type: 'uuid', key: 'PK · FK' },
      { name: 'user_id', type: 'uuid', key: 'PK · FK' },
      { name: 'org_id', type: 'uuid', key: 'FK' },
      { name: 'role', type: 'text' }
    ],
    note: 'org_id denormalized, backed by a composite FK'
  },
  {
    name: 'root_causes',
    tag: 'global catalog',
    columns: [
      { name: 'id', type: 'uuid', key: 'PK' },
      { name: 'code', type: 'text', key: 'unique (global)' },
      { name: 'title', type: 'text' },
      { name: 'severity', type: 'severity' },
      { name: 'first_discovered', type: 'date' },
      { name: 'fix_available', type: 'boolean' },
      { name: 'fix_method', type: 'fix_method' },
      { name: 'fix_effort', type: 'fix_effort' },
      { name: 'workaround', type: 'text' }
    ],
    note: 'NO org_id — reference data by design'
  },
  {
    name: 'findings',
    tag: 'tenant data',
    columns: [
      { name: 'id', type: 'uuid', key: 'PK' },
      { name: 'org_id', type: 'uuid', key: 'FK' },
      { name: 'department_id', type: 'uuid', key: 'FK' },
      { name: 'project_id', type: 'uuid', key: 'FK' },
      { name: 'team_id', type: 'uuid', key: 'FK' },
      { name: 'root_cause_id', type: 'uuid', key: 'FK' },
      { name: 'title', type: 'text' },
      { name: 'severity', type: 'severity' },
      { name: 'cvss', type: 'numeric(3,1)' },
      { name: 'asset', type: 'text' },
      { name: 'affected_component', type: 'text' },
      { name: 'detected_at', type: 'timestamptz' }
    ],
    note: 'composite FKs on all three scope refs · unique (org_id, title)'
  }
]

const stack = [
  'nuxt 4 · static SPA',
  'typescript',
  'supabase · postgres + auth',
  'postgres RLS',
  'one project · two schemas',
  'cloudflare workers',
  'ibm plex sans / mono'
]

// ---- SQL artifacts -----------------------------------------------------------

const policySql = `-- Enable RLS on every table (policies are ignored without this).
alter table bastion_v2.findings     enable row level security;
alter table bastion_v2.departments  enable row level security;
-- … identical for members, projects, teams, team_members, organizations

-- Structure tables: the same flat org predicate everywhere.
create policy departments_select_own
  on bastion_v2.departments
  for select
  to authenticated
  using (
    org_id in (
      select m.org_id
      from bastion_v2.members m
      where m.user_id = (select auth.uid())
    )
  );
comment on policy departments_select_own on bastion_v2.departments is
  'SELECT: org-level isolation — only departments of the caller''s organizations.';

-- findings: the tenant isolation boundary (core deliverable).
create policy findings_select_own_org
  on bastion_v2.findings
  for select
  to authenticated
  using (
    org_id in (
      select m.org_id
      from bastion_v2.members m
      where m.user_id = (select auth.uid())
    )
  );
comment on policy findings_select_own_org on bastion_v2.findings is
  'SELECT: the tenant isolation boundary — findings of the caller''s organizations only.';

-- root_causes: intentionally permissive — see the classification note.
create policy root_causes_select_all
  on bastion_v2.root_causes
  for select
  to authenticated
  using ( true );
comment on policy root_causes_select_all on bastion_v2.root_causes is
  'SELECT: global catalog — readable across tenants by design (no tenant data).'

-- Full source: supabase/01_schema.sql (this page shows the pattern,
-- not all eight policies — they differ only in table name).`

const naiveSql = `using (
  org_id in (
    select m.org_id
    from bastion_v2.members m
    where m.user_id = auth.uid()
  )
)`

const shippedSql = `using (
  org_id in (
    select m.org_id
    from bastion_v2.members m
    where m.user_id = (select auth.uid())
  )
)`

const fkSql = `-- Every hierarchical edge enforces tenant integrity on the WRITE side:
foreign key (department_id, org_id)
  references bastion_v2.departments (id, org_id) on delete cascade,
foreign key (project_id, org_id)
  references bastion_v2.projects (id, org_id) on delete cascade,
foreign key (team_id, org_id)
  references bastion_v2.teams (id, org_id) on delete cascade

-- RLS decides who can SEE rows; these decide which rows can EXIST.
-- A finding cannot reference another org's team even if every policy
-- were dropped — the database rejects the write.`

const teamPolicySql = `-- Documented, deliberately NOT applied. One statement away if a
-- client requires need-to-know between teams (M&A walls, compartments).
-- The org-admin override keeps the client's own security team org-wide:

create policy findings_select_team_scoped
  on bastion_v2.findings
  for select
  to authenticated
  using (
    org_id in (
      select m.org_id from bastion_v2.members m
      where m.user_id = (select auth.uid()) and m.role = 'admin'
    )
    or team_id in (
      select tm.team_id from bastion_v2.team_members tm
      where tm.user_id = (select auth.uid())
    )
  );`
</script>

<template>
  <div class="about">
    <!-- ---- intro ---- -->
    <header class="intro">
      <p class="mark mono">// about this build</p>
      <h1>An audit portal, isolated at the database</h1>
      <p class="lede">
        Bastion is what an external security team hands a client: two
        organizations, 28 synthetic findings, each mapped to a root cause with
        fix economics. The key design decision: tenant isolation is enforced by
        <strong>Postgres row-level security</strong>, not by the UI — the client
        never filters by organization because it can't. Every request carries
        the user's JWT; Postgres resolves membership and only that org's rows
        ever leave the database. The Attack Lab probes this boundary live with
        raw API calls.
      </p>
      <p class="lede">
        This v2 build runs in a dedicated schema (<span class="mono">bastion_v2</span>)
        of the same Supabase project as v1 — same URL, same anon key, one
        additive env var. The schema is a routing parameter, not a credential.
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
        Eight tables: a tenant structure (org → department → project → team),
        two membership tables, one global root-cause catalog, and the findings
        themselves — each carrying its full scope path denormalized, so every
        policy stays flat.
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

      <aside class="callout">
        <p>
          <strong>Composite foreign keys are the write-side boundary.</strong>
          RLS controls who can <em>see</em> rows; these constraints control
          which rows can <em>exist</em>. If a policy is ever misconfigured or
          dropped, the schema still refuses to link tenants — defense in depth
          means the layers fail independently.
        </p>
        <CodeBlock :code="fkSql" />
      </aside>
    </section>

    <!-- ---- 02 RLS ---- -->
    <section class="sec">
      <header class="sec-head">
        <span class="sec-num mono">02</span>
        <h2>Row-level security</h2>
      </header>
      <p class="sec-intro">
        RLS is enabled on <strong>every</strong> table — and the boundary is a
        per-table decision, not a blanket. Source of truth:
        <code>supabase/01_schema.sql</code>, every policy with a SQL comment.
      </p>

      <CodeBlock filename="supabase/01_schema.sql — policy pattern" :code="policySql" />

      <h3 class="sub-head">The boundary matrix</h3>
      <table class="matrix mono">
        <thead>
          <tr>
            <th>table</th>
            <th>org boundary</th>
            <th>team boundary</th>
            <th>note</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>findings</td>
            <td class="on">✓ enforced</td>
            <td class="avail">○ available</td>
            <td>the tenant boundary — policy applied</td>
          </tr>
          <tr>
            <td>departments · projects · teams</td>
            <td class="on">✓ enforced</td>
            <td class="avail">○ available</td>
            <td>identical flat predicate</td>
          </tr>
          <tr>
            <td>team_members</td>
            <td class="on">✓ enforced</td>
            <td>—</td>
            <td>resolves the team-level policy</td>
          </tr>
          <tr>
            <td>organizations · members</td>
            <td class="on">✓ enforced</td>
            <td>—</td>
            <td>members: own rows only</td>
          </tr>
          <tr>
            <td>root_causes</td>
            <td class="glob">global</td>
            <td>—</td>
            <td>reference data — see classification</td>
          </tr>
        </tbody>
      </table>
      <p class="matrix-legend mono">
        ✓ applied · ○ written and one statement away · global = intentionally
        permissive
      </p>

      <h3 class="sub-head">
        Why <code>(select auth.uid())</code> and not <code>auth.uid()</code>?
      </h3>
      <p class="sec-intro">
        A bare <code>auth.uid()</code> is planned as a per-row expression —
        called once per row scanned. Wrapped in a scalar subquery, the planner
        hoists it into an <strong>InitPlan</strong>: evaluated exactly once per
        statement, cached for every row. Identical rows, identical semantics,
        very different cost.
      </p>

      <div class="duo">
        <div class="duo-item">
          <p class="duo-label bad mono">✕ naive — per row</p>
          <CodeBlock :code="naiveSql" />
        </div>
        <div class="duo-item">
          <p class="duo-label good mono">✓ shipped — per statement</p>
          <CodeBlock :code="shippedSql" />
        </div>
      </div>

      <aside class="callout">
        <p>
          <strong>Data classification: the one permissive policy is a decision,
          not an oversight.</strong>
          <code>root_causes</code> holds public knowledge about the world —
          CVE/CWE codes, fix guidance — with zero tenant columns, so sharing it
          across tenants leaks nothing and creates no inference channel (row
          existence can't correlate with any tenant). The invariant that keeps
          it safe: <strong>tenant-derived data never enters this table.</strong>
          The day a client-specific root cause is needed, that row becomes
          tenant data and the policy changes. Also note: the anon key ships in
          the browser bundle by design — no policy matches the
          <code>anon</code> role, so it reads zero rows from every table.
          Enforcement lives in the database, not in key secrecy.
        </p>
      </aside>

      <h3 class="sub-head">The team-level boundary — designed, not enabled</h3>
      <p class="sec-intro">
        Today every org member sees their whole org (role is display-only).
        If a client requires need-to-know between teams, this is the entire
        change — no migration, no new tables:
      </p>
      <CodeBlock filename="documented — apply when the business requires it" :code="teamPolicySql" />
    </section>

    <!-- ---- 03 build notes ---- -->
    <section class="sec">
      <header class="sec-head">
        <span class="sec-num mono">03</span>
        <h2>Notes from the build</h2>
      </header>
      <div class="notes">
        <article class="note-card panel">
          <h4>The database's own error hint proposed the insecure fix</h4>
          <p>
            A query failed on <code>auth.users</code> and Postgres suggested
            <code>GRANT SELECT … TO authenticated</code> — which would have let
            any signed-in user of any tenant read every other user's email.
            The real bug was ordering: a privileged lookup ran after the role
            had dropped. Fixed by reordering, never by widening the grant.
          </p>
          <p class="rule mono">// rule: an error hint is telemetry about which check failed — not security advice</p>
        </article>
        <article class="note-card panel">
          <h4>A test that could pass while broken</h4>
          <p>
            The first RLS verification script silently produced a null user ID
            when a lookup missed — and both tenants seeing zero rows looks
            exactly like a passing isolation test. The rewrite asserts its
            preconditions and raises loudly.
          </p>
          <p class="rule mono">// rule: verification must fail loudly when its assumptions break</p>
        </article>
        <article class="note-card panel">
          <h4>The silent wrong-schema bug</h4>
          <p>
            With two schemas in one project, raw REST calls without an
            <code>Accept-Profile</code> header don't error — they silently
            query the first exposed schema. The Attack Lab's probes would have
            attacked v1's tables while displaying v2's UI. Every raw request
            now pins its schema explicitly.
          </p>
          <p class="rule mono">// rule: multi-tenant-by-schema fails silently — pin the profile header</p>
        </article>
      </div>
    </section>

    <!-- ---- 04 setup ---- -->
    <section class="sec">
      <header class="sec-head">
        <span class="sec-num mono">04</span>
        <h2>Run it locally</h2>
      </header>
      <ol class="steps">
        <li class="step">
          <div>
            <p class="step-title">Clone and install</p>
            <p class="step-body">
              <code>git clone &lt;repo&gt; bastion</code>, checkout
              <code>demo2</code>, <code>npm install</code>. Node 20.19+ or
              22.12+.
            </p>
          </div>
        </li>
        <li class="step">
          <div>
            <p class="step-title">Expose the schema</p>
            <p class="step-body">
              Supabase → Project Settings → API → Exposed schemas: add
              <code>bastion_v2</code>. Keep <code>public</code> first — the v1
              app relies on it being the default.
            </p>
          </div>
        </li>
        <li class="step">
          <div>
            <p class="step-title">Create the demo users</p>
            <p class="step-body">
              Authentication → Sign In / Up: turn <em>off</em> "Confirm email"
              first. Then create <code>ada@apex.test</code> and
              <code>sam@meridian.test</code>, password <code>demo1234</code>.
            </p>
          </div>
        </li>
        <li class="step">
          <div>
            <p class="step-title">Run the SQL files</p>
            <p class="step-body">
              SQL Editor, in order: <code>01_schema.sql</code> →
              <code>02_seed.sql</code> → <code>03_verify_rls.sql</code>.
              Expected verify: ada 15/4/11/12/22 · sam 13/3/8/8/22 · anon 0.
            </p>
          </div>
        </li>
        <li class="step">
          <div>
            <p class="step-title">Configure env vars</p>
            <p class="step-body">
              <code>.env</code>: <code>NUXT_PUBLIC_SUPABASE_URL</code>,
              <code>NUXT_PUBLIC_SUPABASE_ANON_KEY</code>, and
              <code>NUXT_PUBLIC_SUPABASE_SCHEMA=bastion_v2</code>. Restart dev
              after any change — env is read at startup.
            </p>
          </div>
        </li>
        <li class="step">
          <div>
            <p class="step-title">Run</p>
            <p class="step-body"><code>npm run dev</code> → http://localhost:3000</p>
          </div>
        </li>
        <li class="step">
          <div>
            <p class="step-title">Deploy (Cloudflare Workers)</p>
            <p class="step-body">
              Build <code>npm run generate && rm -rf .output/server .wrangler</code>
              · deploy <code>npx wrangler deploy --config wrangler.jsonc</code>
              · production branch <code>demo2</code> · all three
              <code>NUXT_PUBLIC_*</code> vars set before the first build.
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

/* ---- boundary matrix ---- */

.matrix {
  width: 100%;
  border-collapse: collapse;
  font-size: var(--text-xs);
  margin-bottom: 0.4rem;
}
.matrix th {
  text-align: left;
  font-size: var(--text-2xs);
  text-transform: uppercase;
  letter-spacing: 0.1em;
  color: var(--text-faint);
  font-weight: 500;
  padding: 0.45rem 0.7rem;
  border-bottom: 1px solid var(--border-strong);
}
.matrix td {
  padding: 0.5rem 0.7rem;
  border-bottom: 1px solid var(--border);
  color: var(--text-muted);
}
.matrix td.on { color: var(--accent); }
.matrix td.avail { color: var(--text-muted); }
.matrix td.glob { color: var(--sev-medium); }
.matrix-legend {
  font-size: var(--text-2xs);
  color: var(--text-faint);
}

/* ---- callouts, duo, notes, steps (shared with v1 patterns) ---- */

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
.callout .code-block-host { margin-top: 0.9rem; }

.notes {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr;
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

@media (max-width: 900px) {
  .duo,
  .notes {
    grid-template-columns: 1fr;
  }
}
</style>
