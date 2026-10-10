import { fetchNui } from './bridge';
import { useAdmin } from '@/store/admin';
import { t } from '@/i18n';
import type { PositionsData, Reply, Snapshot } from '@/types';

type WithSnapshot = { snapshot?: Snapshot; undo?: string };

export async function act<T extends object = object>(verb: string, payload: Record<string, unknown> = {}, recordText?: string): Promise<Reply<T & WithSnapshot>> {
  const store = useAdmin.getState();
  store.setBusy(true);
  const reply = (await fetchNui<Reply<T & WithSnapshot>>(`scoot:admin:${verb}`, payload)) ?? { success: false, message: t('toast.failed') };
  store.setBusy(false);
  if (reply.success) {
    if (reply.data?.snapshot) store.setSnapshot(reply.data.snapshot);
    if (recordText) store.record(recordText, true);
    const token = reply.data?.undo;
    if (token && recordText) {
      store.toast(recordText, true, {
        label: t('actions.undo'),
        run: async () => {
          const back = await act('undodelete', { token });
          if (back.success) useAdmin.getState().toast(t('common.restored'), true);
        },
      });
    }
  } else {
    store.toast(reply.message ?? t('toast.failed'), false);
    if (recordText) store.record(recordText, false);
  }
  return reply;
}

export async function query<T>(verb: string, payload: Record<string, unknown> = {}, toastOnFail = false): Promise<T | null> {
  const reply = await fetchNui<Reply<T>>(`scoot:admin:${verb}`, payload);
  if (reply?.success && reply.data !== undefined) return reply.data;
  if (toastOnFail) useAdmin.getState().toast(reply?.message ?? t('toast.failed'), false);
  return null;
}

export async function place(verb: 'placebunker' | 'placestation' | 'movebunker' | 'movestation', payload: Record<string, unknown>): Promise<void> {
  await fetchNui(`scoot:admin:${verb}`, payload);
}

export async function refresh(): Promise<void> {
  const reply = await fetchNui<Reply<Snapshot>>('scoot:admin:snapshot');
  if (reply?.success && reply.data) useAdmin.getState().setSnapshot(reply.data);
}

export async function positions(): Promise<PositionsData | null> {
  const reply = await fetchNui<Reply<PositionsData>>('scoot:admin:positions');
  return reply?.success && reply.data ? reply.data : null;
}

export async function close(): Promise<void> {
  useAdmin.getState().close();
  await fetchNui('scoot:admin:close');
}
