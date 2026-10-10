export type Slot = false | { scooterId: number; full: boolean; plate?: string; colour?: number; battery?: number; target?: number };
export interface StationView { name: string; slots: Slot[]; free: number }
export interface Toast { text: string; kind: 'ok' | 'error' }
export interface Charging { paid: boolean; pricePerPercent: number; minimumFee: number; step: number; presets: number[]; perMinute: number; drainPerMinute: number; minToRent: number; fullAt: number }
export interface Pricing { unlock: number; currency: string }
export type Method = 'bank' | 'cash';
