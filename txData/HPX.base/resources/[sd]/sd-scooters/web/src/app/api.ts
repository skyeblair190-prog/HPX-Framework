import type { Nearby, PastRide, Receipt, Reply, Ride } from './types';
import { MOCK_NEARBY, MOCK_HISTORY } from './mock';

const isBrowser = () => typeof window.invokeNative === 'undefined';

async function call<T>(verb: string, payload: Record<string, unknown> = {}): Promise<Reply<T>> {
  if (isBrowser()) return mock<T>(verb, payload);
  const resource = window.resourceName ?? 'sd-scooters';
  try {
    const resp = await fetch(`https://${resource}/scoot:app:${verb}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(payload),
    });
    return (await resp.json()) as Reply<T>;
  } catch {
    return { success: false, message: 'No response from the server.' };
  }
}

export const api = {
  nearby: () => call<Nearby>('nearby'),
  rentHere: (bunkerId: number, colour: number, customization: unknown) => call<{ dispense: unknown; nearby: Nearby }>('rentHere', { bunkerId, colour, customization }),
  finish: () => call<{ receipt: Receipt; nearby: Nearby }>('finish'),
  history: () => call<{ rides: PastRide[] }>('history'),
  waypoint: (x: number, y: number) => call<never>('waypoint', { x, y }),
};

let mockRide: Ride | null = null;
async function mock<T>(verb: string, payload: Record<string, unknown>): Promise<Reply<T>> {
  await new Promise(r => setTimeout(r, 120));
  const nearby = (): Nearby => ({ ...MOCK_NEARBY, ride: mockRide, scooters: MOCK_NEARBY.scooters.map(s => ({ ...s, available: s.available && s.id !== mockRide?.scooterId })) });
  switch (verb) {
    case 'nearby':
      return { success: true, data: nearby() as T };
    case 'finish': {
      if (!mockRide) return { success: false, message: 'You have no ride to end.' };
      const receipt: Receipt = { plate: mockRide.plate, minutes: 7, cost: 7, paid: true };
      mockRide = null;
      return { success: true, data: { receipt, nearby: nearby() } as T };
    }
    case 'history':
      return { success: true, data: { rides: MOCK_HISTORY } as T };
    default:
      return { success: true };
  }
}
