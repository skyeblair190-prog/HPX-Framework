import { useMemo, useRef, useState } from 'react';
import { BatteryCharging, Check, Map as MapIcon, Navigation, Zap } from 'lucide-react';
import type { ReactNode } from 'react';

import { t } from '../compat/i18n';
import { seedSessionState, useSessionState } from '../compat/hooks/useSessionState';
import { EmptyState } from '../compat/ui/EmptyState';
import { GroupCard } from '../compat/ui/ListGroup';
import { SegmentedControl } from '../compat/ui/SegmentedControl';
import { scoot, useScootFeed } from './scootApi';
import type { ScootCharger, ScootStation } from './scootApi';
import { StationMap } from './StationMap';
import type { MapFocus } from './StationMap';
import { Toast } from './Toast';

const ACCENT = '#14b8a6';
const CHARGE = '#34d399';
const CARD = 'ring-1 ring-black/[0.04] dark:ring-white/[0.06]';
const ROUND = 'flex h-[38px] w-[38px] shrink-0 items-center justify-center rounded-full bg-black/[0.05] transition-opacity active:opacity-60 dark:bg-white/10';

type Sort = 'closest' | 'stock';

function SectionLabel({ children }: { children: string }) {
    return <div className="px-3 pb-1.5 pt-4 text-[15px] font-semibold uppercase tracking-wide text-ios-gray">{children}</div>;
}

function RouteIcon() {
    return <Navigation className="h-[19px] w-[19px] translate-x-[0.5px] -translate-y-[0.5px]" strokeWidth={2.2} />;
}

function StockTag({ station }: { station: ScootStation }) {
    const out = station.busy || station.stock < 1;
    const label = station.busy ? t('scoot.busyShort', 'Busy')
        : station.stock < 1 ? t('scoot.emptyShort', 'Empty')
        : t('scoot.inStock', '{n} ready', { n: station.stock });
    return (
        <span className="shrink-0 font-semibold tabular-nums" style={{ color: out ? 'rgb(142 142 147)' : ACCENT }}>{label}</span>
    );
}

function EntryRow({ name, sub, tone, icon, selected, divider, onSelect, onMap, onRoute }: {
    name:      string;
    sub:       ReactNode;
    tone:      string;
    icon:      ReactNode;
    selected?: boolean;
    divider:   boolean;
    onSelect?: () => void;
    onMap:     () => void;
    onRoute:   () => void;
}) {
    const body = (
        <>
            <span className="relative flex h-[40px] w-[40px] shrink-0 items-center justify-center rounded-[12px]" style={{ background: `${tone}22`, color: tone }}>
                {icon}
                {selected && (
                    <span className="absolute -bottom-[3px] -end-[3px] flex h-[17px] w-[17px] items-center justify-center rounded-full text-white ring-2 ring-surface" style={{ background: tone }}>
                        <Check className="h-[11px] w-[11px]" strokeWidth={3} />
                    </span>
                )}
            </span>
            <span className="min-w-0 flex-1">
                <span dir="auto" className="block truncate text-[17px] font-semibold leading-tight text-black dark:text-white">{name}</span>
                <span className="mt-0.5 flex items-center gap-1.5 truncate text-[14px] tabular-nums text-ios-gray">{sub}</span>
            </span>
        </>
    );

    return (
        <div className="relative flex items-center">
            {onSelect ? (
                <button type="button" onClick={onSelect} aria-pressed={!!selected} className="flex min-w-0 flex-1 items-center gap-2.5 py-3 ps-3.5 pe-1 text-start active:bg-black/5 dark:active:bg-white/5">
                    {body}
                </button>
            ) : (
                <span className="flex min-w-0 flex-1 items-center gap-2.5 py-3 ps-3.5 pe-1">{body}</span>
            )}
            <span className="flex shrink-0 items-center gap-1 pe-2.5">
                <button type="button" aria-label={t('scoot.showOnMap', 'Show on map')} onClick={onMap} className={ROUND} style={{ color: tone }}>
                    <MapIcon className="h-[18px] w-[18px]" strokeWidth={2.2} />
                </button>
                <button type="button" aria-label={t('scoot.route', 'Route')} onClick={onRoute} className={ROUND} style={{ color: tone }}>
                    <RouteIcon />
                </button>
            </span>
            {divider && <div className="pointer-events-none absolute inset-x-0 bottom-0 bg-ios-gray4 dark:bg-control" style={{ height: '0.5px' }} />}
        </div>
    );
}

export function Stations({ onPicked }: { onPicked: () => void }) {
    const { snapshot, connected } = useScootFeed();
    const [sort, setSort] = useSessionState<Sort>('scoot:stationSort', 'closest');
    const [stationId, setStationId] = useSessionState<number | null>('scoot:station', null);
    const [mapFocus, setMapFocus] = useState<MapFocus | null>(null);
    const [mapOpen, setMapOpen] = useState(false);
    const [toast, setToast] = useState<{ id: number; text: string } | null>(null);
    const toastId = useRef(0);
    const notify = (text: string) => { toastId.current += 1; setToast({ id: toastId.current, text }); };

    const stations = snapshot?.bunkers ?? [];
    const chargers = snapshot?.stations ?? [];
    const ordered = useMemo(() => {
        const list = [...stations];
        list.sort(sort === 'stock'
            ? (a, b) => Number(a.busy) - Number(b.busy) || b.stock - a.stock || a.distance - b.distance
            : (a, b) => a.distance - b.distance);
        return list;
    }, [stations, sort]);
    const sortedChargers = useMemo(() => [...chargers].sort((a, b) => a.distance - b.distance), [chargers]);
    const ready = stations.reduce((n, s) => n + (s.busy ? 0 : s.stock), 0);
    const nearest = ordered.length ? Math.min(...stations.map(s => s.distance)) : 0;

    const pick = (id: number) => { seedSessionState('scoot:station', id); setStationId(id); onPicked(); };
    const route = (entry: ScootStation | ScootCharger) => {
        void scoot.waypoint(entry.x, entry.y)
            .then(() => notify(t('scoot.routeTo', 'Route set to {name}', { name: entry.name })))
            .catch(() => notify(t('scoot.noResponse', 'No response from Scoot')));
    };
    const openMap = (focus: MapFocus | null) => { setMapFocus(focus); setMapOpen(true); };

    return (
        <div className="absolute inset-0 flex flex-col bg-base font-sf">
            <div className="h-11 shrink-0" aria-hidden />
            <div className="no-scrollbar flex-1 overflow-y-auto pb-10">
                <div className="flex items-start justify-between gap-3 px-5 pb-4 pt-1">
                    <div className="min-w-0">
                        <h1 className="text-[34px] font-bold leading-tight tracking-tight text-black dark:text-white">{t('scoot.tabStations', 'Stations')}</h1>
                        <p className="truncate text-[15px] font-medium text-ios-gray">
                            {!connected || !snapshot ? t('scoot.finding', 'Finding scooters…')
                                : stations.length === 0 ? t('scoot.noneInRange', 'None in range')
                                : t('scoot.stationsSummary', '{stations} · {ready} ready · nearest {n} m', {
                                    stations: stations.length === 1 ? t('scoot.oneStation', '1 station') : t('scoot.manyStations', '{n} stations', { n: stations.length }),
                                    ready,
                                    n: Math.round(nearest),
                                })}
                        </p>
                    </div>
                    <button
                        type="button"
                        aria-label={t('scoot.openMap', 'Open pickup map')}
                        onClick={() => openMap(null)}
                        className={`mt-1 flex h-[42px] w-[42px] shrink-0 items-center justify-center rounded-full bg-surface text-black shadow-sm transition-transform active:scale-95 dark:text-white ${CARD}`}
                    >
                        <MapIcon className="h-[22px] w-[22px]" strokeWidth={2.1} />
                    </button>
                </div>

                <div className="px-4">
                    <SegmentedControl
                        slide
                        value={sort}
                        onChange={setSort}
                        options={[
                            { value: 'closest', label: t('scoot.sortClosest', 'Closest') },
                            { value: 'stock', label: t('scoot.sortStock', 'Most in stock') },
                        ]}
                    />
                </div>

                {ordered.length === 0 ? (
                    <EmptyState
                        icon={Zap}
                        title={snapshot ? t('scoot.noStations', 'No stations nearby') : t('scoot.finding', 'Finding scooters…')}
                        subtitle={snapshot ? t('scoot.noStationsSub', 'Stations show up here as soon as one is in range.') : undefined}
                    />
                ) : (
                    <div className="mx-4 mt-3">
                        <GroupCard radius={16} className={CARD} footer={t('scoot.stationsHint', 'Tap a station to rent from it, then head over and pick your colour.')}>
                            {ordered.map((b, i) => (
                                <EntryRow
                                    key={b.id}
                                    name={b.name}
                                    sub={<>
                                        <span className="shrink-0">{t('scoot.metres', '{n} m', { n: Math.round(b.distance) })}</span>
                                        <span aria-hidden className="shrink-0 opacity-50">·</span>
                                        <StockTag station={b} />
                                    </>}
                                    tone={ACCENT}
                                    icon={<Zap className="h-[21px] w-[21px]" strokeWidth={2.2} />}
                                    selected={b.id === stationId}
                                    divider={i < ordered.length - 1}
                                    onSelect={() => pick(b.id)}
                                    onMap={() => openMap({ kind: 'station', id: b.id })}
                                    onRoute={() => route(b)}
                                />
                            ))}
                        </GroupCard>
                    </div>
                )}

                {sortedChargers.length > 0 && (
                    <div className="mx-4 mt-2">
                        <SectionLabel>{t('scoot.chargingStations', 'CHARGING STATIONS')}</SectionLabel>
                        <GroupCard radius={16} className={CARD}>
                            {sortedChargers.map((c, i) => (
                                <EntryRow
                                    key={c.id}
                                    name={c.name}
                                    sub={<>
                                        <span className="shrink-0">{t('scoot.metres', '{n} m', { n: Math.round(c.distance) })}</span>
                                        <span aria-hidden className="shrink-0 opacity-50">·</span>
                                        <span className="truncate" style={c.free > 0 ? { color: CHARGE, fontWeight: 600 } : undefined}>
                                            {t('scoot.docksFree', '{free}/{slots} docks', { free: c.free, slots: c.slots })}
                                        </span>
                                    </>}
                                    tone={CHARGE}
                                    icon={<BatteryCharging className="h-[21px] w-[21px]" strokeWidth={2.2} />}
                                    divider={i < sortedChargers.length - 1}
                                    onMap={() => openMap({ kind: 'charger', id: c.id })}
                                    onRoute={() => route(c)}
                                />
                            ))}
                        </GroupCard>
                    </div>
                )}
            </div>

            {mapOpen && (
                <StationMap
                    snapshot={snapshot}
                    focus={mapFocus}
                    selectedId={stationId}
                    onFocus={setMapFocus}
                    onPick={pick}
                    onWaypoint={(x, y, name) => {
                        void scoot.waypoint(x, y)
                            .then(() => notify(t('scoot.routeTo', 'Route set to {name}', { name })))
                            .catch(() => notify(t('scoot.noResponse', 'No response from Scoot')));
                    }}
                    onClose={() => setMapOpen(false)}
                />
            )}

            {toast && <Toast key={toast.id} message={toast.text} onDone={() => setToast(null)} />}
        </div>
    );
}
