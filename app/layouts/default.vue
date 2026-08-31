<script setup lang="ts">
// App shell: sticky topbar, content slot, slim footer.
// init() is idempotent — the auth middleware (Step 4) awaits the same
// promise, so this just guarantees the topbar reacts on every route.
const { user, org, ready, init, signOut } = useSession()
const signingOut = ref(false)

onMounted(() => {
  void init()
})

async function handleSignOut() {
  if (signingOut.value) return
  signingOut.value = true
  await signOut()
  signingOut.value = false
  await navigateTo('/login')
}
</script>

<template>
  <div class="shell">
    <header class="topbar">
      <div class="topbar-inner">
        <NuxtLink to="/" class="brand" aria-label="Bastion — home">
          <svg width="20" height="20" viewBox="0 0 32 32" fill="none" aria-hidden="true">
            <path
              d="M16 5.5l7.5 2.8v5.9c0 4.8-3.2 8.9-7.5 10.3-4.3-1.4-7.5-5.5-7.5-10.3V8.3L16 5.5z"
              stroke="currentColor" stroke-width="1.8" stroke-linejoin="round" />
            <circle cx="16" cy="14.2" r="2.1" fill="currentColor" />
            <path d="M16 17v3.2" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" />
          </svg>
          <span class="brand-name">Bastion</span>
          <!-- <span class="brand-tag mono">findings console</span> -->
          <span class="brand-tag mono">Audit Portal</span>
        </NuxtLink>

        <nav class="nav" aria-label="Primary">
          <NuxtLink to="/" class="nav-link">Findings</NuxtLink>
          <NuxtLink to="/about" class="nav-link">About</NuxtLink>
        </nav>

        <div class="session">
          <template v-if="ready">
            <template v-if="user">
              <span v-if="org" class="org-chip" :title="`Organization: ${org.name}`">
                <span class="org-dot" />
                {{ org.name }}
              </span>
              <span class="user-email mono" :title="user.email ?? ''">{{ user.email }}</span>
              <button
                class="btn btn-sm"
                :disabled="signingOut"
                @click="handleSignOut"
              >
                {{ signingOut ? 'Signing out…' : 'Sign out' }}
              </button>
            </template>
          </template>
          <span v-else class="session-skeleton skeleton" aria-hidden="true" />
        </div>
      </div>
    </header>

    <main class="content">
      <slot />
    </main>

    <footer class="footer">
      <span class="mono">bastion · audit portal · synthetic findings</span>
      <span class="mono">tenant isolation: postgres row-level security</span>
    </footer>
  </div>
</template>

<style scoped>
.shell {
  min-height: 100dvh;
  display: flex;
  flex-direction: column;
}

/* z-index 40 — the detail drawer (Step 5) layers above at 100. */
.topbar {
  position: sticky;
  top: 0;
  z-index: 40;
  background: rgba(10, 13, 18, 0.82);
  backdrop-filter: blur(10px);
  -webkit-backdrop-filter: blur(10px);
  border-bottom: 1px solid var(--border);
}

.topbar-inner {
  max-width: 1200px;
  margin: 0 auto;
  height: 56px;
  padding: 0 1.5rem;
  display: flex;
  align-items: center;
  gap: 1.5rem;
}

.brand {
  display: inline-flex;
  align-items: center;
  gap: 0.55rem;
  color: var(--text);
  text-decoration: none;
  min-width: 0;
}
.brand svg { color: var(--accent); flex-shrink: 0; }
.brand-name { font-weight: 600; font-size: 1rem; letter-spacing: 0.01em; }
.brand-tag {
  color: var(--text-faint);
  font-size: var(--text-2xs);
  border: 1px solid var(--border);
  border-radius: 4px;
  padding: 0.1rem 0.4rem;
  white-space: nowrap;
}

.nav {
  display: flex;
  gap: 0.25rem;
  height: 100%;
}
.nav-link {
  display: inline-flex;
  align-items: center;
  padding: 0 0.75rem;
  font-size: var(--text-sm);
  font-weight: 500;
  color: var(--text-muted);
  text-decoration: none;
  border-bottom: 2px solid transparent;
  transition: color 0.15s ease;
}
.nav-link:hover { color: var(--text); }
.nav-link.router-link-active {
  color: var(--text);
  border-bottom-color: var(--accent);
}

.session {
  margin-left: auto;
  display: flex;
  align-items: center;
  gap: 0.75rem;
  min-width: 0;
}

.org-chip {
  display: inline-flex;
  align-items: center;
  gap: 0.45rem;
  padding: 0.3rem 0.65rem;
  border-radius: 999px;
  background: var(--accent-dim);
  border: 1px solid var(--accent-border);
  font-size: var(--text-xs);
  font-weight: 500;
  color: var(--text);
  white-space: nowrap;
}
.org-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: var(--accent);
  box-shadow: 0 0 6px var(--accent);
}

.user-email {
  color: var(--text-muted);
  font-size: var(--text-xs);
  max-width: 220px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.session-skeleton {
  width: 160px;
  height: 26px;
  border-radius: 999px;
}

.content {
  flex: 1;
  width: 100%;
  max-width: 1200px;
  margin: 0 auto;
  padding: 1.75rem 1.5rem 3rem;
}

.footer {
  width: 100%;
  max-width: 1200px;
  margin: 0 auto;
  padding: 0.8rem 1.5rem;
  border-top: 1px solid var(--border);
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  flex-wrap: wrap;
  color: var(--text-faint);
  font-size: var(--text-2xs);
}

@media (max-width: 720px) {
  .topbar-inner { padding: 0 1rem; gap: 1rem; }
  .brand-tag { display: none; }
  .user-email { display: none; }
  .content { padding: 1.25rem 1rem 2rem; }
  .footer { padding: 0.8rem 1rem; }
}
</style>
