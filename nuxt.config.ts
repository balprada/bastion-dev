// nuxt.config.ts
export default defineNuxtConfig({
  compatibilityDate: '2025-07-15',
  // modules: ['@nuxtjs/supabase'],

  // Static SPA: the whole app lives behind auth, so there is nothing for a
  // server to render. Output is plain static files — ideal for Cloudflare Pages.
  ssr: false,

  css: [
    // Self-hosted IBM Plex (no Google Fonts round-trip). Only the weights we
    // use; latin subsets load on demand via unicode-range.
    '@fontsource/ibm-plex-sans/400.css',
    '@fontsource/ibm-plex-sans/500.css',
    '@fontsource/ibm-plex-sans/600.css',
    '@fontsource/ibm-plex-mono/400.css',
    '@fontsource/ibm-plex-mono/500.css',
    // Design tokens + base styles + shared primitives (.btn, .input, .panel…)
    '~/assets/css/main.css'
  ],

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
