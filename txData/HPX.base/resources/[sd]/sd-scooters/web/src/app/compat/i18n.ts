export function t(key: string, fallback: string, vars?: Record<string, string | number>): string {
  let value = fallback;
  for (const [name, replacement] of Object.entries(vars ?? {})) value = value.replaceAll(`{${name}}`, String(replacement));
  return value;
}
