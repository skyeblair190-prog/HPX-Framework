import type { HandlingBundle, HandlingField, HandlingValue, HandlingValues, PresetRange, Vec3 } from '@/types';

export const EPSILON = 1e-4;
const MPH_TO_KMH = 1.609344;

export const isVec = (v: HandlingValue | undefined | false): v is Vec3 => typeof v === 'object' && v !== null;

export function asValues(raw: unknown): HandlingValues {
  return raw && typeof raw === 'object' && !Array.isArray(raw) ? (raw as HandlingValues) : {};
}

export function same(a: HandlingValue | undefined, b: HandlingValue | undefined): boolean {
  if (a === undefined || b === undefined) return a === b;
  if (typeof a === 'string' || typeof b === 'string') return a === b;
  if (isVec(a) && isVec(b)) return Math.abs(a.x - b.x) < EPSILON && Math.abs(a.y - b.y) < EPSILON && Math.abs(a.z - b.z) < EPSILON;
  if (isVec(a) || isVec(b)) return false;
  return Math.abs(a - b) < EPSILON;
}

export function allFields(bundle: HandlingBundle): HandlingField[] {
  return bundle.groups.flatMap(g => g.fields);
}

export function resolve(bundle: HandlingBundle, overrides: HandlingValues): HandlingValues {
  const out: HandlingValues = {};
  for (const f of allFields(bundle)) out[f.name] = overrides[f.name] ?? f.default;
  return out;
}

export function clampField(f: HandlingField, v: number): number {
  const n = Math.min(f.max, Math.max(f.min, Number.isFinite(v) ? v : f.min));
  return f.type === 'int' ? Math.round(n) : n;
}

export function decimals(step: number): number {
  const s = String(step);
  return s.includes('.') ? s.split('.')[1].length : 0;
}

export function format(f: HandlingField, v: HandlingValue): string {
  if (typeof v === 'string') return f.options?.find(o => o.id === v)?.label ?? v;
  const d = decimals(f.step);
  return isVec(v) ? `${v.x.toFixed(d)}, ${v.y.toFixed(d)}, ${v.z.toFixed(d)}` : v.toFixed(d);
}


const num = (values: HandlingValues, name: string, fallback: number): number => {
  const v = values[name];
  return typeof v === 'number' ? v : fallback;
};

const lerp = (a: number, b: number, t: number) => a + (b - a) * t;
const unlerp = (a: number, b: number, v: number) => (b === a ? 0 : (v - a) / (b - a));
const toLevel = (r: PresetRange, t: number) => Math.round(Math.min(r.Max, Math.max(r.Min, lerp(r.Min, r.Max, t))));
const levelT = (r: PresetRange, level: number) => unlerp(r.Min, r.Max, level);

export const fromMph = (mph: number, unit: 'mph' | 'kmh') => (unit === 'mph' ? mph : mph * MPH_TO_KMH);
export const toMph = (speed: number, unit: 'mph' | 'kmh') => (unit === 'mph' ? speed : speed / MPH_TO_KMH);

function speedConstant(r: PresetRange): number {
  return (r.AnchorMph * r.AnchorMph * r.AnchorDrag) / r.AnchorForce;
}

export function estimateTopMph(bundle: HandlingBundle, values: HandlingValues): number {
  const r = bundle.presets.TopSpeed;
  const force = num(values, 'fInitialDriveForce', r.AnchorForce);
  const drag = Math.max(0.01, num(values, 'fInitialDragCoeff', r.AnchorDrag));
  return Math.sqrt((speedConstant(r) * force) / drag);
}

function field(bundle: HandlingBundle, name: string): HandlingField | undefined {
  return allFields(bundle).find(f => f.name === name);
}

function setNum(bundle: HandlingBundle, values: HandlingValues, name: string, v: number): void {
  const f = field(bundle, name);
  if (f) values[name] = clampField(f, v);
}

export function withTopSpeed(bundle: HandlingBundle, values: HandlingValues, targetMph: number): HandlingValues {
  const r = bundle.presets.TopSpeed;
  const out = { ...values };
  const k = speedConstant(r);
  const target = Math.max(1, targetMph);
  const force = num(out, 'fInitialDriveForce', r.AnchorForce);
  setNum(bundle, out, 'fInitialDragCoeff', (k * force) / (target * target));
  const drag = num(out, 'fInitialDragCoeff', r.AnchorDrag);
  setNum(bundle, out, 'fInitialDriveForce', (drag * target * target) / k);
  const flat = num(out, 'fInitialDriveMaxFlatVel', 30);
  if (flat < target * 0.75) setNum(bundle, out, 'fInitialDriveMaxFlatVel', Math.ceil(target * 0.8));
  return out;
}

export function accelerationLevel(bundle: HandlingBundle, values: HandlingValues): number {
  const r = bundle.presets.Acceleration;
  return toLevel(r, unlerp(r.ForceMin, r.ForceMax, num(values, 'fInitialDriveForce', r.ForceMin)));
}

export function withAcceleration(bundle: HandlingBundle, values: HandlingValues, level: number): HandlingValues {
  const r = bundle.presets.Acceleration;
  const keepMph = estimateTopMph(bundle, values);
  const out = { ...values };
  setNum(bundle, out, 'fInitialDriveForce', lerp(r.ForceMin, r.ForceMax, levelT(r, level)));
  return withTopSpeed(bundle, out, keepMph);
}

export function gripLevel(bundle: HandlingBundle, values: HandlingValues): number {
  const r = bundle.presets.Grip;
  return toLevel(r, unlerp(r.CurveMaxMin, r.CurveMaxMax, num(values, 'fTractionCurveMax', r.CurveMaxMin)));
}

export function withGrip(bundle: HandlingBundle, values: HandlingValues, level: number): HandlingValues {
  const r = bundle.presets.Grip;
  const out = { ...values };
  const peak = lerp(r.CurveMaxMin, r.CurveMaxMax, levelT(r, level));
  setNum(bundle, out, 'fTractionCurveMax', peak);
  setNum(bundle, out, 'fTractionCurveMin', peak * 0.9);
  return out;
}

export function brakingLevel(bundle: HandlingBundle, values: HandlingValues): number {
  const r = bundle.presets.Braking;
  return toLevel(r, unlerp(r.ForceMin, r.ForceMax, num(values, 'fBrakeForce', r.ForceMin)));
}

export function withBraking(bundle: HandlingBundle, values: HandlingValues, level: number): HandlingValues {
  const r = bundle.presets.Braking;
  const out = { ...values };
  setNum(bundle, out, 'fBrakeForce', lerp(r.ForceMin, r.ForceMax, levelT(r, level)));
  return out;
}

export function leanLevel(bundle: HandlingBundle, values: HandlingValues): number {
  const r = bundle.presets.Lean;
  return toLevel(r, unlerp(r.BankMin, r.BankMax, num(values, 'fMaxBankAngle', r.BankMin)));
}

export function withLean(bundle: HandlingBundle, values: HandlingValues, level: number): HandlingValues {
  const r = bundle.presets.Lean;
  const out = { ...values };
  const bank = lerp(r.BankMin, r.BankMax, levelT(r, level));
  setNum(bundle, out, 'fMaxBankAngle', bank);
  setNum(bundle, out, 'fFullAnimAngle', bank + 6);
  return out;
}

export function dirtyFields(bundle: HandlingBundle, draft: HandlingValues, saved: HandlingValues): string[] {
  return allFields(bundle)
    .filter(f => !same(draft[f.name], saved[f.name]))
    .map(f => f.name);
}
