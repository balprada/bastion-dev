<script setup lang="ts">
import type { FacetGroup, FacetId } from '~/types'

const props = defineProps<{
  groups: FacetGroup[]
  selections: Record<FacetId, string[]>
  resultCount: number
  totalCount: number
  loading?: boolean
  open?: boolean
}>()

const emit = defineEmits<{
  toggle: [id: FacetId, value: string]
  clear: [id: FacetId]
  reset: []
  close: []
}>()

// Long facets cap at 8 rows; "+N more" expands. Nothing is ever removed —
// the hierarchy scopes what's shown, the cap defers the rest.
const MAX = 8
const expanded = reactive<Record<string, boolean>>({})

function shown(g: FacetGroup) {
  return expanded[g.id] ? g.options : g.options.slice(0, MAX)
}

function isSelected(g: FacetGroup, v: string) {
  return props.selections[g.id]?.includes(v) ?? false
}

function activeCount(g: FacetGroup) {
  return props.selections[g.id]?.length ?? 0
}

const anyActive = computed(() => props.groups.some((g) => activeCount(g) > 0))

// Viewport awareness: sticky column on desktop, slide-over on mobile.
const isMobile = ref(false)
let mq: MediaQueryList | undefined

function onMq(e: MediaQueryListEvent) {
  isMobile.value = e.matches
}

onMounted(() => {
  mq = window.matchMedia('(max-width: 960px)')
  isMobile.value = mq.matches
  mq.addEventListener('change', onMq)
})

function onEsc(e: KeyboardEvent) {
  if (e.key === 'Escape' && props.open) emit('close')
}

watch(
  () => props.open,
  (v) => {
    if (v) document.addEventListener('keydown', onEsc)
    else document.removeEventListener('keydown', onEsc)
  }
)

onBeforeUnmount(() => {
  mq?.removeEventListener('change', onMq)
  document.removeEventListener('keydown', onEsc)
})
</script>

<template>
  <div v-if="open && isMobile" class="backdrop" @click="emit('close')" />

  <aside class="rail panel" :class="{ open: open }" :aria-hidden="isMobile && !open">
    <header class="rail-head">
      <p class="rail-title">Filters</p>
      <button class="reset mono" type="button" :disabled="!anyActive" @click="emit('reset')">
        reset all
      </button>
      <button
        v-if="isMobile"
        class="close"
        type="button"
        aria-label="Close filters"
        @click="emit('close')"
      >
        ✕
      </button>
    </header>

    <p class="rail-count mono" aria-live="polite">
      showing {{ resultCount }} of {{ totalCount }} findings
    </p>

    <div v-if="loading" class="rail-loading" aria-hidden="true">
      <div v-for="i in 10" :key="i" class="skeleton skel" />
    </div>

    <div v-else class="rail-groups">
      <section v-for="g in groups" :key="g.id" class="group">
        <header class="group-head">
          <span class="group-label">{{ g.label }}</span>
          <span v-if="activeCount(g)" class="group-badge mono">
            {{ activeCount(g) }}
          </span>
          <!-- Per-group clear: exists ONLY while this group has selections —
               affordance on demand, zero noise at rest. -->
          <button
            v-if="activeCount(g)"
            class="gclear mono"
            type="button"
            :aria-label="`Clear ${g.label} filter`"
            @click="emit('clear', g.id)"
          >
            clear
          </button>
        </header>

        <p v-if="g.scopedNote" class="group-note mono">// {{ g.scopedNote }}</p>

        <ul class="opts">
          <li v-for="o in shown(g)" :key="o.value">
            <button
              type="button"
              class="opt"
              :class="{ selected: isSelected(g, o.value) }"
              :aria-pressed="isSelected(g, o.value)"
              @click="emit('toggle', g.id, o.value)"
            >
              <span v-if="o.tone" class="dot" :class="o.tone" aria-hidden="true" />
              <span class="opt-main">
                <span class="opt-label">{{ o.label }}</span>
                <span v-if="o.sub" class="opt-sub">{{ o.sub }}</span>
              </span>
              <span class="opt-count mono">{{ o.count }}</span>
            </button>
          </li>
        </ul>

        <button
          v-if="g.options.length > MAX"
          type="button"
          class="more mono"
          @click="expanded[g.id] = !expanded[g.id]"
        >
          {{ expanded[g.id] ? '− show less' : `+ ${g.options.length - MAX} more` }}
        </button>
      </section>
    </div>

    <button
      v-if="isMobile"
      class="btn btn-primary done"
      type="button"
      @click="emit('close')"
    >
      Show {{ resultCount }} findings
    </button>
  </aside>
</template>

<style scoped>
/* Desktop: sticky column beside the table. Mobile (≤960px): slide-over. */
.rail {
  position: sticky;
  top: 72px;
  align-self: start;
  max-height: calc(100dvh - 90px);
  overflow-y: auto;
  display: flex;
  flex-direction: column;
}

.rail-head {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  padding: 0.85rem 1rem 0.6rem;
}
.rail-title {
  font-size: var(--text-sm);
  font-weight: 600;
}
.reset {
  margin-left: auto;
  background: none;
  border: 1px solid var(--border-strong);
  border-radius: 6px;
  color: var(--accent);
  font-size: var(--text-2xs);
  text-transform: uppercase;
  letter-spacing: 0.08em;
  cursor: pointer;
  padding: 0.22rem 0.55rem;
  transition: border-color 0.15s ease, color 0.15s ease;
}
.reset:hover:not(:disabled) {
  border-color: var(--accent-border);
}
.reset:disabled {
  color: var(--text-faint);
  border-color: var(--border);
  cursor: default;
}
.close {
  width: 28px;
  height: 28px;
  border-radius: 7px;
  border: 1px solid var(--border-strong);
  background: var(--bg-raised);
  color: var(--text-muted);
  cursor: pointer;
}

.rail-count {
  padding: 0 1rem 0.75rem;
  border-bottom: 1px solid var(--border);
  font-size: var(--text-2xs);
  color: var(--text-faint);
}

.rail-loading {
  padding: 1rem;
  display: grid;
  gap: 0.55rem;
}
.skel {
  height: 14px;
  width: 100%;
}
.skel:nth-child(3n) {
  width: 65%;
}

.rail-groups {
  padding: 0.35rem 0.6rem 0.9rem;
}

.group {
  padding: 0.55rem 0.4rem 0.5rem;
  border-bottom: 1px solid var(--border);
}
.group:last-child {
  border-bottom: none;
}

.group-head {
  display: flex;
  align-items: center;
  gap: 0.45rem;
}
.group-label {
  font-size: var(--text-2xs);
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.1em;
  color: var(--text-muted);
}
.group-badge {
  font-size: var(--text-2xs);
  color: var(--on-accent);
  background: var(--accent);
  border-radius: 999px;
  padding: 0.02rem 0.45rem;
}
.gclear {
  margin-left: auto;
  background: none;
  border: none;
  color: var(--text-faint);
  font-size: var(--text-2xs);
  text-transform: uppercase;
  letter-spacing: 0.06em;
  cursor: pointer;
  padding: 0.1rem 0.25rem;
}
.gclear:hover {
  color: var(--text);
}

.group-note {
  margin-top: 0.25rem;
  font-size: var(--text-2xs);
  color: var(--text-faint);
}

.opts {
  list-style: none;
  margin: 0.3rem 0 0;
  padding: 0;
  display: grid;
  gap: 1px;
}

.opt {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  width: 100%;
  text-align: left;
  padding: 0.3rem 0.45rem;
  border: 1px solid transparent;
  border-radius: 6px;
  background: transparent;
  color: var(--text);
  cursor: pointer;
  transition: background-color 0.12s ease, border-color 0.12s ease;
}
.opt:hover {
  background: var(--bg-hover);
}
.opt.selected {
  background: var(--accent-dim);
  border-color: var(--accent-border);
}

.dot {
  width: 7px;
  height: 7px;
  border-radius: 2px;
  flex-shrink: 0;
}
.dot.critical { background: var(--sev-critical); }
.dot.high     { background: var(--sev-high); }
.dot.medium   { background: var(--sev-medium); }
.dot.low      { background: var(--sev-low); }

.opt-main {
  min-width: 0;
  flex: 1;
  display: grid;
}
.opt-label {
  font-size: var(--text-xs);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.opt-sub {
  font-size: var(--text-2xs);
  color: var(--text-faint);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.opt-count {
  flex-shrink: 0;
  font-size: var(--text-2xs);
  color: var(--text-muted);
  background: var(--bg);
  border: 1px solid var(--border);
  border-radius: 5px;
  padding: 0.02rem 0.35rem;
}

.more {
  margin-top: 0.35rem;
  background: none;
  border: none;
  color: var(--text-faint);
  font-size: var(--text-2xs);
  cursor: pointer;
  padding: 0.15rem 0.45rem;
}
.more:hover {
  color: var(--text);
}

.done {
  margin: 0.75rem;
}

/* ---- mobile slide-over ---- */

.backdrop {
  position: fixed;
  inset: 0;
  z-index: 108;
  background: rgba(4, 6, 9, 0.62);
}

@media (max-width: 960px) {
  .rail {
    position: fixed;
    top: 0;
    right: 0;
    bottom: 0;
    z-index: 112;
    width: min(20rem, 88vw);
    max-height: none;
    border-radius: 0;
    border-left: 1px solid var(--border-strong);
    background: var(--bg-overlay);
    transform: translateX(100%);
    transition: transform 0.28s cubic-bezier(0.2, 0.8, 0.2, 1);
  }
  .rail.open {
    transform: none;
  }
  .rail-groups {
    flex: 1;
    overflow-y: auto;
  }
}
</style>
