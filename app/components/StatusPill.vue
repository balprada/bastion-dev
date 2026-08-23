<script setup lang="ts">
import type { FindingStatus } from '~/types'

defineProps<{ status: FindingStatus }>()

const LABELS: Record<FindingStatus, string> = {
  open: 'Open',
  in_progress: 'In progress',
  resolved: 'Resolved'
}
</script>

<template>
  <!-- Round dot = status marker. Status deliberately avoids the severity
       palette: open = bright neutral, in_progress = accent (active work),
       resolved = faint (calm, done). -->
  <span class="pill" :class="status">
    <span class="dot" aria-hidden="true" />
    {{ LABELS[status] }}
  </span>
</template>

<style scoped>
.pill {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  font-size: var(--text-xs);
  padding: 0.22rem 0.58rem;
  border-radius: 999px;
  border: 1px solid var(--border);
  color: var(--text-muted);
  white-space: nowrap;
}
.dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: currentColor;
}

.open {
  color: var(--text);
  border-color: var(--border-strong);
}

.in_progress {
  color: var(--accent);
  border-color: var(--accent-border);
  background: var(--accent-dim);
}

.resolved {
  color: var(--text-faint);
}
</style>
