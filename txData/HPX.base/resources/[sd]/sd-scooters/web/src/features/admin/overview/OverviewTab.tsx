import { useState } from 'react';
import { ArrowUpRight, Bike, MapPin, Warehouse, Zap } from 'lucide-react';
import { useAdmin } from '@/store/admin';
import { useQuery } from '@/nui/useQuery';
import { t } from '@/i18n';
import { BarChart, money } from '@/components/shared';
import type { RidesData, Tab } from '@/types';
import { PlaceBunkerModal } from '../bunkers/BunkersTab';
import { PlaceStationModal } from '../stations/StationsTab';
import { NewScooterModal } from '../scooters/ScootersTab';

const Stat = ({ label, value, tab, index, columns }: { label: string; value: string; tab: Tab; index: number; columns: number }) => {
  const setTab = useAdmin(s => s.setTab);
  return (
    <button
      type="button"
      onClick={() => setTab(tab)}
      className="group text-left px-5 py-4 transition-colors hover:bg-[var(--surface-2)]"
      style={{
        background: 'none',
        border: 'none',
        borderLeft: index % columns === 0 ? 'none' : '1px solid var(--hairline)',
        borderTop: index < columns ? 'none' : '1px solid var(--hairline)',
      }}
    >
      <div className="flex items-center justify-between">
        <span className="text-[12px] font-medium" style={{ color: 'var(--text-3)' }}>
          {label}
        </span>
        <ArrowUpRight size={13} className="opacity-0 group-hover:opacity-100 transition-opacity" style={{ color: 'var(--text-3)' }} />
      </div>
      <div className="text-[26px] font-semibold mono tracking-[-0.02em] mt-1.5 leading-none">{value}</div>
    </button>
  );
};

const hourLabel = (hour: number) => new Date(hour * 3600 * 1000).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

export const OverviewTab = () => {
  const snapshot = useAdmin(s => s.snapshot)!;
  const recent = useAdmin(s => s.recent);
  const busy = useAdmin(s => s.busy);
  const [placingBunker, setPlacingBunker] = useState(false);
  const [placingStation, setPlacingStation] = useState(false);
  const [creating, setCreating] = useState<'self' | 'spawn' | null>(null);
  const { data: rides } = useQuery<RidesData>('rides');

  const enabled = snapshot.bunkers.filter(b => b.enabled).length;
  const charging = snapshot.scooters.filter(s => s.status === 'charging').length;
  const stock = snapshot.bunkers.reduce((n, b) => n + (b.stock ?? 0), 0);
  const cur = snapshot.currency;

  const stats: { label: string; value: string; tab: Tab }[] = [
    { label: t('stats.revenue_today'), value: money(cur, snapshot.today.revenue), tab: 'rides' },
    { label: t('stats.rides_today'), value: String(snapshot.today.rides), tab: 'rides' },
    { label: t('stats.active_rides'), value: String(snapshot.rides.length), tab: 'rides' },
    { label: t('stats.scooters'), value: String(snapshot.scooters.length), tab: 'scooters' },
    { label: t('stats.bunkers'), value: `${enabled}/${snapshot.bunkers.length}`, tab: 'bunkers' },
    { label: t('bunkers.stock'), value: String(stock), tab: 'bunkers' },
    { label: t('stats.stations'), value: String(snapshot.stations.length), tab: 'stations' },
    { label: t('stats.charging'), value: String(charging), tab: 'stations' },
  ];

  const buckets = [0, 0, 0, 0, 0];
  snapshot.scooters.forEach(s => buckets[Math.min(4, Math.floor(Math.max(0, s.battery) / 20))]++);
  const bucketLabels = ['0-19%', '20-39%', '40-59%', '60-79%', '80-100%'];

  const hours = rides ? Array.from({ length: 24 }, (_, i) => rides.firstHour + i) : [];
  const perHour = hours.map(h => rides?.hourly.find(x => x.hour === h)?.rides ?? 0);

  return (
    <div className="flex flex-col h-full min-h-0 px-6 py-5 gap-6 overflow-y-auto sc-scroll">
      <div className="sc-card grid grid-cols-4 overflow-hidden flex-shrink-0">
        {stats.map((s, i) => (
          <Stat key={s.label} index={i} columns={4} {...s} />
        ))}
      </div>

      <div className="grid grid-cols-2 gap-4 flex-shrink-0">
        <div className="flex flex-col gap-2.5 min-w-0">
          <div className="sc-heading">{t('overview.rides_24h')}</div>
          <div className="sc-card px-4 py-4">
            {rides ? <BarChart values={perHour} labels={hours.map(hourLabel)} height={84} /> : <div style={{ height: 106 }} />}
          </div>
        </div>
        <div className="flex flex-col gap-2.5 min-w-0">
          <div className="sc-heading">{t('overview.battery_spread')}</div>
          <div className="sc-card px-4 py-4">
            {snapshot.battery.enabled && snapshot.scooters.length > 0 ? (
              <BarChart values={buckets} labels={bucketLabels} height={84} />
            ) : (
              <div className="flex items-center justify-center text-[12.5px]" style={{ height: 106, color: 'var(--text-3)' }}>
                {t('overview.no_data')}
              </div>
            )}
          </div>
        </div>
      </div>

      {snapshot.canEdit && (
        <div className="flex items-center gap-2 flex-wrap flex-shrink-0">
          <button type="button" className="sc-btn" disabled={busy} onClick={() => setPlacingBunker(true)}>
            <MapPin size={14} />
            {t('actions.place_bunker')}
          </button>
          <button type="button" className="sc-btn" disabled={busy} onClick={() => setPlacingStation(true)}>
            <Zap size={14} />
            {t('actions.place_station')}
          </button>
          <button type="button" className="sc-btn" disabled={busy} onClick={() => setCreating('self')}>
            <Bike size={14} />
            {t('actions.place_scooter')}
          </button>
          <button type="button" className="sc-btn" disabled={busy || enabled === 0} onClick={() => setCreating('spawn')}>
            <Warehouse size={14} />
            {t('actions.spawn_at_bunker')}
          </button>
          <span className="ml-auto text-[11.5px]" style={{ color: 'var(--text-4)' }}>
            {t('common.shortcuts')}
          </span>
        </div>
      )}

      <div className="flex flex-col gap-2.5">
        <div className="sc-heading">{t('recent.title')}</div>
        {recent.length === 0 ? (
          <div className="sc-card px-4 py-6 text-[12.5px] text-center" style={{ color: 'var(--text-3)' }}>
            {t('recent.empty')}
          </div>
        ) : (
          <div className="sc-list">
            {recent.map(r => (
              <div key={r.id} className="sc-row" style={{ minHeight: 40 }}>
                <span className="w-1.5 h-1.5 rounded-full flex-shrink-0" style={{ backgroundColor: r.ok ? 'var(--ok)' : 'var(--danger)' }} />
                <span className="text-[12.5px] truncate">{r.text}</span>
                <span className="ml-auto mono text-[11.5px] pr-1" style={{ color: 'var(--text-3)' }}>
                  {new Date(r.at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                </span>
              </div>
            ))}
          </div>
        )}
      </div>

      {placingBunker && <PlaceBunkerModal onClose={() => setPlacingBunker(false)} />}
      {placingStation && <PlaceStationModal onClose={() => setPlacingStation(false)} />}
      {creating && <NewScooterModal mode={creating} onClose={() => setCreating(null)} />}
    </div>
  );
};
