import { useCallback, useEffect, useRef, useState } from 'react';
import { query } from './api';

const cache = new Map<string, unknown>();

const keyOf = (verb: string, payload?: Record<string, unknown>) => `${verb}:${payload ? JSON.stringify(payload) : ''}`;

export function cached<T>(verb: string, payload?: Record<string, unknown>): T | null {
  return (cache.get(keyOf(verb, payload)) as T | undefined) ?? null;
}

export function prime(verb: string, payload: Record<string, unknown> | undefined, data: unknown): void {
  cache.set(keyOf(verb, payload), data);
}

export function useQuery<T>(verb: string, payload?: Record<string, unknown>, options: { refreshMs?: number; enabled?: boolean } = {}) {
  const { refreshMs, enabled = true } = options;
  const key = keyOf(verb, payload);
  const [data, setData] = useState<T | null>(() => (cache.get(key) as T | undefined) ?? null);
  const live = useRef({ verb, payload, key });
  live.current = { verb, payload, key };

  const refresh = useCallback(async () => {
    const { verb: v, payload: p, key: k } = live.current;
    const next = await query<T>(v, p ?? {});
    if (next === null) return;
    cache.set(k, next);
    if (live.current.key === k) setData(next);
  }, []);

  useEffect(() => {
    setData((cache.get(key) as T | undefined) ?? null);
    if (!enabled) return;
    void refresh();
    if (!refreshMs) return;
    const id = window.setInterval(() => void refresh(), refreshMs);
    return () => window.clearInterval(id);
  }, [key, enabled, refreshMs, refresh]);

  return { data, refresh, setData };
}

export function useSlow(loading: boolean, ms = 200): boolean {
  const [slow, setSlow] = useState(false);
  useEffect(() => {
    if (!loading) {
      setSlow(false);
      return;
    }
    const id = window.setTimeout(() => setSlow(true), ms);
    return () => window.clearTimeout(id);
  }, [loading, ms]);
  return slow;
}
