import { useState } from 'react';
import { MapPin, Move, Navigation, Package, Pencil, Power, Trash2 } from 'lucide-react';
import { useAdmin } from '@/store/admin';
import { act, place } from '@/nui/api';
import { t } from '@/i18n';
import { ConfirmDialog, Empty, Heading, Hint, Modal, ModalActions, Status } from '@/components/shared';
import type { Bunker } from '@/types';
import { StockModal } from '../details/modals';

export const PlaceBunkerModal = ({ onClose }: { onClose: () => void }) => {
  const [name, setName] = useState('');
  const ok = name.trim().length >= 1 && name.trim().length <= 48;
  const go = async () => {
    if (!ok) return;
    useAdmin.getState().setBusy(true);
    await place('placebunker', { name: name.trim() });
    onClose();
  };
  return (
    <Modal title={t('actions.place_bunker')} onClose={onClose}>
      <label className="sc-label block mb-1.5">{t('bunkers.name')}</label>
      <input className="sc-input" autoFocus value={name} maxLength={48} onChange={e => setName(e.target.value)} onKeyDown={e => e.key === 'Enter' && void go()} placeholder="Legion Square" />
      <Hint className="mt-2">{t('placing.hint')}</Hint>
      <ModalActions>
        <button type="button" className="sc-btn" onClick={onClose}>
          {t('actions.cancel')}
        </button>
        <button type="button" className="sc-btn sc-btn--primary" disabled={!ok} onClick={() => void go()}>
          {t('actions.place_bunker')}
        </button>
      </ModalActions>
    </Modal>
  );
};

const RenameModal = ({ bunker, onClose }: { bunker: Bunker; onClose: () => void }) => {
  const [name, setName] = useState(bunker.name);
  const ok = name.trim().length >= 1 && name.trim().length <= 48;
  const save = async () => {
    if (!ok) return;
    const reply = await act('renamebunker', { id: bunker.id, name: name.trim() }, `Renamed ${bunker.name} to ${name.trim()}`);
    if (reply.success) onClose();
  };
  return (
    <Modal title={t('bunkers.rename_title')} onClose={onClose}>
      <label className="sc-label block mb-1.5">{t('bunkers.name')}</label>
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

export const BunkersTab = () => {
  const snapshot = useAdmin(s => s.snapshot)!;
  const busy = useAdmin(s => s.busy);
  const [placing, setPlacing] = useState(false);
  const [renaming, setRenaming] = useState<Bunker | null>(null);
  const [deleting, setDeleting] = useState<Bunker | null>(null);
  const [wiping, setWiping] = useState(false);
  const [stocking, setStocking] = useState<Bunker | null>(null);
  const detail = useAdmin(s => s.detail);
  const openDetail = useAdmin(s => s.setDetail);
  const edit = snapshot.canEdit;

  const teleport = (b: Bunker) => void act('teleport', { kind: 'bunker', id: b.id }, `Teleported to ${b.name}`);
  const move = (b: Bunker) => {
    useAdmin.getState().setBusy(true);
    void place('movebunker', { id: b.id });
  };
  const toggle = (b: Bunker) => void act('togglebunker', { id: b.id, enabled: !b.enabled }, `${b.enabled ? 'Disabled' : 'Enabled'} ${b.name}`);

  return (
    <div className="flex flex-col h-full min-h-0 px-6 py-5 gap-4">
      <Heading title={t('tabs.bunkers')} count={snapshot.bunkers.length}>
        {edit && snapshot.bunkers.length > 0 && (
          <button type="button" className="sc-btn sc-btn--danger" disabled={busy} onClick={() => setWiping(true)}>
            <Trash2 size={14} />
            {t('actions.delete_all')}
          </button>
        )}
        {edit && (
          <button type="button" className="sc-btn sc-btn--primary" disabled={busy} onClick={() => setPlacing(true)}>
            <MapPin size={14} />
            {t('actions.place_bunker')}
          </button>
        )}
      </Heading>

      <div className="flex-1 min-h-0 overflow-y-auto sc-scroll">
        {snapshot.bunkers.length === 0 ? (
          <Empty text={t('bunkers.empty')} />
        ) : (
          <div className="sc-list">
            {snapshot.bunkers.map(b => (
              <div key={b.id} className={`sc-row sc-row--click${detail?.kind === 'bunker' && detail.id === b.id ? ' sc-row--active' : ''}`} onClick={() => openDetail({ kind: 'bunker', id: b.id })}>
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-3">
                    <span className="text-[13px] font-medium truncate">{b.name}</span>
                    <Status tone={b.enabled ? 'ok' : 'neutral'}>{b.enabled ? t('bunkers.enabled') : t('bunkers.disabled')}</Status>
                  </div>
                  <div className="text-[11.5px] mono mt-1" style={{ color: 'var(--text-3)' }}>
                    #{b.id} · {b.x.toFixed(1)}, {b.y.toFixed(1)}, {b.z.toFixed(1)} · {b.heading.toFixed(0)}° · {t('bunkers.scooters')} {b.scooters}
                  </div>
                </div>
                <div className="flex flex-col items-end pr-2">
                  <span className="mono text-[13px]" style={{ color: b.stock > 0 ? 'var(--text-1)' : 'var(--danger)' }}>
                    {b.stock}
                  </span>
                  <span className="text-[11px]" style={{ color: 'var(--text-3)' }}>
                    {t('bunkers.stock')}
                  </span>
                </div>
                {edit && (
                <div className="sc-row__actions" onClick={e => e.stopPropagation()}>
                  <button type="button" className="sc-btn sc-btn--icon" title={t('actions.stock')} disabled={busy} onClick={() => setStocking(b)}>
                    <Package size={14} />
                  </button>
                  <button type="button" className="sc-btn sc-btn--icon" title={t('actions.teleport')} disabled={busy} onClick={() => teleport(b)}>
                    <Navigation size={14} />
                  </button>
                  <button type="button" className="sc-btn sc-btn--icon" title={t('actions.rename')} disabled={busy} onClick={() => setRenaming(b)}>
                    <Pencil size={14} />
                  </button>
                  <button type="button" className="sc-btn sc-btn--icon" title={t('actions.move')} disabled={busy} onClick={() => move(b)}>
                    <Move size={14} />
                  </button>
                  <button type="button" className="sc-btn sc-btn--icon" title={b.enabled ? t('actions.disable') : t('actions.enable')} disabled={busy} onClick={() => toggle(b)}>
                    <Power size={14} />
                  </button>
                  <button type="button" className="sc-btn sc-btn--icon sc-btn--danger" title={t('actions.delete')} disabled={busy} onClick={() => setDeleting(b)}>
                    <Trash2 size={14} />
                  </button>
                </div>
                )}
              </div>
            ))}
          </div>
        )}
      </div>

      {wiping && (
        <ConfirmDialog
          title={t('bunkers.delete_all_title')}
          body={t('bunkers.delete_all_body', String(snapshot.bunkers.length))}
          confirmLabel={t('actions.delete_all')}
          onClose={() => setWiping(false)}
          onConfirm={async () => {
            await act('deleteallbunkers', { count: snapshot.bunkers.length }, t('common.deleted', t('tabs.bunkers')));
            setWiping(false);
          }}
        />
      )}
      {placing && <PlaceBunkerModal onClose={() => setPlacing(false)} />}
      {stocking && <StockModal bunker={stocking} onClose={() => setStocking(null)} />}
      {renaming && <RenameModal bunker={renaming} onClose={() => setRenaming(null)} />}
      {deleting && (
        <ConfirmDialog
          title={t('bunkers.delete_title')}
          body={t('bunkers.delete_body', deleting.name)}
          confirmLabel={t('actions.delete')}
          onClose={() => setDeleting(null)}
          onConfirm={async () => {
            await act('deletebunker', { id: deleting.id }, t('common.deleted', deleting.name));
            setDeleting(null);
          }}
        />
      )}
    </div>
  );
};
