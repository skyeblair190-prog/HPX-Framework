import { useHandling } from '@/store/handling';
import { t } from '@/i18n';

const Metric = ({ label, value, unit, big = false }: { label: string; value: string; unit?: string; big?: boolean }) => (
  <div>
    <div className="text-[11.5px]" style={{ color: 'var(--text-3)' }}>
      {label}
    </div>
    <div className="mono font-semibold leading-none mt-1.5 tracking-[-0.02em]" style={{ fontSize: big ? 32 : 20 }}>
      {value}
      {unit && (
        <span className="text-[11.5px] font-normal ml-1" style={{ color: 'var(--text-3)' }}>
          {unit}
        </span>
      )}
    </div>
  </div>
);

export const TestRideHud = () => {
  const test = useHandling(s => s.test);
  const telemetry = useHandling(s => s.telemetry);
  const unit = test.unit === 'mph' ? 'mph' : 'km/h';
  const launchTarget = Math.round(test.launch ?? 30);
  const speed = telemetry?.speed ?? 0;
  const top = telemetry?.top ?? 0;
  return (
    <div
      className="fixed left-1/2 bottom-10 rounded-[12px] animate-hudIn font-sans"
      style={{ transform: 'translateX(-50%)', width: 400, backgroundColor: 'rgba(18,19,22,0.94)', border: '1px solid var(--hairline-strong)', boxShadow: '0 16px 40px rgba(0,0,0,0.45)' }}
    >
      <div className="flex items-center gap-2 px-4 h-10" style={{ borderBottom: '1px solid var(--hairline)' }}>
        <span className="w-1.5 h-1.5 rounded-full" style={{ backgroundColor: 'var(--ok)' }} />
        <span className="text-[12.5px] font-medium">{t('handling.hud.title')}</span>
        <span className="ml-auto text-[11.5px]" style={{ color: 'var(--text-3)' }}>
          {t('handling.hud.back', test.key ?? 'F7')}
        </span>
      </div>
      <div className="grid grid-cols-3 gap-4 items-end px-4 py-3.5">
        <Metric label={t('handling.hud.speed')} value={speed.toFixed(0)} unit={unit} big />
        <Metric label={t('handling.hud.top')} value={top.toFixed(1)} />
        <Metric label={`${t('handling.hud.launch', launchTarget)} ${t('handling.hud.best')}`} value={telemetry?.launch != null ? `${telemetry.launch.toFixed(1)}s` : '—'} />
      </div>
    </div>
  );
};
