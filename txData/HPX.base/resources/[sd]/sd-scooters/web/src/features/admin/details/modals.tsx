import { useState } from 'react';
import type { CSSProperties } from 'react';
import { act } from '@/nui/api';
import { t } from '@/i18n';
import { Hint, Modal, ModalActions, Stepper } from '@/components/shared';
import type { Bunker } from '@/types';

export const BatteryModal = ({ ids, current, title, onClose, onDone }: { ids: number[]; current: number; title: string; onClose: () => void; onDone?: () => void }) => {
  const [level, setLevel] = useState(Math.round(current));
  const save = async () => {
    const reply =
      ids.length === 1
        ? await act('setscooterbattery', { id: ids[0], level }, `Set battery to ${level}%`)
        : await act<{ done?: number; failed?: number }>('bulkscooters', { action: 'battery', ids, level }, `Set battery to ${level}% on ${ids.length} scooters`);
    if (reply.success) {
      onDone?.();
      onClose();
    }
  };
  return (
    <Modal title={title} onClose={onClose} width={380}>
      <div className="flex items-baseline justify-between mb-3">
        <span className="sc-label">{t('scooters.battery')}</span>
        <span className="mono text-[20px] font-semibold">{level}%</span>
      </div>
      <input
        type="range"
        className="sc-range w-full"
        min={0}
        max={100}
        step={1}
        value={level}
        style={{ '--fill': `${level}%` } as CSSProperties}
        onChange={e => setLevel(Number(e.target.value))}
      />
      <div className="flex gap-1.5 mt-4">
        {[0, 25, 50, 75, 100].map(n => (
          <button key={n} type="button" className={`sc-btn flex-1${level === n ? ' sc-btn--on' : ''}`} onClick={() => setLevel(n)}>
            {n}%
          </button>
        ))}
      </div>
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

export const StockModal = ({ bunker, onClose }: { bunker: Bunker; onClose: () => void }) => {
  const [stock, setStock] = useState(bunker.stock ?? 0);
  const save = async () => {
    if (stock === bunker.stock) return onClose();
    const reply = await act('setbunkerstock', { id: bunker.id, stock }, `Set ${bunker.name} stock to ${stock}`);
    if (reply.success) onClose();
  };
  return (
    <Modal title={t('bunkers.stock_title')} onClose={onClose} width={380}>
      <div className="flex items-center justify-between gap-4">
        <span className="text-[13px] font-medium truncate">{bunker.name}</span>
        <Stepper value={stock} onChange={setStock} min={0} max={999} />
      </div>
      <Hint className="mt-3">{t('bunkers.stock_body')}</Hint>
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
