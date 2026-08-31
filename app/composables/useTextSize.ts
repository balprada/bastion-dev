// app/composables/useTextSize.ts
// Root-font scaling: every type token is rem-based, so scaling <html>
// scales the entire app proportionally — the whole design system moves
// together, nothing re-hardcodes. Persisted per browser.
export type TextSize = 's' | 'm' | 'l'

const SIZES: TextSize[] = ['s', 'm', 'l']
const STORAGE_KEY = 'bastion:text-size'

export function useTextSize() {
  const size = useState<TextSize>('bastion:text-size', () => 'm')

  function apply(s: TextSize) {
    if (s === 'm') delete document.documentElement.dataset.size
    else document.documentElement.dataset.size = s
  }

  // Restore the stored preference. Called once from app.vue on mount.
  function init() {
    const stored = localStorage.getItem(STORAGE_KEY)
    if (stored === 's' || stored === 'l') size.value = stored
    apply(size.value)
  }

  function set(s: TextSize) {
    size.value = s
    localStorage.setItem(STORAGE_KEY, s)
    apply(s)
  }

  return { size, sizes: SIZES, init, set }
}
