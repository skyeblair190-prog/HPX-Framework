import { create } from 'zustand';
import type { HandlingBundle, HandlingValues, Telemetry, TestRideState } from '@/types';
import { asValues, resolve } from '@/features/admin/handling/model';

export const BASELINE_ID = 0;

interface HandlingState {
  bundle: HandlingBundle | null;
  selectedId: number;
  saved: HandlingValues;
  draft: HandlingValues;
  onScooter: boolean;
  test: TestRideState;
  telemetry: Telemetry | null;
  lastRun: { top: number; launch: number | null } | null;
  search: string;
  changedOnly: boolean;
  collapsed: Record<string, boolean>;

  setBundle: (bundle: HandlingBundle, selectId?: number) => void;
  select: (id: number) => void;
  setDraft: (draft: HandlingValues) => void;
  setField: (name: string, value: HandlingValues[string]) => void;
  discard: () => void;
  setOnScooter: (on: boolean) => void;
  setTest: (test: TestRideState) => void;
  setTelemetry: (t: Telemetry) => void;
  setSearch: (search: string) => void;
  setChangedOnly: (on: boolean) => void;
  toggleGroup: (id: string) => void;
}

function normalise(bundle: HandlingBundle): HandlingBundle {
  return {
    ...bundle,
    profiles: (Array.isArray(bundle.profiles) ? bundle.profiles : []).map(p => ({ ...p, values: asValues(p.values) })),
    history: (Array.isArray(bundle.history) ? bundle.history : []).map(h => ({ ...h, changes: (asValues(h.changes) as never) ?? {} })),
    templates: (Array.isArray(bundle.templates) ? bundle.templates : []).map(tpl => ({ ...tpl, values: asValues(tpl.values) })),
  };
}

function savedFor(bundle: HandlingBundle, id: number): HandlingValues {
  const profile = bundle.profiles.find(p => p.id === id);
  return resolve(bundle, profile ? profile.values : {});
}

export const useHandling = create<HandlingState>((set, get) => ({
  bundle: null,
  selectedId: BASELINE_ID,
  saved: {},
  draft: {},
  onScooter: false,
  test: { active: false },
  telemetry: null,
  lastRun: null,
  search: '',
  changedOnly: false,
  collapsed: {},

  setBundle: (raw, selectId) => {
    const bundle = normalise(raw);
    const wanted = selectId ?? get().selectedId;
    const first = get().bundle === null && selectId === undefined;
    let id = first ? bundle.activeId : wanted;
    if (id !== BASELINE_ID && !bundle.profiles.some(p => p.id === id)) id = BASELINE_ID;
    const saved = savedFor(bundle, id);
    set({ bundle, selectedId: id, saved, draft: saved });
  },
  select: id => {
    const bundle = get().bundle;
    if (!bundle) return;
    const saved = savedFor(bundle, id);
    set({ selectedId: id, saved, draft: saved });
  },
  setDraft: draft => set({ draft }),
  setField: (name, value) => set(s => ({ draft: { ...s.draft, [name]: value } })),
  discard: () => set(s => ({ draft: s.saved })),
  setOnScooter: onScooter => set({ onScooter }),
  setTest: test =>
    set(s => {
      if (!test.active && s.test.active && s.telemetry) {
        return { test, lastRun: { top: s.telemetry.top, launch: s.telemetry.launch ?? null }, telemetry: null };
      }
      return test.active ? { test, telemetry: { speed: 0, top: 0 } } : { test };
    }),
  setTelemetry: telemetry => set({ telemetry }),
  setSearch: search => set({ search }),
  setChangedOnly: changedOnly => set({ changedOnly }),
  toggleGroup: id => set(s => ({ collapsed: { ...s.collapsed, [id]: !s.collapsed[id] } })),
}));
