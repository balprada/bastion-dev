<script setup lang="ts">
import type { ScopedFinding, Severity } from '~/types'
import { SEVERITY_LABELS, SEVERITY_ORDER } from '~/utils/labels'

const props = defineProps<{
  findings: ScopedFinding[]
  loading?: boolean
  activeSeverity?: Severity | 'all'
}>()

const emit = defineEmits<{ select: [severity: Severity] }>()

const counts = computed(() => {
  const c: Record<Severity, number> = { critical: 0, high: 0, medium: 0, low: 0 }
  for (const f of props.findings) c[f.severity]++
  return c
})

// Scope of the audit: which parts of the org have findings at all.
const scopeCounts = computed(() => {
  const depts = new Set<string>()
  const projects = new Set<string>()
  const teams = new Set<string>()
  for (const f of props.findings) {
    depts.add(f.department.id)
    projects.add(f.project.id)
    teams.add(f.team.id)
  }
  return { depts: depts.size, projects: projects.size, teams: teams.size }
})

const total = computed(() => props.findings.length)

function onChip(s: Severity) {
  if (counts.value[s] === 0) return
  emit('select', s)
}
</script>

<template>
  <!-- Instrument panel: total at left, proportional severity bar at right.
       Severity-only, permanently: it answers "how bad", never "where". -->
  <section class="kpi panel" aria-label="Findings summary by severity">
    <div v-if="loading" class="kpi-grid" aria-hidden="true">
      <div class="total-col">
        <span class="skel-num skeleton" />
        <span class="skel-cap skeleton" />
      </div>
      <div class="bar-col">
        <span class="skel-legend skeleton" />
        <span class="skel-bar skeleton" />
      </div>
    </div>

    <div v-else class="kpi-grid">
      <div class="total-col">
        <p class="num mono">{{ total }}</p>
        <p class="cap">findings</p>
        <p class="scope mono">
          {{ scopeCounts.depts }} departments · {{ scopeCounts.projects }}
          projects · {{ scopeCounts.teams }} teams affected
        </p>
      </div>

      <div class="bar-col">
        <div class="legend" role="group" aria-label="Filter by severity">
          <button
            v-for="s in SEVERITY_ORDER"
            :key="s"
            type="button"
            class="chip"
            :class="[s, { active: activeSeverity === s, zero: counts[s] === 0 }]"
            :aria-pressed="activeSeverity === s"
            :disabled="counts[s] === 0"
            @click="onChip(s)"
          >
            <span class="chip-dot" aria-hidden="true" />
            <span class="lbl">{{ SEVERITY_LABELS[s] }}</span>
            <span class="cnt mono">{{ counts[s] }}</span>
          </button>
        </div>

        <div class="bar" :class="{ empty: total === 0 }" aria-hidden="true">
          <button
            v-for="s in SEVERITY_ORDER"
            v-show="counts[s] > 0"
            :key="s"
            type="button"
            class="seg"
            :class="s"
            :style="{ flexGrow: counts[s] }"
            :title="`${counts[s]} ${SEVERITY_LABELS[s].toLowerCase()}`"
            tabindex="-1"
            @click="onChip(s)"
          />
        </div>
      </div>
    </div>
  </section>
</template>

<style scoped>
.kpi {
  padding: 1.1rem 1.4rem;
}

.kpi-grid {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr);
  gap: 1.75rem;
  align-items: center;
}

.total-col {
  min-width: 11rem;
}
.num {
  font-size: 1.9rem;
  font-weight: 600;
  line-height: 1;
  color: var(--text);
}
.cap {
  color: var(--text-muted);
  font-size: var(--text-xs);
  margin-top: 0.2rem;
}
.scope {
  color: var(--text-faint);
  font-size: var(--text-2xs);
  margin-top: 0.6rem;
  white-space: nowrap;
}

.bar-col {
  display: grid;
  gap: 0.65rem;
  min-width: 0;
}

.legend {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
}
.chip {
  display: inline-flex;
  align-items: center;
  gap: 0.45rem;
  padding: 0.26rem 0.6rem;
  border-radius: 999px;
  border: 1px solid var(--border);
  background: transparent;
  color: var(--text-muted);
  font-size: var(--text-xs);
  cursor: pointer;
  transition: border-color 0.15s ease, background-color 0.15s ease, color 0.15s ease;
}
.chip-dot {
  width: 7px;
  height: 7px;
  border-radius: 2px;
  background: var(--c);
}
.chip .lbl { font-weight: 500; }
.chip .cnt { color: var(--text); }
.chip:hover:not(:disabled) { border-color: var(--c); }
.chip.active {
  border-color: var(--c);
  background: var(--c-bg);
  color: var(--text);
}
.chip:disabled {
  opacity: 0.4;
  cursor: default;
}

.bar {
  display: flex;
  gap: 3px;
  height: 10px;
}
.bar.empty {
  background: var(--bg-hover);
  border-radius: 2px;
}
.seg {
  flex-basis: 0;
  min-width: 10px;
  border: none;
  padding: 0;
  border-radius: 2px;
  background: var(--c);
  opacity: 0.85;
  cursor: pointer;
  transition: opacity 0.15s ease;
}
.seg:hover { opacity: 1; }

.critical { --c: var(--sev-critical); --c-bg: var(--sev-critical-bg); }
.high     { --c: var(--sev-high);     --c-bg: var(--sev-high-bg); }
.medium   { --c: var(--sev-medium);   --c-bg: var(--sev-medium-bg); }
.low      { --c: var(--sev-low);      --c-bg: var(--sev-low-bg); }

.skel-num { display: block; width: 64px; height: 30px; }
.skel-cap { display: block; width: 56px; height: 10px; margin-top: 10px; }
.skel-legend { display: block; width: 62%; height: 26px; border-radius: 999px; }
.skel-bar { display: block; width: 100%; height: 10px; }

@media (max-width: 720px) {
  .kpi-grid {
    grid-template-columns: 1fr;
    gap: 1rem;
  }
  .scope { white-space: normal; }
}
</style>
