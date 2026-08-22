// nuxt.config.ts
export default defineNuxtConfig({
  compatibilityDate: '2025-07-15',

  // Static SPA: the whole app lives behind auth, so there is nothing for a
  // server to render. Output is plain static files — ideal for Cloudflare Pages.
  ssr: false,

  runtimeConfig: {
    public: {
      // Set via NUXT_PUBLIC_SUPABASE_URL / NUXT_PUBLIC_SUPABASE_ANON_KEY
      // (.env locally, Pages env vars in production).
      // The anon key is public by design — RLS is the enforcement layer.
      supabaseUrl: '',
      supabaseAnonKey: ''
    }
  },

  app: {
    head: {
      title: 'Bastion — Security Findings Console',
      htmlAttrs: { lang: 'en' },
      meta: [
        { name: 'viewport', content: 'width=device-width, initial-scale=1' },
        {
          name: 'description',
          content: 'Multi-tenant security findings dashboard with Postgres row-level security.'
        },
        { name: 'theme-color', content: '#0a0d12' }
      ],
      link: [{ rel: 'icon', type: 'image/svg+xml', href: '/favicon.svg' }]
    }
  }
})
