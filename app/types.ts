// app/types.ts — v2 domain types. Mirrors supabase/01_schema.sql (demo2).
// cvss arrives as a JSON number from PostgREST (numeric(3,1)) and is
// normalized with Number() at load time.

export type Severity = 'critical' | 'high' | 'medium' | 'low'
export type FixMethod =
  | 'version_upgrade'
  | 'patch_install'
  | 'configuration_change'
  | 'code_change'
  | 'credential_rotation'
export type FixEffort = 'low' | 'medium' | 'high'

export interface Department {
  id: string
  org_id: string
  slug: string
  name: string
}

export interface Project {
  id: string
  org_id: string
  department_id: string
  slug: string
  name: string
}

export interface Team {
  id: string
  org_id: string
  project_id: string
  slug: string
  name: string
}

// Global catalog row — no org_id by design (reference data, shared across
// tenants; see the root_causes policy comment in 01_schema.sql).
export interface RootCause {
  id: string
  code: string
  title: string
  severity: Severity
  first_discovered: string
  fix_available: boolean
  fix_method: FixMethod | null
  fix_effort: FixEffort | null
  workaround: string
}

export interface Finding {
  id: string
  org_id: string
  department_id: string
  project_id: string
  team_id: string
  root_cause_id: string
  title: string
  severity: Severity
  cvss: number
  asset: string
  affected_component: string
  description: string
  detected_at: string
  created_at: string
}

// Finding with its scope chain and root cause joined client-side.
export interface ScopedFinding extends Finding {
  department: Department
  project: Project
  team: Team
  rootCause: RootCause
}

// ---- facet engine -----------------------------------------------------------

export const FACET_IDS = [
  'severity',
  'department',
  'project',
  'team',
  'software',
  'rootCause',
  'fixMethod',
  'fixEffort'
] as const

export type FacetId = (typeof FACET_IDS)[number]

export interface FacetOption {
  value: string
  label: string
  sub?: string
  count: number
  tone?: Severity // severity group only — keeps color discipline
}

export interface FacetGroup {
  id: FacetId
  label: string
  scopedNote?: string
  options: FacetOption[]
}
