import type { ActiveRide, AuditRow, RideRow, SettingItem, Snapshot } from '@/types';
import { MOCK_SNAPSHOT } from './mock';


const now = () => Math.floor(Date.now() / 1000);
const snap: Snapshot = structuredClone(MOCK_SNAPSHOT);

const NAMES = ['Jamie Carter', 'Ava Brooks', 'Leo Martinez', 'Mia Chen', 'Noah Patel', 'Zoe Kim', 'Ethan Ross', 'Lily Evans'];
const history: RideRow[] = Array.from({ length: 120 }, (_, i) => {
  const started = now() - i * 2400 - Math.floor(Math.random() * 1800);
  const minutes = 3 + ((i * 7) % 24);
  const cost = snap.today.revenue > -1 ? 5 + minutes : 0;
  const renter = `char${(i % NAMES.length) + 1}`;
  return {
    id: 500 - i,
    scooterId: (i % 5) + 1,
    plate: `SCOOT00${(i % 5) + 1}`,
    bunkerId: i % 4 === 3 ? null : (i % 3) + 1,
    renter,
    renterName: NAMES[i % NAMES.length],
    startedAt: started,
    endedAt: started + minutes * 60,
    minutes,
    cost,
    paid: i % 11 === 5 ? 0 : 1,
    refunded: i === 7 ? cost : 0,
    endedBy: ['rider', 'rider', 'rider', 'flat', 'dropped', 'rider', 'admin', 'timeout'][i % 8],
    startX: -1400 + ((i * 97) % 1600),
    startY: -1600 + ((i * 53) % 1400),
    endX: -1300 + ((i * 71) % 1500),
    endY: -1500 + ((i * 29) % 1300),
  };
});

const audit: AuditRow[] = [
  { id: 9, actor: 'Samuel', verb: 'settingsSave', message: 'setting Rentals.UnlockFee: 5 -> 6', at: now() - 600 },
  { id: 8, actor: 'Samuel', verb: 'setBunkerStock', message: 'set stock of bunker #1 Legion Square to 8', at: now() - 3600 },
  { id: 7, actor: 'Moderator', verb: 'forceEndRide', message: 'force-ended the ride of Leo Martinez on SCOOT004', at: now() - 7200 },
  { id: 6, actor: 'Samuel', verb: 'deleteScooter', message: 'deleted scooter #9 SCOOT009', at: now() - 86400 },
];

const settings: SettingItem[] = [
  { path: 'Rentals.UnlockFee', group: 'pricing', type: 'int', min: 0, max: 10000, step: 1, unit: '$', default: 5, value: 5, overridden: false },
  { path: 'Rentals.Account', group: 'pricing', type: 'enum', options: ['bank', 'cash'], default: 'bank', value: 'bank', overridden: false },
  { path: 'Rentals.MaxRideMinutes', group: 'rides', type: 'int', min: 5, max: 1440, step: 5, unit: 'min', default: 180, value: 180, overridden: false },
  { path: 'Rentals.LockIdle', group: 'rides', type: 'bool', default: true, value: true, overridden: false },
  { path: 'Rentals.RentDistance', group: 'rides', type: 'number', min: 1, max: 100, step: 0.5, unit: 'm', default: 12, value: 12, overridden: false },
  { path: 'Rentals.StationDistance', group: 'rides', type: 'number', min: 1, max: 100, step: 0.5, unit: 'm', default: 12, value: 12, overridden: false },
  { path: 'Rentals.DockDistance', group: 'rides', type: 'number', min: 1, max: 100, step: 0.5, unit: 'm', default: 12, value: 12, overridden: false },
  { path: 'Rentals.NearbyRadius', group: 'rides', type: 'number', min: 50, max: 5000, step: 50, unit: 'm', default: 600, value: 600, overridden: false },
  { path: 'Battery.DrainPerMinute', group: 'battery', type: 'number', min: 0, max: 50, step: 0.1, unit: '%/min', default: 2.5, value: 2.5, overridden: false },
  { path: 'Battery.ChargePerMinute', group: 'battery', type: 'number', min: 0.1, max: 100, step: 0.5, unit: '%/min', default: 20, value: 20, overridden: false },
  { path: 'Battery.MinToRent', group: 'battery', type: 'int', min: 0, max: 100, step: 1, unit: '%', default: 15, value: 15, overridden: false },
  { path: 'Battery.FlatRecoverMinutes', group: 'battery', type: 'int', min: 1, max: 1440, step: 1, unit: 'min', default: 30, value: 30, overridden: false },
  { path: 'Battery.AdoptedLevel', group: 'battery', type: 'int', min: 0, max: 100, step: 1, unit: '%', default: 55, value: 55, overridden: false },
  { path: 'Battery.Paid.Enabled', group: 'charging', type: 'bool', default: true, value: true, overridden: false },
  { path: 'Battery.Paid.PricePerPercent', group: 'charging', type: 'number', min: 0, max: 100, step: 0.01, unit: '$', default: 0.1, value: 0.1, overridden: false },
  { path: 'Battery.Paid.MinimumFee', group: 'charging', type: 'int', min: 0, max: 10000, step: 1, unit: '$', default: 1, value: 1, overridden: false },
  { path: 'Battery.Paid.Step', group: 'charging', type: 'int', min: 1, max: 50, step: 1, unit: '%', default: 5, value: 5, overridden: false },
  { path: 'Battery.Paid.RefundOnStop', group: 'charging', type: 'bool', default: true, value: true, overridden: false },
  { path: 'Battery.Paid.Account', group: 'charging', type: 'enum', options: ['bank', 'cash'], default: 'bank', value: 'bank', overridden: false },
  { path: 'Bunkers.Stock', group: 'fleet', type: 'int', min: 0, max: 100, step: 1, default: 5, value: 5, overridden: false },
];

const undo = new Map<string, () => void>();
const ok = (data: unknown = {}) => ({ success: true, data });
const withSnap = (extra: Record<string, unknown> = {}) => ok({ ...extra, snapshot: structuredClone(snap) });
const totals = (since: number) => {
  const rows = history.filter(r => r.startedAt >= since);
  return {
    rides: rows.length,
    revenue: rows.reduce((n, r) => n + (r.paid ? r.cost - r.refunded : 0), 0),
    unpaid: rows.reduce((n, r) => n + (r.paid ? 0 : r.cost), 0),
    minutes: rows.reduce((n, r) => n + r.minutes, 0),
  };
};
const midnight = () => {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  return Math.floor(d.getTime() / 1000);
};

snap.today = totals(midnight());
const liveRides = (): ActiveRide[] =>
  snap.scooters
    .filter(s => s.status === 'rented')
    .map((s, i) => ({ id: 900 + s.id, renter: `char${i + 1}`, renterName: NAMES[i], online: true, scooterId: s.id, plate: s.plate, startedAt: now() - 540 - i * 300, minutes: 9 + i * 5, cost: 14 + i * 5, battery: s.battery, x: s.x, y: s.y }));
snap.rides = liveRides();

const page = <T,>(rows: T[], offset: number) => ok({ rows: rows.slice(offset, offset + 40), total: rows.length, offset, pageSize: 40 });

export async function mockNui(callback: string, raw: unknown): Promise<unknown> {
  await new Promise(r => setTimeout(r, 120));
  const data = (raw ?? {}) as Record<string, any>;
  const verb = callback.replace('scoot:admin:', '').toLowerCase();
  const scooter = snap.scooters.find(s => s.id === data.id);
  switch (verb) {
    case 'snapshot':
      return ok(structuredClone(snap));
    case 'positions':
      return ok({
        scooters: snap.scooters.map(s => ({ id: s.id, x: s.x + Math.sin(Date.now() / 4000 + s.id) * (s.status === 'rented' ? 30 : 0), y: s.y, z: s.z, heading: s.heading })),
        player: snap.player,
        riders: snap.rides.map(r => ({ rideId: r.id, scooterId: r.scooterId, name: r.renterName, plate: r.plate, minutes: r.minutes, x: r.x, y: r.y })),
      });
    case 'mapactivity':
      return ok({ points: history.slice(0, 120).map(r => ({ sx: r.startX, sy: r.startY, ex: r.endX, ey: r.endY })) });
    case 'rides': {
      const firstHour = Math.floor(now() / 3600) - 23;
      const hourly = Array.from({ length: 24 }, (_, i) => {
        const hour = firstHour + i;
        const rows = history.filter(r => Math.floor(r.startedAt / 3600) === hour);
        return { hour, rides: rows.length, revenue: rows.reduce((n, r) => n + (r.paid ? r.cost : 0), 0) };
      }).filter(h => h.rides > 0);
      const week = now() - 7 * 86400;
      const byBunker = [1, 2, 3, null].map(id => {
        const rows = history.filter(r => r.bunkerId === id && r.startedAt >= week);
        return { bunkerId: id, name: snap.bunkers.find(b => b.id === id)?.name ?? null, rides: rows.length, revenue: rows.reduce((n, r) => n + (r.paid ? r.cost - r.refunded : 0), 0) };
      });
      return ok({ active: snap.rides, totals: { today: totals(midnight()), week: totals(week), all: totals(0) }, byBunker, hourly, firstHour, currency: snap.currency });
    }
    case 'ridehistory': {
      const q = String(data.query ?? '').toLowerCase();
      const rows = q ? history.filter(r => `${r.renterName} ${r.renter} ${r.plate}`.toLowerCase().includes(q)) : history;
      return page(rows, Number(data.offset) || 0);
    }
    case 'playerrides':
      return ok({ rows: history.filter(r => r.renter === data.renter) });
    case 'auditlog': {
      const q = String(data.query ?? '').toLowerCase();
      const rows = q ? audit.filter(r => `${r.actor} ${r.message}`.toLowerCase().includes(q)) : audit;
      return page(rows, Number(data.offset) || 0);
    }
    case 'settings':
      return ok({ settings: { settings, currency: snap.currency } });
    case 'settingssave': {
      let n = 0;
      for (const [path, value] of Object.entries(data.values ?? {})) {
        const item = settings.find(s => s.path === path);
        if (item && item.value !== value) {
          item.value = value as never;
          item.overridden = value !== item.default;
          item.updatedBy = 'You';
          item.updatedAt = now();
          n++;
        }
      }
      return withSnap({ changed: n, settings: { settings, currency: snap.currency } });
    }
    case 'settingsreset':
      settings.forEach(s => Object.assign(s, { value: s.default, overridden: false }));
      return withSnap({ settings: { settings, currency: snap.currency } });
    case 'setbunkerstock': {
      const b = snap.bunkers.find(x => x.id === data.id);
      if (b) b.stock = Number(data.stock);
      return withSnap();
    }
    case 'releasedock': {
      const st = snap.stations.find(x => x.id === data.stationId);
      if (st) {
        const slot = st.slots[data.slot - 1];
        if (slot) {
          const sc = snap.scooters.find(s => s.id === slot.scooterId);
          if (sc) Object.assign(sc, { status: 'available', stationId: null, slot: null });
        }
        st.slots[data.slot - 1] = false;
        st.occupied = st.slots.filter(Boolean).length;
      }
      return withSnap();
    }
    case 'setscooterbattery':
      if (scooter) scooter.battery = Number(data.level);
      return withSnap();
    case 'lockscooter':
      if (scooter) scooter.locked = !!data.locked;
      return withSnap();
    case 'bringscooter':
      if (scooter && snap.player) Object.assign(scooter, { x: snap.player.x + 2, y: snap.player.y, status: 'available', stationId: null, slot: null });
      return withSnap();
    case 'sendhome':
      if (scooter) {
        if (!scooter.bunkerId) return { success: false, message: 'That scooter has no home bunker.' };
        snap.scooters = snap.scooters.filter(s => s.id !== scooter.id);
      }
      return withSnap();
    case 'bulkscooters': {
      let done = 0;
      for (const id of data.ids ?? []) {
        const s = snap.scooters.find(x => x.id === id);
        if (!s || s.status === 'rented') continue;
        if (data.action === 'battery') s.battery = Number(data.level);
        if (data.action === 'lock') s.locked = true;
        if (data.action === 'unlock') s.locked = false;
        if (data.action === 'delete') snap.scooters = snap.scooters.filter(x => x.id !== id);
        done++;
      }
      return withSnap({ done, failed: (data.ids?.length ?? 0) - done });
    }
    case 'deletescooter':
    case 'deletebunker':
    case 'deletestation': {
      const key = verb === 'deletescooter' ? 'scooters' : verb === 'deletebunker' ? 'bunkers' : 'stations';
      const list = snap[key] as { id: number }[];
      const item = list.find(x => x.id === data.id);
      (snap as any)[key] = list.filter(x => x.id !== data.id);
      const token = String(Math.random());
      undo.set(token, () => item && (snap as any)[key].push(item));
      return withSnap({ undo: token });
    }
    case 'undodelete':
      undo.get(String(data.token))?.();
      return withSnap();
    case 'forceendride': {
      const ride = snap.rides.find(r => r.id === data.rideId);
      const sc = ride && snap.scooters.find(s => s.id === ride.scooterId);
      if (sc) sc.status = 'available';
      snap.rides = snap.rides.filter(r => r.id !== data.rideId);
      return withSnap();
    }
    case 'refundride': {
      const ride = history.find(r => r.id === data.rideId);
      if (!ride || !ride.paid) return { success: false, message: 'That ride was never paid, so there is nothing to refund.' };
      const amount = ride.cost - ride.refunded;
      ride.refunded = ride.cost;
      return ok({ amount });
    }
    case 'teleportpoint':
    case 'teleport':
      return ok({ x: data.x ?? 0, y: data.y ?? 0, z: 0 });
    default:
      if (verb.startsWith('handling')) return null;
      return withSnap();
  }
}
