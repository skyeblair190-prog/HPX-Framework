import { useEffect, useRef, useState } from 'react';
import { t } from '@/i18n';
import type { Customization } from '@/types';

type PreviewApi = { colour: (hex: string) => void; extras: (value: Customization) => void; zoom: (factor: number) => void; dispose: () => void };

export const ScooterPreview3D = ({ hex, customization, height = 190 }: { hex: string; customization?: Customization | null; height?: number }) => {
  const host = useRef<HTMLDivElement>(null);
  const api = useRef<PreviewApi | null>(null);
  const colour = useRef(hex);
  colour.current = hex;
  const extras = useRef(customization);
  extras.current = customization;
  const [status, setStatus] = useState<'loading' | 'ready' | 'error'>('loading');

  useEffect(() => {
    let alive = true;
    void import('@/app/native/previewScene')
      .then(async ({ createPreview }) => {
        if (!alive || !host.current) return;
        const scene = await createPreview(
          host.current,
          colour.current,
          () => alive && setStatus('ready'),
          () => alive && setStatus('error'),
        );
        if (!alive) scene.dispose();
        else {
          api.current = scene;
          if (extras.current) scene.extras(extras.current);
          scene.zoom(0.62);
        }
      })
      .catch(() => alive && setStatus('error'));
    return () => {
      alive = false;
      api.current?.dispose();
      api.current = null;
    };
  }, []);

  useEffect(() => {
    api.current?.colour(hex);
  }, [hex]);

  useEffect(() => {
    if (customization) api.current?.extras(customization);
  }, [customization]);

  return (
    <div className="relative rounded-[10px] overflow-hidden" style={{ height, background: 'radial-gradient(ellipse at 50% 80%, rgba(255,255,255,0.06), transparent 70%), var(--field)', border: '1px solid var(--hairline)' }}>
      <div ref={host} className="absolute inset-0 cursor-grab active:cursor-grabbing [&_canvas]:block [&_canvas]:h-full [&_canvas]:w-full" />
      {status !== 'ready' && (
        <div className="absolute inset-0 flex items-center justify-center text-[12px]" style={{ color: 'var(--text-3)' }}>
          {status === 'loading' ? <span className="sc-skeleton" style={{ width: 120, height: 10 }} /> : t('scooters.preview')}
        </div>
      )}
    </div>
  );
};
