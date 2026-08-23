<script setup lang="ts">
// Placeholder — the full "About this build" page (schema, RLS policy SQL,
// initplan note, setup steps) lands in Step 6. This stub exists so the
// topbar's About link never targets a missing route (console cleanliness).
</script>

<template>
  <div class="stub panel">
    <p class="mark mono">// about this build</p>
    <h1>Documentation incoming</h1>
    <p class="muted">
      Schema, RLS policy SQL and local setup steps are documented in Step 6.
      Until then they live in <span class="mono path">supabase/*.sql</span> in the repo.
    </p>
  </div>
</template>

<style scoped>
.stub {
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
  margin-bottom: 0.75rem;
}
.muted { color: var(--text-muted); font-size: var(--text-sm); line-height: 1.6; }
.path { color: var(--text); font-size: var(--text-xs); }
</style>
