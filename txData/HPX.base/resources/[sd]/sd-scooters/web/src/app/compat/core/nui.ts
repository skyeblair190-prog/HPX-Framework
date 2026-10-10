export const isFiveM = typeof window !== 'undefined' && typeof window.invokeNative !== 'undefined';
export const hostResource = typeof window !== 'undefined' ? (window.resourceName ?? 'sd-scooters') : 'sd-scooters';
export async function fetchNui<T = unknown>(event: string, data?: unknown): Promise<T | undefined> {
  if (typeof window !== 'undefined' && window.fetchNui) return window.fetchNui<T>(event, data);
  return undefined;
}
