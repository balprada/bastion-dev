import type { User } from '@supabase/supabase-js'

export interface OrgInfo {
  id: string
  slug: string
  name: string
  role: string
}

// One shared session + org state for the whole app (topbar, middleware,
// dashboard). init() is idempotent: every caller awaits the same promise,
// and the auth listener is registered exactly once.
// Module scope is safe because ssr:false keeps this per-browser.
let initPromise: Promise<void> | null = null

export function useSession() {
  const user = useState<User | null>('bastion:user', () => null)
  const org = useState<OrgInfo | null>('bastion:org', () => null)
  const ready = useState<boolean>('bastion:ready', () => false)

  async function loadOrg(): Promise<void> {
    const supabase = useSupabase()

    // RLS in action even here: this query can only ever return the caller's
    // own membership row. The topbar's org chip is tenant-scoped by the
    // database, not by the UI.
    const { data, error } = await supabase
      .from('members')
      .select('role, organizations(id, slug, name)')
      .limit(1)

    if (error) {
      console.error('[session] could not load org membership:', error.message)
      org.value = null
      return
    }

    const row = data?.[0]
    org.value = row?.organizations
      ? {
          id: row.organizations.id,
          slug: row.organizations.slug,
          name: row.organizations.name,
          role: row.role
        }
      : null
  }

  // Restores any persisted session, then keeps state reactive for
  // sign-in / sign-out / token refresh. Never rejects — a failed init
  // means "treat as signed out"; the login page surfaces real errors.
  function init(): Promise<void> {
    if (!initPromise) {
      initPromise = (async () => {
        try {
          const supabase = useSupabase()

          const { data } = await supabase.auth.getSession()
          user.value = data.session?.user ?? null
          if (data.session) await loadOrg()

          supabase.auth.onAuthStateChange((event, session) => {
            user.value = session?.user ?? null

            // Null the org FIRST on sign-in: when the demo switches from
            // org A's user to org B's user, the old chip must vanish
            // immediately, before the new org resolves.
            if (event === 'SIGNED_IN') {
              org.value = null
              void loadOrg()
            }
            if (event === 'SIGNED_OUT') {
              org.value = null
            }
            // TOKEN_REFRESHED / USER_UPDATED only refresh `user` above.
          })
        } catch (err) {
          console.error('[session] init failed:', err)
        } finally {
          ready.value = true
        }
      })()
    }
    return initPromise
  }

  async function signOut(): Promise<void> {
    const supabase = useSupabase()
    const { error } = await supabase.auth.signOut()
    if (error) console.error('[session] sign-out failed:', error.message)
  }

  return { user, org, ready, init, signOut, loadOrg }
}
