import { useEffect, useMemo, useRef, useState } from 'react';
import { BatteryCharging, Navigation, Search, X, Zap } from 'lucide-react';
import type { ReactNode } from 'react';

import { t } from '../compat/i18n';
import { Sheet } from '../compat/ui/Sheet';
import { LiveDot } from '../compat/maps/LiveDot';
import { MapView, usePinStyle } from '../compat/maps/MapView';
import type { MapViewHandle } from '../compat/maps/MapView';
import type { ScootCharger, ScootSnapshot, ScootStation } from './scootApi';

const ACCENT = '#14b8a6';
const CHARGE = '#34d399';

export interface MapFocus { kind: 'station' | 'charger'; id: number }

interface Props {
    snapshot:    ScootSnapshot | null;
    focus:       MapFocus | null;
    selectedId?: number | null;
    onFocus:     (focus: MapFocus | null) => void;
    onPick?:     (id: number) => void;
    onWaypoint:  (x: number, y: number, name: string) => void;
    onClose:     () => void;
}

function Pin({ x, y, children }: { x: number; y: number; children: ReactNode }) {
    return <div style={{ ...usePinStyle(x, y), zIndex: 10, pointerEvents: 'auto' }}>{children}</div>;
}

function Chip({ on, tone, onClick, children }: { on: boolean; tone: string; onClick: () => void; children: ReactNode }) {
    return (
        <button
            type="button"
            aria-pressed={on}
            onClick={onClick}
            className={`flex shrink-0 items-center gap-1.5 rounded-full px-3 py-1.5 text-[14px] font-semibold transition-colors ${on ? 'text-white' : 'bg-black/[0.05] text-black/70 dark:bg-white/10 dark:text-white/70'}`}
            style={on ? { background: tone } : undefined}
        >
            {children}
        </button>
    );
}

export function StationMap({ snapshot, focus, selectedId, onFocus, onPick, onWaypoint, onClose }: Props) {
    const map = useRef<MapViewHandle>(null);
    const [query, setQuery] = useState('');
    const [showStations, setShowStations] = useState(true);
    const [showChargers, setShowChargers] = useState(true);

    const stations = snapshot?.bunkers ?? [];
    const chargers = snapshot?.stations ?? [];
    const needle = query.trim().toLowerCase();

    const visibleStations = useMemo(
        () => (showStations ? stations.filter(s => !needle || s.name.toLowerCase().includes(needle)) : []),
        [stations, showStations, needle],
    );
    const visibleChargers = useMemo(
        () => (showChargers ? chargers.filter(c => !needle || c.name.toLowerCase().includes(needle)) : []),
        [chargers, showChargers, needle],
    );

    const focused = focus?.kind === 'station'
        ? stations.find(s => s.id === focus.id)
        : focus?.kind === 'charger' ? chargers.find(c => c.id === focus.id) : undefined;

    const [openedAt] = useState(() => {
        const start = focus?.kind === 'station'
            ? snapshot?.bunkers?.find(s => s.id === focus.id)
            : focus?.kind === 'charger' ? snapshot?.stations?.find(c => c.id === focus.id) : undefined;
        const at = start ?? snapshot?.player;
        return at ? { x: at.x, y: at.y } : undefined;
    });

    const target = focus ? `${focus.kind}:${focus.id}` : '';
    const tracked = useRef(target);
    useEffect(() => {
        if (tracked.current === target) return;
        tracked.current = target;
        if (focused) map.current?.centerOnWorld(focused.x, focused.y, 3);
    }, [target, focused]);

    const total = visibleStations.length + visibleChargers.length;
    const isStation = (entry: ScootStation | ScootCharger): entry is ScootStation => 'stock' in entry;

    return (
        <Sheet fit="full" top={40} grabber={false} onClose={onClose} className="bg-base">
            {({ close }) => (
                <>
                    <div className="shrink-0 px-4 pb-2 pt-3">
                        <div className="flex items-center gap-2">
                            <div className="flex min-w-0 flex-1 items-center gap-2 rounded-[11px] bg-black/[0.06] px-2.5 py-2 dark:bg-white/[0.1]">
                                <Search className="h-[17px] w-[17px] shrink-0 text-ios-gray" strokeWidth={2.4} />
                                <input
                                    value={query}
                                    onChange={e => setQuery(e.target.value)}
                                    placeholder={t('scoot.searchStations', 'Search stations')}
                                    aria-label={t('scoot.searchStations', 'Search stations')}
                                    className="min-w-0 flex-1 bg-transparent text-[16px] font-medium text-black outline-none placeholder:text-ios-gray dark:text-white"
                                />
                                {query && (
                                    <button type="button" aria-label={t('common.clear', 'Clear')} onClick={() => setQuery('')} className="shrink-0 text-ios-gray active:opacity-60">
                                        <X className="h-[16px] w-[16px]" strokeWidth={2.6} />
                                    </button>
                                )}
                            </div>
                            <button
                                type="button"
                                onClick={close}
                                className="shrink-0 rounded-full px-3 py-2 text-[16px] font-semibold active:opacity-60"
                                style={{ color: ACCENT }}
                            >
                                {t('common.done', 'Done')}
                            </button>
                        </div>
                        <div className="no-scrollbar mt-2 flex items-center gap-2 overflow-x-auto">
                            <Chip on={showStations} tone={ACCENT} onClick={() => setShowStations(v => !v)}>
                                <Zap className="h-[15px] w-[15px]" strokeWidth={2.4} />
                                {t('scoot.tabStations', 'Stations')} · {stations.length}
                            </Chip>
                            <Chip on={showChargers} tone={CHARGE} onClick={() => setShowChargers(v => !v)}>
                                <BatteryCharging className="h-[15px] w-[15px]" strokeWidth={2.4} />
                                {t('scoot.chargers', 'Chargers')} · {chargers.length}
                            </Chip>
                            {focus && (
                                <button
                                    type="button"
                                    onClick={() => onFocus(null)}
                                    className="flex shrink-0 items-center gap-1.5 rounded-full bg-black/[0.05] px-3 py-1.5 text-[14px] font-semibold text-black/70 active:opacity-60 dark:bg-white/10 dark:text-white/70"
                                >
                                    <X className="h-[14px] w-[14px]" strokeWidth={2.6} />
                                    {t('scoot.showAll', 'Show all')}
                                </button>
                            )}
                        </div>
                    </div>

                    <div dir="ltr" className="relative min-h-0 flex-1">
                        <MapView
                            ref={map}
                            centerTo={openedAt}
                            onTapEmpty={() => onFocus(null)}
                            chromeBottom={focused ? '146px' : '12px'}
                        >
                            {visibleStations.map(b => {
                                const active = focus?.kind === 'station' && focus.id === b.id;
                                const dim = !!focus && !active;
                                return (
                                    <Pin key={`b${b.id}`} x={b.x} y={b.y}>
                                        <button
                                            type="button"
                                            aria-label={b.name}
                                            aria-pressed={active}
                                            onClick={() => onFocus(active ? null : { kind: 'station', id: b.id })}
                                            className="relative flex items-center justify-center rounded-[12px] border-2 border-white text-white shadow-md transition-all duration-200 active:scale-90"
                                            style={{ background: ACCENT, opacity: dim ? 0.4 : 1, width: active ? 46 : 38, height: active ? 46 : 38 }}
                                        >
                                            {active && <span className="scoot-pin-halo" style={{ background: ACCENT }} />}
                                            <Zap className="relative" style={{ width: active ? 23 : 19, height: active ? 23 : 19 }} strokeWidth={2.4} />
                                            {b.id === selectedId && !active && (
                                                <span className="absolute -bottom-1 -end-1 h-[12px] w-[12px] rounded-full border-2 border-white" style={{ background: '#0f766e' }} />
                                            )}
                                        </button>
                                    </Pin>
                                );
                            })}
                            {visibleChargers.map(c => {
                                const active = focus?.kind === 'charger' && focus.id === c.id;
                                const dim = !!focus && !active;
                                return (
                                    <Pin key={`c${c.id}`} x={c.x} y={c.y}>
                                        <button
                                            type="button"
                                            aria-label={c.name}
                                            aria-pressed={active}
                                            onClick={() => onFocus(active ? null : { kind: 'charger', id: c.id })}
                                            className="relative flex items-center justify-center rounded-[10px] border-2 border-white text-white shadow-md transition-all duration-200 active:scale-90"
                                            style={{ background: CHARGE, opacity: dim ? 0.4 : 1, width: active ? 42 : 34, height: active ? 42 : 34 }}
                                        >
                                            {active && <span className="scoot-pin-halo" style={{ background: CHARGE }} />}
                                            <BatteryCharging className="relative" style={{ width: active ? 21 : 18, height: active ? 21 : 18 }} strokeWidth={2.4} />
                                        </button>
                                    </Pin>
                                );
                            })}
                            {snapshot && <LiveDot x={snapshot.player.x} y={snapshot.player.y} heading={snapshot.player.heading} />}
                        </MapView>

                        {total === 0 && (
                            <div className="pointer-events-none absolute inset-x-6 top-4 rounded-[14px] bg-black/70 px-4 py-3 text-center text-[15px] font-semibold text-white backdrop-blur">
                                {query ? t('scoot.noMatches', 'Nothing matches “{q}”', { q: query }) : t('scoot.nothingShown', 'Turn a filter back on to see pins')}
                            </div>
                        )}

                        {focused && (
                            <div className="absolute inset-x-3 bottom-3 z-20" style={{ animation: 'swipe-in-soft 0.26s cubic-bezier(0.32,0.72,0,1)' }}>
                                <div className="rounded-[18px] bg-elevated p-3.5 shadow-[0_18px_40px_-16px_rgba(0,0,0,0.55)] ring-1 ring-black/[0.05] dark:bg-control dark:ring-white/[0.08]">
                                    <div className="flex items-center gap-3">
                                        <span
                                            className="flex h-[40px] w-[40px] shrink-0 items-center justify-center rounded-[12px]"
                                            style={isStation(focused) ? { background: `${ACCENT}22`, color: ACCENT } : { background: `${CHARGE}22`, color: CHARGE }}
                                        >
                                            {isStation(focused)
                                                ? <Zap className="h-[21px] w-[21px]" strokeWidth={2.3} />
                                                : <BatteryCharging className="h-[21px] w-[21px]" strokeWidth={2.3} />}
                                        </span>
                                        <span className="min-w-0 flex-1">
                                            <span dir="auto" className="block truncate text-[18px] font-bold leading-tight text-black dark:text-white">{focused.name}</span>
                                            <span className="mt-0.5 block truncate text-[14px] text-ios-gray">
                                                {Math.round(focused.distance)} m · {isStation(focused)
                                                    ? (focused.busy ? t('scoot.stationBusy', 'Station is busy') : t('scoot.stock', '{n} scooters ready', { n: focused.stock }))
                                                    : t('scoot.freeSlots', '{free} of {slots} docks free', { free: focused.free, slots: focused.slots })}
                                            </span>
                                        </span>
                                        <button
                                            type="button"
                                            aria-label={t('common.close', 'Close')}
                                            onClick={() => onFocus(null)}
                                            className="flex h-[30px] w-[30px] shrink-0 items-center justify-center rounded-full bg-black/[0.06] text-ios-gray active:opacity-60 dark:bg-white/10"
                                        >
                                            <X className="h-[16px] w-[16px]" strokeWidth={2.6} />
                                        </button>
                                    </div>
                                    <div className="mt-3 flex gap-2">
                                        <button
                                            type="button"
                                            onClick={() => onWaypoint(focused.x, focused.y, focused.name)}
                                            className="flex h-[42px] flex-1 items-center justify-center gap-2 rounded-[13px] bg-black/[0.06] text-[16px] font-semibold text-black active:opacity-60 dark:bg-white/10 dark:text-white"
                                        >
                                            <Navigation className="h-[17px] w-[17px] translate-x-[0.5px] -translate-y-[0.5px]" strokeWidth={2.3} />
                                            {t('scoot.route', 'Route')}
                                        </button>
                                        {isStation(focused) && onPick && (
                                            <button
                                                type="button"
                                                disabled={focused.busy || focused.stock < 1}
                                                onClick={() => { onPick(focused.id); close(); }}
                                                className="flex h-[42px] flex-1 items-center justify-center rounded-[13px] text-[16px] font-bold text-white transition-opacity active:opacity-90 disabled:opacity-40"
                                                style={{ background: ACCENT }}
                                            >
                                                {t('scoot.rentHere', 'Rent here')}
                                            </button>
                                        )}
                                    </div>
                                </div>
                            </div>
                        )}
                    </div>
                </>
            )}
        </Sheet>
    );
}
