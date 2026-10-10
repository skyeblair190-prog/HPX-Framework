import { useEffect, useState } from 'react';
import { Bike, ChevronRight, Zap } from 'lucide-react';

import { t } from '../compat/i18n';
import { isFiveM } from '../compat/core/nui';
import { EmptyState } from '../compat/ui/EmptyState';
import { GroupCard, ListGroup, ListRow } from '../compat/ui/ListGroup';
import { scoot, useScootFeed } from './scootApi';
import type { ScootPastRide } from './scootApi';

const ACCENT = '#14b8a6';

const DEV_RIDES: ScootPastRide[] = [
    { id: 12, scooterId: 2, plate: 'SCOOT002', startedAt: 1789500000, endedAt: 1789500900, minutes: 15, cost: 15, paid: 1 },
    { id: 9,  scooterId: 1, plate: 'SCOOT001', startedAt: 1789400000, endedAt: 1789400300, minutes: 5,  cost: 5,  paid: 1 },
];

function when(unix: number): string {
    const d = new Date(unix * 1000);
    return `${d.toLocaleDateString([], { day: '2-digit', month: 'short' })} · ${d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}`;
}

function elapsed(start: number): string {
    const s = Math.max(0, Math.floor(Date.now() / 1000) - start);
    return `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`;
}

export function Rides({ onOpenRide }: { onOpenRide: () => void }) {
    const { snapshot } = useScootFeed();
    const [rides, setRides] = useState<ScootPastRide[] | null>(isFiveM ? null : DEV_RIDES);
    const [, tick] = useState(0);
    const ride = snapshot?.ride;
    const currency = snapshot?.pricing.currency ?? '$';

    useEffect(() => {
        if (!isFiveM) return;
        void scoot.history().then(r => setRides(r?.data?.rides ?? []));
    }, [ride?.id]);

    useEffect(() => {
        if (!ride) return;
        const timer = window.setInterval(() => tick(n => n + 1), 1000);
        return () => window.clearInterval(timer);
    }, [ride]);

    const spent = (rides ?? []).reduce((n, r) => n + r.cost, 0);
    const minutes = (rides ?? []).reduce((n, r) => n + r.minutes, 0);

    return (
        <div className="absolute inset-0 flex flex-col bg-base font-sf">
            <div className="h-11 shrink-0" aria-hidden />
            <div className="no-scrollbar flex-1 overflow-y-auto pb-10">
                <div className="px-5 pb-2 pt-1 text-[34px] font-bold tracking-tight text-black dark:text-white">{t('scoot.tabRides', 'Rides')}</div>

                {ride && (
                    <button
                        type="button"
                        onClick={onOpenRide}
                        className="mx-4 mb-4 flex w-[calc(100%-2rem)] items-center gap-3 rounded-[16px] bg-surface p-3.5 text-start ring-1 ring-black/[0.04] transition-transform active:scale-[0.99] dark:ring-white/[0.06]"
                    >
                        <span className="flex h-[40px] w-[40px] shrink-0 items-center justify-center rounded-[12px]" style={{ background: `${ACCENT}22`, color: ACCENT }}>
                            <Zap className="h-[21px] w-[21px]" strokeWidth={2.2} />
                        </span>
                        <span className="min-w-0 flex-1">
                            <span className="block truncate text-[17px] font-semibold leading-tight text-black dark:text-white">{t('scoot.rideInProgress', 'Ride in progress')}</span>
                            <span className="mt-0.5 block truncate text-[14px] tabular-nums text-ios-gray">
                                {ride.plate} · {elapsed(ride.startedAt)} · {currency}{ride.cost}
                            </span>
                        </span>
                        <ChevronRight className="h-[18px] w-[18px] shrink-0 text-ios-gray3" strokeWidth={2.5} />
                    </button>
                )}

                <div className="mx-4 mb-5 grid grid-cols-2 gap-3">
                    <GroupCard radius={16} className="p-4">
                        <p className="text-[13px] font-semibold uppercase tracking-wider text-ios-gray">{t('scoot.totalSpent', 'Total spent')}</p>
                        <p className="mt-1 text-[26px] font-bold tabular-nums text-black dark:text-white">${spent}</p>
                    </GroupCard>
                    <GroupCard radius={16} className="p-4">
                        <p className="text-[13px] font-semibold uppercase tracking-wider text-ios-gray">{t('scoot.minutesRidden', 'Minutes ridden')}</p>
                        <p className="mt-1 text-[26px] font-bold tabular-nums text-black dark:text-white">{minutes}</p>
                    </GroupCard>
                </div>

                {rides && rides.length === 0 ? (
                    <EmptyState icon={Bike} title={t('scoot.noRides', 'No rides yet')} subtitle={t('scoot.noRidesSub', 'Unlock a scooter from the Ride tab.')} center />
                ) : (
                    <ListGroup header={t('scoot.recent', 'Recent')}>
                        {(rides ?? []).map((r, i) => (
                            <ListRow
                                key={r.id}
                                label={r.plate ?? `#${r.scooterId}`}
                                sub={`${when(r.startedAt)} · ${t('scoot.minutes', '{n} min', { n: r.minutes })}`}
                                value={`$${r.cost}`}
                                divider={i < (rides?.length ?? 0) - 1}
                            />
                        ))}
                    </ListGroup>
                )}
            </div>
        </div>
    );
}
