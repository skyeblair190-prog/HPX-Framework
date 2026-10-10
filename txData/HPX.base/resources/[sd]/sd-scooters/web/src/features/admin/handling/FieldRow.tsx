import { memo, useEffect, useState } from 'react';
import type { CSSProperties } from 'react';
import { Play, RotateCcw } from 'lucide-react';
import { t } from '@/i18n';
import { Select } from '@/components/Select';
import { fetchNui } from '@/nui/bridge';
import { useAdmin } from '@/store/admin';
import type { Reply } from '@/types';
import type { HandlingField, HandlingValue, Vec3 } from '@/types';
import { clampField, decimals, format, isVec, same } from './model';

const NumberControl = ({
  field,
  value,
  disabled,
  onChange,
  axis,
}: {
  field: HandlingField;
  value: number;
  disabled: boolean;
  onChange: (v: number) => void;
  axis?: string;
}) => {
  const d = decimals(field.step);
  const [text, setText] = useState(value.toFixed(d));
  useEffect(() => setText(value.toFixed(d)), [value, d]);
  const commit = () => {
    const n = Number(text);
    if (text.trim() === '' || !Number.isFinite(n)) {
      setText(value.toFixed(d));
      return;
    }
    onChange(clampField(field, n));
  };
  const fill = ((value - field.min) / (field.max - field.min || 1)) * 100;
  return (
    <div className="flex items-center gap-2.5 min-w-0">
      {axis && (
        <span className="mono text-[11px] w-3 text-center" style={{ color: 'var(--text-3)' }}>
          {axis}
        </span>
      )}
      <input
        type="range"
        className="sc-range flex-1 min-w-0"
        min={field.min}
        max={field.max}
        step={field.step}
        value={value}
        disabled={disabled}
        style={{ '--fill': `${Math.min(100, Math.max(0, fill))}%` } as CSSProperties}
        onChange={e => onChange(clampField(field, Number(e.target.value)))}
      />
      <input
        className="sc-input sc-input--num mono"
        value={text}
        disabled={disabled}
        inputMode="decimal"
        onChange={e => setText(e.target.value)}
        onBlur={commit}
        onKeyDown={e => {
          if (e.key === 'Enter') (e.target as HTMLInputElement).blur();
        }}
      />
    </div>
  );
};

const HornControl = ({ field, value, disabled, onChange }: { field: HandlingField; value: string; disabled: boolean; onChange: (v: string) => void }) => {
  const play = async () => {
    const reply = await fetchNui<Reply>('scoot:admin:hornpreview', { horn: value });
    if (reply && !reply.success) useAdmin.getState().toast(reply.message ?? t('toast.failed'), false);
  };
  return (
    <div className="flex items-center gap-2 min-w-0">
      <div className="flex-1 min-w-0">
        <Select value={value} disabled={disabled} ariaLabel={t('handling.fields.horn.label')}
          options={(field.options ?? []).map(o => ({ value: o.id, label: o.label }))} onChange={onChange} />
      </div>
      <button type="button" className="sc-btn" style={{ height: 32 }} disabled={value === 'none'} title={t('handling.horn_play')} onClick={() => void play()}>
        <Play size={13} />
        {t('handling.horn_play')}
      </button>
    </div>
  );
};

export const FieldRow = memo(
  ({
    field,
    value,
    saved,
    disabled,
    onChange,
  }: {
    field: HandlingField;
    value: HandlingValue;
    saved: HandlingValue;
    disabled: boolean;
    onChange: (name: string, value: HandlingValue) => void;
  }) => {
    const unsaved = !same(value, saved);
    const fromFile = !same(value, field.default);
    const label = t(`handling.fields.${field.name}.label`);
    const hint = t(`handling.fields.${field.name}.hint`);
    const vec = isVec(value) ? value : null;
    return (
      <div className={`sc-field${unsaved ? ' sc-field--unsaved' : ''}`}>
        <div className="min-w-0">
          <div className="flex items-center gap-2">
            <span className="text-[13px] font-medium truncate">{label}</span>
            <span className="mono text-[11px] truncate" style={{ color: 'var(--text-4)' }}>
              {field.name}
            </span>
          </div>
          <div className="text-[12px] leading-snug mt-0.5" style={{ color: 'var(--text-3)' }}>
            {hint}
          </div>
          {fromFile && (
            <div className="mono text-[11px] mt-1" style={{ color: 'var(--text-3)' }}>
              {t('handling.file_value', format(field, field.default))}
            </div>
          )}
        </div>
        <div className="flex flex-col gap-1.5 min-w-0 justify-center">
          {field.type === 'horn' ? (
            <HornControl field={field} value={String(value)} disabled={disabled} onChange={id => onChange(field.name, id)} />
          ) : vec ? (
            (['x', 'y', 'z'] as (keyof Vec3)[]).map(axis => (
              <NumberControl
                key={axis}
                axis={axis}
                field={field}
                value={vec[axis]}
                disabled={disabled}
                onChange={n => onChange(field.name, { ...vec, [axis]: n })}
              />
            ))
          ) : (
            <NumberControl field={field} value={value as number} disabled={disabled} onChange={n => onChange(field.name, n)} />
          )}
        </div>
        <div className="flex items-center justify-end">
          <button
            type="button"
            className="sc-btn sc-btn--icon"
            title={t('handling.reset_field')}
            disabled={disabled || !fromFile}
            style={{ visibility: fromFile ? 'visible' : 'hidden' }}
            onClick={() => onChange(field.name, field.default)}
          >
            <RotateCcw size={13} />
          </button>
        </div>
      </div>
    );
  },
);
