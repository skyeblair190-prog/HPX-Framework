import { useEffect, useMemo, useState } from 'react';
import { ChevronRight, Copy, FileCode, History, Pencil, Play, Plus, Radio, Search, Trash2, Undo2, X } from 'lucide-react';
import { useAdmin } from '@/store/admin';
import { BASELINE_ID, useHandling } from '@/store/handling';
import { t } from '@/i18n';
import { ConfirmDialog, Empty, Hint, Modal, ModalActions, Status } from '@/components/shared';
import type { HandlingBundle, HandlingField, HandlingHistoryEntry, HandlingValue, HandlingValues } from '@/types';
import { FieldRow } from './FieldRow';
import { PresetDials } from './PresetDials';
import { copyText, handlingAct, loadHandling, schedulePreview, startTestRide } from './api';
import { Select } from '@/components/Select';
import { allFields, dirtyFields, estimateTopMph, format, fromMph, same } from './model';

const ago = (at: number): string => {
  const s = Math.max(0, Math.floor(Date.now() / 1000 - at));
  if (s < 60) return `${s}s ago`;
  if (s < 3600) return `${Math.floor(s / 60)}m ago`;
  if (s < 86400) return `${Math.floor(s / 3600)}h ago`;
  return `${Math.floor(s / 86400)}d ago`;
};

const NewProfileModal = ({ bundle, onClose }: { bundle: HandlingBundle; onClose: () => void }) => {
  const [name, setName] = useState('');
  const [from, setFrom] = useState('defaults');
  const ok = name.trim().length >= 1 && name.trim().length <= 48;
  const create = async () => {
    if (!ok) return;
    const [kind, ref] = from.split(':');
    const payload: Record<string, unknown> = { name: name.trim(), from: kind };
    if (kind === 'template') payload.index = Number(ref);
    if (kind === 'profile') payload.id = Number(ref);
    const reply = await handlingAct('handlingcreate', payload);
    if (reply.success) {
      useAdmin.getState().record(`Created handling profile ${name.trim()}`, true);
      onClose();
    }
  };
  return (
    <Modal title={t('handling.new_profile')} onClose={onClose}>
      <label className="sc-label block mb-1.5">{t('handling.name')}</label>
      <input className="sc-input" autoFocus value={name} maxLength={48} onChange={e => setName(e.target.value)} onKeyDown={e => e.key === 'Enter' && void create()} placeholder="Summer event" />
      <label className="sc-label block mt-4 mb-1.5">{t('handling.new_from')}</label>
      <Select
        value={from}
        onChange={setFrom}
        options={[
          { value: 'defaults', label: t('handling.from_defaults') },
          ...bundle.templates.map((tpl, i) => ({ value: `template:${i + 1}`, label: tpl.name, group: t('handling.group_templates') })),
          ...bundle.profiles.map(p => ({ value: `profile:${p.id}`, label: p.name, group: t('handling.group_profiles') })),
        ]}
      />
      <ModalActions>
        <button type="button" className="sc-btn" onClick={onClose}>
          {t('actions.cancel')}
        </button>
        <button type="button" className="sc-btn sc-btn--primary" disabled={!ok} onClick={() => void create()}>
          {t('handling.new_profile')}
        </button>
      </ModalActions>
    </Modal>
  );
};

const RenameModal = ({ id, current, onClose }: { id: number; current: string; onClose: () => void }) => {
  const [name, setName] = useState(current);
  const ok = name.trim().length >= 1 && name.trim().length <= 48;
  const save = async () => {
    if (!ok) return;
    const reply = await handlingAct('handlingrename', { id, name: name.trim() });
    if (reply.success) onClose();
  };
  return (
    <Modal title={t('handling.rename')} onClose={onClose}>
      <label className="sc-label block mb-1.5">{t('handling.name')}</label>
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

const ExportModal = ({ values, onClose }: { values: HandlingValues; onClose: () => void }) => {
  const [text, setText] = useState('');
  useEffect(() => {
    void handlingAct('handlingexport', { values }).then(reply => setText(reply.data?.text ?? ''));
  }, [values]);
  return (
    <Modal title={t('handling.export_title')} onClose={onClose} width={660}>
      <Hint className="mb-3">{t('handling.export_body')}</Hint>
      <textarea readOnly className="sc-input mono sc-scroll" style={{ height: 340, fontSize: 11.5, lineHeight: 1.5, resize: 'none', userSelect: 'text', color: 'var(--text-2)' }} value={text} />
      <ModalActions>
        <button type="button" className="sc-btn" onClick={onClose}>
          {t('actions.close')}
        </button>
        <button
          type="button"
          className="sc-btn sc-btn--primary"
          disabled={!text}
          onClick={() => {
            const done = copyText(text);
            useAdmin.getState().toast(done ? t('handling.copied') : t('toast.failed'), done);
          }}
        >
          <Copy size={14} />
          {t('handling.copy')}
        </button>
      </ModalActions>
    </Modal>
  );
};

const HistoryDrawer = ({ entries, fields, dirty, onClose }: { entries: HandlingHistoryEntry[]; fields: Map<string, HandlingField>; dirty: boolean; onClose: () => void }) => {
  const busy = useAdmin(s => s.busy);
  const show = (name: string, v: HandlingValue | false) => {
    if (v === false) return t('handling.baseline');
    const f = fields.get(name);
    return f ? format(f, v) : String(v);
  };
  return (
    <div className="absolute inset-y-0 right-0 z-30 w-[360px] flex flex-col animate-drawerIn" style={{ backgroundColor: 'var(--surface)', borderLeft: '1px solid var(--hairline-strong)', boxShadow: '-24px 0 48px rgba(0,0,0,0.35)' }}>
      <div className="flex items-center gap-2 pl-5 pr-3 h-12 flex-shrink-0" style={{ borderBottom: '1px solid var(--hairline)' }}>
        <span className="text-[13px] font-semibold">{t('handling.history')}</span>
        <button type="button" className="sc-btn sc-btn--icon ml-auto" onClick={onClose} aria-label={t('actions.close')}>
          <X size={15} />
        </button>
      </div>
      <div className="flex-1 min-h-0 overflow-y-auto sc-scroll">
        {entries.length === 0 && <Empty text={t('handling.history_empty')} />}
        {entries.map(entry => {
          const names = Object.keys(entry.changes);
          return (
            <div key={entry.id} className="px-5 py-3.5" style={{ borderBottom: '1px solid var(--hairline)' }}>
              <div className="flex items-center gap-2">
                <span className="text-[12.5px] font-medium truncate">{entry.actor}</span>
                <span className="text-[11.5px]" style={{ color: 'var(--text-3)' }}>
                  {ago(entry.at)}
                </span>
                <button type="button" className="sc-btn ml-auto" style={{ height: 26 }} disabled={busy || dirty} title={dirty ? t('handling.unsaved', 1) : undefined} onClick={() => void handlingAct('handlingundo', { logId: entry.id })}>
                  <Undo2 size={13} />
                  {t('handling.undo')}
                </button>
              </div>
              <div className="mt-2 space-y-1">
                {names.slice(0, 5).map(name => (
                  <div key={name} className="text-[12px] flex items-center gap-2 min-w-0">
                    <span className="truncate" style={{ color: 'var(--text-2)' }}>
                      {t(`handling.fields.${name}.label`)}
                    </span>
                    <span className="mono ml-auto flex-shrink-0 text-[11.5px]" style={{ color: 'var(--text-3)' }}>
                      {show(name, entry.changes[name][0])} → <span style={{ color: 'var(--text-1)' }}>{show(name, entry.changes[name][1])}</span>
                    </span>
                  </div>
                ))}
                {names.length > 5 && (
                  <div className="text-[11.5px]" style={{ color: 'var(--text-3)' }}>
                    {t('handling.more', names.length - 5)}
                  </div>
                )}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
};

export const HandlingTab = () => {
  const busy = useAdmin(s => s.busy);
  const bundle = useHandling(s => s.bundle);
  const selectedId = useHandling(s => s.selectedId);
  const saved = useHandling(s => s.saved);
  const draft = useHandling(s => s.draft);
  const onScooter = useHandling(s => s.onScooter);
  const lastRun = useHandling(s => s.lastRun);
  const search = useHandling(s => s.search);
  const changedOnly = useHandling(s => s.changedOnly);
  const collapsed = useHandling(s => s.collapsed);
  const [creating, setCreating] = useState(false);
  const [renaming, setRenaming] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [exporting, setExporting] = useState(false);
  const [historyOpen, setHistoryOpen] = useState(false);
  const [switchTo, setSwitchTo] = useState<number | null>(null);

  useEffect(() => {
    void loadHandling();
  }, []);

  const dirty = useMemo(() => (bundle ? dirtyFields(bundle, draft, saved) : []), [bundle, draft, saved]);

  useEffect(() => {
    if (!bundle) return;
    schedulePreview(dirty.length > 0 ? draft : null);
  }, [bundle, draft, dirty.length]);

  const fieldMap = useMemo(() => new Map(bundle ? allFields(bundle).map(f => [f.name, f]) : []), [bundle]);

  if (!bundle) return <Empty text="" />;

  const profile = bundle.profiles.find(p => p.id === selectedId) ?? null;
  const readOnly = selectedId === BASELINE_ID;
  const isLive = selectedId === bundle.activeId;
  const store = useHandling.getState();
  const unitLabel = bundle.unit === 'mph' ? 'mph' : 'km/h';
  const defaults = Object.fromEntries(allFields(bundle).map(f => [f.name, f.default])) as HandlingValues;

  const pick = (id: number) => {
    if (id === selectedId) return;
    if (dirty.length > 0) setSwitchTo(id);
    else store.select(id);
  };

  const save = async () => {
    if (!profile || dirty.length === 0) return;
    const reply = await handlingAct('handlingsave', { id: profile.id, values: draft }, profile.id);
    if (reply.success) {
      const n = reply.data?.changed ?? 0;
      useAdmin.getState().toast(n > 0 ? t('handling.saved', n) : t('handling.nothing_changed'), true);
      useAdmin.getState().record(`Saved handling profile ${profile.name}`, true);
    }
  };

  const query = search.trim().toLowerCase();
  const matches = (f: HandlingField) => {
    if (changedOnly && same(draft[f.name], f.default) && same(draft[f.name], saved[f.name])) return false;
    if (!query) return true;
    return f.name.toLowerCase().includes(query) || t(`handling.fields.${f.name}.label`).toLowerCase().includes(query);
  };

  const entries = [{ id: BASELINE_ID, name: t('handling.baseline'), values: {} as HandlingValues }, ...bundle.profiles];

  return (
    <div className="relative flex h-full min-h-0">
      <aside className="w-[240px] flex-shrink-0 flex flex-col min-h-0" style={{ borderRight: '1px solid var(--hairline)' }}>
        <div className="flex items-center gap-2 pl-5 pr-3 h-12 flex-shrink-0">
          <span className="sc-heading">
            {t('handling.profiles')}
            <span className="sc-heading__count">{bundle.profiles.length}</span>
          </span>
          <button type="button" className="sc-btn sc-btn--icon ml-auto" title={t('handling.new_profile')} disabled={busy} onClick={() => setCreating(true)}>
            <Plus size={15} />
          </button>
        </div>
        <div className="flex-1 min-h-0 overflow-y-auto sc-scroll px-2.5 pb-2 space-y-0.5">
          {entries.map(p => {
            const active = p.id === selectedId;
            const live = p.id === bundle.activeId;
            const baseline = p.id === BASELINE_ID;
            const top = Math.round(fromMph(estimateTopMph(bundle, { ...defaults, ...p.values }), bundle.unit));
            return (
              <button
                key={p.id}
                type="button"
                onClick={() => pick(p.id)}
                className="w-full text-left px-2.5 py-2 rounded-[7px] transition-colors"
                style={{ backgroundColor: active ? 'var(--surface-3)' : 'transparent', border: 'none' }}
                onMouseEnter={e => {
                  if (!active) e.currentTarget.style.backgroundColor = 'var(--surface-2)';
                }}
                onMouseLeave={e => {
                  if (!active) e.currentTarget.style.backgroundColor = 'transparent';
                }}
              >
                <div className="flex items-center gap-2">
                  <span className={`text-[12.5px] font-medium truncate ${baseline ? 'mono' : ''}`} style={{ color: active ? 'var(--text-1)' : 'var(--text-2)' }}>
                    {p.name}
                  </span>
                  {live && (
                    <span className="ml-auto flex-shrink-0">
                      <Status tone="ok">{t('handling.live')}</Status>
                    </span>
                  )}
                </div>
                <div className="text-[11.5px] mt-0.5" style={{ color: 'var(--text-3)' }}>
                  {baseline ? t('handling.baseline_hint') : `${top} ${unitLabel} ${t('handling.estimate')}`}
                </div>
              </button>
            );
          })}
        </div>

        <div className="px-5 py-4 flex-shrink-0" style={{ borderTop: '1px solid var(--hairline)' }}>
          <div className="sc-label mb-2.5">{t('handling.last_run')}</div>
          {lastRun ? (
            <div className="grid grid-cols-2 gap-3">
              <div>
                <div className="text-[11.5px]" style={{ color: 'var(--text-3)' }}>
                  {t('handling.top_speed')}
                </div>
                <div className="mono text-[17px] font-semibold mt-0.5">
                  {lastRun.top.toFixed(1)}
                  <span className="text-[11px] font-normal ml-1" style={{ color: 'var(--text-3)' }}>
                    {unitLabel}
                  </span>
                </div>
              </div>
              <div>
                <div className="text-[11.5px]" style={{ color: 'var(--text-3)' }}>
                  {t('handling.launch', bundle.unit === 'mph' ? '30' : '50')}
                </div>
                <div className="mono text-[17px] font-semibold mt-0.5">{lastRun.launch != null ? `${lastRun.launch.toFixed(1)}s` : '—'}</div>
              </div>
            </div>
          ) : (
            <Hint>{t('handling.no_run')}</Hint>
          )}
        </div>
      </aside>

      <div className="flex-1 min-w-0 flex flex-col min-h-0">
        <div className="flex items-center gap-3 pl-6 pr-4 h-[60px] flex-shrink-0" style={{ borderBottom: '1px solid var(--hairline)' }}>
          <div className="min-w-0">
            <div className="flex items-center gap-2.5">
              <span className={`text-[14px] font-semibold truncate ${readOnly ? 'mono' : ''}`}>{profile ? profile.name : t('handling.baseline')}</span>
              {isLive && <Status tone="ok">{t('handling.live')}</Status>}
              {profile && (
                <>
                  <button type="button" className="sc-btn sc-btn--icon" style={{ width: 24, height: 24 }} title={t('handling.rename')} disabled={busy} onClick={() => setRenaming(true)}>
                    <Pencil size={13} />
                  </button>
                  <button type="button" className="sc-btn sc-btn--icon sc-btn--danger" style={{ width: 24, height: 24, marginLeft: -6 }} title={t('handling.delete_title')} disabled={busy} onClick={() => setDeleting(true)}>
                    <Trash2 size={13} />
                  </button>
                </>
              )}
            </div>
            <div className="text-[12px] mt-0.5 truncate" style={{ color: 'var(--text-3)' }}>
              {readOnly ? t('handling.baseline_readonly') : isLive ? t('handling.live_warning') : t('handling.not_live')}
            </div>
          </div>
          <div className="ml-auto flex items-center gap-2 flex-shrink-0">
            <button type="button" className={`sc-btn sc-btn--icon${historyOpen ? ' sc-btn--on' : ''}`} onClick={() => setHistoryOpen(v => !v)} disabled={!profile} title={t('handling.history')}>
              <History size={15} />
            </button>
            <button type="button" className="sc-btn sc-btn--icon" title={t('handling.export_title')} onClick={() => setExporting(true)}>
              <FileCode size={15} />
            </button>
            {!isLive && (
              <button type="button" className="sc-btn" disabled={busy || dirty.length > 0} onClick={() => void handlingAct('handlingactivate', { id: selectedId })}>
                <Radio size={14} />
                {readOnly ? t('handling.use_baseline') : t('handling.make_live')}
              </button>
            )}
            <button type="button" className="sc-btn" disabled={busy} onClick={() => void startTestRide(draft)}>
              <Play size={14} />
              {t('handling.test_ride')}
            </button>
          </div>
        </div>

        <div className="flex-1 min-h-0 overflow-y-auto sc-scroll px-6 py-5 space-y-6">
          <section>
            <div className="flex items-baseline gap-3 mb-1">
              <span className="sc-heading">{t('handling.presets')}</span>
              <span className="ml-auto text-[11.5px] flex items-center gap-1.5" style={{ color: 'var(--text-3)' }}>
                <span className="w-1.5 h-1.5 rounded-full" style={{ backgroundColor: onScooter ? 'var(--ok)' : 'var(--text-4)' }} />
                {onScooter ? t('handling.previewing') : t('handling.not_previewing')}
              </span>
            </div>
            <Hint className="mb-4">{t('handling.presets_hint')}</Hint>
            <div className="sc-card px-5 py-4">
              <PresetDials bundle={bundle} values={draft} disabled={readOnly} onChange={next => store.setDraft(next)} />
            </div>
          </section>

          <section className="space-y-3">
            <div className="flex items-center gap-2">
              <div className="relative flex-1">
                <Search size={14} className="absolute left-2.5 top-1/2 -translate-y-1/2" style={{ color: 'var(--text-3)' }} />
                <input className="sc-input" style={{ paddingLeft: 30 }} value={search} placeholder={t('handling.search')} onChange={e => store.setSearch(e.target.value)} />
              </div>
              <button type="button" className={`sc-btn${changedOnly ? ' sc-btn--on' : ''}`} style={{ height: 32 }} onClick={() => store.setChangedOnly(!changedOnly)}>
                {t('handling.changed_only')}
              </button>
            </div>

            {bundle.groups.map(group => {
              const visible = group.fields.filter(matches);
              if (visible.length === 0) return null;
              const open = !collapsed[group.id] || query.length > 0;
              const changed = group.fields.filter(f => !same(draft[f.name], f.default)).length;
              return (
                <div key={group.id} className="sc-card overflow-hidden">
                  <button type="button" className="w-full flex items-center gap-2 px-4 h-11" style={{ background: 'none', border: 'none', color: 'var(--text-1)' }} onClick={() => store.toggleGroup(group.id)}>
                    <ChevronRight size={14} style={{ color: 'var(--text-3)', transform: open ? 'rotate(90deg)' : 'none', transition: 'transform 0.15s' }} />
                    <span className="text-[13px] font-medium">{t(`handling.groups.${group.id}`)}</span>
                    <span className="mono text-[12px]" style={{ color: 'var(--text-3)' }}>
                      {visible.length}
                    </span>
                    {changed > 0 && (
                      <span className="ml-auto text-[11.5px]" style={{ color: 'var(--text-3)' }}>
                        {changed} {t('handling.changed_from_file')}
                      </span>
                    )}
                  </button>
                  {open && (
                    <div style={{ borderTop: '1px solid var(--hairline)' }}>
                      {visible.map(f => (
                        <FieldRow key={f.name} field={f} value={draft[f.name]} saved={saved[f.name]} disabled={readOnly} onChange={store.setField} />
                      ))}
                    </div>
                  )}
                </div>
              );
            })}
          </section>
        </div>

        {!readOnly && (
          <div className="flex items-center gap-2 pl-6 pr-4 h-14 flex-shrink-0" style={{ borderTop: '1px solid var(--hairline)' }}>
            <span className="text-[12px] flex items-center gap-2" style={{ color: dirty.length ? 'var(--text-2)' : 'var(--text-3)' }}>
              {dirty.length > 0 && <span className="w-1.5 h-1.5 rounded-full" style={{ backgroundColor: 'var(--warn)' }} />}
              {dirty.length ? t('handling.unsaved', dirty.length) : t('handling.nothing_changed')}
            </span>
            <button type="button" className="sc-btn ml-auto" disabled={busy || dirty.length === 0} onClick={() => store.discard()}>
              {t('handling.discard')}
            </button>
            <button type="button" className="sc-btn sc-btn--primary" disabled={busy || dirty.length === 0} onClick={() => void save()}>
              {isLive ? t('handling.save_live') : t('handling.save')}
            </button>
          </div>
        )}
      </div>

      {historyOpen && profile && <HistoryDrawer entries={bundle.history.filter(h => h.profileId === profile.id)} fields={fieldMap} dirty={dirty.length > 0} onClose={() => setHistoryOpen(false)} />}
      {creating && <NewProfileModal bundle={bundle} onClose={() => setCreating(false)} />}
      {renaming && profile && <RenameModal id={profile.id} current={profile.name} onClose={() => setRenaming(false)} />}
      {exporting && <ExportModal values={draft} onClose={() => setExporting(false)} />}
      {deleting && profile && (
        <ConfirmDialog
          title={t('handling.delete_title')}
          body={t('handling.delete_body', profile.name)}
          confirmLabel={t('actions.delete')}
          onClose={() => setDeleting(false)}
          onConfirm={async () => {
            const reply = await handlingAct('handlingdelete', { id: profile.id }, BASELINE_ID);
            if (reply.success) useAdmin.getState().record(`Deleted handling profile ${profile.name}`, true);
            setDeleting(false);
          }}
        />
      )}
      {switchTo !== null && (
        <ConfirmDialog
          title={t('handling.discard')}
          body={t('handling.unsaved_switch')}
          confirmLabel={t('handling.discard')}
          onClose={() => setSwitchTo(null)}
          onConfirm={() => {
            store.select(switchTo);
            setSwitchTo(null);
          }}
        />
      )}
    </div>
  );
};
