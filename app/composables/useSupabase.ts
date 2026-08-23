import { createClient, type SupabaseClient } from '@supabase/supabase-js'

// Module-level singleton: one client per browser session. Safe because
// ssr:false — under SSR module scope would leak across requests and we'd
// hold the client in useState instead.
let client: SupabaseClient | undefined

export function useSupabase(): SupabaseClient {
  if (client) return client

  const config = useRuntimeConfig()
  const url = config.public.supabaseUrl
  const key = config.public.supabaseAnonKey

  if (!url || !key) {
    throw new Error(
      'Supabase is not configured. Copy .env.example to .env and set ' +
        'NUXT_PUBLIC_SUPABASE_URL and NUXT_PUBLIC_SUPABASE_ANON_KEY.'
    )
  }

  client = createClient(url, key, {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      // No OAuth or magic-link flows in this app, so never parse tokens
      // out of the URL — avoids surprise redirect/session quirks.
      detectSessionInUrl: false
    }
  })

  return client
}
