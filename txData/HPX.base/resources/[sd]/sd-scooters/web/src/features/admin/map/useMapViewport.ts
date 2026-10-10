import { useCallback, useEffect, useLayoutEffect, useRef, useState } from 'react';

export interface Viewport {
  zoom: number;
  x: number;
  y: number;
}

export const MIN_ZOOM = 1;
export const MAX_ZOOM = 16;

const HOME: Viewport = { zoom: 1, x: 0, y: 0 };
const TICK_MS = 16;
const EASE = 0.22;
const WHEEL_RATE = 0.0022;
const WHEEL_STEP_MAX = 1.6;

function clamp(n: number, lo: number, hi: number): number {
  return Math.min(hi, Math.max(lo, n));
}

function settle(next: Viewport): Viewport {
  const zoom = clamp(next.zoom, MIN_ZOOM, MAX_ZOOM);
  const span = (1 - 1 / zoom) / 2;
  return { zoom, x: clamp(next.x, -span, span), y: clamp(next.y, -span, span) };
}

function same(a: Viewport, b: Viewport): boolean {
  return a.zoom === b.zoom && a.x === b.x && a.y === b.y;
}

export interface MapViewport {
  view: Viewport;
  ref: React.RefObject<HTMLDivElement | null>;
  width: number;
  height: number;
  side: number;
  panning: boolean;
  atHome: boolean;
  zoomBy: (factor: number) => void;
  home: () => void;
  focus: (leftPct: number, topPct: number, zoom?: number) => void;
  toScreen: (leftPct: number, topPct: number) => { left: number; top: number };
  surface: {
    onPointerDown: (e: React.PointerEvent<HTMLDivElement>) => void;
    onWheel: (e: React.WheelEvent<HTMLDivElement>) => void;
  };
}

export function useMapViewport(): MapViewport {
  const ref = useRef<HTMLDivElement | null>(null);
  const [width, setWidth] = useState(0);
  const [height, setHeight] = useState(0);
  const [view, setView] = useState<Viewport>(HOME);
  const [panning, setPanning] = useState(false);

  const live = useRef(view);
  live.current = view;
  const target = useRef<Viewport>(HOME);
  const timer = useRef<number | null>(null);

  const stop = useCallback(() => {
    if (timer.current == null) return;
    window.clearInterval(timer.current);
    timer.current = null;
  }, []);

  const glide = useCallback(() => {
    if (timer.current != null) return;
    timer.current = window.setInterval(() => {
      const cur = live.current;
      const to = target.current;
      const lz = Math.log(cur.zoom);
      const tz = Math.log(to.zoom);
      const nz = lz + (tz - lz) * EASE;
      const nx = cur.x + (to.x - cur.x) * EASE;
      const ny = cur.y + (to.y - cur.y) * EASE;
      const done = Math.abs(tz - nz) < 0.0015 && Math.abs(to.x - nx) < 0.0003 && Math.abs(to.y - ny) < 0.0003;
      const next = done ? to : settle({ zoom: Math.exp(nz), x: nx, y: ny });
      live.current = next;
      setView(next);
      if (done) stop();
    }, TICK_MS);
  }, [stop]);

  useEffect(() => stop, [stop]);

  useLayoutEffect(() => {
    const el = ref.current;
    if (!el) return;
    const ro = new ResizeObserver(() => {
      setWidth(el.clientWidth);
      setHeight(el.clientHeight);
    });
    ro.observe(el);
    setWidth(el.clientWidth);
    setHeight(el.clientHeight);
    return () => ro.disconnect();
  }, []);

  const jump = useCallback(
    (next: Viewport) => {
      stop();
      target.current = next;
      live.current = next;
      setView(next);
    },
    [stop],
  );

  const aim = useCallback(
    (next: Viewport) => {
      if (same(next, target.current)) return;
      target.current = next;
      glide();
    },
    [glide],
  );

  const zoomAt = useCallback(
    (factor: number, ox: number, oy: number) => {
      const prev = target.current;
      const zoom = clamp(prev.zoom * factor, MIN_ZOOM, MAX_ZOOM);
      if (zoom === prev.zoom) return;
      const shift = 1 / prev.zoom - 1 / zoom;
      aim(settle({ zoom, x: prev.x + (ox - 0.5) * shift, y: prev.y + (oy - 0.5) * shift }));
    },
    [aim],
  );

  const zoomBy = useCallback((factor: number) => zoomAt(factor, 0.5, 0.5), [zoomAt]);

  const home = useCallback(() => aim(HOME), [aim]);

  const focus = useCallback(
    (leftPct: number, topPct: number, zoom = 6) => {
      aim(settle({ zoom, x: leftPct / 100 - 0.5, y: topPct / 100 - 0.5 }));
    },
    [aim],
  );

  const onWheel = useCallback(
    (e: React.WheelEvent<HTMLDivElement>) => {
      const el = ref.current;
      if (!el) return;
      const box = el.getBoundingClientRect();
      const factor = clamp(Math.exp(-e.deltaY * WHEEL_RATE), 1 / WHEEL_STEP_MAX, WHEEL_STEP_MAX);
      zoomAt(factor, (e.clientX - box.left) / box.width, (e.clientY - box.top) / box.height);
    },
    [zoomAt],
  );

  const onPointerDown = useCallback(
    (e: React.PointerEvent<HTMLDivElement>) => {
      const el = ref.current;
      if (!el || e.button !== 0) return;

      const originX = e.clientX;
      const originY = e.clientY;
      const start = target.current;
      let dragged = false;

      el.setPointerCapture(e.pointerId);

      const move = (ev: PointerEvent) => {
        const dx = ev.clientX - originX;
        const dy = ev.clientY - originY;
        if (!dragged && Math.hypot(dx, dy) > 4) {
          dragged = true;
          setPanning(true);
        }
        if (!dragged) return;
        jump(
          settle({
            zoom: start.zoom,
            x: start.x - dx / (el.clientWidth * start.zoom),
            y: start.y - dy / (el.clientHeight * start.zoom),
          }),
        );
      };

      const up = (ev: PointerEvent) => {
        el.removeEventListener('pointermove', move);
        el.removeEventListener('pointerup', up);
        el.removeEventListener('pointercancel', up);
        try {
          el.releasePointerCapture(ev.pointerId);
        } catch {
        }
        setPanning(false);
        if (dragged) {
          const swallow = (c: MouseEvent) => {
            c.stopPropagation();
            c.preventDefault();
          };
          el.addEventListener('click', swallow, { capture: true, once: true });
          window.setTimeout(() => el.removeEventListener('click', swallow, true), 0);
        }
      };

      el.addEventListener('pointermove', move);
      el.addEventListener('pointerup', up);
      el.addEventListener('pointercancel', up);
    },
    [jump],
  );

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const block = (e: WheelEvent) => e.preventDefault();
    el.addEventListener('wheel', block, { passive: false });
    return () => el.removeEventListener('wheel', block);
  }, []);

  const toScreen = useCallback(
    (leftPct: number, topPct: number) => ({
      left: ((leftPct / 100 - view.x - 0.5) * view.zoom + 0.5) * 100,
      top: ((topPct / 100 - view.y - 0.5) * view.zoom + 0.5) * 100,
    }),
    [view],
  );

  return {
    view,
    ref,
    width,
    height,
    side: Math.min(width, height) || width,
    panning,
    atHome: same(target.current, HOME) && same(view, HOME),
    zoomBy,
    home,
    focus,
    toScreen,
    surface: { onPointerDown, onWheel },
  };
}
