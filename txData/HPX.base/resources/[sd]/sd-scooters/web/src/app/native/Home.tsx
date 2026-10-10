import { useEffect, useMemo, useRef, useState } from 'react';
import { ArrowUpRight, BatteryCharging, BatteryFull, BatteryLow, BatteryMedium, BatteryWarning, Map as MapIcon, Power, Zap } from 'lucide-react';
import type { ReactNode } from 'react';

import { t } from '../compat/i18n';
import { useSessionState } from '../compat/hooks/useSessionState';
import { AlertDialog } from '../compat/ui/AlertDialog';
import { GroupCard } from '../compat/ui/ListGroup';
import { Sheet } from '../compat/ui/Sheet';
import { Spinner } from '../compat/ui/Spinner';
import { SCOOT_PALETTE, scoot, useScootFeed } from './scootApi';
import type { ScootReceipt } from './scootApi';
import { StationMap } from './StationMap';
import type { MapFocus } from './StationMap';
import { Toast } from './Toast';
import { useViewportHeight } from './useViewportHeight';
import { ScooterPreview } from './ScooterPreview';
import { Customizer, Section } from './Customizer';
import { SwatchGrid } from './Swatches';
import { EXTRAS, extraFee } from './customization';
import type { Customization } from './customization';

const ACCENT = '#14b8a6';
const CHARGE = '#34d399';
const ENTER = 'swipe-in-soft 0.3s cubic-bezier(0.32,0.72,0,1)';
const CARD = 'ring-1 ring-black/[0.04] dark:ring-white/[0.06]';

function batteryTone(level: number, minToRent: number): string {
    if (level < minToRent) return '#ff453a';
    if (level < 50) return '#ff9f0a';
    return '#34c759';
}

function BatteryPill({ level, minToRent, charging = false, size = 'sm' }: { level: number; minToRent: number; charging?: boolean; size?: 'sm' | 'lg' }) {
    const tone = batteryTone(level, minToRent);
    const Icon = charging ? BatteryCharging : level < minToRent ? BatteryWarning : level < 40 ? BatteryLow : level < 75 ? BatteryMedium : BatteryFull;
    const big = size === 'lg';
    return (
        <span className={`inline-flex shrink-0 items-center gap-1 rounded-full font-semibold tabular-nums ${big ? 'px-2.5 py-1 text-[15px]' : 'px-2 py-0.5 text-[13px]'}`} style={{ background: `${tone}1f`, color: tone }}>
            <Icon className={big ? 'h-[18px] w-[18px]' : 'h-[15px] w-[15px]'} strokeWidth={2.2} />
            {level}%
        </span>
    );
}

function SectionLabel({ children, right }: { children: ReactNode; right?: ReactNode }) {
    return (
        <div className="flex items-baseline justify-between px-3 pb-1.5 pt-4">
            <span className="text-[15px] font-semibold uppercase tracking-wide text-ios-gray">{children}</span>
            {right && <span className="text-[14px] font-medium text-ios-gray">{right}</span>}
        </div>
    );
}

function Plate({ children }: { children: string }) {
    return (
        <span dir="ltr" className="shrink-0 rounded-[7px] border border-black/15 bg-black/[0.03] px-2.5 py-1 font-mono text-[14px] font-semibold tracking-[0.12em] text-black/80 dark:border-white/20 dark:bg-white/[0.06] dark:text-white/80">
            {children}
        </span>
    );
}

function ColourDot({ hex, size = 14 }: { hex: string; size?: number }) {
    return <span className="inline-block shrink-0 rounded-full ring-1 ring-black/10 dark:ring-white/20" style={{ width: size, height: size, background: hex }} />;
}

function elapsed(start: number): string {
    const s = Math.max(0, Math.floor(Date.now() / 1000) - start);
    return `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`;
}

export function Home() {
    const { snapshot, setSnapshot, refresh, connected } = useScootFeed();
    const [customization, setCustomization] = useSessionState<Customization>('scoot:extras', EXTRAS.defaults);
    const [colourId, setColourId] = useSessionState('scoot:colour', 10);
    const [stationId, setStationId] = useSessionState<number | null>('scoot:station', null);
    const [map, setMap] = useState(false);
    const [mapFocus, setMapFocus] = useState<MapFocus | null>(null);
    const [toast, setToast] = useState<{ id: number; text: string } | null>(null);
    const toastId = useRef(0);
    const notify = (text: string) => { toastId.current += 1; setToast({ id: toastId.current, text }); };
    const [expanded, setExpanded] = useState(false);
    const [pinned, setPinned] = useState(() => { try { return localStorage.getItem('scoot:pinPreview') === '1'; } catch { return false; } });
    const [stuck, setStuck] = useState(false);
    const scroller = useRef<HTMLDivElement>(null);
    const previewAnchor = useRef<HTMLDivElement>(null);
    useEffect(() => {
        const el = scroller.current;
        if (!el || !pinned) { setStuck(false); return; }
        let frame = 0;
        const check = () => {
            frame = 0;
            const anchor = previewAnchor.current;
            if (!anchor) return;
            const past = el.scrollTop - (anchor.offsetTop - el.offsetTop);
            setStuck(prev => (prev ? past > 4 : past > 20));
        };
        const onScroll = () => { if (!frame) frame = requestAnimationFrame(check); };
        el.addEventListener('scroll', onScroll, { passive: true });
        check();
        return () => { el.removeEventListener('scroll', onScroll); if (frame) cancelAnimationFrame(frame); };
    }, [pinned]);
    const viewportHeight = useViewportHeight();
    const compact = viewportHeight < 720;
    const previewHeight = Math.max(compact ? 128 : 150, Math.min(236, Math.round(viewportHeight * (compact ? 0.22 : 0.25))));
    const [busy, setBusy] = useState(false);
    const submitting = useRef(false);
    const [error, setError] = useState<string | null>(null);
    const [receipt, setReceipt] = useState<ScootReceipt | null>(null);
    const [confirmEnd, setConfirmEnd] = useState(false);
    const [, tick] = useState(0);

    const ride = snapshot?.ride;
    const pending = snapshot?.dispense;
    const palette = useMemo(() => (snapshot?.colours ?? SCOOT_PALETTE).map(c => ({ ...c, previewHex: c.previewHex ?? SCOOT_PALETTE.find(p => p.id === c.id)?.previewHex ?? c.hex })), [snapshot?.colours]);
    const stations = snapshot?.bunkers ?? [];
    const chargers = snapshot?.stations ?? [];
    const batteryOn = snapshot?.battery?.enabled ?? false;
    const minToRent = snapshot?.battery?.minToRent ?? 0;
    const nearest = useMemo(() => [...stations].sort((a, b) => a.distance - b.distance)[0], [stations]);
    const station = stations.find(b => b.id === stationId) ?? nearest;
    const chosen = palette.find(c => c.id === colourId) ?? palette[0];
    const displayed = palette.find(c => c.id === (ride?.colour ?? pending?.colour ?? chosen?.id)) ?? chosen;
    const pricing = snapshot?.pricing;
    const currency = pricing?.currency ?? '$';
    const selectedExtras = ride?.customization ?? pending?.customization ?? customization;
    const catalog = snapshot?.extrasCatalog ?? EXTRAS;
    const fee = extraFee(selectedExtras, catalog);
    const price = pricing ? `${currency}${pricing.unlock + fee}` : '—';
    const cost = ride?.cost ?? 0;
    const nearStation = !!(station && pricing && station.distance <= pricing.stationDistance);
    const nearCharger = ride && pricing ? chargers.find(c => c.free > 0 && c.distance <= (pricing.dockDistance ?? pricing.stationDistance)) : undefined;
    const phase = ride ? 'ride' : pending ? 'pending' : 'station';
    const showPreview = !(compact && phase === 'ride');

    const navigate = (x: number, y: number, name?: string) => {
        void scoot.waypoint(x, y)
            .then(() => notify(name
                ? t('scoot.routeTo', 'Route set to {name}', { name })
                : t('scoot.routeSet', 'Route set. Follow your GPS to the pickup point.')))
            .catch(() => setError(t('scoot.noResponse', 'No response from Scoot')));
    };

    useEffect(() => {
        if (!ride && !pending) return;
        const timer = window.setInterval(() => tick(n => n + 1), 1000);
        return () => clearInterval(timer);
    }, [ride, pending]);

    async function order() {
        if (submitting.current || pending || !snapshot || !connected) return;
        if (!station || !chosen || !snapshot.canChooseColour) return;
        if (!nearStation) { navigate(station.x, station.y); return; }
        submitting.current = true; setBusy(true);
        try {
            const reply = await scoot.rentHere(station.id, chosen.id, customization);
            if (reply.success && reply.data) setSnapshot(reply.data.nearby);
            else setError(reply.message ?? t('scoot.failed', 'That did not work'));
        } catch { setError(t('scoot.noResponse', 'No response from Scoot')); }
        finally { submitting.current = false; setBusy(false); }
    }

    async function finish() {
        setConfirmEnd(false);
        if (submitting.current) return;
        submitting.current = true; setBusy(true);
        try {
            const reply = await scoot.finish();
            if (reply.success && reply.data) { setSnapshot(reply.data.nearby); setReceipt(reply.data.receipt); }
            else setError(reply.message ?? t('scoot.failed', 'That did not work'));
        } catch { setError(t('scoot.noResponse', 'No response from Scoot')); }
        finally { submitting.current = false; setBusy(false); void refresh(); }
    }

    const unavailable = !snapshot || !connected || busy || !!pending || !station || !chosen || !snapshot.canChooseColour || station.busy || station.stock < 1;
    const blocked = !connected ? t('scoot.offline', 'Scoot is not responding')
        : !station ? t('scoot.noStations', 'No stations nearby')
        : station.busy ? t('scoot.stationBusy', 'Station is busy')
        : station.stock < 1 ? t('scoot.stationEmpty', 'No scooters left here')
        : null;
    const far = !!station && !nearStation;
    const action = busy ? t('scoot.working', 'One moment…')
        : far ? t('scoot.directions', 'Directions')
        : t('scoot.rent', 'Rent');

    const previewColour = displayed?.previewHex ?? '#0b4145';
    const previewName = displayed?.name ?? 'Teal';

    return (
        <div className="absolute inset-0 flex flex-col bg-base font-sf">
            <div className="flex shrink-0 items-end justify-between px-5 pb-3" style={{ paddingTop: 'calc(var(--safe-top) + 10px)' }}>
                <div>
                    <h1 className="text-[28px] font-extrabold tracking-tight text-black dark:text-white">Scoot</h1>
                    <p className="text-[15px] font-medium text-ios-gray">{t('scoot.tagline', 'Ride the city')}</p>
                </div>
                <button
                    type="button"
                    aria-label={t('scoot.openMap', 'Open pickup map')}
                    onClick={() => setMap(true)}
                    className={`flex h-[42px] w-[42px] items-center justify-center rounded-full bg-surface text-black shadow-sm transition-transform active:scale-95 dark:text-white ${CARD}`}
                >
                    <MapIcon className="h-[22px] w-[22px]" strokeWidth={2.1} />
                </button>
            </div>

            <div ref={scroller} className="no-scrollbar min-h-0 flex-1 overflow-y-auto px-4 pb-4 [overflow-anchor:none]">
                <div ref={previewAnchor} />
                {showPreview && (
                <div
                    className={pinned ? 'sticky top-0 z-20 -mx-4 -mb-3 px-4 pb-3' : ''}
                    style={pinned ? { background: 'linear-gradient(to bottom, rgb(var(--base)) 80%, rgb(var(--base) / 0))' } : undefined}
                >
                    <div className={`rounded-[22px] transition-shadow duration-300 ${pinned && stuck ? 'shadow-[0_10px_28px_-12px_rgba(0,0,0,0.35)]' : ''}`}>
                        <ScooterPreview
                            customization={selectedExtras}
                            colour={previewColour}
                            name={previewName}
                            height={pinned && stuck ? Math.round(previewHeight * 0.74) : previewHeight}
                            pinned={pinned}
                            onTogglePin={() => setPinned(p => { const next = !p; try { localStorage.setItem('scoot:pinPreview', next ? '1' : '0'); } catch { } return next; })}
                            onExpand={() => setExpanded(true)}
                        />
                    </div>
                </div>
                )}

                <div key={phase} style={{ animation: ENTER }}>
                    {phase === 'ride' && ride && (
                        <>
                            <SectionLabel>{t('scoot.rideActive', 'YOU’RE ON YOUR WAY')}</SectionLabel>
                            <GroupCard radius={16} className={`p-4 ${CARD}`}>
                                <div className="flex items-center justify-between gap-3">
                                    <span className="flex min-w-0 items-center gap-2.5 text-[22px] font-bold tracking-tight text-black dark:text-white">
                                        <span className="truncate">{displayed?.name}</span>
                                        <ColourDot hex={displayed?.hex ?? previewColour} />
                                    </span>
                                    <span className="flex shrink-0 items-center gap-2">
                                        {batteryOn && ride.battery !== undefined && <BatteryPill level={ride.battery} minToRent={minToRent} size="lg" />}
                                        <Plate>{ride.plate}</Plate>
                                    </span>
                                </div>
                                <div className="mt-3.5 grid grid-cols-2 gap-3">
                                    <div className="rounded-[14px] bg-black/[0.04] px-4 py-3 dark:bg-white/[0.06]">
                                        <p className="text-[13px] font-semibold uppercase tracking-wider text-ios-gray">{t('scoot.elapsed', 'Elapsed')}</p>
                                        <p className={`mt-1 font-bold tabular-nums leading-none text-black dark:text-white ${compact ? 'text-[24px]' : 'text-[28px]'}`}>{elapsed(ride.startedAt)}</p>
                                    </div>
                                    <div className="rounded-[14px] bg-black/[0.04] px-4 py-3 dark:bg-white/[0.06]">
                                        <p className="text-[13px] font-semibold uppercase tracking-wider text-ios-gray">{t('scoot.farePaid', 'Fare paid')}</p>
                                        <p className={`mt-1 font-bold tabular-nums leading-none text-black dark:text-white ${compact ? 'text-[24px]' : 'text-[28px]'}`}>{currency}{cost}</p>
                                    </div>
                                </div>
                                {nearCharger ? (
                                    <p className="mt-3 flex items-center gap-2 text-[15px] leading-snug" style={{ color: CHARGE }}>
                                        <BatteryCharging className="h-[18px] w-[18px] shrink-0" strokeWidth={2.2} />
                                        {t('scoot.dockHint', 'End here to dock at {name} and charge it up.', { name: nearCharger.name })}
                                    </p>
                                ) : compact ? null : (
                                    <p className="mt-3 text-[15px] leading-snug text-ios-gray">{batteryOn ? t('scoot.returnHintCharge', 'Park safely. End your ride at a charging station or bunker to return your scooter.') : t('scoot.returnHint', 'Park safely. End your ride near a station to return your scooter.')}</p>
                                )}
                                <button
                                    type="button"
                                    disabled={busy}
                                    onClick={() => setConfirmEnd(true)}
                                    className={`mt-3.5 flex w-full items-center justify-center gap-2 rounded-[14px] bg-ios-red/15 text-[17px] font-bold text-ios-red transition-[transform,opacity] active:scale-[0.98] active:opacity-80 disabled:opacity-45 ${compact ? 'h-[44px]' : 'h-[46px]'}`}
                                >
                                    {busy ? <Spinner size={18} /> : <Power className="h-[19px] w-[19px]" strokeWidth={2.4} />}
                                    {busy ? t('scoot.working', 'One moment…') : t('scoot.endRide', 'End ride')}
                                </button>
                            </GroupCard>
                        </>
                    )}

                    {phase === 'pending' && (
                        <GroupCard radius={16} className={`mt-4 flex flex-col items-center px-6 py-6 text-center ${CARD}`}>
                            <span className="flex h-[64px] w-[64px] items-center justify-center rounded-full" style={{ background: `${ACCENT}22`, color: ACCENT }}>
                                <Zap className="h-[30px] w-[30px]" strokeWidth={2.2} />
                            </span>
                            <h2 className="mt-4 text-[22px] font-bold tracking-tight text-black dark:text-white">{t('scoot.preparingColour', 'Preparing your {colour} scooter', { colour: displayed?.name ?? '' })}</h2>
                            <p className="mt-2 max-w-[290px] text-[16px] leading-snug text-ios-gray">{t('scoot.pickupSoon', 'Stay by the station. Your ride starts when the scooter is ready.')}</p>
                            <Spinner size={30} className="mt-5" />
                        </GroupCard>
                    )}

                    {phase === 'station' && (
                        <>
                            <SectionLabel right={t('scoot.finishCount', '{count} finishes', { count: palette.length })}>{t('scoot.makeItYours', 'MAKE IT YOURS')}</SectionLabel>
                            <GroupCard radius={16} className={CARD}>
                                <Section title={t('scoot.paint', 'Paint')} choice={chosen?.name} first>
                                    <SwatchGrid
                                        label={t('scoot.chooseColour', 'Choose a color')}
                                        items={palette.map(c => ({ id: c.id, label: c.name, hex: c.hex }))}
                                        value={chosen?.id}
                                        disabled={busy}
                                        onPick={id => setColourId(Number(id))}
                                    />
                                </Section>
                                <Customizer bare first={false} value={selectedExtras} onChange={setCustomization} currency={currency} catalog={catalog} />
                            </GroupCard>
                        </>
                    )}
                </div>
                {pinned && <div aria-hidden className="transition-[height] duration-300 ease-[cubic-bezier(0.32,0.72,0,1)]" style={{ height: stuck ? 60 : 0 }} />}
            </div>

            {!ride && !pending && (
            <div className="shrink-0 border-t border-hairline/10 bg-surface px-4 py-2.5">
                <div className="flex items-center gap-3">
                    <div className="min-w-0 flex-1">
                        {!station ? (
                            <>
                                <p className="truncate text-[17px] font-bold leading-tight text-black dark:text-white">{t('scoot.noStations', 'No stations nearby')}</p>
                                <p className="truncate text-[13px] leading-snug text-ios-gray">{t('scoot.openMapHint', 'Open the map to find one')}</p>
                            </>
                        ) : far ? (
                            <>
                                <p className="truncate text-[16px] font-bold leading-tight text-black dark:text-white">{t('scoot.notAtStation', 'Not at a station')}</p>
                                <p className="truncate text-[13px] leading-snug tabular-nums text-ios-gray">
                                    {t('scoot.stationAway', '{name} · {n} m away', { name: station.name, n: Math.round(station.distance) })}
                                </p>
                            </>
                        ) : (
                            <>
                                <p className="truncate text-[20px] font-bold leading-tight text-black dark:text-white">
                                    {price} <span className="text-[14px] font-medium text-ios-gray">{fee ? t('scoot.unlockWithExtras', 'unlock incl. extras') : t('scoot.unlockFee', 'unlock')}</span>
                                </p>
                                <p className={`truncate text-[13px] leading-snug ${blocked ? 'font-medium text-ios-red' : 'text-ios-gray'}`}>
                                    {blocked ?? t('scoot.fareFrom', 'One-time fare · from {name}', { name: station.name })}
                                </p>
                            </>
                        )}
                    </div>
                    {!connected ? (
                        <button type="button" onClick={() => void refresh()} className="flex h-[44px] shrink-0 items-center rounded-full bg-black/[0.05] px-4 text-[15px] font-semibold active:opacity-60 dark:bg-white/10" style={{ color: ACCENT }}>
                            {t('scoot.retryShort', 'Retry')}
                        </button>
                    ) : !station ? (
                        <button
                            type="button"
                            onClick={() => { setMapFocus(null); setMap(true); }}
                            className="flex h-[44px] shrink-0 items-center gap-1.5 rounded-full px-5 text-[16px] font-bold text-white transition-transform active:scale-[0.97]"
                            style={{ background: ACCENT }}
                        >
                            <MapIcon className="h-[18px] w-[18px]" strokeWidth={2.3} />
                            {t('scoot.openMapShort', 'Map')}
                        </button>
                    ) : (
                        <button
                            type="button"
                            disabled={unavailable}
                            onClick={() => void order()}
                            className={`flex h-[44px] shrink-0 items-center justify-center gap-1 rounded-full text-white transition-[transform,opacity] active:scale-[0.97] active:opacity-90 disabled:opacity-45 ${
                                far ? 'px-3.5 text-[15px] font-semibold' : 'px-5 text-[16px] font-bold'
                            }`}
                            style={{ background: ACCENT }}
                        >
                            {action}
                            {far && !busy && <ArrowUpRight className="h-[16px] w-[16px]" strokeWidth={2.4} />}
                        </button>
                    )}
                </div>
            </div>
            )}

            {map && (
                <StationMap
                    snapshot={snapshot}
                    focus={mapFocus}
                    selectedId={station?.id ?? null}
                    onFocus={setMapFocus}
                    onPick={id => setStationId(id)}
                    onWaypoint={(x, y, name) => navigate(x, y, name)}
                    onClose={() => setMap(false)}
                />
            )}

            {expanded && (
                <Sheet fit="full" top={40} grabber={false} onClose={() => setExpanded(false)} className="bg-base">
                    {({ close }) => <ScooterPreview full customization={selectedExtras} colour={previewColour} name={previewName} onCollapse={close} />}
                </Sheet>
            )}

            {confirmEnd && <AlertDialog title={t('scoot.endRideTitle', 'End your ride?')} message={t('scoot.endRideBody', 'Your {currency}{cost} fare is already paid. Park somewhere safe before you hand the scooter back.', { currency, cost })} confirmLabel={t('scoot.endRide', 'End ride')} destructive onCancel={() => setConfirmEnd(false)} onConfirm={() => void finish()} />}
            {error && <AlertDialog title={t('scoot.oops', 'Scoot')} message={error} hideCancel onCancel={() => setError(null)} onConfirm={() => setError(null)} />}
            {toast && <Toast key={toast.id} message={toast.text} onDone={() => setToast(null)} />}
            {receipt && <AlertDialog title={receipt.flat ? t('scoot.batteryFlat', 'Battery flat') : t('scoot.rideEnded', 'Ride ended')} message={t('scoot.receiptFare', '{plate} · {minutes} min · {currency}{cost} fare', { plate: receipt.plate, minutes: receipt.minutes, currency, cost: receipt.cost }) + (receipt.docked ? ` · ${receipt.charging ? t('scoot.dockedCharging', 'docked at {name}, charging', { name: receipt.docked }) : t('scoot.dockedAt', 'docked at {name}', { name: receipt.docked })}` : '') + (receipt.flat ? ` · ${t('scoot.flatNote', 'the scooter ran out of charge')}` : '')} hideCancel onCancel={() => setReceipt(null)} onConfirm={() => setReceipt(null)} />}
        </div>
    );
}
