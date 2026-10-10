import en from '../../../locales/en.json';

type Dict = { [key: string]: string | Dict };

let active: Dict = (en as { ui: Dict }).ui;
const listeners = new Set<() => void>();

function merge(base: Dict, over: Dict): Dict {
  const out: Dict = { ...base };
  for (const [k, v] of Object.entries(over)) {
    const cur = out[k];
    out[k] = typeof v === 'object' && v && typeof cur === 'object' && cur ? merge(cur, v) : v;
  }
  return out;
}

export function setLocale(ui: Dict | null | undefined): void {
  active = merge((en as { ui: Dict }).ui, ui ?? {});
  for (const fn of listeners) fn();
}

export function onLocaleChange(fn: () => void): () => void {
  listeners.add(fn);
  return () => listeners.delete(fn);
}

function lookup(dict: Dict, path: string): string | undefined {
  let cur: string | Dict | undefined = dict;
  for (const part of path.split('.')) {
    if (!cur || typeof cur === 'string') return undefined;
    cur = cur[part];
  }
  return typeof cur === 'string' ? cur : undefined;
}

export function t(path: string, ...args: (string | number)[]): string {
  const raw = lookup(active, path) ?? lookup((en as { ui: Dict }).ui, path) ?? path;
  let i = 0;
  return raw.replace(/%[sd]/g, () => String(args[i++] ?? ''));
}
