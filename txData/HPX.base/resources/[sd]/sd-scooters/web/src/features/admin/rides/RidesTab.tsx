import { useEffect, useState } from 'react';
import { CircleStop, RefreshCw } from 'lucide-react';
import { useAdmin } from '@/store/admin';
import { act, query } from '@/nui/api';
import { useQuery, useSlow } from '@/nui/useQuery';
import { t } from '@/i18n';
import { ago, BarChart, ConfirmDialog, Empty, Heading, money, SearchInput, Skeleton, Status } from '@/components/shared';
import type { ActiveRide, Page, RideRow, RidesData } from '@/types';
import { BatteryBar } from '../details/DetailDrawer';

type Period = 'today' | 'week' | 'all';

const Stat = ({ label, value, sub }: { label: string; value: string; sub?: string }) => (
  <div className="px-5 py-4">
    <div className="text-[12px] font-medium" style={{ color: 'var(--text-3)' }}>
      {label}
    </div>
    <div className="text-[24px] font-semibold mono tracking-[-0.02em] mt-1.5 leading-none">{value}</div>
    {sub && (
      <div className="text-[11.5px] mt-1.5" style={{ color: 'var(--text-3)' }}>
        {sub}
      </div>
    )}
  </div>
);

const hourLabel = (hour: number) => new Date(hour * 3600 * 1000).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

export const RidesTab = () => {
  const snapshot = useAdmin(s => s.snapshot)!;
  const busy = useAdmin(s => s.busy);
  const openDetail = useAdmin(s => s.setDetail);
  const [period, setPeriod] = useState<Period>('today');
  const [search, setSearch] = useState('');
  const [term, setTerm] = useState('');
  const [more, setMore] = useState<RideRow[]>([]);
  const [ending, setEnding] = useState<ActiveRide | null>(null);
  const cur = snapshot.currency;

  const { data, refresh: loadStats } = useQuery<RidesData>('rides', undefined, { refreshMs: 10000 });
  const { data: firstPage } = useQuery<Page<RideRow>>('ridehistory', { query: term, offset: 0 });
  const slowStats = useSlow(!data);
  const slowHistory = useSlow(!firstPage);

  useEffect(() => {
    const id = window.setTimeout(() => setTerm(search.trim()), search ? 250 : 0);
    return () => window.clearTimeout(id);
  }, [search]);
  useEffect(() => setMore([]), [term]);

  const history: Page<RideRow> | null = firstPage ? { ...firstPage, rows: [...firstPage.rows, ...more] } : null;
  const loadMore = async () => {
    if (!history) return;
    const page = await query<Page<RideRow>>('ridehistory', { query: term, offset: history.rows.length });
    if (page) setMore(prev => [...prev, ...page.rows]);
  };

  const totals = data?.totals[period];
  const hours = data ? Array.from({ length: 24 }, (_, i) => data.firstHour + i) : [];
  const perHour = hours.map(h => data?.hourly.find(x => x.hour === h)?.rides ?? 0);
  const maxBunker = Math.max(1, ...(data?.byBunker.map(b => b.revenue) ?? [1]));

  return (
    <div className="h-full overflow-y-auto sc-scroll">
      <div className="px-6 py-5 flex flex-col gap-6">
        <div className="flex flex-col gap-3">
          <Heading title={t('tabs.rides')}>
            <div className="sc-segment">
              {(['today', 'week', 'all'] as Period[]).map(p => (
                <button key={p} type="button" data-on={period === p} onClick={() => setPeriod(p)}>
                  {t(`rides.${p}`)}
                </button>
              ))}
            </div>
            <button type="button" className="sc-btn sc-btn--icon" title="Refresh" onClick={() => void loadStats()}>
              <RefreshCw size={14} />
            </button>
          </Heading>
          <div className="sc-card grid grid-cols-4 overflow-hidden">
            {[
              { label: t('rides.revenue'), value: totals ? money(cur, totals.revenue) : '—' },
              { label: t('rides.rides'), value: totals ? String(totals.rides) : '—' },
              { label: t('rides.minutes'), value: totals ? t('common.minutes', totals.minutes) : '—' },
              { label: t('rides.unpaid'), value: totals ? money(cur, totals.unpaid) : '—' },
            ].map((s, i) => (
              <div key={s.label} style={{ borderLeft: i ? '1px solid var(--hairline)' : 'none' }}>
                <Stat label={s.label} value={s.value} />
              </div>
            ))}
          </div>
        </div>

        <div className="grid gap-4" style={{ gridTemplateColumns: 'minmax(0, 1.35fr) minmax(0, 1fr)' }}>
          <div className="flex flex-col gap-2.5 min-w-0">
            <div className="sc-heading">
              {t('rides.live')}
              <span className="sc-heading__count">{data?.active.length ?? snapshot.rides.length}</span>
            </div>
            {!data ? (
              slowStats && <Skeleton rows={2} />
            ) : data.active.length === 0 ? (
              <div className="sc-card px-4 py-6 text-center text-[12.5px]" style={{ color: 'var(--text-3)' }}>
                {t('rides.live_empty')}
              </div>
            ) : (
              <div className="sc-list">
                {data.active.map(r => (
                  <div key={r.id} className="sc-row">
                    <span className="w-1.5 h-1.5 rounded-full flex-shrink-0" style={{ backgroundColor: r.online ? 'var(--ok)' : 'var(--text-4)' }} />
                    <div className="min-w-0 flex-1">
                      <button
                        type="button"
                        className="text-[13px] font-medium truncate hover:underline underline-offset-2"
                        style={{ background: 'none', border: 'none', padding: 0, color: 'var(--text-1)' }}
                        onClick={() => openDetail({ kind: 'player', renter: r.renter, name: r.renterName })}
                      >
                        {r.renterName}
                      </button>
                      <div className="text-[11.5px] mt-0.5" style={{ color: 'var(--text-3)' }}>
                        <button type="button" className="mono hover:underline underline-offset-2" style={{ background: 'none', border: 'none', padding: 0, color: 'inherit' }} onClick={() => openDetail({ kind: 'scooter', id: r.scooterId })}>
                          {r.plate}
                        </button>{' '}
                        · {t('common.minutes', r.minutes)}
                      </div>
                    </div>
                    {r.battery != null && <BatteryBar level={r.battery} />}
                    <span className="mono text-[12.5px] w-12 text-right">{money(cur, r.cost)}</span>
                    {snapshot.canEdit && (
                      <button type="button" className="sc-btn" style={{ height: 26 }} disabled={busy} onClick={() => setEnding(r)}>
                        <CircleStop size={13} />
                        {t('rides.end_ride')}
                      </button>
                    )}
                  </div>
                ))}
              </div>
            )}
          </div>

          <div className="flex flex-col gap-2.5 min-w-0">
            <div className="sc-heading">{t('rides.last_24h')}</div>
            <div className="sc-card px-4 py-4">
              {data ? <BarChart values={perHour} labels={hours.map(hourLabel)} height={96} /> : <div className={slowStats ? 'sc-skeleton' : ''} style={{ height: 120 }} />}
            </div>
          </div>
        </div>

        <div className="flex flex-col gap-2.5">
          <div className="sc-heading">{t('rides.by_bunker')}</div>
          {!data ? (
            slowStats && <Skeleton rows={3} height={44} />
          ) : data.byBunker.length === 0 ? (
            <div className="sc-card px-4 py-6 text-center text-[12.5px]" style={{ color: 'var(--text-3)' }}>
              {t('rides.history_empty')}
            </div>
          ) : (
            <div className="sc-list">
              {data.byBunker.map(b => (
                <div key={String(b.bunkerId)} className="sc-row" style={{ minHeight: 44 }}>
                  <span className="text-[12.5px] w-48 truncate">{b.name ?? (b.bunkerId == null ? t('rides.no_bunker') : `#${b.bunkerId}`)}</span>
                  <div className="flex-1 h-[5px] rounded-full overflow-hidden" style={{ backgroundColor: 'rgba(255,255,255,0.06)' }}>
                    <div className="h-full rounded-full" style={{ width: `${(b.revenue / maxBunker) * 100}%`, backgroundColor: 'rgba(237,237,239,0.55)' }} />
                  </div>
                  <span className="mono text-[12px] w-16 text-right" style={{ color: 'var(--text-3)' }}>
                    {b.rides} {t('rides.rides').toLowerCase()}
                  </span>
                  <span className="mono text-[12.5px] w-16 text-right pr-2">{money(cur, b.revenue)}</span>
                </div>
              ))}
            </div>
          )}
        </div>

        <div className="flex flex-col gap-2.5">
          <div className="flex items-center gap-3">
            <div className="sc-heading">
              {t('rides.history')}
              {history && <span className="sc-heading__count">{history.total}</span>}
            </div>
            <div className="ml-auto w-72 flex">
              <SearchInput value={search} onChange={setSearch} placeholder={t('rides.search')} />
            </div>
          </div>
          {!history ? (
            slowHistory && <Skeleton rows={6} height={48} />
          ) : history.rows.length === 0 ? (
            <Empty text={t('rides.history_empty')} />
          ) : (
            <>
              <div className="sc-thead">
                <span className="flex-1">{t('rides.columns.rider')}</span>
                <span className="w-24">{t('rides.columns.scooter')}</span>
                <span className="w-24">{t('rides.columns.when')}</span>
                <span className="w-16 text-right">{t('rides.columns.duration')}</span>
                <span className="w-16 text-right pr-2">{t('rides.columns.cost')}</span>
              </div>
              <div className="sc-list">
                {history.rows.map(r => (
                  <div key={r.id} className="sc-row sc-row--click" style={{ minHeight: 48 }} onClick={() => openDetail({ kind: 'player', renter: r.renter, name: r.renterName ?? r.renter })}>
                    <div className="flex-1 min-w-0">
                      <div className="text-[12.5px] font-medium truncate">{r.renterName ?? r.renter}</div>
                      <div className="text-[11.5px] mt-0.5 truncate" style={{ color: 'var(--text-3)' }}>
                        {r.endedBy ? t(`rides.ended.${r.endedBy}`) : '—'}
                      </div>
                    </div>
                    <span className="w-24 mono text-[12px]">{r.plate ?? '—'}</span>
                    <span className="w-24 text-[12px]" style={{ color: 'var(--text-2)' }}>
                      {ago(r.startedAt)}
                    </span>
                    <span className="w-16 text-right mono text-[12px]" style={{ color: 'var(--text-2)' }}>
                      {t('common.minutes', r.minutes)}
                    </span>
                    <span className="w-16 text-right pr-2 flex flex-col items-end">
                      <span className="mono text-[12.5px]">{money(cur, r.cost)}</span>
                      {!r.paid ? <Status tone="danger">{t('rides.unpaid_tag')}</Status> : r.refunded > 0 ? <Status tone="warn">{t('rides.refunded_tag')}</Status> : null}
                    </span>
                  </div>
                ))}
              </div>
              {history.rows.length < history.total && (
                <button type="button" className="sc-btn self-center" onClick={() => void loadMore()}>
                  {t('common.load_more')}
                </button>
              )}
            </>
          )}
        </div>
      </div>

      {ending && (
        <ConfirmDialog
          title={t('rides.end_title')}
          body={t('rides.end_body', ending.renterName)}
          confirmLabel={t('rides.end_ride')}
          onClose={() => setEnding(null)}
          onConfirm={async () => {
            const reply = await act('forceendride', { rideId: ending.id }, `Ended the ride of ${ending.renterName}`);
            setEnding(null);
            if (reply.success) void loadStats();
          }}
        />
      )}
    </div>
  );
};
