import { useEffect, useRef, useState } from 'react';
import type { ReactNode } from 'react';
import { Minus, Plus, Search, X } from 'lucide-react';
import { useAdmin } from '@/store/admin';
import { t } from '@/i18n';

const escapeStack: { current: () => void }[] = [];
let escapeBound = false;

function bindEscape() {
  if (escapeBound) return;
  escapeBound = true;
  window.addEventListener(
    'keydown',
    e => {
      if (e.key !== 'Escape' || escapeStack.length === 0) return;
      e.stopPropagation();
      e.preventDefault();
      escapeStack[escapeStack.length - 1].current();
    },
    true,
  );
}

export function useEscape(onClose: () => void): void {
  const entry = useRef({ current: onClose });
  entry.current.current = onClose;
  useEffect(() => {
    bindEscape();
    const item = entry.current;
    escapeStack.push(item);
    return () => {
      const i = escapeStack.lastIndexOf(item);
      if (i >= 0) escapeStack.splice(i, 1);
    };
  }, []);
}

type Tone = 'neutral' | 'accent' | 'danger' | 'warn';

export const Badge = ({ children, tone = 'neutral' }: { children: ReactNode; tone?: Tone }) => {
  const styles: Record<Tone, { bg: string; fg: string }> = {
    neutral: { bg: 'rgba(255,255,255,0.06)', fg: 'var(--text-2)' },
    accent: { bg: 'var(--ok-soft)', fg: 'var(--ok)' },
    danger: { bg: 'var(--danger-soft)', fg: 'var(--danger)' },
    warn: { bg: 'var(--warn-soft)', fg: 'var(--warn)' },
  };
  const s = styles[tone];
  return (
    <span className="inline-flex items-center h-[18px] px-1.5 rounded text-[11px] font-medium mono whitespace-nowrap" style={{ backgroundColor: s.bg, color: s.fg }}>
      {children}
    </span>
  );
};

export const Status = ({ tone = 'neutral', children }: { tone?: 'neutral' | 'ok' | 'warn' | 'danger'; children: ReactNode }) => (
  <span className={`sc-status${tone === 'neutral' ? '' : ` sc-status--${tone}`}`}>{children}</span>
);

export const Heading = ({ title, count, children }: { title: string; count?: number; children?: ReactNode }) => (
  <div className="flex items-center gap-3 min-h-[30px]">
    <div className="sc-heading">
      {title}
      {count != null && <span className="sc-heading__count">{count}</span>}
    </div>
    {children && <div className="ml-auto flex items-center gap-2">{children}</div>}
  </div>
);

export const Swatch = ({ hex, size = 12, active = false }: { hex: string; size?: number; active?: boolean }) => (
  <span
    className="inline-block rounded-full flex-shrink-0"
    style={{
      width: size,
      height: size,
      backgroundColor: hex,
      boxShadow: active ? `0 0 0 2px var(--bg), 0 0 0 3px var(--text-1)` : 'inset 0 0 0 1px rgba(255,255,255,0.14)',
    }}
  />
);

export const Empty = ({ text }: { text: string }) => (
  <div className="flex items-center justify-center h-full min-h-[140px] text-[12.5px]" style={{ color: 'var(--text-3)' }}>
    {text}
  </div>
);

export const Hint = ({ children, className = '' }: { children: ReactNode; className?: string }) => (
  <p className={`text-[11.5px] leading-relaxed m-0 ${className}`} style={{ color: 'var(--text-3)' }}>
    {children}
  </p>
);

export const Modal = ({ title, onClose, children, width = 420 }: { title: string; onClose: () => void; children: ReactNode; width?: number }) => {
  useEscape(onClose);
  return (
    <div
      data-modal
      className="fixed inset-0 z-40 flex items-center justify-center animate-fadeIn"
      style={{ backgroundColor: 'rgba(0,0,0,0.5)' }}
      onMouseDown={e => {
        if (e.target === e.currentTarget) onClose();
      }}
    >
      <div
        className="relative rounded-[12px] overflow-hidden animate-panelIn"
        style={{ width, maxWidth: '92%', backgroundColor: 'var(--surface)', border: '1px solid var(--hairline-strong)', boxShadow: '0 20px 50px rgba(0,0,0,0.5)' }}
      >
        <div className="flex items-center gap-3 pl-5 pr-3 h-12">
          <span className="text-[14px] font-semibold">{title}</span>
          <button type="button" className="sc-btn sc-btn--icon ml-auto" onClick={onClose} aria-label={t('actions.close')}>
            <X size={15} />
          </button>
        </div>
        <div className="px-5 pb-5 pt-1">{children}</div>
      </div>
    </div>
  );
};

export const ModalActions = ({ children }: { children: ReactNode }) => <div className="flex justify-end gap-2 mt-5">{children}</div>;

export const ConfirmDialog = ({
  title,
  body,
  confirmLabel,
  onConfirm,
  onClose,
  danger = true,
}: {
  title: string;
  body: string;
  confirmLabel?: string;
  onConfirm: () => void | Promise<void>;
  onClose: () => void;
  danger?: boolean;
}) => {
  const [working, setWorking] = useState(false);
  return (
    <Modal title={title} onClose={onClose} width={380}>
      <p className="text-[13px] leading-relaxed m-0" style={{ color: 'var(--text-2)' }}>
        {body}
      </p>
      <ModalActions>
        <button type="button" className="sc-btn" onClick={onClose} disabled={working}>
          {t('actions.cancel')}
        </button>
        <button
          type="button"
          className={`sc-btn ${danger ? 'sc-btn--danger-solid' : 'sc-btn--primary'}`}
          disabled={working}
          onClick={async () => {
            setWorking(true);
            await onConfirm();
            setWorking(false);
          }}
        >
          {confirmLabel ?? t('actions.confirm')}
        </button>
      </ModalActions>
    </Modal>
  );
};

export const Toasts = () => {
  const toasts = useAdmin(s => s.toasts);
  if (!toasts.length) return null;
  return (
    <div className="absolute bottom-5 left-1/2 -translate-x-1/2 z-50 flex flex-col gap-2 items-center pointer-events-none">
      {toasts.map(tt => (
        <div
          key={tt.id}
          className="animate-toastIn flex items-center gap-2.5 pl-3 pr-3.5 h-9 rounded-lg text-[12.5px] font-medium"
          style={{ backgroundColor: 'var(--surface-3)', border: '1px solid var(--hairline-strong)', color: 'var(--text-1)', boxShadow: '0 8px 24px rgba(0,0,0,0.4)' }}
        >
          <span className="w-1.5 h-1.5 rounded-full flex-shrink-0" style={{ backgroundColor: tt.ok ? 'var(--ok)' : 'var(--danger)' }} />
          {tt.text}
          {tt.action && (
            <button
              type="button"
              className="pointer-events-auto ml-2 -mr-1.5 h-6 px-2 rounded-[5px] text-[12px] font-semibold"
              style={{ background: 'rgba(255,255,255,0.08)', border: 'none', color: 'var(--text-1)' }}
              onClick={() => {
                useAdmin.getState().dismissToast(tt.id);
                void tt.action!.run();
              }}
            >
              {tt.action.label}
            </button>
          )}
        </div>
      ))}
    </div>
  );
};

export const Drawer = ({
  title,
  subtitle,
  onClose,
  children,
  footer,
  width = 380,
}: {
  title: ReactNode;
  subtitle?: ReactNode;
  onClose: () => void;
  children: ReactNode;
  footer?: ReactNode;
  width?: number;
}) => {
  useEscape(onClose);
  return (
    <div
      className="absolute inset-y-0 right-0 z-30 flex flex-col animate-drawerIn"
      style={{ width, backgroundColor: 'var(--surface)', borderLeft: '1px solid var(--hairline-strong)', boxShadow: '-24px 0 48px rgba(0,0,0,0.35)' }}
    >
      <div className="flex items-start gap-3 pl-5 pr-3 pt-3.5 pb-3 flex-shrink-0" style={{ borderBottom: '1px solid var(--hairline)' }}>
        <div className="min-w-0 flex-1 pt-0.5">
          <div className="text-[14px] font-semibold truncate">{title}</div>
          {subtitle && (
            <div className="text-[12px] mt-0.5 truncate" style={{ color: 'var(--text-3)' }}>
              {subtitle}
            </div>
          )}
        </div>
        <button type="button" className="sc-btn sc-btn--icon" onClick={onClose} aria-label={t('actions.close')}>
          <X size={15} />
        </button>
      </div>
      <div className="flex-1 min-h-0 overflow-y-auto sc-scroll">{children}</div>
      {footer && (
        <div className="flex items-center gap-2 px-4 h-14 flex-shrink-0" style={{ borderTop: '1px solid var(--hairline)' }}>
          {footer}
        </div>
      )}
    </div>
  );
};

export const Field = ({ label, children }: { label: ReactNode; children: ReactNode }) => (
  <div className="flex items-baseline justify-between gap-4 py-1.5">
    <span className="text-[12.5px] flex-shrink-0" style={{ color: 'var(--text-3)' }}>
      {label}
    </span>
    <span className="text-[12.5px] text-right min-w-0 truncate" style={{ color: 'var(--text-1)' }}>
      {children}
    </span>
  </div>
);

export const Section = ({ title, children, action }: { title?: ReactNode; children: ReactNode; action?: ReactNode }) => (
  <div className="px-5 py-4" style={{ borderBottom: '1px solid var(--hairline)' }}>
    {(title || action) && (
      <div className="flex items-center mb-2 min-h-[22px]">
        {title && <span className="sc-label">{title}</span>}
        {action && <span className="ml-auto">{action}</span>}
      </div>
    )}
    {children}
  </div>
);

export const Skeleton = ({ rows = 4, height = 52 }: { rows?: number; height?: number }) => (
  <div className="sc-list">
    {Array.from({ length: rows }, (_, i) => (
      <div key={i} className="flex items-center gap-3 px-4" style={{ height, borderTop: i ? '1px solid var(--hairline)' : 'none' }}>
        <span className="sc-skeleton" style={{ width: 12, height: 12, borderRadius: 999 }} />
        <span className="sc-skeleton" style={{ width: 120 + ((i * 37) % 90), height: 10 }} />
        <span className="sc-skeleton ml-auto" style={{ width: 60, height: 10 }} />
      </div>
    ))}
  </div>
);

export const SearchInput = ({ value, onChange, placeholder, hotkey = true }: { value: string; onChange: (v: string) => void; placeholder: string; hotkey?: boolean }) => {
  const ref = useRef<HTMLInputElement>(null);
  useEffect(() => {
    if (!hotkey) return;
    const onKey = (e: KeyboardEvent) => {
      const tag = (document.activeElement as HTMLElement | null)?.tagName;
      if (e.key === '/' && tag !== 'INPUT' && tag !== 'TEXTAREA') {
        e.preventDefault();
        ref.current?.focus();
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [hotkey]);
  return (
    <div className="relative flex-1 min-w-[160px]">
      <Search size={14} className="absolute left-2.5 top-1/2 -translate-y-1/2 pointer-events-none" style={{ color: 'var(--text-3)' }} />
      <input
        ref={ref}
        className="sc-input"
        style={{ paddingLeft: 30, paddingRight: 28 }}
        value={value}
        placeholder={placeholder}
        onChange={e => onChange(e.target.value)}
        onKeyDown={e => {
          if (e.key === 'Escape') {
            e.stopPropagation();
            if (value) onChange('');
            else (e.target as HTMLInputElement).blur();
          }
        }}
      />
      {hotkey && !value && <span className="sc-kbd absolute right-2 top-1/2 -translate-y-1/2 pointer-events-none">/</span>}
    </div>
  );
};

export const Stepper = ({ value, onChange, min = 0, max = 999, step = 1 }: { value: number; onChange: (v: number) => void; min?: number; max?: number; step?: number }) => {
  const clamp = (n: number) => Math.min(max, Math.max(min, n));
  return (
    <div className="inline-flex items-center rounded-[6px]" style={{ border: '1px solid var(--hairline-strong)', background: 'var(--field)' }}>
      <button type="button" className="sc-btn sc-btn--icon" style={{ height: 30, width: 30 }} disabled={value <= min} onClick={() => onChange(clamp(value - step))}>
        <Minus size={13} />
      </button>
      <input
        className="mono text-center text-[13px] bg-transparent outline-none"
        style={{ width: 52, border: 'none', color: 'var(--text-1)' }}
        value={value}
        inputMode="numeric"
        onChange={e => {
          const n = Number(e.target.value.replace(/[^0-9]/g, ''));
          if (Number.isFinite(n)) onChange(clamp(n));
        }}
      />
      <button type="button" className="sc-btn sc-btn--icon" style={{ height: 30, width: 30 }} disabled={value >= max} onClick={() => onChange(clamp(value + step))}>
        <Plus size={13} />
      </button>
    </div>
  );
};

export const BarChart = ({ values, labels, height = 72, format }: { values: number[]; labels?: string[]; height?: number; format?: (v: number) => string }) => {
  const [hover, setHover] = useState<number | null>(null);
  const max = Math.max(1, ...values);
  const shown = hover ?? values.length - 1;
  return (
    <div>
      <div className="flex items-end" style={{ height, gap: values.length <= 8 ? 12 : 3 }} onMouseLeave={() => setHover(null)}>
        {values.map((v, i) => (
          <div key={i} className="flex-1 h-full flex items-end" onMouseEnter={() => setHover(i)}>
            <div
              className="w-full rounded-[2px] transition-colors"
              style={{
                height: `${Math.max(v > 0 ? 6 : 2, (v / max) * 100)}%`,
                backgroundColor: i === shown ? 'var(--text-1)' : v > 0 ? 'rgba(237,237,239,0.28)' : 'rgba(255,255,255,0.06)',
              }}
            />
          </div>
        ))}
      </div>
      {labels && values.length > 0 && (
        <div className="flex justify-between mt-2 text-[11.5px] mono" style={{ color: 'var(--text-3)' }}>
          <span>{labels[shown]}</span>
          <span style={{ color: 'var(--text-1)' }}>{format ? format(values[shown]) : values[shown]}</span>
        </div>
      )}
    </div>
  );
};

export function ago(at: number): string {
  const s = Math.max(0, Math.floor(Date.now() / 1000 - at));
  if (s < 45) return t('common.just_now');
  if (s < 3600) return t('common.ago', `${Math.max(1, Math.round(s / 60))}m`);
  if (s < 86400) return t('common.ago', `${Math.floor(s / 3600)}h`);
  return t('common.ago', `${Math.floor(s / 86400)}d`);
}

export function money(currency: string, amount: number): string {
  return `${currency}${Math.round(amount).toLocaleString('en-US')}`;
}
