import { useEffect } from 'react';
import { useNuiEvent } from '@/hooks/useNuiEvent';
import { useAdmin } from '@/store/admin';
import { isEnvBrowser } from '@/nui/bridge';
import { close } from '@/nui/api';
import { devSeed } from '@/nui/mock';
import { setLocale } from '@/i18n';
import { AdminPanel } from '@/features/admin/AdminPanel';
import { TestRideHud } from '@/features/admin/handling/TestRideHud';
import { PlacementHud, usePlacer } from '@/features/admin/PlacementHud';
import type { PlacerHud } from '@/features/admin/PlacementHud';
import { useHandling } from '@/store/handling';
import type { Placed, Snapshot, Telemetry, TestRideState } from '@/types';

export default function App() {
  const open = useAdmin(s => s.open);
  const hidden = useAdmin(s => s.hidden);
  const testing = useHandling(s => s.test.active);
  const placing = usePlacer(s => s.hud.active);

  useNuiEvent<{ snapshot: Snapshot }>('scoot:admin:open', d => useAdmin.getState().openWith(d.snapshot));
  useNuiEvent('scoot:admin:hide', () => useAdmin.getState().hide());
  useNuiEvent<{ snapshot?: Snapshot | null; placed?: Placed | null }>('scoot:admin:show', d =>
    useAdmin.getState().show(d?.snapshot, d?.placed),
  );
  useNuiEvent('scoot:admin:close', () => useAdmin.getState().close());
  useNuiEvent<{ ui?: Record<string, unknown> }>('scoot:admin:locale', d => setLocale(d?.ui as never));
  useNuiEvent<TestRideState>('scoot:handling:test', d => useHandling.getState().setTest(d ?? { active: false }));
  useNuiEvent<Telemetry>('scoot:handling:telemetry', d => useHandling.getState().setTelemetry(d));
  useNuiEvent<PlacerHud>('scoot:placer:hud', d => usePlacer.getState().set(d ?? { active: false }));

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && useAdmin.getState().open && !useAdmin.getState().hidden) void close();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);

  useEffect(() => {
    if (isEnvBrowser()) devSeed();
  }, []);

  if (open && hidden && testing) return <TestRideHud />;
  if (open && hidden && placing) return <PlacementHud />;
  if (!open || hidden) return null;
  return <AdminPanel />;
}
