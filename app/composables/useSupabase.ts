import { createClient, type SupabaseClient } from '@supabase/supabase-js'

// Module-level singleton: one client per browser session. Safe because
// ssr:false — under SSR module scope would leak across requests.
let client: SupabaseClient | undefined

export function useSupabase(): SupabaseClient {
  if (client) return client

  const config = useRuntimeConfig()
  const url = config.public.supabaseUrl
  const key = config.public.supabaseAnonKey
  // v1 (main) sets nothing → 'public'. demo2 sets NUXT_PUBLIC_SUPABASE_SCHEMA
  // → every .from() call routes to that schema. Same URL, same anon key:
  // the schema is a routing parameter, not a credential.
  const schema = config.public.supabaseSchema || 'public'

  if (!url || !key) {
    throw new Error(
      'Supabase is not configured. Copy .env.example to .env and set ' +
        'NUXT_PUBLIC_SUPABASE_URL and NUXT_PUBLIC_SUPABASE_ANON_KEY.'
    )
  }

  client = createClient(url, key, {
    db: { schema },
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: false
    }
  })

  return client
}
