<script setup lang="ts">
import type { Finding } from '~/types'

const props = defineProps<{
  findings: Finding[]
  loading?: boolean
  hasAny?: boolean
}>()

const emit = defineEmits<{
  select: [finding: Finding]
  clear: []
}>()

const SKELETON_ROWS = 8
// Deterministic width variety so skeleton rows don't look copy-pasted.
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
        <div class="cell c-status">
          <span class="skeleton" style="width: 92px; height: 20px; border-radius: 999px" />
        </div>
        <div class="cell c-date">
          <span class="skeleton" style="width: 74px; height: 12px" />
        </div>
      </div>
    </div>

    <template v-else>
      <!-- Empty states: distinguish "no results from filters" vs "org has nothing" -->
      <div v-if="findings.length === 0" class="empty">
        <template v-if="hasAny">
          <p class="empty-title">No findings match the current filters</p>
          <button class="btn btn-sm" type="button" @click="emit('clear')">Clear filters</button>
        </template>
        <template v-else>
          <p class="empty-title">No findings recorded yet</p>
          <p class="empty-sub">
            New scan results for this organization will appear here.
          </p>
        </template>
      </div>

      <template v-else>
        <!-- Header (desktop only — rows become cards on mobile) -->
        <div class="row thead" aria-hidden="true">
          <div class="cell c-sev">Severity</div>
          <div class="cell c-title">Finding</div>
          <div class="cell c-cvss">CVSS</div>
          <div class="cell c-status">Status</div>
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
              <p class="asset mono">{{ f.asset }}</p>
            </div>
            <div class="cell c-cvss mono" :class="f.severity">
              {{ f.cvss.toFixed(1) }}
            </div>
            <div class="cell c-status">
              <StatusPill :status="f.status" />
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
  overflow: hidden; /* clip row hover at the rounded corners */
}

.row {
  display: grid;
  grid-template-columns: 6.4rem minmax(0, 1fr) 3.4rem 7.4rem 6rem;
  grid-template-areas: 'sev title cvss status date';
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
.c-status { grid-area: status; }
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

/* CVSS score colored by its severity — functional color, same palette. */
.c-cvss.critical { --c: var(--sev-critical); }
.c-cvss.high     { --c: var(--sev-high); }
.c-cvss.medium   { --c: var(--sev-medium); }
.c-cvss.low      { --c: var(--sev-low); }

/* Empty states */
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

/* Mobile: rows become cards. Header hidden — each card labels itself. */
@media (max-width: 720px) {
  .row {
    grid-template-columns: minmax(0, 1fr) auto;
    grid-template-areas:
      'sev   date'
      'title title'
      'cvss  status';
    gap: 0.5rem 0.75rem;
    padding: 0.9rem 1rem;
  }
  .thead { display: none; }
  .c-cvss { text-align: left; font-size: var(--text-base); }
  .c-status { justify-self: end; }
  .c-date { color: var(--text-faint); }
}
</style>
