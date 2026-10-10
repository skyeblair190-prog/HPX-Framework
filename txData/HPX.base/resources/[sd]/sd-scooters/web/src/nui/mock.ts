import type { Customization, Snapshot } from '@/types';
import catalog from '@/app/native/extrasCatalog.json';

export const MOCK_SNAPSHOT: Snapshot = {
  bunkers: [
    { id: 1, name: 'Legion Square', x: 195.2, y: -933.8, z: 30.69, heading: 0, enabled: true, scooters: 3, stock: 5 },
    { id: 2, name: 'Vespucci Beach', x: -1183.4, y: -1511.2, z: 4.37, heading: 125, enabled: true, scooters: 2, stock: 1 },
    { id: 3, name: 'Mirror Park (closed)', x: 1044.0, y: -768.9, z: 58.0, heading: 270, enabled: false, scooters: 1, stock: 0 },
  ],
  stations: [
    {
      id: 1, name: 'Pillbox Hill', x: 212.4, y: -920.2, z: 30.7, heading: 90, enabled: true, count: 4, colour: 1, occupied: 2,
      slots: [{ scooterId: 2, full: false, plate: 'SCOOT002', colour: 3, battery: 41, target: 80 }, false, { scooterId: 5, full: true, plate: 'SCOOT005', colour: 7, battery: 100 }, false],
    },
    { id: 2, name: 'Del Perro Pier', x: -1650.0, y: -1000.0, z: 7.3, heading: 320, enabled: false, count: 2, colour: 4, slots: [false, false], occupied: 0 },
  ],
  scooters: [
    { id: 1, plate: 'SCOOT001', colour: 10, bunkerId: 1, status: 'available', battery: 92, x: 195.2, y: -935.4, z: 31.0, heading: 180, exists: true, locked: true },
    { id: 2, plate: 'SCOOT002', colour: 3, bunkerId: 1, stationId: 1, slot: 1, status: 'charging', battery: 41, x: 210.9, y: -921.1, z: 30.7, heading: 90, exists: true, locked: true, chargeTarget: 80 },
    { id: 3, plate: 'SCOOT003', colour: 5, bunkerId: null, status: 'flat', battery: 0, x: -1160.0, y: -1520.0, z: 4.4, heading: 30, exists: false },
    { id: 4, plate: 'SCOOT004', colour: 8, bunkerId: 3, status: 'rented', battery: 67, x: 402.0, y: -870.0, z: 29.0, heading: 0, exists: true, rentedBy: 'Jamie Carter' },
    { id: 5, plate: 'SCOOT005', colour: 7, bunkerId: null, stationId: 1, slot: 3, status: 'charging', battery: 100, x: 213.1, y: -919.5, z: 30.7, heading: 90, exists: true, locked: true },
    { id: 6, plate: 'SCOOT006', colour: 2, bunkerId: 2, status: 'rented', battery: 23, x: -1080.0, y: -1380.0, z: 5.0, heading: 40, exists: true, rentedBy: 'Ava Brooks' },
    { id: 7, plate: 'SCOOT007', colour: 1, bunkerId: 2, status: 'available', battery: 12, x: -1190.0, y: -1500.0, z: 4.4, heading: 125, exists: true, locked: true },
  ],
  rides: [],
  today: { rides: 0, revenue: 0, unpaid: 0, minutes: 0 },
  battery: { enabled: true, minToRent: 15, fullAt: 100 },
  extras: { rear: catalog.rear, trim: catalog.trim, lighting: catalog.lighting, box: catalog.box, defaults: catalog.defaults as Customization },
  colours: [
    { index: 1, name: 'Black', hex: '#0d1116' },
    { index: 2, name: 'White', hex: '#f4f4f4' },
    { index: 3, name: 'Red', hex: '#c00e1a' },
    { index: 4, name: 'Blue', hex: '#0d5fb1' },
    { index: 5, name: 'Yellow', hex: '#f7d117' },
    { index: 6, name: 'Orange', hex: '#f78616' },
    { index: 7, name: 'Green', hex: '#4cc81f' },
    { index: 8, name: 'Purple', hex: '#7f2fdb' },
    { index: 9, name: 'Pink', hex: '#f21f99' },
    { index: 10, name: 'Teal', hex: '#1a6b78' },
  ],
  stationLayout: { slotX: [-1.05, -0.35, 0.35, 1.05], railStart: -1.4, dockPitch: 0.7 },
  stationColours: [
    { index: 1, name: 'Teal', hex: '#0a949a' },
    { index: 2, name: 'Charcoal', hex: '#22282e' },
    { index: 3, name: 'White', hex: '#f4f4f4' },
    { index: 4, name: 'Red', hex: '#c00e1a' },
    { index: 5, name: 'Blue', hex: '#0d5fb1' },
    { index: 6, name: 'Yellow', hex: '#f7d117' },
    { index: 7, name: 'Orange', hex: '#f78616' },
    { index: 8, name: 'Green', hex: '#4cc81f' },
    { index: 9, name: 'Purple', hex: '#7f2fdb' },
    { index: 10, name: 'Pink', hex: '#f21f99' },
  ],
  currency: '$',
  map: 'atlas',
  positionsInterval: 3000,
  player: { x: 201.0, y: -940.0, z: 30.7, heading: 90 },
  canEdit: true,
  undoSeconds: 30,
};

export function devSeed(): void {
  window.setTimeout(async () => {
    const { mockNui } = await import('./mockServer');
    const reply = (await mockNui('scoot:admin:snapshot', {})) as { data: Snapshot };
    window.dispatchEvent(new MessageEvent('message', { data: { action: 'scoot:admin:open', data: { snapshot: reply.data } } }));
  }, 50);
}
