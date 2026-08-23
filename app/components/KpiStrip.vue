<script setup lang="ts">
import type { Finding, FindingStatus, Severity } from '~/types'

const props = defineProps<{
  findings: Finding[]
  loading?: boolean
  activeSeverity?: Severity | 'all'
}>()

const emit = defineEmits<{ select: [severity: Severity] }>()

const SEVERITIES: { key: Severity; label: string }[] = [
  { key: 'critical', label: 'Critical' },
  { key: 'high', label: 'High' },
  { key: 'medium', label: 'Medium' },
  { key: 'low', label: 'Low' }
]

const counts = computed(() => {
  const c: Record<Severity, number> = { critical: 0, high: 0, medium: 0, low: 0 }
  for (const f of props.findings) c[f.severity]++
  return c
})

const statusCounts = computed(() => {
  const s: Record<FindingStatus, number> = { open: 0, in_progress: 0, resolved: 0 }
  for (const f of props.findings) s[f.status]++
  return s
})

const total = computed(() => props.findings.length)

function onChip(s: Severity) {
  if (counts.value[s] === 0) return
  emit('select', s)
}
</script>

<template>
  <!-- Instrument panel, not marketing cards: one panel, total at left,
       proportional severity bar at right. Every part is pressable. -->
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
        <p class="status mono">
          {{ statusCounts.open }} open · {{ statusCounts.in_progress }} in
          progress · {{ statusCounts.resolved }} resolved
        </p>
      </div>

      <div class="bar-col">
        <div class="legend" role="group" aria-label="Filter by severity">
          <button
            v-for="s in SEVERITIES"
            :key="s.key"
            type="button"
            class="chip"
            :class="[s.key, { active: activeSeverity === s.key, zero: counts[s.key] === 0 }]"
            :aria-pressed="activeSeverity === s.key"
            :disabled="counts[s.key] === 0"
            @click="onChip(s.key)"
          >
            <span class="chip-dot" aria-hidden="true" />
            <span class="lbl">{{ s.label }}</span>
            <span class="cnt mono">{{ counts[s.key] }}</span>
          </button>
        </div>

        <div class="bar" :class="{ empty: total === 0 }" aria-hidden="true">
          <button
            v-for="s in SEVERITIES"
            v-show="counts[s.key] > 0"
            :key="s.key"
            type="button"
            class="seg"
            :class="s.key"
            :style="{ flexGrow: counts[s.key] }"
            :title="`${counts[s.key]} ${s.label.toLowerCase()}`"
            tabindex="-1"
            @click="onChip(s.key)"
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

.total-col { min-width: 9rem; }
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
.status {
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

/* Proportional severity bar: segment width = share of total. */
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

/* Skeletons */
.skel-num  { display: block; width: 64px; height: 30px; }
.skel-cap  { display: block; width: 56px; height: 10px; margin-top: 10px; }
.skel-legend { display: block; width: 62%; height: 26px; border-radius: 999px; }
.skel-bar  { display: block; width: 100%; height: 10px; }

@media (max-width: 720px) {
  .kpi-grid {
    grid-template-columns: 1fr;
    gap: 1rem;
  }
  .status { white-space: normal; }
}
</style>
