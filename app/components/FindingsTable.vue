<script setup lang="ts">
import type { ScopedFinding } from '~/types'

const props = defineProps<{
  findings: ScopedFinding[]
  loading?: boolean
  hasAny?: boolean
}>()

const emit = defineEmits<{
  select: [finding: ScopedFinding]
  clear: []
}>()

const SKELETON_ROWS = 8
const TITLE_WIDTHS = ['72%', '55%', '84%']
</script>

<template>
  <div class="table panel">
    <!-- Loading: skeleton rows mirroring the real layout -->
    <div v-if="loading" aria-hidden="true">
      <div v-for="i in SKELETON_ROWS" :key="i" class="row">
        <div class="cell c-sev">
          <span class="skeleton" style="width: 82px; height: 18px; border-radius: 6px" />
        </div>
        <div class="cell c-title">
          <span class="skeleton" :style="{ width: TITLE_WIDTHS[i % 3], height: '13px' }" />
          <span class="skeleton" style="width: 42%; height: 9px; margin-top: 6px" />
        </div>
        <div class="cell c-cvss">
          <span class="skeleton" style="width: 30px; height: 14px" />
        </div>
        <div class="cell c-effort">
          <span class="skeleton" style="width: 58px; height: 18px; border-radius: 6px" />
        </div>
        <div class="cell c-date">
          <span class="skeleton" style="width: 74px; height: 12px" />
        </div>
      </div>
    </div>

    <template v-else>
      <!-- Empty states: filtered-empty vs nothing-at-all -->
      <div v-if="findings.length === 0" class="empty">
        <template v-if="hasAny">
          <p class="empty-title">No findings match the current filters</p>
          <button class="btn btn-sm" type="button" @click="emit('clear')">
            Clear filters
          </button>
        </template>
        <template v-else>
          <p class="empty-title">No findings recorded for this organization</p>
          <p class="empty-sub">
            A clean report — or the next scan hasn't run yet. New findings
            appear here as audits complete.
          </p>
        </template>
      </div>

      <template v-else>
        <div class="row thead" aria-hidden="true">
          <div class="cell c-sev">Severity</div>
          <div class="cell c-title">Finding</div>
          <div class="cell c-cvss">CVSS</div>
          <div class="cell c-effort">Effort</div>
          <div class="cell c-date">Detected</div>
        </div>

        <div>
          <div
            v-for="f in findings"
            :key="f.id"
            class="row"
            role="button"
            tabindex="0"
            @click="emit('select', f)"
            @keydown.enter.prevent="emit('select', f)"
            @keydown.space.prevent="emit('select', f)"
          >
            <div class="cell c-sev">
              <SeverityBadge :severity="f.severity" />
            </div>
            <div class="cell c-title">
              <p class="title">{{ f.title }}</p>
              <p class="asset mono">
                {{ f.asset }}<template v-if="f.affected_component"> · {{ f.affected_component }}</template>
              </p>
            </div>
            <div class="cell c-cvss mono" :class="f.severity">
              {{ f.cvss.toFixed(1) }}
            </div>
            <div class="cell c-effort">
              <EffortChip :effort="f.rootCause.fix_available ? f.rootCause.fix_effort : null" />
            </div>
            <div class="cell c-date mono">{{ formatDate(f.detected_at) }}</div>
          </div>
        </div>
      </template>
    </template>
  </div>
</template>

<style scoped>
.table {
  overflow: hidden;
}

.row {
  display: grid;
  grid-template-columns: 6.4rem minmax(0, 1fr) 3.2rem 6.8rem 5.5rem;
  grid-template-areas: 'sev title cvss effort date';
  gap: 1rem;
  align-items: center;
  padding: 0.85rem 1.25rem;
  cursor: pointer;
  transition: background-color 0.13s ease;
}
.row:not(:last-child) { border-bottom: 1px solid var(--border); }
.row:hover { background: var(--bg-hover); }
.row:focus-visible {
  outline: 2px solid var(--accent);
  outline-offset: -2px;
}

.thead {
  cursor: default;
  padding-top: 0.7rem;
  padding-bottom: 0.7rem;
  background: var(--bg-raised);
}
.thead:hover { background: var(--bg-raised); }
.thead .cell {
  font-size: var(--text-2xs);
  font-weight: 500;
  text-transform: uppercase;
  letter-spacing: 0.12em;
  color: var(--text-faint);
}

.cell { min-width: 0; }
.c-sev    { grid-area: sev; }
.c-title  { grid-area: title; }
.c-cvss   { grid-area: cvss; text-align: right; font-weight: 500; color: var(--c); }
.c-effort { grid-area: effort; }
.c-date   { grid-area: date; text-align: right; color: var(--text-muted); font-size: var(--text-xs); }

.title {
  font-size: var(--text-sm);
  font-weight: 500;
  color: var(--text);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.asset {
  margin-top: 2px;
  font-size: var(--text-2xs);
  color: var(--text-faint);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.c-cvss.critical { --c: var(--sev-critical); }
.c-cvss.high     { --c: var(--sev-high); }
.c-cvss.medium   { --c: var(--sev-medium); }
.c-cvss.low      { --c: var(--sev-low); }

.empty {
  padding: 3rem 1.5rem;
  display: grid;
  gap: 0.8rem;
  justify-items: center;
  text-align: center;
}
.empty-title {
  font-size: var(--text-sm);
  font-weight: 500;
  color: var(--text-muted);
}
.empty-sub {
  font-size: var(--text-xs);
  color: var(--text-faint);
  line-height: 1.6;
  max-width: 26rem;
}

/* Mobile: rows become cards, header hidden — each card labels itself. */
@media (max-width: 720px) {
  .row {
    grid-template-columns: minmax(0, 1fr) auto;
    grid-template-areas:
      'sev    date'
      'title  title'
      'cvss   effort';
    gap: 0.5rem 0.75rem;
    padding: 0.9rem 1rem;
  }
  .thead { display: none; }
  .c-cvss { text-align: left; font-size: var(--text-base); }
  .c-effort { justify-self: end; }
  .c-date { color: var(--text-faint); }
}
</style>
