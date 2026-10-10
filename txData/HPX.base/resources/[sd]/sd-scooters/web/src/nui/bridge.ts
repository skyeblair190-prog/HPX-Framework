declare global {
  interface Window {
    GetParentResourceName?: () => string;
  }
}

export const isEnvBrowser = (): boolean => typeof window.GetParentResourceName !== 'function';

const resourceName = (): string => window.GetParentResourceName?.() ?? 'sd-scooters';

export async function fetchNui<Resp = unknown, Req = unknown>(callback: string, data?: Req): Promise<Resp | null> {
  if (isEnvBrowser()) {
    const { mockNui } = await import('./mockServer');
    return (await mockNui(callback, data)) as Resp | null;
  }
  try {
    const resp = await fetch(`https://${resourceName()}/${callback}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data ?? {}),
    });
    return (await resp.json()) as Resp;
  } catch {
    return null;
  }
}
