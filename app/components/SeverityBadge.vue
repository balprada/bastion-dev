<script setup lang="ts">
import type { Severity } from '~/types'

const props = defineProps<{ severity: Severity }>()

const LABELS: Record<Severity, string> = {
  critical: 'Critical',
  high: 'High',
  medium: 'Medium',
  low: 'Low'
}

const label = computed(() => LABELS[props.severity])
</script>

<template>
  <!-- Square dot = severity marker (status pills use round dots — two
       distinct shapes so the two dimensions never read as the same thing). -->
  <span class="badge" :class="severity">
    <span class="dot" aria-hidden="true" />
    {{ label }}
  </span>
</template>

<style scoped>
/* --c / --c-bg are set per severity below; the badge itself is shape only.
   Severity colors are functional state — they appear nowhere else in the UI
   except CVSS scores and the KPI bar. */
.badge {
  display: inline-flex;
  align-items: center;
  gap: 0.45rem;
  font-size: var(--text-2xs);
  font-weight: 500;
  letter-spacing: 0.05em;
  text-transform: uppercase;
  padding: 0.26rem 0.58rem;
  border-radius: 6px;
  white-space: nowrap;
  background: var(--c-bg);
  color: var(--c);
}
.dot {
  width: 7px;
  height: 7px;
  border-radius: 2px;
  background: var(--c);
}

.critical { --c: var(--sev-critical); --c-bg: var(--sev-critical-bg); }
.high     { --c: var(--sev-high);     --c-bg: var(--sev-high-bg); }
.medium   { --c: var(--sev-medium);   --c-bg: var(--sev-medium-bg); }
.low      { --c: var(--sev-low);      --c-bg: var(--sev-low-bg); }
</style>
