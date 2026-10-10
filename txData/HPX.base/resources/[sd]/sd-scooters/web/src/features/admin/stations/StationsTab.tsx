import { useState } from 'react';
import { Move, Navigation, Palette, Pencil, Power, Rows3, Trash2, Zap } from 'lucide-react';
import { useAdmin } from '@/store/admin';
import { act, place } from '@/nui/api';
import { t } from '@/i18n';
import { ConfirmDialog, Empty, Heading, Hint, Modal, ModalActions, Status, Swatch } from '@/components/shared';
import type { Station } from '@/types';
import { StationPreview3D } from './StationPreview3D';

const MAX_DOCKS = 4;

const ColourPicker = ({ value, onChange }: { value: number; onChange: (n: number) => void }) => {
  const palette = useAdmin(s => s.snapshot?.stationColours) ?? [];
  return (
    <div className="flex flex-wrap gap-2.5">
      {palette.map(c => (
        <button key={c.index} type="button" title={c.name} onClick={() => onChange(c.index)} className="p-0.5 rounded-full" style={{ background: 'none', border: 'none' }}>
          <Swatch hex={c.hex} size={22} active={c.index === value} />
        </button>
      ))}
    </div>
  );
};

const colourOf = (palette: { index: number; hex: string; name: string }[], index: number) => palette.find(c => c.index === index);

const DockPicker = ({ value, onChange, min = 1 }: { value: number; onChange: (n: number) => void; min?: number }) => (
  <div className="sc-segment w-full">
    {Array.from({ length: MAX_DOCKS }, (_, i) => i + 1).map(n => (
      <button key={n} type="button" data-on={n === value} disabled={n < min} onClick={() => onChange(n)} className="flex-1 mono" style={{ opacity: n < min ? 0.35 : 1 }}>
        {n}
      </button>
    ))}
  </div>
);

export const PlaceStationModal = ({ onClose }: { onClose: () => void }) => {
  const [name, setName] = useState('');
  const [count, setCount] = useState(MAX_DOCKS);
  const [colour, setColour] = useState(1);
  const ok = name.trim().length >= 1 && name.trim().length <= 48;
  const palette = useAdmin(s => s.snapshot?.stationColours) ?? [];
  const hex = colourOf(palette, colour)?.hex ?? '#0a949a';
  const go = async () => {
    if (!ok) return;
    useAdmin.getState().setBusy(true);
    await place('placestation', { name: name.trim(), count, colour });
    onClose();
  };
  return (
    <Modal title={t('actions.place_station')} onClose={onClose}>
      <StationPreview3D count={count} hex={hex} />
      <label className="sc-label block mt-4 mb-1.5">{t('stations.name')}</label>
      <input className="sc-input" autoFocus value={name} maxLength={48} onChange={e => setName(e.target.value)} onKeyDown={e => e.key === 'Enter' && void go()} placeholder="Vespucci Beach" />
      <label className="sc-label block mt-4 mb-1.5">{t('stations.docks')}</label>
      <DockPicker value={count} onChange={setCount} />
      <Hint className="mt-1.5">{t('stations.docks_hint')}</Hint>
      <label className="sc-label block mt-4 mb-2">{t('stations.colour')}</label>
      <ColourPicker value={colour} onChange={setColour} />
      <Hint className="mt-4">{t('placing.hint')}</Hint>
      <ModalActions>
        <button type="button" className="sc-btn" onClick={onClose}>
          {t('actions.cancel')}
        </button>
        <button type="button" className="sc-btn sc-btn--primary" disabled={!ok} onClick={() => void go()}>
          {t('actions.place_station')}
        </button>
      </ModalActions>
    </Modal>
  );
};

const RenameModal = ({ station, onClose }: { station: Station; onClose: () => void }) => {
  const [name, setName] = useState(station.name);
  const ok = name.trim().length >= 1 && name.trim().length <= 48;
  const save = async () => {
    if (!ok) return;
    const reply = await act('renamestation', { id: station.id, name: name.trim() }, `Renamed ${station.name} to ${name.trim()}`);
    if (reply.success) onClose();
  };
  return (
    <Modal title={t('stations.rename_title')} onClose={onClose}>
      <label className="sc-label block mb-1.5">{t('stations.name')}</label>
      <input className="sc-input" autoFocus value={name} maxLength={48} onChange={e => setName(e.target.value)} onKeyDown={e => e.key === 'Enter' && void save()} />
      <ModalActions>
        <button type="button" className="sc-btn" onClick={onClose}>
          {t('actions.cancel')}
        </button>
        <button type="button" className="sc-btn sc-btn--primary" disabled={!ok} onClick={() => void save()}>
          {t('actions.save')}
        </button>
      </ModalActions>
    </Modal>
  );
};

const DocksModal = ({ station, onClose }: { station: Station; onClose: () => void }) => {
  const [count, setCount] = useState(station.count);
  const highestUsed = station.slots.reduce((top, slot, i) => (slot ? i + 1 : top), 0);
  const save = async () => {
    if (count === station.count) return onClose();
    const reply = await act('setstationslots', { id: station.id, count }, `${station.name} now has ${count} dock${count === 1 ? '' : 's'}`);
    if (reply.success) onClose();
  };
  return (
    <Modal title={t('stations.docks_title')} onClose={onClose}>
      <label className="sc-label block mb-1.5">{t('stations.docks')}</label>
      <DockPicker value={count} onChange={setCount} min={Math.max(1, highestUsed)} />
      <Hint className="mt-1.5">{t('stations.docks_body')}</Hint>
      <ModalActions>
        <button type="button" className="sc-btn" onClick={onClose}>
          {t('actions.cancel')}
        </button>
        <button type="button" className="sc-btn sc-btn--primary" onClick={() => void save()}>
          {t('actions.save')}
        </button>
      </ModalActions>
    </Modal>
  );
};

const ColourModal = ({ station, onClose }: { station: Station; onClose: () => void }) => {
  const [colour, setColour] = useState(station.colour);
  const palette = useAdmin(s => s.snapshot?.stationColours) ?? [];
  const save = async () => {
    if (colour === station.colour) return onClose();
    const name = colourOf(palette, colour)?.name ?? '';
    const reply = await act('setstationcolour', { id: station.id, colour }, `Painted ${station.name} ${name.toLowerCase()}`);
    if (reply.success) onClose();
  };
  return (
    <Modal title={t('stations.colour_title')} onClose={onClose}>
      <ColourPicker value={colour} onChange={setColour} />
      <Hint className="mt-4">{t('stations.colour_body')}</Hint>
      <ModalActions>
        <button type="button" className="sc-btn" onClick={onClose}>
          {t('actions.cancel')}
        </button>
        <button type="button" className="sc-btn sc-btn--primary" onClick={() => void save()}>
          {t('actions.save')}
        </button>
      </ModalActions>
    </Modal>
  );
};

export const SlotStrip = ({ station }: { station: Station }) => (
  <span className="inline-flex items-center gap-[3px]" title={`${station.occupied}/${station.slots.length}`}>
    {station.slots.map((slot, i) => (
      <span key={i} className="w-[5px] h-3 rounded-[1.5px]" style={{ backgroundColor: !slot ? 'rgba(255,255,255,0.1)' : slot.full ? 'var(--ok)' : 'var(--warn)' }} />
    ))}
  </span>
);

export const StationsTab = () => {
  const snapshot = useAdmin(s => s.snapshot)!;
  const busy = useAdmin(s => s.busy);
  const [placing, setPlacing] = useState(false);
  const [wiping, setWiping] = useState(false);
  const [renaming, setRenaming] = useState<Station | null>(null);
  const [docks, setDocks] = useState<Station | null>(null);
  const [painting, setPainting] = useState<Station | null>(null);
  const [deleting, setDeleting] = useState<Station | null>(null);
  const detail = useAdmin(s => s.detail);
  const openDetail = useAdmin(s => s.setDetail);
  const edit = snapshot.canEdit;

  const teleport = (st: Station) => void act('teleport', { kind: 'station', id: st.id }, `Teleported to ${st.name}`);
  const move = (st: Station) => {
    useAdmin.getState().setBusy(true);
    void place('movestation', { id: st.id });
  };
  const toggle = (st: Station) => void act('togglestation', { id: st.id, enabled: !st.enabled }, `${st.enabled ? 'Disabled' : 'Enabled'} ${st.name}`);

  return (
    <div className="flex flex-col h-full min-h-0 px-6 py-5 gap-4">
      <Heading title={t('tabs.stations')} count={snapshot.stations.length}>
        {edit && snapshot.stations.length > 0 && (
          <button type="button" className="sc-btn sc-btn--danger" disabled={busy} onClick={() => setWiping(true)}>
            <Trash2 size={14} />
            {t('actions.delete_all')}
          </button>
        )}
        {edit && (
          <button type="button" className="sc-btn sc-btn--primary" disabled={busy} onClick={() => setPlacing(true)}>
            <Zap size={14} />
            {t('actions.place_station')}
          </button>
        )}
      </Heading>

      <div className="flex-1 min-h-0 overflow-y-auto sc-scroll">
        {snapshot.stations.length === 0 ? (
          <Empty text={t('stations.empty')} />
        ) : (
          <div className="sc-list">
            {snapshot.stations.map(st => {
              const paint = colourOf(snapshot.stationColours, st.colour);
              return (
                <div key={st.id} className={`sc-row sc-row--click${detail?.kind === 'station' && detail.id === st.id ? ' sc-row--active' : ''}`} onClick={() => openDetail({ kind: 'station', id: st.id })}>
                  <span title={paint?.name}>
                    <Swatch hex={paint?.hex ?? '#0a949a'} size={12} />
                  </span>
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-3">
                      <span className="text-[13px] font-medium truncate">{st.name}</span>
                      <Status tone={st.enabled ? 'ok' : 'neutral'}>{st.enabled ? t('bunkers.enabled') : t('bunkers.disabled')}</Status>
                    </div>
                    <div className="text-[11.5px] mono mt-1" style={{ color: 'var(--text-3)' }}>
                      #{st.id} · {st.x.toFixed(1)}, {st.y.toFixed(1)}, {st.z.toFixed(1)} · {st.heading.toFixed(0)}°
                    </div>
                  </div>
                  <div className="flex items-center gap-2.5 pr-2">
                    <SlotStrip station={st} />
                    <span className="mono text-[11.5px] w-7 text-right" style={{ color: 'var(--text-2)' }}>
                      {st.occupied}/{st.slots.length}
                    </span>
                  </div>
                  {edit && (
                  <div className="sc-row__actions" onClick={e => e.stopPropagation()}>
                    <button type="button" className="sc-btn sc-btn--icon" title={t('actions.teleport')} disabled={busy} onClick={() => teleport(st)}>
                      <Navigation size={14} />
                    </button>
                    <button type="button" className="sc-btn sc-btn--icon" title={t('actions.rename')} disabled={busy} onClick={() => setRenaming(st)}>
                      <Pencil size={14} />
                    </button>
                    <button type="button" className="sc-btn sc-btn--icon" title={t('actions.move')} disabled={busy} onClick={() => move(st)}>
                      <Move size={14} />
                    </button>
                    <button type="button" className="sc-btn sc-btn--icon" title={t('actions.docks')} disabled={busy} onClick={() => setDocks(st)}>
                      <Rows3 size={14} />
                    </button>
                    <button type="button" className="sc-btn sc-btn--icon" title={t('actions.colour')} disabled={busy} onClick={() => setPainting(st)}>
                      <Palette size={14} />
                    </button>
                    <button type="button" className="sc-btn sc-btn--icon" title={st.enabled ? t('actions.disable') : t('actions.enable')} disabled={busy} onClick={() => toggle(st)}>
                      <Power size={14} />
                    </button>
                    <button type="button" className="sc-btn sc-btn--icon sc-btn--danger" title={t('actions.delete')} disabled={busy} onClick={() => setDeleting(st)}>
                      <Trash2 size={14} />
                    </button>
                  </div>
                  )}
                </div>
              );
            })}
          </div>
        )}
      </div>

      {wiping && (
        <ConfirmDialog
          title={t('stations.delete_all_title')}
          body={t('stations.delete_all_body', String(snapshot.stations.length))}
          confirmLabel={t('actions.delete_all')}
          onClose={() => setWiping(false)}
          onConfirm={async () => {
            await act('deleteallstations', { count: snapshot.stations.length }, t('common.deleted', t('tabs.stations')));
            setWiping(false);
          }}
        />
      )}
      {placing && <PlaceStationModal onClose={() => setPlacing(false)} />}
      {renaming && <RenameModal station={renaming} onClose={() => setRenaming(null)} />}
      {docks && <DocksModal station={docks} onClose={() => setDocks(null)} />}
      {painting && <ColourModal station={painting} onClose={() => setPainting(null)} />}
      {deleting && (
        <ConfirmDialog
          title={t('stations.delete_title')}
          body={t('stations.delete_body', deleting.name)}
          confirmLabel={t('actions.delete')}
          onClose={() => setDeleting(null)}
          onConfirm={async () => {
            await act('deletestation', { id: deleting.id }, t('common.deleted', deleting.name));
            setDeleting(null);
          }}
        />
      )}
    </div>
  );
};
