import { fetchNui, isEnvBrowser } from '@/nui/bridge';
import { useAdmin } from '@/store/admin';
import { useHandling } from '@/store/handling';
import { t } from '@/i18n';
import type { HandlingBundle, HandlingValues, Reply } from '@/types';

type WithBundle = { handling?: HandlingBundle; id?: number; changed?: number; text?: string };

export async function handlingAct(verb: string, payload: Record<string, unknown> = {}, selectId?: number): Promise<Reply<WithBundle>> {
  const admin = useAdmin.getState();
  admin.setBusy(true);
  const reply = (await fetchNui<Reply<WithBundle>>(`scoot:admin:${verb}`, payload)) ?? { success: false, message: t('toast.failed') };
  admin.setBusy(false);
  if (reply.success) {
    if (reply.data?.handling) useHandling.getState().setBundle(reply.data.handling, selectId ?? reply.data.id);
  } else {
    admin.toast(reply.message ?? t('toast.failed'), false);
  }
  return reply;
}

export async function loadHandling(): Promise<void> {
  if (isEnvBrowser()) {
    const mock = await import('./handlingMock.json');
    useHandling.getState().setBundle(mock.default as unknown as HandlingBundle);
    return;
  }
  await handlingAct('handling');
}

let previewTimer: number | undefined;

export function schedulePreview(values: HandlingValues | null): void {
  window.clearTimeout(previewTimer);
  previewTimer = window.setTimeout(async () => {
    if (!values) {
      await fetchNui('scoot:admin:handlingdiscard');
      useHandling.getState().setOnScooter(false);
      return;
    }
    const reply = await fetchNui<Reply<{ onScooter: boolean }>>('scoot:admin:handlingpreview', { values });
    useHandling.getState().setOnScooter(!!reply?.data?.onScooter);
  }, 140);
}

export async function startTestRide(values: HandlingValues): Promise<void> {
  const reply = await fetchNui<Reply>('scoot:admin:handlingtest', { values });
  if (reply && !reply.success) useAdmin.getState().toast(reply.message ?? t('toast.failed'), false);
}

export function copyText(text: string): boolean {
  const area = document.createElement('textarea');
  area.value = text;
  area.style.position = 'fixed';
  area.style.opacity = '0';
  document.body.appendChild(area);
  area.select();
  let done = false;
  try {
    done = document.execCommand('copy');
  } catch {
    done = false;
  }
  document.body.removeChild(area);
  return done;
}
