import { useCallback, useState } from 'react';
import { BatteryCharging, Lock, Magnet, Navigation, Package, RotateCcw, Trash2, Undo2, Unlock, Warehouse } from 'lucide-react';
import { useAdmin } from '@/store/admin';
import { act } from '@/nui/api';
import { useQuery, useSlow } from '@/nui/useQuery';
import { t } from '@/i18n';
import { ago, ConfirmDialog, Drawer, Empty, Field, money, Section, Skeleton, Status, Swatch } from '@/components/shared';
import type { RideRow, Scooter, Snapshot, Station } from '@/types';
import { ScooterPreview3D } from './ScooterPreview3D';
import { BatteryModal, StockModal } from './modals';

export const statusTone = (s: Scooter): 'ok' | 'warn' | 'danger' | 'neutral' =>
  !s.exists ? 'danger' : s.status === 'rented' ? 'ok' : s.status === 'charging' ? 'warn' : s.status === 'flat' ? 'danger' : 'neutral';

export const statusLabel = (s: Scooter): string => {
  if (!s.exists) return t('scooters.missing');
  if (s.status === 'rented') return t('scooters.filter_rented');
  if (s.status === 'charging') return t('stations.charging');
  if (s.status === 'flat') return t('scooters.filter_flat');
  return t('scooters.filter_available');
};

export const BatteryBar = ({ level, width = 28 }: { level: number; width?: number }) => {
  const pct = Math.max(0, Math.min(100, Math.round(level)));
  const colour = pct <= 15 ? 'var(--danger)' : pct <= 35 ? 'var(--warn)' : 'var(--text-2)';
  return (
    <span className="inline-flex items-center gap-2" title={`${pct}%`}>
      <span className="relative h-[5px] rounded-full overflow-hidden" style={{ width, backgroundColor: 'rgba(255,255,255,0.08)' }}>
        <span className="absolute inset-y-0 left-0 rounded-full" style={{ width: `${pct}%`, backgroundColor: colour }} />
      </span>
      <span className="mono text-[11.5px] w-8" style={{ color: pct <= 15 ? 'var(--danger)' : 'var(--text-2)' }}>
        {pct}%
      </span>
    </span>
  );
};

const ScooterDetail = ({ snapshot, id, onClose }: { snapshot: Snapshot; id: number; onClose: () => void }) => {
  const busy = useAdmin(s => s.busy);
  const [battery, setBattery] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const scooter = snapshot.scooters.find(s => s.id === id);
  if (!scooter) return <Drawer title="—" onClose={onClose}><Empty text={t('err.no_scooter')} /></Drawer>;
  const colour = snapshot.colours.find(c => c.index === scooter.colour);
  const home = scooter.bunkerId != null ? snapshot.bunkers.find(b => b.id === scooter.bunkerId) : null;
  const station = scooter.stationId != null ? snapshot.stations.find(st => st.id === scooter.stationId) : null;
  const ride = snapshot.rides.find(r => r.scooterId === scooter.id);
  const rented = scooter.status === 'rented';
  const edit = snapshot.canEdit;
  const setUser = useAdmin.getState().setDetail;

  return (
    <Drawer
      title={<span className="mono">{scooter.plate}</span>}
      subtitle={<Status tone={statusTone(scooter)}>{statusLabel(scooter)}</Status>}
      onClose={onClose}
      footer={
        <>
          <button type="button" className="sc-btn" disabled={busy} onClick={() => void act('teleport', { kind: 'scooter', id })}>
            <Navigation size={14} />
            {t('actions.teleport')}
          </button>
          <button type="button" className="sc-btn" disabled={!edit || busy || rented} onClick={() => void act('bringscooter', { id }, `Brought ${scooter.plate}`)}>
            <Magnet size={14} />
            {t('actions.bring')}
          </button>
          <button type="button" className="sc-btn sc-btn--icon sc-btn--danger ml-auto" title={t('actions.delete')} disabled={!edit || busy || rented} onClick={() => setDeleting(true)}>
            <Trash2 size={14} />
          </button>
        </>
      }
    >
      <div className="px-5 pt-4">
        <ScooterPreview3D hex={colour?.hex ?? '#1a6b78'} customization={scooter.customization} />
      </div>
      <Section>
        <Field label={t('scooters.detail_status')}>
          <Status tone={statusTone(scooter)}>{statusLabel(scooter)}</Status>
        </Field>
        {ride && (
          <Field label={t('rides.player')}>
            <button type="button" className="underline-offset-2 hover:underline" style={{ background: 'none', border: 'none', color: 'var(--text-1)', padding: 0 }} onClick={() => setUser({ kind: 'player', renter: ride.renter, name: ride.renterName })}>
              {ride.renterName} · {t('common.minutes', ride.minutes)}
            </button>
          </Field>
        )}
        {snapshot.battery.enabled && (
          <Field label={t('scooters.battery')}>
            <BatteryBar level={scooter.battery} width={48} />
          </Field>
        )}
        <Field label={t('scooters.colour')}>
          <span className="inline-flex items-center gap-2">
            <Swatch hex={colour?.hex ?? '#fff'} size={10} />
            {colour?.name ?? '?'}
          </span>
        </Field>
        <Field label={t('scooters.home')}>{home?.name ?? t('scooters.free')}</Field>
        {station && (
          <Field label={t('scooters.detail_dock')}>
            {station.name} · {t('stations.dock', scooter.slot ?? 0)}
          </Field>
        )}
        <Field label={t('scooters.detail_position')}>
          <span className="mono">
            {scooter.x.toFixed(0)}, {scooter.y.toFixed(0)}, {scooter.z.toFixed(0)}
          </span>
        </Field>
        <Field label={t('scooters.locked')}>{scooter.locked ? t('scooters.locked') : t('scooters.unlocked')}</Field>
      </Section>
      {edit && (
        <>
          <Section title={t('actions.colour')}>
            <div className="flex flex-wrap gap-2">
              {snapshot.colours.map(c => (
                <button key={c.index} type="button" title={c.name} className="p-0.5 rounded-full" style={{ background: 'none', border: 'none' }} disabled={busy} onClick={() => c.index !== scooter.colour && void act('setscootercolour', { id, colour: c.index }, `Repainted ${scooter.plate}`)}>
                  <Swatch hex={c.hex} size={20} active={c.index === scooter.colour} />
                </button>
              ))}
            </div>
          </Section>
          <Section>
            <div className="grid grid-cols-2 gap-2">
              <button type="button" className="sc-btn" disabled={busy || !snapshot.battery.enabled} onClick={() => setBattery(true)}>
                <BatteryCharging size={14} />
                {t('actions.battery')}
              </button>
              <button type="button" className="sc-btn" disabled={busy || rented || !scooter.exists} onClick={() => void act('lockscooter', { id, locked: !scooter.locked }, `${scooter.locked ? 'Unlocked' : 'Locked'} ${scooter.plate}`)}>
                {scooter.locked ? <Unlock size={14} /> : <Lock size={14} />}
                {scooter.locked ? t('actions.unlock') : t('actions.lock')}
              </button>
              <button type="button" className="sc-btn" disabled={busy || rented || scooter.bunkerId == null} onClick={() => void act('sendhome', { id }, `Sent ${scooter.plate} home`)}>
                <Warehouse size={14} />
                {t('actions.send_home')}
              </button>
              <button type="button" className="sc-btn" disabled={busy} onClick={() => void act('respawnscooter', { id }, `Respawned ${scooter.plate}`)}>
                <RotateCcw size={14} />
                {t('actions.respawn')}
              </button>
            </div>
          </Section>
        </>
      )}
      {battery && <BatteryModal ids={[id]} current={scooter.battery} title={t('scooters.battery_title')} onClose={() => setBattery(false)} />}
      {deleting && (
        <ConfirmDialog
          title={t('scooters.delete_title')}
          body={t('scooters.delete_body', scooter.plate)}
          confirmLabel={t('actions.delete')}
          onClose={() => setDeleting(false)}
          onConfirm={async () => {
            const reply = await act('deletescooter', { id }, t('common.deleted', scooter.plate));
            setDeleting(false);
            if (reply.success) onClose();
          }}
        />
      )}
    </Drawer>
  );
};

const StationDetail = ({ snapshot, id, onClose }: { snapshot: Snapshot; id: number; onClose: () => void }) => {
  const busy = useAdmin(s => s.busy);
  const station: Station | undefined = snapshot.stations.find(s => s.id === id);
  if (!station) return <Drawer title="—" onClose={onClose}><Empty text={t('err.no_station')} /></Drawer>;
  const paint = snapshot.stationColours.find(c => c.index === station.colour);
  const open = useAdmin.getState().setDetail;
  return (
    <Drawer
      title={station.name}
      subtitle={<Status tone={station.enabled ? 'ok' : 'neutral'}>{station.enabled ? t('bunkers.enabled') : t('bunkers.disabled')}</Status>}
      onClose={onClose}
      footer={
        <button type="button" className="sc-btn" disabled={busy} onClick={() => void act('teleport', { kind: 'station', id })}>
          <Navigation size={14} />
          {t('actions.teleport')}
        </button>
      }
    >
      <Section>
        <Field label={t('stations.colour')}>
          <span className="inline-flex items-center gap-2">
            <Swatch hex={paint?.hex ?? '#0a949a'} size={10} />
            {paint?.name}
          </span>
        </Field>
        <Field label={t('stations.slots')}>
          {station.occupied}/{station.slots.length}
        </Field>
        <Field label={t('bunkers.coords')}>
          <span className="mono">
            {station.x.toFixed(0)}, {station.y.toFixed(0)}, {station.z.toFixed(0)}
          </span>
        </Field>
      </Section>
      <Section title={t('stations.detail_title')}>
        <div className="sc-list">
          {station.slots.map((slot, i) => (
            <div key={i} className={`sc-row${slot ? ' sc-row--click' : ''}`} style={{ minHeight: 46 }} onClick={() => slot && open({ kind: 'scooter', id: slot.scooterId })}>
              <span className="mono text-[11.5px] w-12" style={{ color: 'var(--text-3)' }}>
                {t('stations.dock', i + 1)}
              </span>
              {slot ? (
                <>
                  <span className="text-[12.5px] mono font-medium">{slot.plate ?? `#${slot.scooterId}`}</span>
                  <span className="ml-auto flex items-center gap-2">
                    {slot.target ? (
                      <span className="text-[11.5px]" style={{ color: 'var(--warn)' }}>
                        {t('stations.target', `${slot.target}%`)}
                      </span>
                    ) : null}
                    {slot.battery != null && <BatteryBar level={slot.battery} />}
                  </span>
                  {snapshot.canEdit && (
                    <button
                      type="button"
                      className="sc-btn"
                      style={{ height: 26 }}
                      disabled={busy}
                      onClick={e => {
                        e.stopPropagation();
                        void act('releasedock', { stationId: station.id, slot: i + 1 }, `Released ${slot.plate ?? 'a scooter'} from ${station.name}`);
                      }}
                    >
                      {t('actions.release')}
                    </button>
                  )}
                </>
              ) : (
                <span className="text-[12px]" style={{ color: 'var(--text-4)' }}>
                  {t('stations.empty_dock')}
                </span>
              )}
            </div>
          ))}
        </div>
      </Section>
    </Drawer>
  );
};

const BunkerDetail = ({ snapshot, id, onClose }: { snapshot: Snapshot; id: number; onClose: () => void }) => {
  const busy = useAdmin(s => s.busy);
  const [stock, setStock] = useState(false);
  const bunker = snapshot.bunkers.find(b => b.id === id);
  if (!bunker) return <Drawer title="—" onClose={onClose}><Empty text={t('err.no_bunker')} /></Drawer>;
  const fleet = snapshot.scooters.filter(s => s.bunkerId === bunker.id);
  const open = useAdmin.getState().setDetail;
  return (
    <Drawer
      title={bunker.name}
      subtitle={<Status tone={bunker.enabled ? 'ok' : 'neutral'}>{bunker.enabled ? t('bunkers.enabled') : t('bunkers.disabled')}</Status>}
      onClose={onClose}
      footer={
        <>
          <button type="button" className="sc-btn" disabled={busy} onClick={() => void act('teleport', { kind: 'bunker', id })}>
            <Navigation size={14} />
            {t('actions.teleport')}
          </button>
          {snapshot.canEdit && (
            <button type="button" className="sc-btn" disabled={busy} onClick={() => setStock(true)}>
              <Package size={14} />
              {t('actions.stock')}
            </button>
          )}
        </>
      }
    >
      <Section>
        <Field label={t('bunkers.stock')}>
          <span className="mono">{bunker.stock}</span>
        </Field>
        <Field label={t('bunkers.coords')}>
          <span className="mono">
            {bunker.x.toFixed(0)}, {bunker.y.toFixed(0)}, {bunker.z.toFixed(0)}
          </span>
        </Field>
      </Section>
      <Section title={`${t('tabs.scooters')} · ${fleet.length}`}>
        {fleet.length === 0 ? (
          <div className="text-[12px] py-2" style={{ color: 'var(--text-3)' }}>
            {t('common.none')}
          </div>
        ) : (
          <div className="sc-list">
            {fleet.map(s => (
              <div key={s.id} className="sc-row sc-row--click" style={{ minHeight: 42 }} onClick={() => open({ kind: 'scooter', id: s.id })}>
                <span className="mono text-[12.5px] font-medium">{s.plate}</span>
                <Status tone={statusTone(s)}>{statusLabel(s)}</Status>
                <span className="ml-auto">{snapshot.battery.enabled && <BatteryBar level={s.battery} />}</span>
              </div>
            ))}
          </div>
        )}
      </Section>
      {stock && <StockModal bunker={bunker} onClose={() => setStock(false)} />}
    </Drawer>
  );
};

const PlayerDetail = ({ snapshot, renter, name, onClose }: { snapshot: Snapshot; renter: string; name: string; onClose: () => void }) => {
  const busy = useAdmin(s => s.busy);
  const { data, refresh: load } = useQuery<{ rows: RideRow[] }>('playerrides', { renter });
  const rows = data?.rows ?? null;
  const slow = useSlow(!rows);
  const [refunding, setRefunding] = useState<RideRow | null>(null);
  const spent = (rows ?? []).reduce((n, r) => n + (r.paid ? r.cost - (r.refunded || 0) : 0), 0);
  const minutes = (rows ?? []).reduce((n, r) => n + (r.minutes || 0), 0);
  return (
    <Drawer title={name} subtitle={<span className="mono">{renter}</span>} onClose={onClose} width={420}>
      <Section>
        <div className="grid grid-cols-3 gap-3">
          <div>
            <div className="sc-label">{t('rides.rides')}</div>
            <div className="mono text-[18px] font-semibold mt-1">{rows ? rows.length : '—'}</div>
          </div>
          <div>
            <div className="sc-label">{t('rides.revenue')}</div>
            <div className="mono text-[18px] font-semibold mt-1">{rows ? money(snapshot.currency, spent) : '—'}</div>
          </div>
          <div>
            <div className="sc-label">{t('rides.minutes')}</div>
            <div className="mono text-[18px] font-semibold mt-1">{rows ? t('common.minutes', minutes) : '—'}</div>
          </div>
        </div>
      </Section>
      <div className="px-5 py-4">
        {!rows ? (
          slow && <Skeleton rows={4} height={48} />
        ) : rows.length === 0 ? (
          <Empty text={t('rides.history_empty')} />
        ) : (
          <div className="sc-list">
            {rows.map(r => (
              <div key={r.id} className="sc-row" style={{ minHeight: 50 }}>
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2">
                    <span className="mono text-[12.5px] font-medium">{r.plate ?? '—'}</span>
                    {!r.endedAt && <Status tone="ok">{t('scooters.filter_rented')}</Status>}
                    {!!r.endedAt && !r.paid && <Status tone="danger">{t('rides.unpaid_tag')}</Status>}
                    {r.refunded > 0 && <Status tone="warn">{t('rides.refunded_tag')}</Status>}
                  </div>
                  <div className="text-[11.5px] mt-0.5" style={{ color: 'var(--text-3)' }}>
                    {ago(r.startedAt)} · {t('common.minutes', r.minutes)}
                    {r.endedBy ? ` · ${t(`rides.ended.${r.endedBy}`)}` : ''}
                  </div>
                </div>
                <span className="mono text-[12.5px]">{money(snapshot.currency, r.cost)}</span>
                {snapshot.canEdit && !!r.endedAt && !!r.paid && r.refunded < r.cost && (
                  <button type="button" className="sc-btn" style={{ height: 26 }} disabled={busy} onClick={() => setRefunding(r)}>
                    <Undo2 size={13} />
                    {t('rides.refund')}
                  </button>
                )}
              </div>
            ))}
          </div>
        )}
      </div>
      {refunding && (
        <ConfirmDialog
          title={t('rides.refund_title')}
          body={t('rides.refund_body', snapshot.currency, refunding.cost - refunding.refunded, name)}
          confirmLabel={t('rides.refund')}
          danger={false}
          onClose={() => setRefunding(null)}
          onConfirm={async () => {
            const reply = await act<{ amount?: number }>('refundride', { rideId: refunding.id }, `Refunded ride #${refunding.id}`);
            setRefunding(null);
            if (reply.success) {
              useAdmin.getState().toast(t('rides.refunded', snapshot.currency, reply.data?.amount ?? 0), true);
              void load();
            }
          }}
        />
      )}
    </Drawer>
  );
};

export const DetailDrawer = () => {
  const detail = useAdmin(s => s.detail);
  const snapshot = useAdmin(s => s.snapshot);
  const setDetail = useAdmin(s => s.setDetail);
  const onClose = useCallback(() => setDetail(null), [setDetail]);
  if (!detail || !snapshot) return null;
  if (detail.kind === 'scooter') return <ScooterDetail key={detail.id} snapshot={snapshot} id={detail.id} onClose={onClose} />;
  if (detail.kind === 'station') return <StationDetail key={detail.id} snapshot={snapshot} id={detail.id} onClose={onClose} />;
  if (detail.kind === 'bunker') return <BunkerDetail key={detail.id} snapshot={snapshot} id={detail.id} onClose={onClose} />;
  return <PlayerDetail key={detail.renter} snapshot={snapshot} renter={detail.renter} name={detail.name} onClose={onClose} />;
};

