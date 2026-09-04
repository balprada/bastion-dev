````markdown
# Bastion v2 — security audit portal (branch `demo2`)

External-audit-team portal: org → department → project → team, findings
mapped to a global root-cause catalog with fix economics. Tenant isolation
enforced by Postgres RLS in the `bastion_v2` schema — the client never
filters by organization because it can't.

**Live:** `https://bastion-v2.<subdomain>.workers.dev` · password `demo1234`

| Account | Organization | Sees |
| --- | --- | --- |
| `ada@apex.test` | Apex Financial | 15 findings |
| `sam@meridian.test` | Meridian Health | 13 findings |

## Quickstart

1. `npm install` (Node 20.19+ / 22.12+), branch `demo2`
2. Supabase project → Settings → API → **Exposed schemas**: add
   `bastion_v2` (keep `public` first — v1 shares this project)
3. Two demo users (`ada@apex.test`, `sam@meridian.test`, `demo1234`) —
   "Confirm email" off *before* creating them
4. SQL Editor: `01_schema.sql` → `02_seed.sql` → `03_verify_rls.sql`
   (expected: ada 15/4/11/12/22 · sam 13/3/8/8/22 · anon 0)
5. `.env`: `NUXT_PUBLIC_SUPABASE_URL`, `NUXT_PUBLIC_SUPABASE_ANON_KEY`,
   `NUXT_PUBLIC_SUPABASE_SCHEMA=bastion_v2`
6. `npm run dev`

## Deploy

Cloudflare Workers (Git integration, production branch `demo2`):
build `npm run generate && rm -rf .output/server .wrangler`, deploy
`npx wrangler deploy --config wrangler.jsonc`. All three
`NUXT_PUBLIC_*` vars set before the first build.
````
