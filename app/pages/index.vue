<script setup lang="ts">
import type { Finding, FindingStatus, Severity } from '~/types'

useHead({ title: 'Findings — Bastion' })

const supabase = useSupabase()
const { org } = useSession()

// ---- data -----------------------------------------------------------------

// One RLS-scoped query per login — this request IS the tenant-isolation
// demo. Filtering happens client-side on ≤15 rows.
const findings = ref<Finding[]>([])
const loadState = ref<'loading' | 'ok' | 'error'>('loading')
const loadError = ref('')

async function loadFindings() {
  loadState.value = 'loading'
  loadError.value = ''

  const { data, error } = await supabase
    .from('findings')
    .select('*')
    .order('cvss', { ascending: false })
    .order('detected_at', { ascending: false })

  if (error) {
    loadState.value = 'error'
    loadError.value = error.message
    return
  }

  // numeric(3,1) arrives as a JSON number; normalize defensively.
  findings.value = (data ?? []).map((r) => ({ ...r, cvss: Number(r.cvss) })) as Finding[]
  loadState.value = 'ok'
}

onMounted(loadFindings)

const hasAny = computed(() => findings.value.length > 0)

// ---- filters ----------------------------------------------------------------

const search = ref('')
const severityFilter = ref<Severity | 'all'>('all')
const statusFilter = ref<FindingStatus | 'all'>('all')

const filtersActive = computed(
  () =>
    search.value.trim() !== '' ||
    severityFilter.value !== 'all' ||
    statusFilter.value !== 'all'
)

const filtered = computed(() => {
  const q = search.value.trim().toLowerCase()
  return findings.value.filter((f) => {
    if (severityFilter.value !== 'all' && f.severity !== severityFilter.value) return false
    if (statusFilter.value !== 'all' && f.status !== statusFilter.value) return false
    if (q && !f.title.toLowerCase().includes(q) && !f.asset.toLowerCase().includes(q)) {
      return false
    }
    return true
  })
})

function clearFilters() {
  search.value = ''
  severityFilter.value = 'all'
  statusFilter.value = 'all'
}

// KPI strip segments and the severity dropdown drive the same filter.
function toggleSeverity(s: Severity) {
  severityFilter.value = severityFilter.value === s ? 'all' : s
}

// ---- drawer -----------------------------------------------------------------

const selected = ref<Finding | null>(null)
</script>

<template>
  <div class="board">
    <header class="page-head">
      <div>
        <h1>Findings</h1>
        <p v-if="loadState === 'ok'" class="sub mono">
          {{ org?.name ?? 'your organization' }} · {{ findings.length }} findings ·
          sorted by CVSS
        </p>
      </div>
    </header>

    <!-- Load error: honest state, one-click retry -->
    <div v-if="loadState === 'error'" class="error panel">
      <p class="error-title">Couldn't load findings</p>
      <p class="error-msg mono">{{ loadError }}</p>
      <button class="btn btn-sm" type="button" @click="loadFindings">Retry</button>
    </div>

    <template v-else>
      <KpiStrip
        :findings="findings"
        :loading="loadState === 'loading'"
        :active-severity="severityFilter"
        @select="toggleSeverity"
      />

      <div v-if="loadState === 'ok'" class="filters panel">
        <div class="search-wrap">
          <svg
            class="search-icon"
            width="14"
            height="14"
            viewBox="0 0 24 24"
            fill="none"
            aria-hidden="true"
          >
            <circle cx="11" cy="11" r="7" stroke="currentColor" stroke-width="2" />
            <path d="M20 20l-3.5-3.5" stroke="currentColor" stroke-width="2" stroke-linecap="round" />
          </svg>
          <input
            v-model="search"
            class="input search-input"
            type="search"
            placeholder="Search title or asset…"
            aria-label="Search findings"
          />
        </div>

        <select
          v-model="severityFilter"
          class="input select"
          aria-label="Filter by severity"
        >
          <option value="all">All severities</option>
          <option value="critical">Critical</option>
          <option value="high">High</option>
          <option value="medium">Medium</option>
          <option value="low">Low</option>
        </select>

        <select
          v-model="statusFilter"
          class="input select"
          aria-label="Filter by status"
        >
          <option value="all">All statuses</option>
          <option value="open">Open</option>
          <option value="in_progress">In progress</option>
          <option value="resolved">Resolved</option>
        </select>

        <button
          v-if="filtersActive"
          class="btn btn-sm"
          type="button"
          @click="clearFilters"
        >
          Clear
        </button>
      </div>

      <p
        v-if="loadState === 'ok' && filtersActive && hasAny"
        class="showing mono"
        aria-live="polite"
      >
        showing {{ filtered.length }} of {{ findings.length }}
      </p>

      <FindingsTable
        :findings="filtered"
        :loading="loadState === 'loading'"
        :has-any="hasAny"
        @select="selected = $event"
        @clear="clearFilters"
      />
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

/* ---- filters ---- */

.filters {
  display: grid;
  grid-template-columns: minmax(220px, 1fr) auto auto auto;
  gap: 0.6rem;
  align-items: center;
  padding: 0.75rem 0.9rem;
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
/* Native clear ("x") button on search inputs — keep it dim */
.search-input::-webkit-search-cancel-button {
  -webkit-appearance: none;
  width: 12px;
  height: 12px;
  opacity: 0.35;
  cursor: pointer;
}

.select {
  width: auto;
  appearance: none;
  -webkit-appearance: none;
  padding-right: 2.2rem;
  cursor: pointer;
  background-image: url("data:image/svg+xml;charset=UTF-8,%3Csvg xmlns='http://www.w3.org/2000/svg' width='10' height='6' viewBox='0 0 10 6'%3E%3Cpath d='M1 1l4 4 4-4' fill='none' stroke='%238b98a9' stroke-width='1.5' stroke-linecap='round' stroke-linejoin='round'/%3E%3C/svg%3E");
  background-repeat: no-repeat;
  background-position: right 0.75rem center;
}

.showing {
  text-align: right;
  font-size: var(--text-2xs);
  color: var(--text-faint);
  padding-right: 0.25rem;
  margin: -0.35rem 0 -0.1rem;
}

/* ---- error state ---- */

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

@media (max-width: 720px) {
  .filters {
    grid-template-columns: 1fr 1fr;
  }
  .search-wrap {
    grid-column: 1 / -1;
  }
}
</style>
