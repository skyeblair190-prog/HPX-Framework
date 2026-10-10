import type { Nearby, PastRide } from './types';

export const MOCK_NEARBY: Nearby = {
  player: { x: 201.0, y: -940.0, z: 30.7, heading: 20 },
  scooters: [
    { id: 1, plate: 'SCOOT001', colour: 10, x: 195.2, y: -935.4, z: 31.0, distance: 7.4, available: true, rentable: true, battery: 92, bunkerId: 1 },
    { id: 2, plate: 'SCOOT002', colour: 3, x: 210.9, y: -921.1, z: 30.7, distance: 21.3, available: true, rentable: true, battery: 41, charging: true, stationId: 1, bunkerId: 1 },
    { id: 3, plate: 'SCOOT003', colour: 5, x: 240.0, y: -900.0, z: 30.7, distance: 56.0, available: false, rentable: false, battery: 63, bunkerId: null },
    { id: 4, plate: 'SCOOT004', colour: 8, x: 120.0, y: -1000.0, z: 29.0, distance: 101.0, available: true, rentable: false, battery: 8, bunkerId: null },
  ],
  bunkers: [
    { id: 1, name: 'Legion Square', x: 195.2, y: -933.8, z: 30.69, distance: 8.7, stock: 4, busy: false },
    { id: 2, name: 'Pillbox Hill', x: 300.0, y: -600.0, z: 43.0, distance: 355.0, stock: 9, busy: false },
    { id: 3, name: 'Del Perro Pier', x: -1850.1, y: -1235.9, z: 8.6, distance: 1962.0, stock: 0, busy: false },
    { id: 4, name: 'Mirror Park', x: 1121.7, y: -651.3, z: 56.9, distance: 941.0, stock: 2, busy: true },
  ],
  stations: [
    { id: 1, name: 'Pillbox Hill', x: 212.4, y: -920.2, z: 30.7, distance: 22.5, slots: 4, free: 3, occupied: 1 },
    { id: 2, name: 'Vespucci Canals', x: -1050.0, y: -1150.0, z: 3.0, distance: 1280.0, slots: 4, free: 0, occupied: 4 },
  ],
  battery: { enabled: true, minToRent: 15, fullAt: 100 },
  ride: null,
  pricing: { unlock: 5, currency: '$', rentDistance: 12, stationDistance: 12, refreshMs: 2500 },
};

export const MOCK_HISTORY: PastRide[] = [
  { id: 12, scooterId: 2, plate: 'SCOOT002', startedAt: 1789500000, endedAt: 1789500900, minutes: 15, cost: 15, paid: 1 },
  { id: 9, scooterId: 1, plate: 'SCOOT001', startedAt: 1789400000, endedAt: 1789400300, minutes: 5, cost: 5, paid: 1 },
  { id: 4, scooterId: 4, plate: 'SCOOT004', startedAt: 1789300000, endedAt: 1789302400, minutes: 40, cost: 40, paid: 0 },
];

export const COLOURS: Record<number, { name: string; hex: string }> = {
  1: { name: 'Black', hex: '#0d1116' },
  2: { name: 'White', hex: '#f4f4f4' },
  3: { name: 'Red', hex: '#c00e1a' },
  4: { name: 'Blue', hex: '#0d5fb1' },
  5: { name: 'Yellow', hex: '#f7d117' },
  6: { name: 'Orange', hex: '#f78616' },
  7: { name: 'Green', hex: '#4cc81f' },
  8: { name: 'Purple', hex: '#7f2fdb' },
  9: { name: 'Pink', hex: '#f21f99' },
  10: { name: 'Teal', hex: '#1a6b78' },
};
