export function readJson<T>(key: string, guard: (value: unknown) => value is T): T | null {
  try { const raw = localStorage.getItem(key); if (!raw) return null; const value: unknown = JSON.parse(raw); return guard(value) ? value : null; } catch { return null; }
}
export function writeJson(key: string, value: unknown): void { try { localStorage.setItem(key, JSON.stringify(value)); } catch { } }
