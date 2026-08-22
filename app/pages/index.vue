<script setup lang="ts">
// Step 1 scaffold check only. This page is replaced by the findings dashboard in Step 5.
</script>

<template>
  <main class="check">
    <p class="mark">// BASTION</p>
    <h1>Scaffold verified</h1>
    <p>Static build works. Next: Supabase schema, RLS policies, seed data.</p>
  </main>
</template>

<style scoped>
.check {
  min-height: 100dvh;
  display: grid;
  place-content: center;
  gap: 0.4rem;
  text-align: center;
  background: #0a0d12;
  color: #e6edf3;
  font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
}
.mark {
  margin: 0;
  color: #3ddc97;
  font-size: 0.75rem;
  letter-spacing: 0.35em;
}
h1 {
  margin: 0;
  font-size: 1.2rem;
  font-weight: 600;
}
.check > p:last-child {
  margin: 0;
  color: #8b98a9;
  font-size: 0.85rem;
}
</style>
