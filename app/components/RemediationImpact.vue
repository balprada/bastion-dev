<script setup lang="ts">
import type { ScopedFinding } from '~/types'
import { FIX_EFFORT_LABELS, FIX_METHOD_LABELS } from '~/utils/labels'

const props = defineProps<{
  findings: ScopedFinding[]
  loading?: boolean
  activeRootCause?: string | null
}>()

const emit = defineEmits<{ focus: [rootCauseId: string] }>()

// Always computed from the FULL dataset, like the KPI strip: this panel
// answers "what would fixing buy us" — independent of current filters.

interface RcRow {
  id: string
  code: string
  title: string
  count: number
  share: number
  criticals: number
  fixAvailable: boolean
  fixMethod: string | null
  fixEffort: string | null
}

const rows = computed<RcRow[]>(() => {
  const total = props.findings.length || 1
  const m = new Map<string, RcRow>()
  for (const f of props.findings) {
    const rc = f.rootCause
    let row = m.get(rc.id)
    if (!row) {
      row = {
        id: rc.id,
        code: rc.code,
        title: rc.title,
        count: 0,
        share: 0,
        criticals: 0,
        fixAvailable: rc.fix_available,
        fixMethod: rc.fix_available ? rc.fix_method : null,
        fixEffort: rc.fix_available ? rc.fix_effort : null
      }
      m.set(rc.id, row)
    }
    row.count++
    if (f.severity === 'critical') row.criticals++
  }
  const out = [...m.values()]
  for (const r of out) r.share = Math.round((r.count / total) * 100)
  return out.sort((a, b) => b.count - a.count || b.criticals - a.criticals)
})

const top = computed(() => rows.value.slice(0, 5))

// The headline: low-effort, fix-available findings — the low-hanging fruit.
const lowHanging = computed(() => {
  const low = props.findings.filter(
    (f) => f.rootCause.fix_available && f.rootCause.fix_effort === 'low'
  )
  const criticals = low.filter((f) => f.severity === 'critical').length
  const pct = props.findings.length
    ? Math.round((low.length / props.findings.length) * 100)
    : 0
  return { total: props.findings.length, low: low.length, criticals, pct }
})
</script>

<template>
  <!-- The CIO panel: turns the findings list into a remediation budget
       decision. Rows are pressable → focus that root cause in the facet
       rail and the table. -->
  <section
    v-if="loading || findings.length"
    class="impact panel"
    aria-label="Remediation impact"
  >
    <header class="head">
      <p class="mark mono">Remediation impact</p>
      <h2>What one change buys you</h2>
    </header>

    <div v-if="loading" class="skel" aria-hidden="true">
      <div class="skeleton sk-head" />
      <div class="skeleton sk-row" />
      <div class="skeleton sk-row" />
      <div class="skeleton sk-row" />
    </div>

    <template v-else>
      <p class="headline">
        <strong>Low-effort fixes cover {{ lowHanging.low }} of
        {{ lowHanging.total }} findings ({{ lowHanging.pct }}%)</strong><template
          v-if="lowHanging.criticals"
        >
          — including
          <span class="crit">{{ lowHanging.criticals }}
          critical{{ lowHanging.criticals > 1 ? 's' : '' }}</span></template
        >.
      </p>

      <ul class="rc-list">
        <li v-for="r in top" :key="r.id">
          <button
            type="button"
            class="rc-row"
            :class="{ active: activeRootCause === r.id, nofix: !r.fixAvailable }"
            @click="emit('focus', r.id)"
          >
            <span class="rc-code mono">{{ r.code }}</span>
            <span class="rc-main">
              <span class="rc-title">{{ r.title }}</span>
              <span v-if="r.fixAvailable" class="rc-meta mono">
                {{ FIX_METHOD_LABELS[r.fixMethod as never] ?? r.fixMethod }} ·
                {{ FIX_EFFORT_LABELS[r.fixEffort as never] ?? r.fixEffort }} effort
              </span>
              <span v-else class="rc-meta mono">no fix available yet</span>
            </span>
            <span class="rc-right">
              <span class="rc-count mono">{{ r.count }}</span>
              <span class="rc-share mono"
                >{{ r.share }}%<template v-if="r.criticals">
                  · {{ r.criticals }} crit</template
                ></span
              >
            </span>
          </button>
        </li>
      </ul>

      <p class="foot mono">
        // click a root cause to isolate its findings — counts always reflect
        the full report, not the current filters
      </p>
    </template>
  </section>
</template>

<style scoped>
.impact {
  padding: 1.15rem 1.4rem 1rem;
}

.mark {
  color: var(--accent);
  font-size: var(--text-xs);
  letter-spacing: 0.18em;
  margin-bottom: 0.5rem;
}
h2 {
  font-size: var(--text-lg);
  font-weight: 600;
}

.headline {
  margin-top: 0.85rem;
  font-size: var(--text-sm);
  color: var(--text-muted);
  line-height: 1.6;
}
.headline strong {
  color: var(--text);
}
.crit {
  color: var(--sev-critical);
  font-weight: 600;
}

.rc-list {
  list-style: none;
  margin: 1rem 0 0;
  padding: 0;
  display: grid;
  gap: 2px;
}

.rc-row {
  display: flex;
  align-items: center;
  gap: 0.9rem;
  width: 100%;
  text-align: left;
  padding: 0.55rem 0.7rem;
  border: 1px solid transparent;
  border-radius: 8px;
  background: transparent;
  color: var(--text);
  cursor: pointer;
  transition: background-color 0.12s ease, border-color 0.12s ease;
}
.rc-row:hover {
  background: var(--bg-hover);
}
.rc-row.active {
  background: var(--accent-dim);
  border-color: var(--accent-border);
}
.rc-row.nofix {
  opacity: 0.65;
}

.rc-code {
  flex-shrink: 0;
  width: 7.2rem;
  font-size: var(--text-xs);
  color: var(--accent);
}
.rc-row.nofix .rc-code {
  color: var(--text-muted);
}

.rc-main {
  min-width: 0;
  flex: 1;
  display: grid;
  gap: 0.1rem;
}
.rc-title {
  font-size: var(--text-sm);
  font-weight: 500;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.rc-meta {
  font-size: var(--text-2xs);
  color: var(--text-faint);
}

.rc-right {
  flex-shrink: 0;
  display: flex;
  align-items: baseline;
  gap: 0.55rem;
}
.rc-count {
  font-size: var(--text-lg);
  font-weight: 600;
}
.rc-share {
  font-size: var(--text-2xs);
  color: var(--text-faint);
  white-space: nowrap;
}

.foot {
  margin-top: 0.8rem;
  font-size: var(--text-2xs);
  color: var(--text-faint);
}

.skel {
  display: grid;
  gap: 0.55rem;
  margin-top: 0.9rem;
}
.sk-head { height: 18px; width: 55%; }
.sk-row { height: 44px; }

@media (max-width: 720px) {
  .rc-code { width: 5.5rem; font-size: var(--text-2xs); }
  .rc-count { font-size: var(--text-base); }
}
</style>
