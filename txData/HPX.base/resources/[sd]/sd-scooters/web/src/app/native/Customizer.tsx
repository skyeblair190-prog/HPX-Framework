import { useEffect, useRef, useState } from 'react';
import type { CSSProperties, ReactNode } from 'react';

import { t } from '../compat/i18n';
import { GroupCard } from '../compat/ui/ListGroup';
import { EXTRAS } from './customization';
import type { Customization, ExtraOption, ExtrasCatalog } from './customization';
import { SwatchGrid } from './Swatches';

const ACCENT = '#14b8a6';
const CARD = 'ring-1 ring-black/[0.04] dark:ring-white/[0.06]';
const STOCK_TRIM = '#1a8f86';
const STOCK_BAND = '#12aa98';

type ColourKey = 'trim' | 'lighting' | 'box';
type TileKey = 'rear';

export function Section({ title, choice, children, first = false }: { title: string; choice?: string; children: ReactNode; first?: boolean }) {
    return (
        <section className={`px-4 pb-4 pt-3.5 ${first ? '' : 'border-t border-hairline/10'}`}>
            <div className="mb-3 min-w-0">
                <h3 className="text-[16px] font-semibold leading-tight text-black dark:text-white">{title}</h3>
                {choice && <p className="mt-0.5 truncate text-[13px] text-ios-gray">{choice}</p>}
            </div>
            {children}
        </section>
    );
}

function Reveal({ open, children }: { open: boolean; children: ReactNode }) {
    const inner = useRef<HTMLDivElement>(null);
    const [height, setHeight] = useState(0);

    useEffect(() => {
        const el = inner.current;
        if (!el) return;
        const measure = () => setHeight(el.offsetHeight);
        measure();
        if (typeof ResizeObserver === 'undefined') return;
        const observer = new ResizeObserver(measure);
        observer.observe(el);
        return () => observer.disconnect();
    }, []);

    return (
        <div
            aria-hidden={!open}
            className={`overflow-hidden transition-[height,opacity] duration-[320ms] ease-[cubic-bezier(0.32,0.72,0,1)] ${open ? '' : 'pointer-events-none'}`}
            style={{ height: open ? height : 0, opacity: open ? 1 : 0 }}
        >
            <div ref={inner}>{children}</div>
        </div>
    );
}

function Tile({ item, active, disabled, price, onPick }: { item: ExtraOption; active: boolean; disabled: boolean; price: string; onPick: () => void }) {
    return (
        <button
            type="button"
            aria-pressed={active}
            disabled={disabled}
            onClick={onPick}
            className={`flex min-h-[58px] min-w-0 flex-col items-start justify-center rounded-[12px] px-3 py-2 text-start ring-inset transition-[transform,background-color,box-shadow,opacity] active:scale-[0.97] disabled:active:scale-100 ${
                active ? 'ring-2' : `bg-black/[0.04] dark:bg-white/[0.07] ${disabled ? 'opacity-40' : ''}`
            }`}
            style={active ? { background: `${ACCENT}1a`, '--tw-ring-color': ACCENT } as CSSProperties : undefined}
        >
            <span className={`w-full break-words text-[15px] font-semibold leading-tight ${active ? '' : 'text-black dark:text-white'}`} style={active ? { color: ACCENT } : undefined}>{item.label}</span>
            <span className="mt-0.5 text-[13px] tabular-nums text-ios-gray">{price}</span>
        </button>
    );
}

export function Customizer({ value, onChange, currency, catalog = EXTRAS, readonly = false, bare = false, first = true }: {
    value:     Customization;
    onChange:  (v: Customization) => void;
    currency:  string;
    catalog?:  ExtrasCatalog;
    readonly?: boolean;
    bare?:     boolean;
    first?:    boolean;
}) {
    const change = (key: keyof Customization, item: string) => onChange({ ...value, [key]: item });
    const price = (n: number) => (n > 0 ? `+${currency}${n}` : t('scoot.extrasIncluded', 'Included'));
    const picked = (key: ColourKey | TileKey) => catalog[key].find(item => item.id === value[key]);
    const chosenLine = (item?: ExtraOption) => (item ? (item.fee > 0 ? `${item.label} · +${currency}${item.fee}` : item.label) : undefined);

    const stockHex = (key: ColourKey, item: ExtraOption) => {
        if (item.hex) return item.hex;
        if (key === 'trim' && item.fee === 0) return STOCK_TRIM;
        if (key === 'box' && item.id === 'stock') return STOCK_BAND;
        return undefined;
    };

    const colourSection = (key: ColourKey, title: string, isFirst: boolean) => {
        const chosen = picked(key);
        return (
            <Section title={title} choice={chosenLine(chosen)} first={isFirst}>
                <SwatchGrid
                    label={title}
                    value={value[key]}
                    disabled={readonly}
                    onPick={id => change(key, String(id))}
                    items={(catalog[key] ?? []).map(item => ({ id: item.id, label: item.label, hex: stockHex(key, item) }))}
                />
            </Section>
        );
    };

    const tileSection = (key: TileKey, title: string, columns: 2 | 3) => {
        const chosen = picked(key);
        return (
            <Section title={title} choice={chosenLine(chosen)}>
                <div className={`grid gap-2 ${columns === 3 ? 'grid-cols-3' : 'grid-cols-2'}`}>
                    {catalog[key].map(item => (
                        <Tile key={item.id} item={item} active={value[key] === item.id} disabled={readonly} price={price(item.fee)} onPick={() => change(key, item.id)} />
                    ))}
                </div>
            </Section>
        );
    };

    const sections = (
        <>
            {colourSection('lighting', t('scoot.extrasLighting', 'Underglow'), first)}
            {colourSection('trim', t('scoot.extrasTrim', 'Grips, cables and wheel trim'), false)}
            {tileSection('rear', t('scoot.extrasRear', 'Storage'), 2)}
            <Reveal open={value.rear === 'delivery'}>
                {colourSection('box', t('scoot.extrasBox', 'Storage box stripe'), false)}
            </Reveal>
        </>
    );

    if (bare) return sections;
    return <GroupCard radius={16} className={CARD}>{sections}</GroupCard>;
}
