````markdown
# Bastion — security findings console

A miniature multi-tenant security dashboard: two organizations, two users,
28 synthetic findings. Tenant isolation is enforced by **Postgres row-level
security** — the client never filters by organization, because it can't.
Every request carries the user's JWT; Postgres resolves their membership and
only that organization's rows ever leave the database.

**Live demo:** `<your-pages-url>`  ·  **Demo password:** `demo1234`

| Account | Organization | Sees |
| --- | --- | --- |
| `ada@apex.test` | Apex Financial | 15 findings |
| `sam@meridian.test` | Meridian Health | 13 findings |

Switching accounts visibly changes the dataset — that's RLS, not UI logic.
An "About this build" page inside the app documents the schema, the exact
policy SQL, and the reasoning behind it.

## Stack

Nuxt 4 (static SPA) · TypeScript · Supabase (hosted Postgres + Auth) ·
Postgres RLS · Cloudflare Pages · IBM Plex Sans / Mono.

## Quickstart

Node 20.19+ or 22.12+.

1. `npm install`
2. Create a free project at supabase.com.
3. **Authentication → Sign In / Up:** turn **off** "Confirm email" *before*
   creating users. Then **Users → Add user → Create new user** for
   `ada@apex.test` and `sam@meridian.test`, password `demo1234` each.
4. SQL Editor — run in order:
   - `supabase/01_schema.sql` — tables, indexes, RLS policies, grants
   - `supabase/02_seed.sql` — memberships + 28 findings
   - `supabase/03_verify_rls.sql` — proves isolation. Expected results:
     **15 rows** (Apex only) · **13 rows** (Meridian only) · **0** (anon).
5. `cp .env.example .env` and fill `NUXT_PUBLIC_SUPABASE_URL` and
   `NUXT_PUBLIC_SUPABASE_ANON_KEY` from Project Settings → API.
   Env vars are read at server start — restart dev after any change.
6. `npm run dev` → http://localhost:3000

## Deploy (Cloudflare Workers — static assets)

- `wrangler.jsonc` configures the project: static assets from
  `.output/public`, SPA fallback via `not_found_handling`.
- Git integration (Workers & Pages → Import a repository):
  - Build command: `npm run generate`
  - Deploy command: `npx wrangler deploy`
- Set both `NUXT_PUBLIC_*` variables (build-time) **before** the first
  build — a static bundle bakes them in at build time.

## Notes

- The anon key ships in the client bundle **by design**: the `anon` role has
  table-level SELECT but no RLS policy matches it, so it reads zero rows.
- Policies use the `(select auth.uid())` pattern so the planner hoists the
  call into an InitPlan — evaluated once per statement, not per row.
- The app is read-only; no write policies exist. Writes would follow the
  same pattern with `USING` / `WITH CHECK`.
- All findings, organizations, and users are synthetic.
````
