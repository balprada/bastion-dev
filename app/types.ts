// app/types.ts — shared domain types. Mirrors the DB schema in
// supabase/01_schema.sql. cvss arrives as a JSON number from PostgREST
// (numeric(3,1)); normalized with Number() at load time.

export type Severity = 'critical' | 'high' | 'medium' | 'low'
export type FindingStatus = 'open' | 'in_progress' | 'resolved'

export interface Finding {
  id: string
  org_id: string
  title: string
  severity: Severity
  status: FindingStatus
  cvss: number
  description: string
  asset: string
  detected_at: string
  created_at: string
}
