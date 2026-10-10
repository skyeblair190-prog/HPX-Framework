import { Ban, Check } from 'lucide-react';
import type { CSSProperties } from 'react';

const ACCENT = '#14b8a6';

export interface SwatchItem {
    id:     string | number;
    label:  string;
    hex?:   string;
}

function isLight(hex: string): boolean {
    const m = /^#?([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i.exec(hex);
    if (!m) return false;
    const [r, g, b] = [m[1], m[2], m[3]].map(c => {
        const v = parseInt(c, 16) / 255;
        return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4;
    });
    return 0.2126 * r + 0.7152 * g + 0.0722 * b > 0.45;
}

export function SwatchGrid({ items, value, onPick, disabled = false, label }: {
    items:     SwatchItem[];
    value:     string | number | undefined;
    onPick:    (id: string | number) => void;
    disabled?: boolean;
    label:     string;
}) {
    return (
        <div role="group" aria-label={label} className="grid grid-cols-5 gap-y-3">
            {items.map(item => {
                const active = item.id === value;
                const none = !item.hex;
                return (
                    <button
                        key={item.id}
                        type="button"
                        title={item.label}
                        aria-label={item.label}
                        aria-pressed={active}
                        disabled={disabled}
                        onClick={() => onPick(item.id)}
                        className="flex h-[44px] w-full items-center justify-center transition-transform active:scale-90 disabled:active:scale-100"
                    >
                        <span
                            className={`flex h-[36px] w-[36px] items-center justify-center rounded-full ring-1 transition-[transform,box-shadow,opacity] duration-200 ${
                                none ? 'bg-black/[0.05] ring-black/15 dark:bg-white/10 dark:ring-white/20' : 'ring-black/10 dark:ring-white/15'
                            } ${active ? 'scale-105 ring-2 ring-offset-2 ring-offset-surface' : disabled ? 'opacity-40' : ''}`}
                            style={{ background: item.hex, ...(active ? { '--tw-ring-color': ACCENT } as CSSProperties : {}) }}
                        >
                            {active && !none && <Check className="h-[18px] w-[18px]" strokeWidth={3} style={{ color: isLight(item.hex!) ? '#102a2a' : '#fff' }} />}
                            {none && <Ban className="h-[18px] w-[18px] text-ios-gray" strokeWidth={2.2} style={active ? { color: ACCENT } : undefined} />}
                        </span>
                    </button>
                );
            })}
        </div>
    );
}
