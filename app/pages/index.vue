<script setup lang="ts">
import type {
  Department,
  FacetGroup,
  FacetId,
  Finding,
  FixEffort,
  FixMethod,
  Project,
  RootCause,
  ScopedFinding,
  Severity,
  Team
} from '~/types'
import { FACET_IDS } from '~/types'
import {
  FIX_EFFORT_LABELS,
  FIX_METHOD_LABELS,
  NO_FIX,
  NO_FIX_LABEL,
  SEVERITY_LABELS,
  SEVERITY_ORDER
} from '~/utils/labels'

useHead({ title: 'Findings — Bastion' })

const supabase = useSupabase()
const { org } = useSession()

// ---- data --------------------------------------------------------------------
// Five parallel RLS-scoped queries; joins happen client-side on ≤30 rows.
// (PostgREST can't embed through the composite FKs that enforce tenant
// integrity — and "five queries, one policy" is the better RLS story anyway.)
const scopedFindings = ref<ScopedFinding[]>([])
const departments = ref<Department[]>([])
const projects = ref<Project[]>([])
const teams = ref<Team[]>([])
const rootCauses = ref<RootCause[]>([])
const loadState = ref<'loading' | 'ok' | 'error'>('loading')
const loadError = ref('')

async function loadAll() {
  loadState.value = 'loading'
  loadError.value = ''

  const [fRes, dRes, pRes, tRes, rRes] = await Promise.all([
    supabase
      .from('findings')
      .select('*')
      .order('cvss', { ascending: false })
      .order('detected_at', { ascending: false }),
    supabase.from('departments').select('*').order('name'),
    supabase.from('projects').select('*').order('name'),
    supabase.from('teams').select('*').order('name'),
    supabase.from('root_causes').select('*')
  ])

  const firstError = [fRes, dRes, pRes, tRes, rRes].find((r) => r.error)?.error
  if (firstError) {
    loadState.value = 'error'
    loadError.value = firstError.message
    return
  }

  const deptMap = new Map((dRes.data ?? []).map((d) => [d.id, d as Department]))
  const projMap = new Map((pRes.data ?? []).map((p) => [p.id, p as Project]))
  const teamMap = new Map((tRes.data ?? []).map((t) => [t.id, t as Team]))
  const rcMap = new Map((rRes.data ?? []).map((r) => [r.id, r as RootCause]))

  const joined: ScopedFinding[] = []
  for (const row of (fRes.data ?? []) as Finding[]) {
    const department = deptMap.get(row.department_id)
    const project = projMap.get(row.project_id)
    const team = teamMap.get(row.team_id)
    const rootCause = rcMap.get(row.root_cause_id)
    if (!department || !project || !team || !rootCause) continue // defensive
    joined.push({ ...row, cvss: Number(row.cvss), department, project, team, rootCause })
  }

  scopedFindings.value = joined
  departments.value = dRes.data ?? []
  projects.value = pRes.data ?? []
  teams.value = tRes.data ?? []
  rootCauses.value = rRes.data ?? []
  loadState.value = 'ok'
}

onMounted(loadAll)

const hasAny = computed(() => scopedFindings.value.length > 0)

// ---- search ------------------------------------------------------------------
// Global, and deliberately spans root-cause codes/titles: typing "log4shell"
// or "CWE-798" works. And it inherits RLS — as Apex you can search for a
// Meridian root cause all day; only findings in YOUR org can ever match.

const search = ref('')
const q = computed(() => search.value.trim().toLowerCase())

function matchesSearch(f: ScopedFinding): boolean {
  const s = q.value
  if (!s) return true
  return [f.title, f.asset, f.affected_component, f.rootCause.code, f.rootCause.title].some(
    (t) => t.toLowerCase().includes(s)
  )
}

// ---- facet engine --------------------------------------------------------------
// Selections: OR within a group, AND across groups. Counts are cross-filtered:
// each group's counts reflect every OTHER active filter (and the search).

function emptySelections(): Record<FacetId, string[]> {
  return {
    severity: [],
    department: [],
    project: [],
    team: [],
    software: [],
    rootCause: [],
    fixMethod: [],
    fixEffort: []
  }
}

const selections = reactive(emptySelections())

function facetValueOf(f: ScopedFinding, g: FacetId): string {
  switch (g) {
    case 'severity':
      return f.severity
    case 'department':
      return f.department.id
    case 'project':
      return f.project.id
    case 'team':
      return f.team.id
    case 'software':
      return f.affected_component
    case 'rootCause':
      return f.rootCause.id
    case 'fixMethod':
      return f.rootCause.fix_available ? (f.rootCause.fix_method ?? NO_FIX) : NO_FIX
    case 'fixEffort':
      return f.rootCause.fix_available ? (f.rootCause.fix_effort ?? NO_FIX) : NO_FIX
  }
}

function passesGroup(f: ScopedFinding, g: FacetId): boolean {
  const sel = selections[g]
  if (!sel.length) return true
  return sel.includes(facetValueOf(f, g))
}

const filtered = computed(() =>
  scopedFindings.value.filter(
    (f) => FACET_IDS.every((g) => passesGroup(f, g)) && matchesSearch(f)
  )
)

// Hierarchy: child facets show descendants of the parent selection.
const projectCandidates = computed(() =>
  selections.department.length
    ? projects.value.filter((p) => selections.department.includes(p.department_id))
    : projects.value
)

const teamCandidates = computed(() => {
  if (selections.project.length) {
    return teams.value.filter((t) => selections.project.includes(t.project_id))
  }
  if (selections.department.length) {
    const pIds = new Set(projectCandidates.value.map((p) => p.id))
    return teams.value.filter((t) => pIds.has(t.project_id))
  }
  return teams.value
})

function pruneScope() {
  const pIds = new Set(projectCandidates.value.map((p) => p.id))
  if (selections.department.length) {
    selections.project = selections.project.filter((id) => pIds.has(id))
  }
  const tIds = new Set(teamCandidates.value.map((t) => t.id))
  if (selections.project.length || selections.department.length) {
    selections.team = selections.team.filter((id) => tIds.has(id))
  }
}

function toggle(g: FacetId, v: string) {
  const arr = selections[g]
  const i = arr.indexOf(v)
  if (i >= 0) arr.splice(i, 1)
  else arr.push(v)
  // Parent selection changed → drop child selections that are no longer
  // visible. Deterministic, and standard cascading-facet behavior.
  if (g === 'department' || g === 'project') pruneScope()
}

function clearAll() {
  for (const g of FACET_IDS) selections[g] = []
  search.value = ''
}

// Per-section clear from the rail. No prune needed: clearing a parent
// group only WIDENS the candidate set — existing child selections remain
// valid members of it.
function clearGroup(id: FacetId) {
  selections[id] = []
}

// Remediation impact panel → facet rail: clicking a root-cause row
// isolates that cause; clicking the already-focused one releases it.
function focusRootCause(id: string) {
  selections.rootCause =
    selections.rootCause.length === 1 && selections.rootCause[0] === id ? [] : [id]
}

const activeFilterCount = computed(
  () => FACET_IDS.reduce((n, g) => n + selections[g].length, 0) + (q.value ? 1 : 0)
)

const filtersActive = computed(() => activeFilterCount.value > 0)

// The rail's group model: candidates + cross-filtered counts.
const facetGroups = computed<FacetGroup[]>(() => {
  const countsFor = (exclude: FacetId) => {
    const base = scopedFindings.value.filter(
      (f) => FACET_IDS.every((g) => g === exclude || passesGroup(f, g)) && matchesSearch(f)
    )
    const m = new Map<string, number>()
    for (const f of base) {
      const v = facetValueOf(f, exclude)
      m.set(v, (m.get(v) ?? 0) + 1)
    }
    return m
  }

  const byCount = (a: { count: number; label: string }, b: { count: number; label: string }) =>
    b.count - a.count || a.label.localeCompare(b.label)

  const keep = (id: FacetId, opts: { value: string; count: number }[]) =>
    opts.filter((o) => o.count > 0 || selections[id].includes(o.value))

  const groups: FacetGroup[] = []

  // severity — canonical order, colored dots
  const sevCounts = countsFor('severity')
  groups.push({
    id: 'severity',
    label: 'Severity',
    options: keep(
      'severity',
      SEVERITY_ORDER.map((s) => ({
        value: s,
        label: SEVERITY_LABELS[s],
        tone: s,
        count: sevCounts.get(s) ?? 0
      }))
    )
  })

  // department
  const deptCounts = countsFor('department')
  groups.push({
    id: 'department',
    label: 'Department',
    options: keep(
      'department',
      departments.value.map((d) => ({ value: d.id, label: d.name, count: deptCounts.get(d.id) ?? 0 }))
    ).sort(byCount)
  })

  // project — scoped by department, sub shows parent
  const projCounts = countsFor('project')
  const deptName = (id: string) => departments.value.find((d) => d.id === id)?.name
  groups.push({
    id: 'project',
    label: 'Project',
    scopedNote: selections.department.length
      ? `scoped to ${selections.department.length} selected department${selections.department.length > 1 ? 's' : ''}`
      : undefined,
    options: keep(
      'project',
      projectCandidates.value.map((p) => ({
        value: p.id,
        label: p.name,
        sub: deptName(p.department_id),
        count: projCounts.get(p.id) ?? 0
      }))
    ).sort(byCount)
  })

  // team — scoped by project/department, sub shows parent
  const teamCounts = countsFor('team')
  const projName = (id: string) => projects.value.find((p) => p.id === id)?.name
  const teamNote = selections.project.length
    ? 'scoped to selected projects'
    : selections.department.length
      ? 'scoped to selected departments'
      : undefined
  groups.push({
    id: 'team',
    label: 'Team',
    scopedNote: teamNote,
    options: keep(
      'team',
      teamCandidates.value.map((t) => ({
        value: t.id,
        label: t.name,
        sub: projName(t.project_id),
        count: teamCounts.get(t.id) ?? 0
      }))
    ).sort(byCount)
  })

  // software (affected component)
  const swCounts = countsFor('software')
  const swCands = new Map<string, number>()
  for (const f of scopedFindings.value) {
    if (f.affected_component) swCands.set(f.affected_component, 0)
  }
  groups.push({
    id: 'software',
    label: 'Software',
    options: keep(
      'software',
      [...swCands.keys()].map((c) => ({ value: c, label: c, count: swCounts.get(c) ?? 0 }))
    ).sort(byCount)
  })

  // root cause — label = catalog code, sub = title
  const rcCounts = countsFor('rootCause')
  const rcCands = new Map<string, RootCause>()
  for (const f of scopedFindings.value) rcCands.set(f.rootCause.id, f.rootCause)
  groups.push({
    id: 'rootCause',
    label: 'Root cause',
    options: keep(
      'rootCause',
      [...rcCands.entries()].map(([id, rc]) => ({
        value: id,
        label: rc.code,
        sub: rc.title,
        count: rcCounts.get(id) ?? 0
      }))
    ).sort(byCount)
  })

  // fix method — from the root-cause catalog; includes a "no fix" bucket
  const fmCounts = countsFor('fixMethod')
  const fmCands = new Map<string, string>()
  for (const f of scopedFindings.value) {
    const v = facetValueOf(f, 'fixMethod')
    fmCands.set(
      v,
      v === NO_FIX ? NO_FIX_LABEL : (FIX_METHOD_LABELS[v as FixMethod] ?? v)
    )
  }
  groups.push({
    id: 'fixMethod',
    label: 'Fix method',
    options: keep(
      'fixMethod',
      [...fmCands.entries()].map(([v, label]) => ({ value: v, label, count: fmCounts.get(v) ?? 0 }))
    ).sort(byCount)
  })

  // fix effort — canonical order, "no fix" last
  const feCounts = countsFor('fixEffort')
  const feOrder: string[] = ['low', 'medium', 'high', NO_FIX]
  const fePresent = new Set(feOrder.filter((v) => scopedFindings.value.some((f) => facetValueOf(f, 'fixEffort') === v)))
  groups.push({
    id: 'fixEffort',
    label: 'Fix effort',
    options: keep(
      'fixEffort',
      feOrder
        .filter((v) => fePresent.has(v))
        .map((v) => ({
          value: v,
          label: v === NO_FIX ? NO_FIX_LABEL : FIX_EFFORT_LABELS[v as FixEffort],
          count: feCounts.get(v) ?? 0
        }))
    )
  })

  return groups
})

const activeSeverity = computed<Severity | undefined>(() =>
  selections.severity.length === 1 ? (selections.severity[0] as Severity) : undefined
)

function toggleSeverity(s: Severity) {
  toggle('severity', s)
}

// ---- drawer -------------------------------------------------------------------

const selected = ref<ScopedFinding | null>(null)

// ---- mobile filters ------------------------------------------------------------

const mobileFiltersOpen = ref(false)
</script>

<template>
  <div class="board">
    <header class="page-head">
      <div>
        <h1>Findings</h1>
        <p v-if="loadState === 'ok'" class="sub mono">
          {{ org?.name ?? 'your organization' }} · {{ scopedFindings.length }} findings ·
          sorted by CVSS
        </p>
      </div>
    </header>

    <div v-if="loadState === 'error'" class="error panel">
      <p class="error-title">Couldn't load findings</p>
      <p class="error-msg mono">{{ loadError }}</p>
      <button class="btn btn-sm" type="button" @click="loadAll">Retry</button>
    </div>

    <template v-else>
      <KpiStrip
        :findings="scopedFindings"
        :loading="loadState === 'loading'"
        :active-severity="activeSeverity ?? 'all'"
        @select="toggleSeverity"
      />

      <RemediationImpact
        :findings="scopedFindings"
        :loading="loadState === 'loading'"
        :active-root-cause="selections.rootCause.length === 1 ? selections.rootCause[0] : null"
        @focus="focusRootCause"
      />

      <div class="board-cols">
        <FacetRail
          :groups="facetGroups"
          :selections="selections"
          :result-count="filtered.length"
          :total-count="scopedFindings.length"
          :loading="loadState === 'loading'"
          :open="mobileFiltersOpen"
          @toggle="toggle"
          @clear="clearGroup"
          @reset="clearAll"
          @close="mobileFiltersOpen = false"
        />

        <div class="main-col">
          <div class="toolbar">
            <button
              class="btn filters-btn"
              type="button"
              @click="mobileFiltersOpen = true"
            >
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" aria-hidden="true">
                <path d="M3 6h18M6 12h12M10 18h4" stroke="currentColor" stroke-width="2" stroke-linecap="round" />
              </svg>
              Filters
              <span v-if="activeFilterCount" class="fbadge mono">{{ activeFilterCount }}</span>
            </button>

            <div class="search-wrap">
              <svg class="search-icon" width="14" height="14" viewBox="0 0 24 24" fill="none" aria-hidden="true">
                <circle cx="11" cy="11" r="7" stroke="currentColor" stroke-width="2" />
                <path d="M20 20l-3.5-3.5" stroke="currentColor" stroke-width="2" stroke-linecap="round" />
              </svg>
              <input
                v-model="search"
                class="input search-input"
                type="search"
                placeholder="Search title, asset, software, CVE/CWE…"
                aria-label="Search findings"
              />
            </div>
          </div>

          <p v-if="loadState === 'ok' && filtersActive && hasAny" class="showing mono">
            showing {{ filtered.length }} of {{ scopedFindings.length }}
            <button class="clear-inline mono" type="button" @click="clearAll">reset</button>
          </p>

          <FindingsTable
            :findings="filtered"
            :loading="loadState === 'loading'"
            :has-any="hasAny"
            @select="selected = $event"
            @clear="clearAll"
          />
        </div>
      </div>
    </template>

    <FindingDrawer :finding="selected" @close="selected = null" />
  </div>
</template>

<style scoped>
.board {
  display: grid;
  gap: 1rem;
}

.page-head {
  margin-bottom: 0.35rem;
}
h1 {
  font-size: var(--text-xl);
  font-weight: 600;
}
.sub {
  color: var(--text-muted);
  font-size: var(--text-xs);
  margin-top: 0.3rem;
}

/* rail column + main column */
.board-cols {
  display: grid;
  grid-template-columns: 250px minmax(0, 1fr);
  gap: 1.25rem;
  align-items: start;
}

.main-col {
  display: grid;
  gap: 0.75rem;
  min-width: 0;
}

/* toolbar: [Filters] on mobile only, search always */
.toolbar {
  display: grid;
  grid-template-columns: minmax(0, 1fr);
  gap: 0.6rem;
}

.filters-btn {
  display: none;
}
.fbadge {
  background: var(--accent);
  color: var(--on-accent);
  border-radius: 999px;
  font-size: var(--text-2xs);
  padding: 0.02rem 0.42rem;
}

.search-wrap {
  position: relative;
  min-width: 0;
}
.search-icon {
  position: absolute;
  left: 0.75rem;
  top: 50%;
  transform: translateY(-50%);
  color: var(--text-faint);
  pointer-events: none;
}
.search-input {
  padding-left: 2.3rem;
}
.search-input::-webkit-search-cancel-button {
  -webkit-appearance: none;
  width: 12px;
  height: 12px;
  opacity: 0.35;
  cursor: pointer;
}

.showing {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 0.6rem;
  font-size: var(--text-2xs);
  color: var(--text-faint);
  padding-right: 0.25rem;
  margin: -0.2rem 0 -0.15rem;
}
.clear-inline {
  background: none;
  border: none;
  color: var(--accent);
  font-size: var(--text-2xs);
  text-transform: uppercase;
  letter-spacing: 0.06em;
  cursor: pointer;
  padding: 0;
}

/* error state */
.error {
  padding: 2rem 1.5rem;
  display: grid;
  gap: 0.6rem;
  justify-items: start;
}
.error-title {
  font-size: var(--text-base);
  font-weight: 600;
}
.error-msg {
  font-size: var(--text-xs);
  color: var(--sev-critical);
  overflow-wrap: anywhere;
}

@media (max-width: 960px) {
  .board-cols {
    grid-template-columns: 1fr;
  }
  .toolbar {
    grid-template-columns: auto minmax(0, 1fr);
  }
  .filters-btn {
    display: inline-flex;
  }
}
</style>
