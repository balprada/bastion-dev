// nuxt.config.ts — demo2 branch (v2 audit portal)
export default defineNuxtConfig({
  compatibilityDate: '2025-07-15',

  ssr: false,

  css: [
    '@fontsource/ibm-plex-sans/400.css',
    '@fontsource/ibm-plex-sans/500.css',
    '@fontsource/ibm-plex-sans/600.css',
    '@fontsource/ibm-plex-mono/400.css',
    '@fontsource/ibm-plex-mono/500.css',
    '~/assets/css/main.css'
  ],

  runtimeConfig: {
    public: {
      supabaseUrl: '',
      supabaseAnonKey: '',
      // '' → public schema (v1 behavior). demo2 sets NUXT_PUBLIC_SUPABASE_SCHEMA
      // in .env / Cloudflare env vars.
      supabaseSchema: ''
    }
  },

  app: {
    head: {
      title: 'Bastion — Security Audit Portal',
      htmlAttrs: { lang: 'en' },
      meta: [
        { name: 'viewport', content: 'width=device-width, initial-scale=1' },
        {
          name: 'description',
          content: 'Multi-tenant security audit portal with findings, root causes, and Postgres row-level security.'
        },
        { name: 'theme-color', content: '#0a0d12' }
      ],
      link: [{ rel: 'icon', type: 'image/svg+xml', href: '/favicon.svg' }]
    }
  }
})
