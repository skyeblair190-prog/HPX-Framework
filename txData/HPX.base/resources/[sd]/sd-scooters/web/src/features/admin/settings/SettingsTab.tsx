import { useEffect, useMemo, useState } from 'react';
import { RotateCcw } from 'lucide-react';
import { useAdmin } from '@/store/admin';
import { act } from '@/nui/api';
import { prime, useQuery, useSlow } from '@/nui/useQuery';
import { t } from '@/i18n';
import { ConfirmDialog, Heading, Hint, Skeleton } from '@/components/shared';
import type { SettingItem, SettingsBundle } from '@/types';

type Value = number | boolean | string;

const GROUP_COLUMNS = [
  ['pricing', 'rides', 'fleet'],
  ['battery', 'charging'],
];

const key = (path: string) => path.replace(/\./g, '_');

const decimals = (step?: number) => (step && String(step).includes('.') ? String(step).split('.')[1].length : 0);

const NumberInput = ({ item, value, disabled, onChange }: { item: SettingItem; value: number; disabled: boolean; onChange: (v: number) => void }) => {
  const currency = useAdmin(s => s.snapshot?.currency ?? '$');
  const d = decimals(item.step);
  const [text, setText] = useState(value.toFixed(d));
  useEffect(() => setText(value.toFixed(d)), [value, d]);
  const commit = () => {
    const n = Number(text);
    if (text.trim() === '' || !Number.isFinite(n)) return setText(value.toFixed(d));
    const clamped = Math.min(item.max ?? n, Math.max(item.min ?? n, n));
    onChange(item.type === 'int' ? Math.round(clamped) : Number(clamped.toFixed(d)));
  };
  return (
    <div className="flex items-center gap-2">
      <input
        className="sc-input mono text-right"
        style={{ width: 96 }}
        value={text}
        disabled={disabled}
        inputMode="decimal"
        onChange={e => setText(e.target.value)}
        onBlur={commit}
        onKeyDown={e => e.key === 'Enter' && (e.target as HTMLInputElement).blur()}
      />
      <span className="text-[12px] w-10" style={{ color: 'var(--text-3)' }}>
        {item.unit === '$' ? currency : item.unit ?? ''}
      </span>
    </div>
  );
};

const show = (item: SettingItem, v: Value, currency: string) => {
  if (item.type === 'bool') return v ? t('settings.on') : t('settings.off');
  if (item.type === 'enum') return t(`settings.options.${v}`);
  const unit = item.unit === '$' ? currency : item.unit ?? '';
  return item.unit === '$' ? `${unit}${v}` : `${v}${unit ? ` ${unit}` : ''}`;
};

export const SettingsTab = () => {
  const snapshot = useAdmin(s => s.snapshot)!;
  const busy = useAdmin(s => s.busy);
  const { data: reply, setData: setReply } = useQuery<{ settings: SettingsBundle }>('settings');
  const bundle = reply?.settings ?? null;
  const setBundle = (next: SettingsBundle) => {
    prime('settings', undefined, { settings: next });
    setReply({ settings: next });
  };
  const slow = useSlow(!bundle);
  const [draft, setDraft] = useState<Record<string, Value>>({});
  const [resetting, setResetting] = useState(false);
  const edit = snapshot.canEdit;

  const dirty = useMemo(() => {
    if (!bundle) return [] as string[];
    return bundle.settings.filter(s => draft[s.path] !== undefined && draft[s.path] !== s.value).map(s => s.path);
  }, [bundle, draft]);

  const save = async () => {
    const values: Record<string, Value> = {};
    dirty.forEach(p => (values[p] = draft[p]));
    const reply = await act<{ changed?: number; settings?: SettingsBundle }>('settingssave', { values }, `Changed ${dirty.length} setting(s)`);
    if (reply.success && reply.data?.settings) {
      setBundle(reply.data.settings);
      setDraft({});
      useAdmin.getState().toast(t('settings.saved', reply.data.changed ?? 0), true);
    }
  };

  if (!bundle) {
    return <div className="px-6 py-5">{slow && <Skeleton rows={8} />}</div>;
  }

  const cur = bundle.currency;
  const columns = GROUP_COLUMNS.map(ids => ids.map(g => ({ id: g, items: bundle.settings.filter(s => s.group === g) })).filter(g => g.items.length));

  return (
    <div className="flex flex-col h-full min-h-0">
      <div className="flex-1 min-h-0 overflow-y-auto sc-scroll">
        <div className="px-6 py-5 flex flex-col gap-6">
          <div>
            <Heading title={t('tabs.settings')}>
              {edit && (
                <button type="button" className="sc-btn" disabled={busy || !bundle.settings.some(s => s.overridden)} onClick={() => setResetting(true)}>
                  <RotateCcw size={14} />
                  {t('settings.reset_all')}
                </button>
              )}
            </Heading>
            <Hint className="mt-1">{t('settings.intro')}</Hint>
          </div>

          <div className="grid grid-cols-2 gap-6 items-start">
            {columns.map((groups, index) => (
              <div key={index} className="flex flex-col gap-6 min-w-0">
                {groups.map(group => (
                  <section key={group.id} className="flex flex-col gap-2.5">
                    <div className="sc-heading">{t(`settings.groups.${group.id}`)}</div>
                    <div className="sc-list">
                      {group.items.map(item => {
                        const value = draft[item.path] ?? item.value;
                        const unsaved = draft[item.path] !== undefined && draft[item.path] !== item.value;
                        const differs = value !== item.default;
                        const set = (v: Value) => setDraft(d => ({ ...d, [item.path]: v }));
                        return (
                          <div key={item.path} className={`sc-field${unsaved ? ' sc-field--unsaved' : ''}`} style={{ gridTemplateColumns: 'minmax(0,1fr) auto 28px', alignItems: 'center' }}>
                            <div className="min-w-0">
                              <div className="flex items-center gap-2">
                                <span className="text-[13px] font-medium">{t(`settings.fields.${key(item.path)}.label`)}</span>
                                {differs && (
                                  <span className="text-[11.5px]" style={{ color: 'var(--text-3)' }}>
                                    {t('settings.file', show(item, item.default, cur))}
                                  </span>
                                )}
                              </div>
                              <div className="text-[12px] mt-0.5" style={{ color: 'var(--text-3)' }}>
                                {t(`settings.fields.${key(item.path)}.hint`)}
                                {item.overridden && item.updatedBy && !unsaved ? ` · ${t('settings.updated_by', item.updatedBy)}` : ''}
                              </div>
                            </div>
                            <div className="flex justify-end">
                              {item.type === 'bool' ? (
                                <button type="button" className="sc-switch" data-on={!!value} disabled={!edit} onClick={() => set(!value)} aria-label={t(`settings.fields.${key(item.path)}.label`)} />
                              ) : item.type === 'enum' ? (
                                <div className="sc-segment">
                                  {item.options!.map(o => (
                                    <button key={o} type="button" data-on={value === o} disabled={!edit} onClick={() => set(o)}>
                                      {t(`settings.options.${o}`)}
                                    </button>
                                  ))}
                                </div>
                              ) : (
                                <NumberInput item={item} value={Number(value)} disabled={!edit} onChange={set} />
                              )}
                            </div>
                            <div className="flex justify-end">
                              {edit && differs && (
                                <button type="button" className="sc-btn sc-btn--icon" title={t('settings.reset_one')} onClick={() => set(item.default)}>
                                  <RotateCcw size={13} />
                                </button>
                              )}
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  </section>
                ))}
              </div>
            ))}
          </div>
        </div>
      </div>

      {edit && (
        <div className="flex items-center gap-2 pl-6 pr-4 h-14 flex-shrink-0" style={{ borderTop: '1px solid var(--hairline)' }}>
          <span className="text-[12px] flex items-center gap-2" style={{ color: dirty.length ? 'var(--text-2)' : 'var(--text-3)' }}>
            {dirty.length > 0 && <span className="w-1.5 h-1.5 rounded-full" style={{ backgroundColor: 'var(--warn)' }} />}
            {dirty.length ? t('settings.unsaved', dirty.length) : t('handling.nothing_changed')}
          </span>
          <button type="button" className="sc-btn ml-auto" disabled={busy || dirty.length === 0} onClick={() => setDraft({})}>
            {t('settings.discard')}
          </button>
          <button type="button" className="sc-btn sc-btn--primary" disabled={busy || dirty.length === 0} onClick={() => void save()}>
            {t('settings.save')}
          </button>
        </div>
      )}

      {resetting && (
        <ConfirmDialog
          title={t('settings.reset_title')}
          body={t('settings.reset_body')}
          confirmLabel={t('settings.reset_all')}
          onClose={() => setResetting(false)}
          onConfirm={async () => {
            const reply = await act<{ settings?: SettingsBundle }>('settingsreset', {}, 'Reset live settings');
            setResetting(false);
            if (reply.success && reply.data?.settings) {
              setBundle(reply.data.settings);
              setDraft({});
            }
          }}
        />
      )}
    </div>
  );
};
