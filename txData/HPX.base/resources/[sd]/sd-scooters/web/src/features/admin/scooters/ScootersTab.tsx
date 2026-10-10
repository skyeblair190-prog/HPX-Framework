import { useEffect, useMemo, useState } from 'react';
import { ArrowDownUp, BatteryCharging, Bike, Lock, RotateCcw, Trash2, Unlock, Warehouse } from 'lucide-react';
import { useAdmin } from '@/store/admin';
import { act } from '@/nui/api';
import { t } from '@/i18n';
import { ConfirmDialog, Empty, Heading, Hint, Modal, ModalActions, SearchInput, Status, Swatch } from '@/components/shared';
import type { Customization, ExtrasCatalog, ExtrasOption, Scooter } from '@/types';
import { BatteryBar, statusLabel, statusTone } from '../details/DetailDrawer';
import { BatteryModal } from '../details/modals';
import { Select } from '@/components/Select';
import { ScooterPreview3D } from '../details/ScooterPreview3D';

type Filter = 'all' | 'available' | 'rented' | 'charging' | 'flat' | 'missing';
type Sort = 'plate' | 'battery' | 'distance';
type Bulk = 'lock' | 'unlock' | 'sendHome' | 'respawn';

const ColourPicker = ({ value, onChange }: { value: number; onChange: (index: number) => void }) => {
  const colours = useAdmin(s => s.snapshot?.colours ?? []);
  const current = colours.find(c => c.index === value);
  return (
    <div>
      <div className="flex flex-wrap gap-2.5">
        {colours.map(c => (
          <button key={c.index} type="button" title={c.name} onClick={() => onChange(c.index)} className="p-0.5 rounded-full" style={{ background: 'none', border: 'none' }}>
            <Swatch hex={c.hex} size={22} active={value === c.index} />
          </button>
        ))}
      </div>
      {current && (
        <div className="text-[12px] mt-2.5" style={{ color: 'var(--text-2)' }}>
          {current.name}
        </div>
      )}
    </div>
  );
};

const ExtrasPicker = ({ catalog, value, onChange }: { catalog: ExtrasCatalog; value: Customization; onChange: (next: Customization) => void }) => {
  const set = <K extends keyof Customization>(key: K, v: Customization[K]) => onChange({ ...value, [key]: v });
  const options = (items: ExtrasOption[]) =>
    items.map(o => ({ value: o.id, label: o.label, icon: o.hex ? <Swatch hex={o.hex} size={12} /> : undefined }));
  const field = (key: 'rear' | 'lighting' | 'trim' | 'box', label: string) => (
    <div className="min-w-0">
      <label className="sc-label block mb-1.5">{label}</label>
      <Select value={value[key]} onChange={v => set(key, v)} options={options(catalog[key])} ariaLabel={label} />
    </div>
  );
  return (
    <div>
      <div className="grid grid-cols-2 gap-x-3 gap-y-3">
        {field('rear', t('scooters.extras_rear'))}
        {field('lighting', t('scooters.extras_lighting'))}
        {field('trim', t('scooters.extras_trim'))}
        {value.rear === 'delivery' && catalog.box && field('box', t('scooters.extras_box'))}
      </div>
      {value.rear === 'delivery' && <Hint className="mt-2">{t('scooters.extras_box_hint')}</Hint>}
    </div>
  );
};

export const NewScooterModal = ({ mode, onClose }: { mode: 'self' | 'spawn'; onClose: () => void }) => {
  const snapshot = useAdmin(s => s.snapshot)!;
  const enabledBunkers = snapshot.bunkers.filter(b => b.enabled);
  const [colour, setColour] = useState(1);
  const [bunkerId, setBunkerId] = useState<number | null>(mode === 'spawn' ? (enabledBunkers[0]?.id ?? null) : null);
  const catalog = snapshot.extras;
  const [customization, setCustomization] = useState<Customization | null>(catalog ? { ...catalog.defaults } : null);
  const canGo = mode === 'self' || bunkerId != null;

  const go = async () => {
    if (!canGo) return;
    const extras = customization ?? undefined;
    if (mode === 'self') {
      const reply = await act('spawnscooteronme', { colour, bunkerId, customization: extras }, 'Spawned a scooter on themselves');
      if (reply.success) onClose();
      return;
    }
    const reply = await act('spawnatbunker', { bunkerId, colour, customization: extras }, 'Spawned a scooter at a bunker');
    if (reply.success) onClose();
  };

  return (
    <Modal title={mode === 'self' ? t('actions.place_scooter') : t('actions.spawn_at_bunker')} onClose={onClose} width={480}>
      <div className="mb-4">
        <ScooterPreview3D hex={snapshot.colours.find(c => c.index === colour)?.hex ?? '#1a6b78'} height={180} customization={customization} />
      </div>
      <label className="sc-label block mb-2">{t('scooters.colour')}</label>
      <ColourPicker value={colour} onChange={setColour} />
      {catalog && customization && (
        <>
          <label className="sc-label block mt-4 mb-2">{t('scooters.extras')}</label>
          <ExtrasPicker catalog={catalog} value={customization} onChange={setCustomization} />
        </>
      )}
      <label className="sc-label block mt-4 mb-1.5">{t('scooters.home_bunker')}</label>
      <Select
        value={bunkerId ?? ''}
        onChange={v => setBunkerId(v === '' ? null : Number(v))}
        placeholder={t('scooters.no_home')}
        options={[
          ...(mode === 'self' ? [{ value: '' as number | '', label: t('scooters.no_home') }] : []),
          ...enabledBunkers.map(b => ({ value: b.id as number | '', label: b.name })),
        ]}
      />
      {mode === 'self' && <Hint className="mt-2">{t('scooters.spawn_on_me_hint')}</Hint>}
      <ModalActions>
        <button type="button" className="sc-btn" onClick={onClose}>
          {t('actions.cancel')}
        </button>
        <button type="button" className="sc-btn sc-btn--primary" disabled={!canGo} onClick={() => void go()}>
          {mode === 'self' ? t('actions.place_scooter') : t('actions.spawn_at_bunker')}
        </button>
      </ModalActions>
    </Modal>
  );
};

const matchesFilter = (s: Scooter, f: Filter) => {
  if (f === 'all') return true;
  if (f === 'missing') return !s.exists;
  if (f === 'available') return s.exists && s.status === 'available';
  return s.status === f;
};

export const ScootersTab = () => {
  const snapshot = useAdmin(s => s.snapshot)!;
  const busy = useAdmin(s => s.busy);
  const detail = useAdmin(s => s.detail);
  const openDetail = useAdmin(s => s.setDetail);
  const [creating, setCreating] = useState<'self' | 'spawn' | null>(null);
  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState<Filter>('all');
  const [sort, setSort] = useState<Sort>('plate');
  const [selected, setSelected] = useState<Set<number>>(new Set());
  const [bulkBattery, setBulkBattery] = useState(false);
  const [bulkDelete, setBulkDelete] = useState(false);
  const edit = snapshot.canEdit;

  const colourOf = (index: number) => snapshot.colours.find(c => c.index === index) ?? { index, name: '?', hex: '#ffffff' };
  const homeOf = (id: number | null) => (id == null ? t('scooters.free') : (snapshot.bunkers.find(b => b.id === id)?.name ?? `#${id}`));
  const distance = (s: Scooter) => (snapshot.player ? Math.hypot(s.x - snapshot.player.x, s.y - snapshot.player.y) : Infinity);

  const counts = useMemo(() => {
    const out: Record<Filter, number> = { all: 0, available: 0, rented: 0, charging: 0, flat: 0, missing: 0 };
    for (const s of snapshot.scooters) (Object.keys(out) as Filter[]).forEach(f => matchesFilter(s, f) && out[f]++);
    return out;
  }, [snapshot.scooters]);

  const rows = useMemo(() => {
    const q = search.trim().toLowerCase();
    const list = snapshot.scooters.filter(s => {
      if (!matchesFilter(s, filter)) return false;
      if (!q) return true;
      return `${s.plate} ${s.rentedBy ?? ''} ${homeOf(s.bunkerId)}`.toLowerCase().includes(q);
    });
    list.sort((a, b) => (sort === 'battery' ? a.battery - b.battery : sort === 'distance' ? distance(a) - distance(b) : a.plate.localeCompare(b.plate)));
    return list;
  }, [snapshot, search, filter, sort]);

  useEffect(() => {
    setSelected(prev => {
      const visible = new Set(rows.map(r => r.id));
      const next = new Set([...prev].filter(id => visible.has(id)));
      return next.size === prev.size ? prev : next;
    });
  }, [rows]);

  const allChecked = rows.length > 0 && rows.every(r => selected.has(r.id));
  const someChecked = selected.size > 0 && !allChecked;
  const ids = [...selected];

  const toggle = (id: number) =>
    setSelected(prev => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });

  const bulk = async (action: Bulk | 'delete') => {
    const reply = await act<{ done?: number; failed?: number }>('bulkscooters', { action, ids }, `Bulk ${action} on ${ids.length} scooters`);
    if (reply.success) {
      useAdmin.getState().toast(t('scooters.bulk_done', reply.data?.done ?? 0, reply.data?.failed ?? 0), true);
      setSelected(new Set());
    }
  };

  const FILTERS: Filter[] = ['all', 'available', 'rented', 'charging', 'flat', 'missing'];

  return (
    <div className="flex flex-col h-full min-h-0 px-6 py-5 gap-4">
      <Heading title={t('tabs.scooters')} count={snapshot.scooters.length}>
        {edit && (
          <>
            <button type="button" className="sc-btn" disabled={busy || !snapshot.bunkers.some(b => b.enabled)} onClick={() => setCreating('spawn')}>
              <Warehouse size={14} />
              {t('actions.spawn_at_bunker')}
            </button>
            <button type="button" className="sc-btn sc-btn--primary" disabled={busy} onClick={() => setCreating('self')}>
              <Bike size={14} />
              {t('actions.place_scooter')}
            </button>
          </>
        )}
      </Heading>

      <div className="flex items-center gap-2">
        <SearchInput value={search} onChange={setSearch} placeholder={t('common.search')} />
        <div className="sc-segment">
          {FILTERS.map(f => (
            <button key={f} type="button" data-on={filter === f} onClick={() => setFilter(f)}>
              {t(`scooters.filter_${f}`)}
              <span className="mono ml-1.5" style={{ color: 'var(--text-4)' }}>
                {counts[f]}
              </span>
            </button>
          ))}
        </div>
        <Select
          value={sort}
          onChange={setSort}
          width={140}
          ariaLabel={t('scooters.sort')}
          leading={<ArrowDownUp size={13} />}
          options={[
            { value: 'plate' as Sort, label: t('scooters.sort_plate') },
            { value: 'battery' as Sort, label: t('scooters.sort_battery') },
            { value: 'distance' as Sort, label: t('scooters.sort_distance') },
          ]}
        />
      </div>

      {edit && selected.size > 0 && (
        <div className="flex items-center gap-2 px-3 h-11 rounded-[8px] animate-fadeIn" style={{ background: 'var(--surface-3)', border: '1px solid var(--hairline-strong)' }}>
          <span className="text-[12.5px] font-medium pl-1">{t('common.selected', selected.size)}</span>
          <button type="button" className="sc-btn" style={{ height: 28 }} onClick={() => setSelected(new Set())}>
            {t('actions.clear')}
          </button>
          <div className="ml-auto flex items-center gap-1.5">
            {snapshot.battery.enabled && (
              <button type="button" className="sc-btn" style={{ height: 28 }} disabled={busy} onClick={() => setBulkBattery(true)}>
                <BatteryCharging size={14} />
                {t('actions.battery')}
              </button>
            )}
            <button type="button" className="sc-btn" style={{ height: 28 }} disabled={busy} onClick={() => void bulk('lock')}>
              <Lock size={14} />
              {t('actions.lock')}
            </button>
            <button type="button" className="sc-btn" style={{ height: 28 }} disabled={busy} onClick={() => void bulk('unlock')}>
              <Unlock size={14} />
              {t('actions.unlock')}
            </button>
            <button type="button" className="sc-btn" style={{ height: 28 }} disabled={busy} onClick={() => void bulk('sendHome')}>
              <Warehouse size={14} />
              {t('actions.send_home')}
            </button>
            <button type="button" className="sc-btn" style={{ height: 28 }} disabled={busy} onClick={() => void bulk('respawn')}>
              <RotateCcw size={14} />
              {t('actions.respawn')}
            </button>
            <button type="button" className="sc-btn sc-btn--danger" style={{ height: 28 }} disabled={busy} onClick={() => setBulkDelete(true)}>
              <Trash2 size={14} />
              {t('actions.delete')}
            </button>
          </div>
        </div>
      )}

      <div className="flex-1 min-h-0 overflow-y-auto sc-scroll">
        {snapshot.scooters.length === 0 ? (
          <Empty text={t('scooters.empty')} />
        ) : rows.length === 0 ? (
          <Empty text={t('scooters.no_results')} />
        ) : (
          <div className="sc-list">
            {edit && (
              <div className="flex items-center gap-3 px-3.5 h-9" style={{ borderBottom: '1px solid var(--hairline)' }}>
                <input
                  type="checkbox"
                  className="sc-check"
                  checked={allChecked}
                  ref={el => {
                    if (el) el.indeterminate = someChecked;
                  }}
                  onChange={() => setSelected(allChecked ? new Set() : new Set(rows.map(r => r.id)))}
                />
                <span className="text-[11.5px]" style={{ color: 'var(--text-3)' }}>
                  {t('common.of', rows.length, snapshot.scooters.length)}
                </span>
              </div>
            )}
            {rows.map(s => {
              const c = colourOf(s.colour);
              const d = distance(s);
              const active = detail?.kind === 'scooter' && detail.id === s.id;
              return (
                <div key={s.id} className={`sc-row sc-row--click${active ? ' sc-row--active' : ''}`} onClick={() => openDetail({ kind: 'scooter', id: s.id })}>
                  {edit && (
                    <input type="checkbox" className="sc-check" checked={selected.has(s.id)} onClick={e => e.stopPropagation()} onChange={() => toggle(s.id)} />
                  )}
                  <span title={c.name}>
                    <Swatch hex={c.hex} size={12} />
                  </span>
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-3">
                      <span className="text-[13px] font-medium mono">{s.plate}</span>
                      <Status tone={statusTone(s)}>{statusLabel(s)}</Status>
                      {s.locked && <Lock size={12} style={{ color: 'var(--text-4)' }} />}
                    </div>
                    <div className="text-[11.5px] mt-1 truncate" style={{ color: 'var(--text-3)' }}>
                      {s.rentedBy ? t('scooters.rented_by', s.rentedBy) : `${t('scooters.home')}: ${homeOf(s.bunkerId)}`}
                    </div>
                  </div>
                  {snapshot.battery.enabled && <BatteryBar level={s.battery} />}
                  <span className="mono text-[11.5px] w-14 text-right pr-2" style={{ color: 'var(--text-3)' }}>
                    {Number.isFinite(d) ? t('scooters.distance', d.toFixed(0)) : '—'}
                  </span>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {creating && <NewScooterModal mode={creating} onClose={() => setCreating(null)} />}
      {bulkBattery && <BatteryModal ids={ids} current={100} title={t('scooters.bulk_battery_title', ids.length)} onClose={() => setBulkBattery(false)} onDone={() => setSelected(new Set())} />}
      {bulkDelete && (
        <ConfirmDialog
          title={t('scooters.bulk_delete_title', ids.length)}
          body={t('scooters.bulk_delete_body')}
          confirmLabel={t('actions.delete')}
          onClose={() => setBulkDelete(false)}
          onConfirm={async () => {
            await bulk('delete');
            setBulkDelete(false);
          }}
        />
      )}
    </div>
  );
};
