const hex = {
  accent: '#4ade80',
  bright: '#86efac',
  dim: '#15803d',
  danger: '#f14c4c',
  warn: '#ff9500',
  canvasBg: '#070a0e',
  fieldBg: '#0b0f15',
  panelBg: '#0a0d12',
  slate: '#11151b',
  deep: '#0c0f14',
  raise: '#161b24',
  ink: '#08080b',
  white: '#ffffff',
  fog: '#cccccc',
} as const

export type PaletteKey = keyof typeof hex

export const palette: Record<PaletteKey, string> = hex

function hexToTriple(value: string): string {
  const n = parseInt(value.slice(1), 16)
  return `${(n >> 16) & 255}, ${(n >> 8) & 255}, ${n & 255}`
}

export const triple = Object.fromEntries(
  (Object.keys(hex) as PaletteKey[]).map(key => [key, hexToTriple(hex[key])]),
) as Record<PaletteKey, string>

export function alpha(key: PaletteKey, a: number): string {
  return `rgba(${triple[key]}, ${a})`
}
