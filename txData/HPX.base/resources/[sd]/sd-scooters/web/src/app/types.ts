export interface AppScooter {
  id: number;
  plate: string;
  colour: number;
  x: number;
  y: number;
  z: number;
  distance: number;
  available: boolean;
  rentable?: boolean;
  battery?: number;
  charging?: boolean;
  flat?: boolean;
  bunkerId: number | null;
  stationId?: number | null;
}

export interface AppCharger {
  id: number;
  name: string;
  x: number;
  y: number;
  z: number;
  distance: number;
  slots: number;
  free: number;
  occupied: number;
}

export interface AppBunker {
  id: number;
  name: string;
  x: number;
  y: number;
  z: number;
  distance: number;
  stock: number;
  busy: boolean;
}

export interface Ride {
  id: number;
  scooterId: number;
  plate: string;
  colour: number;
  startedAt: number;
  minutes: number;
  cost: number;
}

export interface Pricing {
  unlock: number;
  currency: string;
  rentDistance: number;
  stationDistance: number;
  refreshMs: number;
}

export interface Nearby {
  player: { x: number; y: number; z: number; heading: number };
  scooters: AppScooter[];
  bunkers: AppBunker[];
  stations?: AppCharger[];
  battery?: { enabled: boolean; minToRent: number; fullAt: number };
  ride: Ride | null;
  pricing: Pricing;
}

export interface Receipt {
  plate: string;
  minutes: number;
  cost: number;
  paid: boolean;
}

export interface PastRide {
  id: number;
  scooterId: number;
  plate: string | null;
  startedAt: number;
  endedAt: number;
  minutes: number;
  cost: number;
  paid: number;
}

export interface Reply<T = unknown> {
  success: boolean;
  message?: string;
  data?: T;
}
