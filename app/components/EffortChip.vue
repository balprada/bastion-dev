<script setup lang="ts">
import type { FixEffort } from '~/types'
import { FIX_EFFORT_LABELS } from '~/utils/labels'

defineProps<{ effort: FixEffort | null }>()
</script>

<template>
  <!-- Deliberately monochrome: effort is NOT severity. The severity palette
       stays exclusive so color alone always means risk. -->
  <span v-if="effort" class="chip">{{ FIX_EFFORT_LABELS[effort] }}</span>
  <span v-else class="none mono" title="No fix available yet">—</span>
</template>

<style scoped>
.chip {
  display: inline-flex;
  align-items: center;
  font-size: var(--text-2xs);
  font-weight: 500;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  padding: 0.26rem 0.58rem;
  border-radius: 6px;
  white-space: nowrap;
  background: var(--bg);
  border: 1px solid var(--border-strong);
  color: var(--text-muted);
}
.none {
  color: var(--text-faint);
}
</style>
