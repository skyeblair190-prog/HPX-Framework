import { create } from 'zustand';
import { TABS } from '@/types';
import type { Placed, Snapshot, Tab } from '@/types';

export interface RecentAction {
  id: number;
  at: number;
  text: string;
  ok: boolean;
}

export interface ToastAction {
  label: string;
  run: () => void | Promise<void>;
}

export interface Toast {
  id: number;
  text: string;
  ok: boolean;
  action?: ToastAction;
}

export type Detail = { kind: 'scooter'; id: number } | { kind: 'station'; id: number } | { kind: 'bunker'; id: number } | { kind: 'player'; renter: string; name: string } | null;

interface AdminState {
  open: boolean;
  hidden: boolean;
  snapshot: Snapshot | null;
  tab: Tab;
  busy: boolean;
  toasts: Toast[];
  recent: RecentAction[];
  placedPending: Placed | null;
  detail: Detail;

  openWith: (snapshot: Snapshot) => void;
  hide: () => void;
  show: (snapshot: Snapshot | null | undefined, placed?: Placed | null) => void;
  close: () => void;
  setSnapshot: (snapshot: Snapshot) => void;
  setTab: (tab: Tab) => void;
  setBusy: (busy: boolean) => void;
  toast: (text: string, ok?: boolean, action?: ToastAction, ms?: number) => void;
  dismissToast: (id: number) => void;
  record: (text: string, ok?: boolean) => void;
  setDetail: (detail: Detail) => void;
}

let seq = 1;
const TAB_KEY = 'sd_scoot:adminTab';

const loadTab = (): Tab => {
  try {
    const raw = window.localStorage.getItem(TAB_KEY);
    if (raw && (TABS as readonly string[]).includes(raw)) return raw as Tab;
  } catch {
  }
  return 'overview';
};

export const useAdmin = create<AdminState>((set, get) => ({
  open: false,
  hidden: false,
  snapshot: null,
  tab: loadTab(),
  busy: false,
  toasts: [],
  recent: [],
  placedPending: null,
  detail: null,

  openWith: snapshot => set({ open: true, hidden: false, snapshot, busy: false }),
  hide: () => set({ hidden: true }),
  show: (snapshot, placed) => {
    const next: Partial<AdminState> = { hidden: false, busy: false };
    if (snapshot) next.snapshot = snapshot;
    set(next);
    if (placed) {
      const noun = placed.kind === 'vehicle' ? 'scooter' : placed.what === 'station' ? 'station' : 'bunker';
      const verb = placed.action === 'moved' ? 'moved' : 'placed';
      const text = placed.message ?? `${noun[0].toUpperCase()}${noun.slice(1)} ${verb}`;
      if (!placed.cancelled) get().toast(text, placed.success);
      if (placed.success) get().record(`${verb[0].toUpperCase()}${verb.slice(1)} a ${noun}`, true);
    }
  },
  close: () => set({ open: false, hidden: false, busy: false, detail: null }),
  setSnapshot: snapshot => set({ snapshot }),
  setTab: tab => {
    try {
      window.localStorage.setItem(TAB_KEY, tab);
    } catch {
    }
    set({ tab, detail: null });
  },
  setBusy: busy => set({ busy }),
  toast: (text, ok = true, action, ms) => {
    const id = seq++;
    set(s => ({ toasts: [...s.toasts, { id, text, ok, action }] }));
    window.setTimeout(() => get().dismissToast(id), ms ?? (action ? 8000 : 3200));
  },
  dismissToast: id => set(s => ({ toasts: s.toasts.filter(t => t.id !== id) })),
  record: (text, ok = true) => set(s => ({ recent: [{ id: seq++, at: Date.now(), text, ok }, ...s.recent].slice(0, 8) })),
  setDetail: detail => set({ detail }),
}));
