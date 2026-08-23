<script setup lang="ts">
// Step 4 build checkpoint — proves the full auth loop end-to-end:
// sign in → session restore → org resolution → RLS-scoped data access.
// Fully replaced by the findings dashboard in Step 5.
const supabase = useSupabase()
const { user, org } = useSession()

const countState = ref<'checking' | 'ok' | 'error'>('checking')
const findingCount = ref<number | null>(null)
const countError = ref('')

onMounted(async () => {
  // Authenticated read: RLS scopes this count to the signed-in user's org.
  // ada@apex.test → 15 · sam@meridian.test → 13. This line IS the demo.
  const { count, error } = await supabase
    .from('findings')
    .select('id', { count: 'exact', head: true })

  if (error) {
    countState.value = 'error'
    countError.value = error.message
    return
  }
  countState.value = 'ok'
  findingCount.value = count ?? 0
})
</script>

<template>
  <div class="checkpoint panel">
    <p class="mark mono">// bastion — build checkpoint</p>
    <h1>Authenticated</h1>

    <ul class="checks mono">
      <li>
        <span class="sym ok">✓</span>
        supabase client initialized · env vars OK
      </li>
      <li v-if="user">
        <span class="sym ok">✓</span>
        session: {{ user.email }}
      </li>
      <li v-if="org">
        <span class="sym ok">✓</span>
        organization: {{ org.name }} · role {{ org.role }}
      </li>
      <li :class="{ pending: countState !== 'ok' }">
        <span
          class="sym"
          :class="countState === 'error' ? 'error' : countState === 'ok' ? 'ok' : 'pending'"
        >
          {{ countState === 'ok' ? '✓' : countState === 'error' ? '✗' : '·' }}
        </span>
        <template v-if="countState === 'checking'">counting findings visible to this account…</template>
        <template v-else-if="countState === 'error'">query failed: {{ countError }}</template>
        <template v-else>{{ findingCount }} findings visible to this account — RLS enforced</template>
      </li>
      <li class="pending">
        <span class="sym pending">·</span>
        next: findings dashboard (step 5)
      </li>
    </ul>

    <p class="hint">
      Sign out, then sign in as the other demo account — the count must change.
      That's row-level security doing tenant isolation, live, before the
      dashboard even exists.
    </p>
  </div>
</template>

<style scoped>
.checkpoint {
  margin-top: 3rem;
  max-width: 34rem;
  padding: 2rem 2.25rem;
}

.mark {
  color: var(--accent);
  font-size: var(--text-xs);
  letter-spacing: 0.18em;
  margin-bottom: 0.75rem;
}

h1 {
  font-size: var(--text-xl);
  font-weight: 600;
  margin-bottom: 1.25rem;
}

.checks {
  list-style: none;
  padding: 0;
  display: grid;
  gap: 0.5rem;
  font-size: var(--text-sm);
  color: var(--text-muted);
}

.sym { display: inline-block; width: 1.1rem; }
.sym.ok { color: var(--accent); }
.sym.error { color: var(--sev-critical); }
.sym.pending { color: var(--text-faint); }
li.pending { color: var(--text-faint); }

.hint {
  margin-top: 1.5rem;
  padding-top: 1.25rem;
  border-top: 1px solid var(--border);
  color: var(--text-faint);
  font-size: var(--text-xs);
  line-height: 1.6;
}
</style>
