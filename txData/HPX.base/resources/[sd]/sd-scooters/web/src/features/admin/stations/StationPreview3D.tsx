import { useEffect, useRef, useState } from 'react';
import { t } from '@/i18n';
import { useAdmin } from '@/store/admin';
import type { StationLayout, StationPreview } from './stationScene';

export const StationPreview3D = ({ count, hex, height = 200 }: { count: number; hex: string; height?: number }) => {
  const host = useRef<HTMLDivElement>(null);
  const api = useRef<StationPreview | null>(null);
  const latest = useRef({ count, hex });
  latest.current = { count, hex };
  const layout = useAdmin(s => s.snapshot?.stationLayout);
  const [status, setStatus] = useState<'loading' | 'ready' | 'error'>('loading');

  useEffect(() => {
    let alive = true;
    void import('./stationScene')
      .then(async ({ createStationPreview, DEFAULT_LAYOUT }) => {
        if (!alive || !host.current) return;
        const scene = await createStationPreview(host.current, latest.current.count, latest.current.hex, (layout as StationLayout | undefined) ?? DEFAULT_LAYOUT);
        if (!alive) return scene.dispose();
        api.current = scene;
        setStatus('ready');
      })
      .catch(() => alive && setStatus('error'));
    return () => {
      alive = false;
      api.current?.dispose();
      api.current = null;
    };
  }, [layout]);

  useEffect(() => {
    api.current?.build(count);
  }, [count]);

  useEffect(() => {
    api.current?.colour(hex);
  }, [hex]);

  return (
    <div className="relative rounded-[10px] overflow-hidden" style={{ height, background: 'radial-gradient(ellipse at 50% 80%, rgba(255,255,255,0.06), transparent 70%), var(--field)', border: '1px solid var(--hairline)' }}>
      <div ref={host} className="absolute inset-0 cursor-grab active:cursor-grabbing [&_canvas]:block [&_canvas]:h-full [&_canvas]:w-full" />
      {status !== 'ready' && (
        <div className="absolute inset-0 flex items-center justify-center text-[12px]" style={{ color: 'var(--text-3)' }}>
          {status === 'loading' ? <span className="sc-skeleton" style={{ width: 120, height: 10 }} /> : t('stations.preview_unavailable')}
        </div>
      )}
    </div>
  );
};
