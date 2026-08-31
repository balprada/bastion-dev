<script setup lang="ts">
import type { ScopedFinding, Severity } from '~/types'
import { FIX_EFFORT_LABELS, FIX_METHOD_LABELS } from '~/utils/labels'

const props = defineProps<{ finding: ScopedFinding | null }>()
const emit = defineEmits<{ close: [] }>()

const closeBtn = ref<HTMLButtonElement | null>(null)
const drawerEl = ref<HTMLElement | null>(null)
let restoreFocus: HTMLElement | null = null

const BANDS: Record<Severity, string> = {
  critical: '9.0 – 10.0',
  high: '7.0 – 8.9',
  medium: '4.0 – 6.9',
  low: '0.0 – 3.9'
}

function onKeydown(e: KeyboardEvent) {
  if (e.key === 'Escape') {
    emit('close')
    return
  }

  // Tab trap: aria-modal="true" promises focus stays in the dialog.
  if (e.key !== 'Tab') return
  const root = drawerEl.value
  if (!root) return

  const focusables = Array.from(
    root.querySelectorAll<HTMLElement>(
      'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
    )
  ).filter((el) => !el.hasAttribute('disabled'))

  if (focusables.length === 0) return

  const first = focusables[0]
  const last = focusables[focusables.length - 1]
  const active = document.activeElement

  if (e.shiftKey && (active === first || active === root)) {
    e.preventDefault()
    last.focus()
  } else if (!e.shiftKey && active === last) {
    e.preventDefault()
    first.focus()
  } else if (active !== root && !root.contains(active)) {
    e.preventDefault()
    first.focus()
  }
}

watch(
  () => props.finding,
  (f, prev) => {
    if (f) {
      if (!prev) {
        restoreFocus = (document.activeElement as HTMLElement) ?? null
        document.body.style.overflow = 'hidden'
        nextTick(() => closeBtn.value?.focus())
      }
      document.addEventListener('keydown', onKeydown)
    } else if (prev) {
      document.removeEventListener('keydown', onKeydown)
      document.body.style.overflow = ''
      restoreFocus?.focus?.()
      restoreFocus = null
    }
  }
)

onBeforeUnmount(() => {
  document.removeEventListener('keydown', onKeydown)
  if (props.finding) document.body.style.overflow = ''
})
</script>

<template>
  <Teleport to="body">
    <Transition name="fade">
      <div v-if="finding" class="backdrop" @click="emit('close')" />
    </Transition>

    <Transition name="drawer">
      <aside
        v-if="finding"
        ref="drawerEl"
        class="drawer"
        role="dialog"
        aria-modal="true"
        :aria-label="finding.title"
      >
        <header class="drawer-head">
          <div class="badges">
            <SeverityBadge :severity="finding.severity" />
            <span class="rc-chip mono">{{ finding.rootCause.code }}</span>
          </div>
          <button
            ref="closeBtn"
            type="button"
            class="close"
            aria-label="Close details"
            @click="emit('close')"
          >
            ✕
          </button>
        </header>

        <div class="drawer-body">
          <h2 class="title">{{ finding.title }}</h2>
          <p class="asset mono">
            {{ finding.asset }}<template v-if="finding.affected_component"> · {{ finding.affected_component }}</template>
          </p>

          <p class="scope mono">
            {{ finding.department.name }} › {{ finding.project.name }} ›
            {{ finding.team.name }}
          </p>

          <div class="meta">
            <div class="meta-item">
              <p class="meta-label">CVSS</p>
              <p class="score mono" :class="finding.severity">
                {{ finding.cvss.toFixed(1) }}
              </p>
              <p class="band mono">{{ BANDS[finding.severity] }}</p>
            </div>
            <div class="meta-item">
              <p class="meta-label">Detected</p>
              <p class="meta-value mono">{{ formatDateTime(finding.detected_at) }}</p>
            </div>
            <div class="meta-item">
              <p class="meta-label">Finding ID</p>
              <p class="meta-value mono">#{{ shortId(finding.id) }}</p>
            </div>
          </div>

          <div class="divider" />

          <p class="meta-label">Description</p>
          <p class="description">{{ finding.description }}</p>

          <!-- Root cause: the remediation intel — why it exists and what
               kills it. This is the auditor's value-add. -->
          <div class="rc-card">
            <p class="meta-label">Root cause</p>
            <p class="rc-title-row">
              <span class="rc-code mono">{{ finding.rootCause.code }}</span>
              <span class="rc-name">{{ finding.rootCause.title }}</span>
            </p>
            <ul class="rc-facts mono">
              <li>
                fix available:
                <template v-if="finding.rootCause.fix_available">
                  <span class="yes">✓ yes</span>
                </template>
                <template v-else>
                  <span class="no">✗ not yet</span>
                </template>
              </li>
              <li v-if="finding.rootCause.fix_available && finding.rootCause.fix_method">
                method: {{ FIX_METHOD_LABELS[finding.rootCause.fix_method] }}
              </li>
              <li v-if="finding.rootCause.fix_available && finding.rootCause.fix_effort">
                effort: {{ FIX_EFFORT_LABELS[finding.rootCause.fix_effort] }}
              </li>
              <li>first discovered: {{ formatDate(finding.rootCause.first_discovered) }}</li>
            </ul>
            <p v-if="finding.rootCause.workaround" class="rc-workaround">
              <span class="wk-label mono">workaround</span>
              {{ finding.rootCause.workaround }}
            </p>
          </div>
        </div>

        <footer class="drawer-foot mono">
          Visible only to members of this organization — enforced by Postgres
          row-level security.
        </footer>
      </aside>
    </Transition>
  </Teleport>
</template>

<style scoped>
.backdrop {
  position: fixed;
  inset: 0;
  z-index: 90;
  background: rgba(4, 6, 9, 0.62);
  backdrop-filter: blur(2px);
  -webkit-backdrop-filter: blur(2px);
}

.drawer {
  position: fixed;
  top: 0;
  right: 0;
  bottom: 0;
  z-index: 100;
  width: min(30rem, 100vw);
  display: flex;
  flex-direction: column;
  background: var(--bg-overlay);
  border-left: 1px solid var(--border-strong);
  box-shadow: -24px 0 48px rgba(0, 0, 0, 0.35);
}

.drawer-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  padding: 1rem 1.4rem;
  border-bottom: 1px solid var(--border);
}
.badges {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  flex-wrap: wrap;
}
.rc-chip {
  font-size: var(--text-2xs);
  color: var(--text-muted);
  border: 1px solid var(--border-strong);
  border-radius: 6px;
  padding: 0.22rem 0.5rem;
}

.close {
  flex-shrink: 0;
  width: 32px;
  height: 32px;
  border-radius: 8px;
  border: 1px solid var(--border-strong);
  background: var(--bg-raised);
  color: var(--text-muted);
  font-size: 13px;
  line-height: 1;
  cursor: pointer;
  transition: background-color 0.15s ease, color 0.15s ease;
}
.close:hover { background: var(--bg-hover); color: var(--text); }

.drawer-body {
  flex: 1;
  overflow-y: auto;
  padding: 1.4rem;
}

.title {
  font-size: var(--text-lg);
  font-weight: 600;
  line-height: 1.35;
}
.asset {
  margin-top: 0.45rem;
  font-size: var(--text-xs);
  color: var(--text-muted);
  overflow-wrap: anywhere;
}
.scope {
  margin-top: 0.5rem;
  font-size: var(--text-2xs);
  color: var(--text-faint);
  overflow-wrap: anywhere;
}

.meta {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 1rem;
  margin-top: 1.4rem;
}
.meta-label {
  font-size: var(--text-2xs);
  font-weight: 500;
  text-transform: uppercase;
  letter-spacing: 0.12em;
  color: var(--text-faint);
  margin-bottom: 0.35rem;
}
.meta-value {
  font-size: var(--text-sm);
  color: var(--text);
}
.score {
  font-size: 1.7rem;
  font-weight: 600;
  line-height: 1;
  color: var(--c);
}
.band {
  margin-top: 0.35rem;
  font-size: var(--text-2xs);
  color: var(--text-faint);
}

.score.critical { --c: var(--sev-critical); }
.score.high     { --c: var(--sev-high); }
.score.medium   { --c: var(--sev-medium); }
.score.low      { --c: var(--sev-low); }

.divider {
  height: 1px;
  background: var(--border);
  margin: 1.4rem 0;
}

.description {
  font-size: var(--text-sm);
  color: var(--text-muted);
  line-height: 1.7;
}

/* ---- root-cause card ---- */

.rc-card {
  margin-top: 1.4rem;
  border: 1px solid var(--border);
  border-left: 2px solid var(--accent);
  border-radius: 0 var(--radius-sm) var(--radius-sm) 0;
  background: var(--bg-raised);
  padding: 0.9rem 1.1rem;
}

.rc-title-row {
  display: flex;
  align-items: baseline;
  gap: 0.6rem;
  flex-wrap: wrap;
}
.rc-code {
  font-size: var(--text-xs);
  color: var(--accent);
}
.rc-name {
  font-size: var(--text-sm);
  font-weight: 500;
}

.rc-facts {
  list-style: none;
  margin: 0.6rem 0 0;
  padding: 0;
  display: grid;
  gap: 0.25rem;
  font-size: var(--text-2xs);
  color: var(--text-muted);
}
.yes { color: var(--accent); }
.no { color: var(--text-muted); }

.rc-workaround {
  margin-top: 0.7rem;
  padding-top: 0.6rem;
  border-top: 1px dashed var(--border-strong);
  font-size: var(--text-xs);
  color: var(--text-muted);
  line-height: 1.6;
}
.wk-label {
  display: block;
  font-size: var(--text-2xs);
  text-transform: uppercase;
  letter-spacing: 0.1em;
  color: var(--text-faint);
  margin-bottom: 0.2rem;
}

.drawer-foot {
  padding: 0.9rem 1.4rem;
  border-top: 1px solid var(--border);
  font-size: var(--text-2xs);
  color: var(--text-faint);
  line-height: 1.6;
}

.drawer-enter-active,
.drawer-leave-active {
  transition: transform 0.28s cubic-bezier(0.2, 0.8, 0.2, 1);
}
.drawer-enter-from,
.drawer-leave-to {
  transform: translateX(100%);
}
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.25s ease;
}
.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}

@media (max-width: 520px) {
  .meta {
    grid-template-columns: minmax(0, 1fr) minmax(0, 1fr);
  }
  .meta-item:nth-child(2) {
    grid-column: 1 / -1;
  }
}
</style>
