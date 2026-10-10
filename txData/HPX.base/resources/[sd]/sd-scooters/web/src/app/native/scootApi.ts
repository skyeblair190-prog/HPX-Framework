import { useCallback, useSyncExternalStore } from 'react';
import palette from './palette.json';
import type { Customization, ExtrasCatalog } from './customization';
import { api } from '../api';

export interface ScootScooter { customization?: Customization; extraFee?: number; id: number; plate: string; colour: number; x: number; y: number; z: number; distance: number; available: boolean; rentable?: boolean; battery?: number; charging?: boolean; flat?: boolean; bunkerId: number | null; stationId?: number | null }
export interface ScootStation { id: number; name: string; x: number; y: number; z: number; distance: number; stock: number; busy: boolean }
export interface ScootCharger { id: number; name: string; x: number; y: number; z: number; distance: number; slots: number; free: number; occupied: number }
export interface ScootBattery { enabled: boolean; minToRent: number; fullAt: number }
export interface ScootRide { customization?: Customization; extraFee?: number; id: number; scooterId: number; plate: string; colour: number; startedAt: number; minutes: number; cost: number; battery?: number }
export interface ScootPricing { unlock: number; currency: string; rentDistance: number; stationDistance: number; dockDistance?: number; refreshMs: number }
export interface ScootColour { id: number; name: string; hex: string; previewHex?: string }
export interface ScootDispense { customization?: Customization; extraFee?: number; bunkerId: number; colour: number; readyAt: number }
export interface ScootSnapshot { extrasCatalog?: ExtrasCatalog; colours?: ScootColour[]; canChooseColour?: boolean; dispense?: ScootDispense | null; player: { x: number; y: number; z: number; heading: number }; scooters: ScootScooter[]; bunkers: ScootStation[]; stations?: ScootCharger[]; battery?: ScootBattery; ride: ScootRide | null; pricing: ScootPricing }
export interface ScootReceipt { plate: string; minutes: number; cost: number; paid: boolean; docked?: string | null; charging?: boolean; flat?: boolean; battery?: number }
export interface ScootPastRide { id: number; scooterId: number; plate: string | null; startedAt: number; endedAt: number; minutes: number; cost: number; paid: number }

export const SCOOT_PALETTE: ScootColour[] = palette;
export const SCOOT_COLOURS: Record<number, string> = Object.fromEntries(palette.map(c => [c.id, c.hex]));

export const scoot = {
  snapshot: () => api.nearby() as Promise<{ success: boolean; data?: ScootSnapshot }>,
  history: () => api.history() as Promise<{ success: boolean; data?: { rides: ScootPastRide[] } }>,
  rentHere: (bunkerId: number, colour: number, customization: Customization) => api.rentHere(bunkerId, colour, customization) as Promise<{ success: boolean; message?: string; data?: { dispense: ScootDispense; nearby: ScootSnapshot } }>,
  finish: () => api.finish() as Promise<{ success: boolean; message?: string; data?: { receipt: ScootReceipt; nearby: ScootSnapshot } }>,
  waypoint: (x: number, y: number) => api.waypoint(x, y),
};

export const DEV_SNAPSHOT: ScootSnapshot = {
  colours: SCOOT_PALETTE, canChooseColour: true, dispense: null,
  player: { x: 201, y: -940, z: 30.7, heading: 20 },
  scooters: [
    { id: 1, plate: 'SCOOT001', colour: 10, x: 195.2, y: -935.4, z: 31, distance: 7.4, available: true, rentable: true, battery: 92, bunkerId: 1 },
    { id: 2, plate: 'SCOOT002', colour: 3, x: 210.9, y: -921.1, z: 30.7, distance: 21.3, available: true, rentable: true, battery: 41, charging: true, stationId: 1, bunkerId: 1 },
    { id: 4, plate: 'SCOOT004', colour: 7, x: 214.2, y: -918.6, z: 30.7, distance: 24.8, available: true, rentable: false, battery: 8, bunkerId: null },
  ],
  bunkers: [{ id: 1, name: 'Legion Square', x: 195.2, y: -933.8, z: 30.69, distance: 8.7, stock: 4, busy: false }],
  stations: [{ id: 1, name: 'Pillbox Hill', x: 212.4, y: -920.2, z: 30.7, distance: 22.5, slots: 4, free: 3, occupied: 1 }],
  battery: { enabled: true, minToRent: 15, fullAt: 100 },
  ride: null, pricing: { unlock: 5, currency: '$', rentDistance: 12, stationDistance: 12, dockDistance: 12, refreshMs: 2500 },
};

interface ScootFeed { snapshot: ScootSnapshot | null; connected: boolean }

const browser = typeof window === 'undefined' || typeof window.invokeNative === 'undefined';
let feed: ScootFeed = { snapshot: browser ? DEV_SNAPSHOT : null, connected: browser };
const listeners = new Set<() => void>();
let timer: number | null = null;
let watchers = 0;

function publish(next: Partial<ScootFeed>) {
  feed = { ...feed, ...next };
  for (const listener of listeners) listener();
}

async function pull() {
  try {
    const reply = await scoot.snapshot();
    publish(reply?.data ? { connected: !!reply.success, snapshot: reply.data } : { connected: !!reply?.success });
  } catch {
    publish({ connected: false });
  }
}

function schedule() {
  if (timer !== null) window.clearTimeout(timer);
  timer = window.setTimeout(async () => {
    timer = null;
    if (watchers === 0) return;
    await pull();
    if (watchers > 0) schedule();
  }, feed.snapshot?.pricing.refreshMs ?? 2500);
}

function watch(listener: () => void) {
  listeners.add(listener);
  watchers += 1;
  if (watchers === 1) { void pull().then(() => { if (watchers > 0) schedule(); }); }
  return () => {
    listeners.delete(listener);
    watchers -= 1;
    if (watchers === 0 && timer !== null) { window.clearTimeout(timer); timer = null; }
  };
}

export function useScootFeed() {
  const state = useSyncExternalStore(watch, () => feed, () => feed);
  const setSnapshot = useCallback((snapshot: ScootSnapshot) => publish({ snapshot }), []);
  const refresh = useCallback(() => pull(), []);
  return { snapshot: state.snapshot, connected: state.connected, setSnapshot, refresh };
}
