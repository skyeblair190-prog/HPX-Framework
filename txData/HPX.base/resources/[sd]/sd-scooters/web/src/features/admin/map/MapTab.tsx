import { useEffect, useMemo, useRef, useState } from 'react';
import type { MouseEvent as ReactMouseEvent } from 'react';
import { Crosshair, Minus, Navigation, PanelRight, Plus, X } from 'lucide-react';
import { useAdmin } from '@/store/admin';
import { act, positions, query } from '@/nui/api';
import { t } from '@/i18n';
import type { ActivityPoint, Bunker, MapStyleId, Position, Rider, Scooter, Station, Vec3 } from '@/types';
import { MAP_STYLES, WORLD, loadStyleId, projectPct, saveStyleId } from './mapData';
import { MAX_ZOOM, MIN_ZOOM, useMapViewport } from './useMapViewport';
import { TileCanvas } from './TileCanvas';

type Kind = 'bunker' | 'station' | 'scooter' | 'rider';
type Pin = { key: string; kind: Kind; colour: string; label: string; sub: string; x: number; y: number; z: number; ref: Bunker | Station | Scooter | Rider };
type Placed = Pin & { left: number; top: number };
type Cluster = { key: string; left: number; top: number; pins: Placed[] };

const BUNKER_COLOUR = '#3ecf73';
const STATION_COLOUR = '#e5a33b';
const RIDER_COLOUR = '#ffffff';
const STYLE_FADE_MS = 450;
const CLUSTER_PX = 18;

const Detail = ({ label, value }: { label: string; value: string }) => (
  <div className="flex items-baseline justify-between gap-4">
    <span className="text-[12px]" style={{ color: 'var(--text-3)' }}>
      {label}
    </span>
    <span className="text-[12px] mono" style={{ color: 'var(--text-1)' }}>
      {value}
    </span>
  </div>
);

export const MapTab = () => {
  const snapshot = useAdmin(s => s.snapshot)!;
  const openDetail = useAdmin(s => s.setDetail);
  const vp = useMapViewport();
  const [styleId, setStyleId] = useState<MapStyleId>(() => loadStyleId(snapshot.map));
  const [prevStyleId, setPrevStyleId] = useState<MapStyleId | null>(null);
  const fadeTimer = useRef<number | null>(null);
  const [showBunkers, setShowBunkers] = useState(true);
  const [showStations, setShowStations] = useState(true);
  const [showScooters, setShowScooters] = useState(true);
  const [showRiders, setShowRiders] = useState(true);
  const [showActivity, setShowActivity] = useState(false);
  const [activity, setActivity] = useState<ActivityPoint[] | null>(null);
  const [hover, setHover] = useState<Pin | null>(null);
  const [pinned, setPinned] = useState<Pin | null>(null);
  const [menu, setMenu] = useState<{ x: number; y: number; worldX: number; worldY: number } | null>(null);
  const [live, setLive] = useState<{ scooters: Map<number, Position>; player: Vec3 | null; riders: Rider[] }>({ scooters: new Map(), player: snapshot.player, riders: [] });

  useEffect(() => {
    let stopped = false;
    const tick = async () => {
      const data = await positions();
      if (!data || stopped) return;
      setLive({ scooters: new Map(data.scooters.map(p => [p.id, p])), player: data.player, riders: data.riders ?? [] });
    };
    void tick();
    const id = window.setInterval(() => void tick(), Math.max(1000, snapshot.positionsInterval || 3000));
    return () => {
      stopped = true;
      window.clearInterval(id);
    };
  }, [snapshot.positionsInterval]);

  useEffect(() => {
    if (showActivity && !activity) void query<{ points: ActivityPoint[] }>('mapactivity').then(d => setActivity(d?.points ?? []));
  }, [showActivity, activity]);

  const style = MAP_STYLES.find(s => s.id === styleId) ?? MAP_STYLES[0];
  const prevStyle = prevStyleId ? (MAP_STYLES.find(s => s.id === prevStyleId) ?? null) : null;

  useEffect(
    () => () => {
      if (fadeTimer.current) window.clearTimeout(fadeTimer.current);
    },
    [],
  );
  const colourHex = (index: number) => snapshot.colours.find(c => c.index === index)?.hex ?? '#ffffff';
  const colourName = (index: number) => snapshot.colours.find(c => c.index === index)?.name ?? '?';
  const bunkerName = (id: number | null) => (id == null ? t('scooters.free') : (snapshot.bunkers.find(b => b.id === id)?.name ?? `#${id}`));

  const pins = useMemo<Pin[]>(() => {
    const out: Pin[] = [];
    const ridden = new Set(live.riders.map(r => r.scooterId));
    if (showBunkers) {
      for (const b of snapshot.bunkers) {
        out.push({ key: `b${b.id}`, kind: 'bunker', colour: BUNKER_COLOUR, label: b.name, sub: b.enabled ? t('bunkers.enabled') : t('bunkers.disabled'), x: b.x, y: b.y, z: b.z, ref: b });
      }
    }
    if (showStations) {
      for (const st of snapshot.stations) {
        out.push({ key: `t${st.id}`, kind: 'station', colour: STATION_COLOUR, label: st.name, sub: st.enabled ? t('bunkers.enabled') : t('bunkers.disabled'), x: st.x, y: st.y, z: st.z, ref: st });
      }
    }
    if (showScooters) {
      for (const s of snapshot.scooters) {
        if (showRiders && ridden.has(s.id)) continue;
        const p = live.scooters.get(s.id);
        out.push({ key: `s${s.id}`, kind: 'scooter', colour: colourHex(s.colour), label: s.plate, sub: colourName(s.colour), x: p?.x ?? s.x, y: p?.y ?? s.y, z: p?.z ?? s.z, ref: s });
      }
    }
    if (showRiders) {
      for (const r of live.riders) {
        const p = live.scooters.get(r.scooterId);
        const x = p?.x ?? r.x;
        const y = p?.y ?? r.y;
        if (x == null || y == null) continue;
        out.push({ key: `r${r.rideId}`, kind: 'rider', colour: RIDER_COLOUR, label: r.name, sub: `${r.plate} · ${t('common.minutes', r.minutes)}`, x, y, z: p?.z ?? 0, ref: r });
      }
    }
    return out.filter(p => Number.isFinite(p.x) && Number.isFinite(p.y));
  }, [snapshot, live, showBunkers, showStations, showScooters, showRiders]);

  const shown = pinned ?? hover;
  const player = live.player ?? snapshot.player;

  const { singles, clusters } = useMemo(() => {
    const placed: Placed[] = [];
    for (const pin of pins) {
      const world = projectPct(pin.x, pin.y);
      const at = vp.toScreen(world.left, world.top);
      if (at.left < -4 || at.left > 104 || at.top < -4 || at.top > 104) continue;
      placed.push({ ...pin, left: at.left, top: at.top });
    }
    const side = vp.side || 1;
    const px = (a: Placed, b: { left: number; top: number }) => Math.hypot(((a.left - b.left) / 100) * side, ((a.top - b.top) / 100) * side);
    const groups: Cluster[] = [];
    const lone: Placed[] = [];
    for (const p of placed) {
      if (shown?.key === p.key || vp.view.zoom >= MAX_ZOOM - 4) {
        lone.push(p);
        continue;
      }
      const near = groups.find(g => px(p, g) < CLUSTER_PX);
      if (near) {
        near.pins.push(p);
        near.left = near.pins.reduce((n, q) => n + q.left, 0) / near.pins.length;
        near.top = near.pins.reduce((n, q) => n + q.top, 0) / near.pins.length;
      } else {
        groups.push({ key: p.key, left: p.left, top: p.top, pins: [p] });
      }
    }
    return { singles: [...lone, ...groups.filter(g => g.pins.length === 1).map(g => g.pins[0])], clusters: groups.filter(g => g.pins.length > 1) };
  }, [pins, vp.view, vp.side, shown?.key]);

  const pickStyle = (id: MapStyleId) => {
    if (id === styleId) return;
    if (fadeTimer.current) window.clearTimeout(fadeTimer.current);
    setPrevStyleId(styleId);
    setStyleId(id);
    saveStyleId(id);
    fadeTimer.current = window.setTimeout(() => {
      setPrevStyleId(null);
      fadeTimer.current = null;
    }, STYLE_FADE_MS);
  };

  const openPin = (pin: Pin) => {
    if (pin.kind === 'rider') {
      const ride = snapshot.rides.find(r => r.id === (pin.ref as Rider).rideId);
      if (ride) openDetail({ kind: 'player', renter: ride.renter, name: ride.renterName });
      return;
    }
    openDetail({ kind: pin.kind, id: (pin.ref as Bunker).id });
  };

  const teleportTo = async (pin: Pin) => {
    if (pin.kind === 'rider') {
      await act('teleport', { kind: 'scooter', id: (pin.ref as Rider).scooterId });
      return;
    }
    await act('teleport', { kind: pin.kind, id: (pin.ref as Bunker).id }, `Teleported to ${pin.label}`);
  };

  const worldAt = (e: ReactMouseEvent) => {
    const el = vp.ref.current;
    if (!el) return null;
    const rect = el.getBoundingClientRect();
    const squareLeft = rect.left + (vp.width - vp.side) / 2;
    const squareTop = rect.top + (vp.height - vp.side) / 2;
    const fx = (e.clientX - squareLeft) / vp.side;
    const fy = (e.clientY - squareTop) / vp.side;
    const leftPct = (fx - 0.5) / vp.view.zoom + 0.5 + vp.view.x;
    const topPct = (fy - 0.5) / vp.view.zoom + 0.5 + vp.view.y;
    return { x: WORLD.xMin + leftPct * (WORLD.xMax - WORLD.xMin), y: WORLD.yMax - topPct * (WORLD.yMax - WORLD.yMin), rect };
  };

  const toggle = (on: boolean, set: (v: boolean) => void, label: string, colour: string, count?: number) => (
    <button type="button" onClick={() => set(!on)} className={`sc-btn${on ? ' sc-btn--on' : ''}`} style={{ color: on ? 'var(--text-1)' : 'var(--text-3)' }}>
      <span className="w-2 h-2 rounded-full" style={{ backgroundColor: on ? colour : 'var(--text-4)', boxShadow: colour === RIDER_COLOUR && on ? 'inset 0 0 0 2px #0c0d0f' : 'none' }} />
      {label}
      {count != null && (
        <span className="mono" style={{ color: 'var(--text-3)' }}>
          {count}
        </span>
      )}
    </button>
  );

  return (
    <div className="flex flex-col h-full min-h-0 gap-4 px-6 py-5">
      <div className="flex items-center justify-between gap-3 flex-wrap">
        <div className="flex items-center gap-2 flex-wrap">
          {toggle(showBunkers, setShowBunkers, t('map.bunkers'), BUNKER_COLOUR, snapshot.bunkers.length)}
          {toggle(showStations, setShowStations, t('map.stations'), STATION_COLOUR, snapshot.stations.length)}
          {toggle(showScooters, setShowScooters, t('map.scooters'), '#9aa0a6', snapshot.scooters.length)}
          {toggle(showRiders, setShowRiders, t('map.riders'), RIDER_COLOUR, live.riders.length)}
          {toggle(showActivity, setShowActivity, t('map.activity'), '#7aa2ff')}
        </div>
        <div className="flex items-center gap-2">
          <div className="sc-segment">
            {MAP_STYLES.map(s => (
              <button key={s.id} type="button" data-on={s.id === styleId} onClick={() => pickStyle(s.id)}>
                {s.id === 'atlas' ? t('map.atlas') : t('map.satellite')}
              </button>
            ))}
          </div>
          <span className="w-px h-5 mx-1" style={{ backgroundColor: 'var(--hairline-strong)' }} />
          <button type="button" onClick={() => vp.zoomBy(1 / 1.4)} disabled={vp.view.zoom <= MIN_ZOOM} className="sc-map-btn">
            <Minus size={13} />
          </button>
          <button type="button" onClick={() => vp.zoomBy(1.4)} disabled={vp.view.zoom >= MAX_ZOOM} className="sc-map-btn">
            <Plus size={13} />
          </button>
          <button type="button" onClick={vp.home} disabled={vp.atHome} className="sc-map-btn">
            <Crosshair size={13} />
          </button>
        </div>
      </div>

      <div
        ref={vp.ref}
        onPointerDown={e => {
          if (e.button === 2) return;
          setMenu(null);
          vp.surface.onPointerDown(e);
        }}
        onWheel={vp.surface.onWheel}
        onContextMenu={e => {
          e.preventDefault();
          const w = worldAt(e);
          if (!w) return;
          setMenu({ x: e.clientX - w.rect.left, y: e.clientY - w.rect.top, worldX: w.x, worldY: w.y });
        }}
        className={`relative flex-1 min-h-0 w-full touch-none overflow-hidden rounded-[10px] border ${vp.panning ? 'cursor-grabbing' : 'cursor-grab'}`}
        style={{ background: style.bg, borderColor: 'var(--hairline)', transition: `background ${STYLE_FADE_MS}ms ease` }}
      >
        <div className="absolute" style={{ width: vp.side, height: vp.side, left: (vp.width - vp.side) / 2, top: (vp.height - vp.side) / 2 }}>
          {prevStyle && <TileCanvas key={prevStyle.id} style={prevStyle} view={vp.view} width={vp.side} />}
          <div key={style.id} className="absolute inset-0" style={{ animation: prevStyle ? `fadeIn ${STYLE_FADE_MS}ms ease-out` : undefined }}>
            <TileCanvas style={style} view={vp.view} width={vp.side} />
          </div>

          {showActivity &&
            (activity ?? []).flatMap((p, i) => {
              const dots: { key: string; x: number; y: number; colour: string }[] = [];
              if (p.sx != null && p.sy != null) dots.push({ key: `s${i}`, x: p.sx, y: p.sy, colour: '#3ecf73' });
              if (p.ex != null && p.ey != null) dots.push({ key: `e${i}`, x: p.ex, y: p.ey, colour: '#7aa2ff' });
              return dots.map(d => {
                const w = projectPct(d.x, d.y);
                const at = vp.toScreen(w.left, w.top);
                if (at.left < 0 || at.left > 100 || at.top < 0 || at.top > 100) return null;
                return (
                  <span
                    key={d.key}
                    className="absolute -translate-x-1/2 -translate-y-1/2 rounded-full pointer-events-none"
                    style={{ left: `${at.left}%`, top: `${at.top}%`, width: 7, height: 7, backgroundColor: d.colour, opacity: 0.32, zIndex: 1 }}
                  />
                );
              });
            })}

          {player &&
            (() => {
              const at = vp.toScreen(projectPct(player.x, player.y).left, projectPct(player.x, player.y).top);
              return (
                <span
                  className="absolute -translate-x-1/2 -translate-y-1/2 rounded-full pointer-events-none"
                  title={t('map.you')}
                  style={{ left: `${at.left}%`, top: `${at.top}%`, width: 10, height: 10, backgroundColor: '#ffffff', boxShadow: '0 0 0 2px rgba(0,0,0,0.7), 0 0 0 5px rgba(255,255,255,0.18)', zIndex: 4 }}
                />
              );
            })()}

          {clusters.map(c => (
            <button
              key={c.key}
              type="button"
              title={t('map.cluster', c.pins.length)}
              onPointerDown={e => e.stopPropagation()}
              onClick={e => {
                e.stopPropagation();
                vp.focus(c.left / vp.view.zoom + (0.5 + vp.view.x) * 100 - 50 / vp.view.zoom, c.top / vp.view.zoom + (0.5 + vp.view.y) * 100 - 50 / vp.view.zoom, Math.min(MAX_ZOOM, vp.view.zoom * 2.5));
              }}
              className="absolute -translate-x-1/2 -translate-y-1/2 flex items-center justify-center rounded-full mono text-[11px] font-semibold transition-transform hover:scale-110"
              style={{ left: `${c.left}%`, top: `${c.top}%`, minWidth: 22, height: 22, padding: '0 6px', background: '#121316', color: '#ededef', border: '1.5px solid rgba(255,255,255,0.7)', boxShadow: '0 1px 4px rgba(0,0,0,0.5)', zIndex: 2 }}
            >
              {c.pins.length}
            </button>
          ))}

          {singles.map(pin => {
            const active = shown?.key === pin.key;
            const rider = pin.kind === 'rider';
            const size = rider ? (active ? 16 : 13) : pin.kind !== 'scooter' ? (active ? 18 : 14) : active ? 14 : 10;
            return (
              <button
                key={pin.key}
                type="button"
                onPointerDown={e => e.stopPropagation()}
                onClick={e => {
                  e.stopPropagation();
                  setPinned(pin);
                }}
                onMouseEnter={() => setHover(pin)}
                onMouseLeave={() => setHover(h => (h?.key === pin.key ? null : h))}
                className="sc-map-pin absolute -translate-x-1/2 -translate-y-1/2 transition-transform"
                style={{
                  left: `${pin.left}%`,
                  top: `${pin.top}%`,
                  width: size,
                  height: size,
                  borderRadius: pin.kind === 'bunker' ? 4 : pin.kind === 'station' ? 2 : 999,
                  backgroundColor: rider ? '#121316' : pin.colour,
                  border: rider ? `${active ? 3 : 2.5}px solid #ffffff` : `${active ? 2 : 1.5}px solid ${active ? '#ffffff' : 'rgba(0,0,0,0.6)'}`,
                  boxShadow: '0 1px 3px rgba(0,0,0,0.5)',
                  zIndex: active ? 5 : rider ? 4 : pin.kind !== 'scooter' ? 3 : 2,
                }}
              />
            );
          })}
        </div>

        {showActivity && (
          <div className="absolute right-3 top-3 flex items-center gap-3 px-2.5 h-7 rounded-[6px] text-[11.5px] pointer-events-none" style={{ background: 'rgba(18,19,22,0.9)', border: '1px solid var(--hairline-strong)', color: 'var(--text-2)' }}>
            <span className="flex items-center gap-1.5">
              <span className="w-2 h-2 rounded-full" style={{ background: '#3ecf73' }} />
              {t('map.starts')}
            </span>
            <span className="flex items-center gap-1.5">
              <span className="w-2 h-2 rounded-full" style={{ background: '#7aa2ff' }} />
              {t('map.ends')}
            </span>
          </div>
        )}

        {menu && (
          <div
            className="absolute z-20 rounded-[8px] overflow-hidden animate-fadeIn"
            style={{ left: menu.x, top: menu.y, background: 'var(--surface)', border: '1px solid var(--hairline-strong)', boxShadow: '0 12px 32px rgba(0,0,0,0.45)', minWidth: 170 }}
            onPointerDown={e => e.stopPropagation()}
          >
            <div className="px-3 h-8 flex items-center mono text-[11.5px]" style={{ color: 'var(--text-3)', borderBottom: '1px solid var(--hairline)' }}>
              {menu.worldX.toFixed(0)}, {menu.worldY.toFixed(0)}
            </div>
            <button
              type="button"
              className="sc-map-action w-full justify-start px-3"
              onClick={() => {
                void act('teleportpoint', { x: menu.worldX, y: menu.worldY });
                setMenu(null);
              }}
            >
              <Navigation className="w-3.5 h-3.5" />
              {t('map.teleport_here')}
            </button>
          </div>
        )}

        {shown && (
          <div
            className={`absolute left-3 bottom-3 w-64 rounded-[10px] border overflow-hidden animate-fadeIn ${pinned ? '' : 'pointer-events-none'}`}
            onPointerDown={e => e.stopPropagation()}
            style={{ backgroundColor: 'var(--surface)', borderColor: 'var(--hairline-strong)', boxShadow: '0 12px 32px rgba(0,0,0,0.45)' }}
          >
            <div className="flex items-center gap-2 px-3 h-10" style={{ borderBottom: '1px solid var(--hairline)' }}>
              <span className="w-2.5 h-2.5 flex-shrink-0" style={{ backgroundColor: shown.kind === 'rider' ? '#121316' : shown.colour, border: shown.kind === 'rider' ? '2px solid #fff' : 'none', borderRadius: shown.kind === 'scooter' || shown.kind === 'rider' ? 999 : 2 }} />
              <span className="text-[13px] font-semibold truncate" style={{ color: 'var(--text-1)' }}>
                {shown.label}
              </span>
              <span className="ml-auto text-[11px] flex-shrink-0" style={{ color: 'var(--text-3)' }}>
                {shown.kind === 'bunker' ? t('map.bunkers') : shown.kind === 'station' ? t('map.stations') : shown.kind === 'rider' ? t('map.rider') : t('map.scooters')}
              </span>
              {pinned && (
                <button type="button" onClick={() => setPinned(null)} className="sc-btn sc-btn--icon flex-shrink-0 -mr-1.5" style={{ width: 24, height: 24 }}>
                  <X className="w-3.5 h-3.5" />
                </button>
              )}
            </div>
            <div className="px-3 py-2.5 space-y-1.5">
              <Detail label={shown.kind === 'rider' ? t('scooters.plate') : t('bunkers.status')} value={shown.sub} />
              {shown.kind === 'scooter' && <Detail label={t('scooters.home')} value={bunkerName((shown.ref as Scooter).bunkerId)} />}
              {shown.kind === 'scooter' && snapshot.battery.enabled && <Detail label={t('scooters.battery')} value={`${(shown.ref as Scooter).battery}%`} />}
              {shown.kind === 'bunker' && <Detail label={t('bunkers.stock')} value={String((shown.ref as Bunker).stock)} />}
              {shown.kind === 'station' && <Detail label={t('stations.slots')} value={`${(shown.ref as Station).occupied}/${(shown.ref as Station).slots.length}`} />}
              <Detail label={t('bunkers.coords')} value={`${shown.x.toFixed(0)}, ${shown.y.toFixed(0)}`} />
            </div>
            {pinned ? (
              <div className="flex" style={{ borderTop: '1px solid var(--hairline)' }}>
                <button type="button" onClick={() => void teleportTo(pinned)} className="sc-map-action">
                  <Navigation className="w-3.5 h-3.5" />
                  {t('actions.teleport')}
                </button>
                <span className="w-px" style={{ background: 'var(--hairline)' }} />
                <button type="button" onClick={() => openPin(pinned)} className="sc-map-action">
                  <PanelRight className="w-3.5 h-3.5" />
                  {t('actions.details')}
                </button>
              </div>
            ) : (
              <div className="px-3 h-8 flex items-center text-[11px]" style={{ borderTop: '1px solid var(--hairline)', color: 'var(--text-3)' }}>
                {t('map.click')}
              </div>
            )}
          </div>
        )}

        {pins.length === 0 && (
          <div className="absolute inset-0 flex items-center justify-center text-[12px] pointer-events-none" style={{ color: 'var(--text-2)' }}>
            {t('map.empty')}
          </div>
        )}
      </div>
    </div>
  );
};
