<script setup lang="ts">
import type { AuthError } from '@supabase/supabase-js'

// Bare layout: the pre-auth screen is a centered panel — no topbar, no
// empty session area flashing a skeleton.
definePageMeta({ layout: false })

useHead({ title: 'Sign in — Bastion' })

const { user } = useSession()

// Demo accounts: one click signs in — this is the user-switch moment on the
// live call. Manual email/password entry works identically via the form.
const DEMO_PASSWORD = 'demo1234'
const demoAccounts = [
  { label: 'Apex Financial', email: 'ada@apex.test', hint: 'fintech tenant' },
  { label: 'Meridian Health', email: 'sam@meridian.test', hint: 'healthcare tenant' }
]

const email = ref('')
const password = ref('')
const showPassword = ref(false)
const busy = ref(false)
const errorMessage = ref('')

// Supabase error messages are developer-facing; the demo needs human ones.
// Match on error code (newer supabase-js) with message-text fallback (older).
function friendlyError(err: AuthError): string {
  if (err.code === 'invalid_credentials' || /invalid login credentials/i.test(err.message)) {
    return 'Invalid email or password.'
  }
  if (err.code === 'email_not_confirmed' || /email not confirmed/i.test(err.message)) {
    return 'Email not confirmed — confirm the user in Supabase Studio (Authentication → Users).'
  }
  if (err.code === 'over_request_rate_limit' || err.status === 429) {
    return 'Too many attempts — wait a few seconds and try again.'
  }
  return err.message || 'Sign-in failed. Try again.'
}

async function signIn(withEmail: string, withPassword: string) {
  if (busy.value) return
  busy.value = true
  errorMessage.value = ''

  try {
    const supabase = useSupabase()
    const { data, error } = await supabase.auth.signInWithPassword({
      email: withEmail,
      password: withPassword
    })

    if (error) {
      errorMessage.value = friendlyError(error)
      return
    }

    // The auth listener in useSession also sets this; setting it here makes
    // the middleware check on the next navigation deterministic regardless
    // of listener/promise ordering inside supabase-js.
    user.value = data.session?.user ?? data.user ?? null

    await navigateTo('/', { replace: true })
  } catch (err) {
    errorMessage.value = err instanceof Error ? err.message : 'Unexpected error. Try again.'
  } finally {
    busy.value = false
  }
}
</script>

<template>
  <div class="login-page">
    <div class="login-panel panel">
      <div class="brand-row">
        <svg width="34" height="34" viewBox="0 0 32 32" fill="none" aria-hidden="true">
          <path
            d="M16 5.5l7.5 2.8v5.9c0 4.8-3.2 8.9-7.5 10.3-4.3-1.4-7.5-5.5-7.5-10.3V8.3L16 5.5z"
            stroke="currentColor" stroke-width="1.8" stroke-linejoin="round" />
          <circle cx="16" cy="14.2" r="2.1" fill="currentColor" />
          <path d="M16 17v3.2" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" />
        </svg>
        <div>
          <p class="brand-name">Bastion</p>
          <p class="brand-sub">Security findings console</p>
        </div>
      </div>

      <form class="form" @submit.prevent="signIn(email, password)">
        <label class="field">
          <span class="label">Email</span>
          <input
            v-model="email"
            class="input"
            type="email"
            autocomplete="username"
            placeholder="you@company.test"
            required
            :disabled="busy"
          />
        </label>

        <label class="field">
          <span class="label">Password</span>
          <span class="pw-wrap">
            <input
              v-model="password"
              class="input"
              :type="showPassword ? 'text' : 'password'"
              autocomplete="current-password"
              placeholder="••••••••"
              required
              :disabled="busy"
            />
            <button
              type="button"
              class="pw-toggle mono"
              :aria-label="showPassword ? 'Hide password' : 'Show password'"
              @click="showPassword = !showPassword"
            >
              {{ showPassword ? 'hide' : 'show' }}
            </button>
          </span>
        </label>

        <p v-if="errorMessage" class="error" role="alert">{{ errorMessage }}</p>

        <button class="btn btn-primary submit" type="submit" :disabled="busy">
          {{ busy ? 'Signing in…' : 'Sign in' }}
        </button>
      </form>

      <div class="divider"><span class="mono">demo accounts</span></div>

      <div class="demo-list">
        <button
          v-for="acct in demoAccounts"
          :key="acct.email"
          type="button"
          class="demo-btn"
          :disabled="busy"
          @click="signIn(acct.email, DEMO_PASSWORD)"
        >
          <span class="demo-org">{{ acct.label }}</span>
          <span class="demo-meta mono">{{ acct.email }} · {{ acct.hint }}</span>
        </button>
      </div>

      <p class="footnote mono">
        Each account sees only its own organization's findings — enforced by
        Postgres row-level security, not by the UI.
      </p>

      <div class="about-row">
        <NuxtLink to="/about" class="about-link">About this build →</NuxtLink>
      </div>
    </div>
  </div>
</template>

<style scoped>
.login-page {
  min-height: 100dvh;
  display: grid;
  place-items: center;
  padding: 1.5rem 1rem;
}

.login-panel {
  width: 100%;
  max-width: 24rem;
  padding: 2rem 2rem 1.75rem;
}

.brand-row {
  display: flex;
  align-items: center;
  gap: 0.8rem;
  margin-bottom: 1.75rem;
}
.brand-row svg { color: var(--accent); flex-shrink: 0; }
.brand-name { font-weight: 600; font-size: var(--text-lg); line-height: 1.25; }
.brand-sub { color: var(--text-muted); font-size: var(--text-xs); }

.form { display: grid; gap: 1rem; }
.field { display: grid; gap: 0.35rem; }
.label {
  font-size: var(--text-xs);
  font-weight: 500;
  color: var(--text-muted);
  letter-spacing: 0.02em;
}

.pw-wrap { position: relative; display: block; }
.pw-toggle {
  position: absolute;
  right: 0.55rem;
  top: 50%;
  transform: translateY(-50%);
  background: none;
  border: none;
  padding: 0.25rem;
  color: var(--text-faint);
  font-size: var(--text-2xs);
  text-transform: uppercase;
  letter-spacing: 0.08em;
  cursor: pointer;
}
.pw-toggle:hover { color: var(--text); }

.error {
  background: var(--sev-critical-bg);
  border: 1px solid rgba(248, 81, 73, 0.4);
  border-radius: 8px;
  padding: 0.6rem 0.8rem;
  font-size: var(--text-sm);
  color: #ff948d;
  line-height: 1.45;
}

.submit {
  width: 100%;
  margin-top: 0.25rem;
  padding: 0.7rem;
}

.divider {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  margin: 1.5rem 0 0.9rem;
  color: var(--text-faint);
  font-size: var(--text-2xs);
  text-transform: uppercase;
  letter-spacing: 0.14em;
  white-space: nowrap;
}
.divider::before,
.divider::after {
  content: '';
  height: 1px;
  background: var(--border);
  flex: 1;
}

.demo-list { display: grid; gap: 0.5rem; }
.demo-btn {
  display: grid;
  gap: 0.15rem;
  text-align: left;
  padding: 0.7rem 0.85rem;
  background: var(--bg);
  border: 1px solid var(--border);
  border-radius: 8px;
  color: var(--text);
  cursor: pointer;
  transition: background-color 0.15s ease, border-color 0.15s ease;
}
.demo-btn:hover:not(:disabled) {
  background: var(--bg-hover);
  border-color: var(--border-strong);
}
.demo-btn:disabled { opacity: 0.55; cursor: not-allowed; }
.demo-org { font-size: var(--text-sm); font-weight: 500; }
.demo-meta { font-size: var(--text-2xs); color: var(--text-muted); }

.footnote {
  margin-top: 1.4rem;
  font-size: var(--text-2xs);
  color: var(--text-faint);
  line-height: 1.65;
  text-align: center;
}

.about-row {
  margin-top: 0.9rem;
  text-align: center;
}
.about-link {
  font-size: var(--text-xs);
  color: var(--text-faint);
  text-decoration: none;
  transition: color 0.15s ease;
}
.about-link:hover { color: var(--accent); }
</style>
