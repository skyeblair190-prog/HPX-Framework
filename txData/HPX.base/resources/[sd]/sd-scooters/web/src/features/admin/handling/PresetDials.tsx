import type { CSSProperties } from 'react';
import { t } from '@/i18n';
import type { HandlingBundle, HandlingValues } from '@/types';
import {
  accelerationLevel,
  brakingLevel,
  estimateTopMph,
  fromMph,
  gripLevel,
  leanLevel,
  toMph,
  withAcceleration,
  withBraking,
  withGrip,
  withLean,
  withTopSpeed,
} from './model';

const Dial = ({
  id,
  min,
  max,
  step,
  value,
  display,
  disabled,
  onChange,
}: {
  id: string;
  min: number;
  max: number;
  step: number;
  value: number;
  display: string;
  disabled: boolean;
  onChange: (v: number) => void;
}) => {
  const fill = ((value - min) / (max - min || 1)) * 100;
  return (
    <div className="sc-dial">
      <div className="min-w-0">
        <div className="text-[13px] font-medium">{t(`handling.preset.${id}.label`)}</div>
        <div className="text-[11.5px] leading-snug mt-0.5" style={{ color: 'var(--text-3)' }}>
          {t(`handling.preset.${id}.hint`)}
        </div>
      </div>
      <input
        type="range"
        className="sc-range w-full"
        min={min}
        max={max}
        step={step}
        value={Math.min(max, Math.max(min, value))}
        disabled={disabled}
        style={{ '--fill': `${Math.min(100, Math.max(0, fill))}%` } as CSSProperties}
        onChange={e => onChange(Number(e.target.value))}
      />
      <div className="mono text-right text-[14px] font-medium" style={{ color: disabled ? 'var(--text-3)' : 'var(--text-1)' }}>
        {display}
      </div>
    </div>
  );
};

export const PresetDials = ({
  bundle,
  values,
  disabled,
  onChange,
}: {
  bundle: HandlingBundle;
  values: HandlingValues;
  disabled: boolean;
  onChange: (next: HandlingValues) => void;
}) => {
  const unit = bundle.unit;
  const p = bundle.presets;
  const top = fromMph(estimateTopMph(bundle, values), unit);
  const topMin = Math.round(fromMph(p.TopSpeed.Min, unit));
  const topMax = Math.round(fromMph(p.TopSpeed.Max, unit));
  const levels = {
    Acceleration: accelerationLevel(bundle, values),
    Grip: gripLevel(bundle, values),
    Braking: brakingLevel(bundle, values),
    Lean: leanLevel(bundle, values),
  };
  return (
    <div className="flex flex-col gap-4">
      <Dial
        id="TopSpeed"
        min={topMin}
        max={topMax}
        step={p.TopSpeed.Step}
        value={Math.round(top)}
        display={`${Math.round(top)} ${unit === 'mph' ? 'mph' : 'km/h'}`}
        disabled={disabled}
        onChange={v => onChange(withTopSpeed(bundle, values, toMph(v, unit)))}
      />
      <Dial id="Acceleration" min={p.Acceleration.Min} max={p.Acceleration.Max} step={p.Acceleration.Step} value={levels.Acceleration} display={`${levels.Acceleration} / ${p.Acceleration.Max}`} disabled={disabled} onChange={v => onChange(withAcceleration(bundle, values, v))} />
      <Dial id="Grip" min={p.Grip.Min} max={p.Grip.Max} step={p.Grip.Step} value={levels.Grip} display={`${levels.Grip} / ${p.Grip.Max}`} disabled={disabled} onChange={v => onChange(withGrip(bundle, values, v))} />
      <Dial id="Braking" min={p.Braking.Min} max={p.Braking.Max} step={p.Braking.Step} value={levels.Braking} display={`${levels.Braking} / ${p.Braking.Max}`} disabled={disabled} onChange={v => onChange(withBraking(bundle, values, v))} />
      <Dial id="Lean" min={p.Lean.Min} max={p.Lean.Max} step={p.Lean.Step} value={levels.Lean} display={`${levels.Lean} / ${p.Lean.Max}`} disabled={disabled} onChange={v => onChange(withLean(bundle, values, v))} />
    </div>
  );
};
