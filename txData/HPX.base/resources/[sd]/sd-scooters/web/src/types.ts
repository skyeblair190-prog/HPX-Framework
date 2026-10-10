export interface Bunker {
  id: number;
  name: string;
  x: number;
  y: number;
  z: number;
  heading: number;
  enabled: boolean;
  scooters: number;
  stock: number;
  busy?: boolean;
  createdBy?: string | null;
}

export type StationSlot = false | { scooterId: number; full: boolean; plate?: string; colour?: number; battery?: number; target?: number | null };

export interface Station {
  id: number;
  name: string;
  x: number;
  y: number;
  z: number;
  heading: number;
  enabled: boolean;
  count: number;
  colour: number;
  slots: StationSlot[];
  occupied: number;
  createdBy?: string | null;
}

export interface BatteryInfo {
  enabled: boolean;
  minToRent: number;
  fullAt: number;
}

export interface Scooter {
  id: number;
  plate: string;
  colour: number;
  bunkerId: number | null;
  stationId?: number | null;
  slot?: number | null;
  battery: number;
  status: string;
  x: number;
  y: number;
  z: number;
  heading: number;
  exists: boolean;
  locked?: boolean;
  rentedBy?: string | null;
  chargeTarget?: number | null;
  customization?: Customization | null;
}

export interface Colour {
  index: number;
  name: string;
  hex: string;
}

export interface Vec3 {
  x: number;
  y: number;
  z: number;
}

export type MapStyleId = 'satellite' | 'atlas';

export interface RideTotals {
  rides: number;
  revenue: number;
  unpaid: number;
  minutes: number;
}

export interface ActiveRide {
  id: number;
  renter: string;
  renterName: string;
  source?: number;
  online: boolean;
  scooterId: number;
  plate: string;
  startedAt: number;
  minutes: number;
  cost: number;
  battery?: number | null;
  x?: number | null;
  y?: number | null;
}

export interface ExtrasOption {
  id: string;
  label: string;
  fee: number;
  hex?: string;
}

export interface Customization {
  rear: string;
  trim: string;
  lighting: string;
  box: string;
}

export interface ExtrasCatalog {
  rear: ExtrasOption[];
  trim: ExtrasOption[];
  lighting: ExtrasOption[];
  box: ExtrasOption[];
  defaults: Customization;
}

export interface Snapshot {
  bunkers: Bunker[];
  stations: Station[];
  scooters: Scooter[];
  rides: ActiveRide[];
  today: RideTotals;
  battery: BatteryInfo;
  colours: Colour[];
  extras?: ExtrasCatalog;
  stationColours: StationColour[];
  stationLayout?: { slotX: number[]; railStart: number; dockPitch: number };
  currency: string;
  map: MapStyleId;
  positionsInterval: number;
  player: (Vec3 & { heading?: number }) | null;
  canEdit: boolean;
  undoSeconds: number;
}

export interface RideRow {
  id: number;
  scooterId: number;
  plate: string | null;
  bunkerId: number | null;
  renter: string;
  renterName: string | null;
  startedAt: number;
  endedAt: number | null;
  minutes: number;
  cost: number;
  paid: number | boolean;
  refunded: number;
  endedBy: string | null;
  startX?: number | null;
  startY?: number | null;
  endX?: number | null;
  endY?: number | null;
}

export interface RidesData {
  active: ActiveRide[];
  totals: { today: RideTotals; week: RideTotals; all: RideTotals };
  byBunker: { bunkerId: number | null; name?: string | null; rides: number; revenue: number }[];
  hourly: { hour: number; rides: number; revenue: number }[];
  firstHour: number;
  currency: string;
}

export interface Page<T> {
  rows: T[];
  total: number;
  offset: number;
  pageSize: number;
}

export interface AuditRow {
  id: number;
  actor: string;
  verb: string;
  message: string;
  at: number;
}

export interface SettingItem {
  path: string;
  group: string;
  type: 'int' | 'number' | 'bool' | 'enum';
  min?: number;
  max?: number;
  step?: number;
  options?: string[];
  unit?: string;
  default: number | boolean | string;
  value: number | boolean | string;
  overridden: boolean;
  updatedBy?: string | null;
  updatedAt?: number | null;
}

export interface SettingsBundle {
  settings: SettingItem[];
  currency: string;
}

export interface Rider {
  rideId: number;
  scooterId: number;
  name: string;
  plate: string;
  minutes: number;
  x?: number | null;
  y?: number | null;
}

export interface ActivityPoint {
  sx: number | null;
  sy: number | null;
  ex: number | null;
  ey: number | null;
}

export interface StationColour {
  index: number;
  name: string;
  hex: string;
}

export interface Placed {
  kind: 'object' | 'vehicle';
  what?: 'bunker' | 'station' | 'scooter';
  action?: 'placed' | 'moved';
  success: boolean;
  cancelled?: boolean;
  message?: string;
}

export interface Reply<T = unknown> {
  success: boolean;
  message?: string;
  data?: T;
}

export interface Position {
  id: number;
  x: number;
  y: number;
  z: number;
  heading: number;
}

export interface PositionsData {
  scooters: Position[];
  player: Vec3 | null;
  riders?: Rider[];
}

export const TABS = ['overview', 'rides', 'bunkers', 'stations', 'scooters', 'map', 'handling', 'settings', 'log'] as const;
export type Tab = (typeof TABS)[number];

export type HandlingValue = number | Vec3 | string;
export type HandlingValues = Record<string, HandlingValue>;

export interface HandlingField {
  name: string;
  class: string;
  type: 'float' | 'int' | 'vector' | 'horn';
  unit?: 'deg';
  min: number;
  max: number;
  step: number;
  default: HandlingValue;
  options?: { id: string; label: string }[];
}

export interface HandlingGroup {
  id: string;
  fields: HandlingField[];
}

export interface HandlingProfile {
  id: number;
  name: string;
  values: HandlingValues;
  active: boolean;
  updatedBy?: string | null;
  updatedAt?: number | null;
}

export interface HandlingHistoryEntry {
  id: number;
  profileId: number;
  actor: string;
  changes: Record<string, [HandlingValue | false, HandlingValue | false]>;
  at: number;
}

export interface PresetRange {
  Min: number;
  Max: number;
  Step: number;
  [key: string]: number;
}

export interface HandlingTemplate {
  name: string;
  values: HandlingValues;
}

export interface HandlingBundle {
  enabled: boolean;
  groups: HandlingGroup[];
  presets: Record<'TopSpeed' | 'Acceleration' | 'Grip' | 'Braking' | 'Lean', PresetRange>;
  templates: HandlingTemplate[];
  profiles: HandlingProfile[];
  activeId: number;
  history: HandlingHistoryEntry[];
  returnKey: string;
  unit: 'mph' | 'kmh';
}

export interface TestRideState {
  active: boolean;
  key?: string;
  unit?: 'mph' | 'kmh';
  launch?: number;
}

export interface Telemetry {
  speed: number;
  top: number;
  launch?: number | null;
  lastLaunch?: number | null;
}
