// app/utils/format.ts — date/ID formatting for the console aesthetic:
// ISO-style dates in mono, tabular. Formatters are created once at module
// scope (Intl construction is surprisingly expensive per call).

// en-CA yields YYYY-MM-DD.
const dateFormatter = new Intl.DateTimeFormat('en-CA', {
  year: 'numeric',
  month: '2-digit',
  day: '2-digit'
})

// en-GB yields 24h HH:MM.
const timeFormatter = new Intl.DateTimeFormat('en-GB', {
  hour: '2-digit',
  minute: '2-digit',
  hour12: false
})

export function formatDate(iso: string): string {
  const d = new Date(iso)
  return Number.isNaN(d.getTime()) ? '—' : dateFormatter.format(d)
}

export function formatDateTime(iso: string): string {
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return '—'
  return `${dateFormatter.format(d)} ${timeFormatter.format(d)}`
}

export function shortId(id: string): string {
  return id.slice(0, 8)
}
