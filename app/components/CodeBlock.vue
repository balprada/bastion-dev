<script setup lang="ts">
const props = defineProps<{
  code: string
  filename?: string
}>()

const copied = ref(false)
let timer: ReturnType<typeof setTimeout> | undefined

async function copy() {
  try {
    await navigator.clipboard.writeText(props.code)
    copied.value = true
    if (timer) clearTimeout(timer)
    timer = setTimeout(() => (copied.value = false), 1500)
  } catch {
    // Clipboard unavailable (permissions / insecure context) — skip silently.
  }
}

onBeforeUnmount(() => {
  if (timer) clearTimeout(timer)
})

// SQL comment lines (first non-space chars are --) render dimmed — the
// comments are documentation, not code, and should read that way.
const lines = computed(() =>
  props.code
    .replace(/\n$/, '')
    .split('\n')
    .map((text) => ({ text, comment: /^\s*--/.test(text) }))
)
</script>

<template>
  <figure class="code panel">
    <figcaption class="head">
      <span v-if="filename" class="filename mono">{{ filename }}</span>
      <span v-else class="filename-spacer" aria-hidden="true" />
      <button class="copy mono" type="button" aria-label="Copy code" @click="copy">
        {{ copied ? 'copied ✓' : 'copy' }}
      </button>
    </figcaption>
    <pre><code><span
      v-for="(line, i) in lines"
      :key="i"
      class="line"
      :class="{ comment: line.comment }"
    >{{ line.text || ' ' }}</span></code></pre>
  </figure>
</template>

<style scoped>
.code {
  overflow: hidden;
}

.head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  padding: 0.5rem 0.6rem 0.5rem 1rem;
  border-bottom: 1px solid var(--border);
  background: var(--bg);
}

.filename {
  font-size: var(--text-2xs);
  color: var(--text-muted);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.filename-spacer { flex: 1; }

.copy {
  flex-shrink: 0;
  background: none;
  border: 1px solid var(--border-strong);
  border-radius: 6px;
  color: var(--text-faint);
  font-size: var(--text-2xs);
  text-transform: uppercase;
  letter-spacing: 0.08em;
  padding: 0.22rem 0.6rem;
  cursor: pointer;
  transition: color 0.15s ease, border-color 0.15s ease;
}
.copy:hover {
  color: var(--text);
  border-color: var(--text-faint);
}

pre {
  margin: 0;
  padding: 1rem;
  overflow-x: auto;
  font-family: var(--font-mono);
  font-size: var(--text-xs);
  line-height: 1.7;
  color: var(--text);
}

.line {
  display: block;
  white-space: pre;
}
.line.comment {
  color: var(--text-faint);
}
</style>
