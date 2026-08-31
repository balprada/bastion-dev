// app/utils/labels.ts — display labels shared by the facet rail, table,
// and drawer. Facet values are the raw DB values; humans get these.
import type { FixEffort, FixMethod, Severity } from '~/types'

export const SEVERITY_ORDER: Severity[] = ['critical', 'high', 'medium', 'low']

export const SEVERITY_LABELS: Record<Severity, string> = {
  critical: 'Critical',
  high: 'High',
  medium: 'Medium',
  low: 'Low'
}

export const FIX_METHOD_LABELS: Record<FixMethod, string> = {
  version_upgrade: 'Version upgrade',
  patch_install: 'Patch install',
  configuration_change: 'Configuration change',
  code_change: 'Code change',
  credential_rotation: 'Credential rotation'
}

export const FIX_EFFORT_LABELS: Record<FixEffort, string> = {
  low: 'Low',
  medium: 'Medium',
  high: 'High'
}

// Facet sentinel for findings whose root cause has no fix available yet.
export const NO_FIX = 'none'
export const NO_FIX_LABEL = 'No fix available yet'
