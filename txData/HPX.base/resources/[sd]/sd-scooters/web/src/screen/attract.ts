import type { Charging, Pricing, Slot, StationView } from './types';

export interface AttractContext {
  station: StationView | null;
  clock: string;
  pricing: Pricing;
  charging: Charging;
  colours: Record<number, string>;
}

type SlideKey = 'welcome' | 'charging' | 'how' | 'docks' | 'pricing';
type ChargeKind = 'charging' | 'ready' | 'idle';

const SLIDE_MS = 7000;
const CHARGING_SLIDE_MS = 9000;
const LEAVE_MS = 650;

const BOLT = '<svg class="a-bolt" viewBox="0 0 24 32" aria-hidden="true"><path d="M14.5 1 3 18h8l-1.5 13L21 13h-8z"/></svg>';
const ICON_SCAN = '<svg viewBox="0 0 32 32" aria-hidden="true"><rect x="8" y="2.5" width="16" height="27" rx="3.5" fill="none" stroke="currentColor" stroke-width="2.4"/><rect x="12.5" y="9" width="7" height="7" rx="1" fill="none" stroke="currentColor" stroke-width="2"/><path d="M12.5 21h7" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"/></svg>';
const ICON_RIDE = '<svg viewBox="0 0 32 32" aria-hidden="true"><circle cx="7" cy="24" r="4" fill="none" stroke="currentColor" stroke-width="2.4"/><circle cx="25" cy="24" r="4" fill="none" stroke="currentColor" stroke-width="2.4"/><path d="M11 24h10l-3-16h4M18 8h-4" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/></svg>';
const ICON_DOCK = '<svg viewBox="0 0 32 32" aria-hidden="true"><path d="M6 29V9a4 4 0 0 1 4-4h2a4 4 0 0 1 4 4v20" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"/><path d="M22 12l-4 7h5l-3 7" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/></svg>';

function escapeHtml(text: string): string {
  return text.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!);
}

export function createAttract(read: () => AttractContext) {
  let host: HTMLElement | null = null;
  let stage: HTMLElement | null = null;
  let progress: HTMLElement | null = null;
  let clockEl: HTMLElement | null = null;
  let current: HTMLElement | null = null;
  let currentKey: SlideKey | null = null;
  let order: SlideKey[] = [];
  let position = -1;
  let timer = 0;
  let shownFor: string | null = null;
  let lastStation: StationView | null = null;

  function context(): AttractContext {
    const ctx = read();
    if (ctx.station) lastStation = ctx.station;
    return ctx.station || !lastStation ? ctx : { ...ctx, station: lastStation };
  }

  const docked = (ctx: AttractContext) =>
    (ctx.station?.slots ?? []).map((slot, i) => ({ slot, dock: i + 1 })).filter((d): d is { slot: Exclude<Slot, false>; dock: number } => !!d.slot);

  const level = (slot: Exclude<Slot, false>) => Math.max(0, Math.min(100, Math.round(slot.battery ?? 0)));

  function kindOf(ctx: AttractContext, slot: Exclude<Slot, false>): ChargeKind {
    const lvl = level(slot);
    if (slot.full || lvl >= ctx.charging.fullAt) return 'ready';
    if (!ctx.charging.paid) return 'charging';
    return slot.target && slot.target > lvl ? 'charging' : 'idle';
  }

  const minutes = (ctx: AttractContext, percent: number) => Math.max(1, Math.ceil(percent / Math.max(0.01, ctx.charging.perMinute)));
  const money = (ctx: AttractContext, amount: number) => `${ctx.pricing.currency}${Number.isInteger(amount) ? amount : amount.toFixed(2)}`;

  function note(ctx: AttractContext, slot: Exclude<Slot, false>, kind: ChargeKind): string {
    const lvl = level(slot);
    if (kind === 'ready') return 'Ready to ride';
    if (kind === 'idle') return 'Connected &middot; tap the screen to charge';
    const goal = ctx.charging.paid && slot.target ? slot.target : ctx.charging.fullAt;
    return goal >= ctx.charging.fullAt ? `Full in ${minutes(ctx, goal - lvl)} min` : `To ${goal}% in ${minutes(ctx, goal - lvl)} min`;
  }

  function freeLabel(free: number): string {
    return free === 0 ? 'Station full' : free === 1 ? 'dock free' : 'docks free';
  }

  function plan(ctx: AttractContext): SlideKey[] {
    if (!ctx.station) return ['welcome', 'how', 'pricing'];
    const base: SlideKey[] = ['welcome', 'how', 'docks', 'pricing'];
    const cars = docked(ctx);
    if (!cars.length) return base;
    if (cars.some((d) => kindOf(ctx, d.slot) === 'charging')) return base.flatMap((k) => [k, 'charging' as SlideKey]);
    return ['welcome', 'charging', 'how', 'docks', 'pricing'];
  }

  function strip(ctx: AttractContext): string {
    const slots = ctx.station?.slots ?? [];
    return slots.map((slot) => `<i class="${slot ? `on on--${kindOf(ctx, slot)}` : ''}"></i>`).join('');
  }

  function row(ctx: AttractContext, slot: Exclude<Slot, false>, dock: number, i: number): string {
    const lvl = level(slot);
    const kind = kindOf(ctx, slot);
    const paint = ctx.colours[slot.colour ?? 0] ?? '#8a9199';
    return `<li class="a-row a-row--${kind}" data-dock="${dock}" style="--i:${i + 2}">
      <div class="a-row__dock">${dock}</div>
      <div class="a-row__main">
        <div class="a-row__top"><span class="a-paint" style="background:${paint}"></span><b>${escapeHtml(slot.plate ?? 'Scooter')}</b><em data-pct>${lvl}%</em></div>
        <div class="a-bar"><i data-bar style="width:${lvl}%"></i></div>
        <div class="a-row__note" data-note>${note(ctx, slot, kind)}</div>
      </div>
    </li>`;
  }

  function slideHtml(key: SlideKey, ctx: AttractContext): string {
    const st = ctx.station;
    switch (key) {
      case 'welcome':
        return `<div class="a-watermark">${BOLT}</div>
          ${st ? `<div class="a-eyebrow" style="--i:0">${escapeHtml(st.name)}</div>` : ''}
          <h1 class="a-hero"><span style="--i:1">Charge</span><span style="--i:2">here.</span></h1>
          <p class="a-lede" style="--i:3">Roll your scooter into a free dock. It locks in and starts charging on its own.</p>
          ${st ? `<div class="a-strip" style="--i:4"><div class="a-strip__cells" data-strip>${strip(ctx)}</div><span data-strip-label>${st.free === 0 ? 'All docks in use' : `${st.free} ${freeLabel(st.free)}`}</span></div>` : ''}`;
      case 'charging': {
        const cars = docked(ctx);
        return `<div class="a-eyebrow a-eyebrow--live" style="--i:0"><span class="a-live"></span>Live at this station</div>
          <h2 class="a-title" style="--i:1" data-charging-title>${chargingTitle(ctx)}</h2>
          <ul class="a-rows${cars.length >= 4 ? ' a-rows--dense' : ''}" data-rows="${cars.map((d) => d.dock).join(',')}">${cars.slice(0, 4).map((d, i) => row(ctx, d.slot, d.dock, i)).join('')}</ul>`;
      }
      case 'how':
        return `<div class="a-eyebrow" style="--i:0">How it works</div>
          <h2 class="a-title" style="--i:1">Three steps.</h2>
          <ol class="a-steps">
            <li style="--i:2"><div class="a-step__icon">${ICON_SCAN}</div><div><b>Scan</b><span>Unlock the nearest scooter in the Scoot app</span></div></li>
            <li style="--i:3"><div class="a-step__icon">${ICON_RIDE}</div><div><b>Ride</b><span>Pay by the minute, go anywhere in the city</span></div></li>
            <li style="--i:4"><div class="a-step__icon">${ICON_DOCK}</div><div><b>Dock</b><span>Roll into any free dock to end and recharge</span></div></li>
          </ol>`;
      case 'docks': {
        const total = st?.slots.length ?? 0;
        const free = st?.free ?? 0;
        return `<div class="a-eyebrow" style="--i:0">Right now</div>
          <div class="a-count" style="--i:1">
            <div class="a-ring"><svg viewBox="0 0 120 120" aria-hidden="true"><circle class="a-ring__track" cx="60" cy="60" r="52"/><circle class="a-ring__fill" data-ring cx="60" cy="60" r="52" style="stroke-dashoffset:${ringOffset(free, total)}"/></svg><span data-free>${free}</span></div>
            <div class="a-count__text"><b data-free-label>${freeLabel(free)}</b><span data-of>of ${total} at this station</span></div>
          </div>
          <p class="a-lede" style="--i:2" data-docks-lede>${free === 0 ? 'Every dock is charging a scooter. The nearest station is on the Scoot map.' : 'Ending your ride here? Roll straight in, the dock does the rest.'}</p>`;
      }
      case 'pricing':
        return `<div class="a-eyebrow" style="--i:0">Simple pricing</div>
          <div class="a-prices">
            <div class="a-price" style="--i:1"><span class="a-price__big">${money(ctx, ctx.pricing.unlock)}</span><span class="a-price__label">one-time fare</span></div>
            <div class="a-price" style="--i:2"><span class="a-price__big">&infin;</span><span class="a-price__label">ride as long as you like</span></div>
          </div>
          <div class="a-chip" style="--i:3">${BOLT}${ctx.charging.paid ? `Charging ${money(ctx, ctx.charging.pricePerPercent * 10)} per 10% here` : 'Charging here is free'}</div>`;
    }
  }

  function chargingTitle(ctx: AttractContext): string {
    const cars = docked(ctx);
    const active = cars.filter((d) => kindOf(ctx, d.slot) === 'charging').length;
    if (active) return `${active} charging`;
    const ready = cars.filter((d) => kindOf(ctx, d.slot) === 'ready').length;
    return ready === cars.length ? `${ready} ready to ride` : `${cars.length} docked`;
  }

  function ringOffset(free: number, total: number): number {
    const circumference = 2 * Math.PI * 52;
    return circumference * (1 - (total ? free / total : 0));
  }

  function mount(el: HTMLElement): void {
    stop();
    host = el;
    host.innerHTML = `<div class="attract">
        <div class="a-bg" aria-hidden="true"><i class="a-orb a-orb--1"></i><i class="a-orb a-orb--2"></i><i class="a-orb a-orb--3"></i><i class="a-lines"></i></div>
        <div class="a-top"><div class="a-brand">${BOLT}<span>Scoot</span></div><div class="a-clock"></div></div>
        <div class="a-stage"></div>
        <div class="a-progress"></div>
      </div>`;
    stage = host.querySelector('.a-stage');
    progress = host.querySelector('.a-progress');
    clockEl = host.querySelector('.a-clock');
    position = -1;
    shownFor = context().station?.name ?? null;
    advance();
  }

  function advance(): void {
    if (!host || !stage) return;
    const ctx = context();
    order = plan(ctx);
    position = (position + 1) % order.length;
    if (order.length > 1 && order[position] === currentKey) position = (position + 1) % order.length;
    const key = order[position];
    const duration = key === 'charging' ? CHARGING_SLIDE_MS : SLIDE_MS;
    const next = document.createElement('section');
    next.className = `slide slide--${key} is-in`;
    next.innerHTML = slideHtml(key, ctx);
    stage.appendChild(next);
    const old = current;
    if (old) {
      old.classList.remove('is-in');
      old.classList.add('is-out');
      window.setTimeout(() => old.remove(), LEAVE_MS);
    }
    current = next;
    currentKey = key;
    drawProgress(duration);
    if (clockEl) clockEl.textContent = ctx.clock;
    window.clearTimeout(timer);
    timer = window.setTimeout(advance, duration);
  }

  function drawProgress(duration: number): void {
    if (!progress) return;
    progress.innerHTML = order
      .map((_, i) => `<i class="${i < position ? 'done' : i === position ? 'now' : ''}"${i === position ? ` style="animation-duration:${duration}ms"` : ''}></i>`)
      .join('');
  }

  function update(): void {
    if (!host || !current) return;
    const ctx = context();
    if ((ctx.station?.name ?? null) !== shownFor) {
      shownFor = ctx.station?.name ?? null;
      if (currentKey && !plan(ctx).includes(currentKey)) {
        advance();
        return;
      }
      if (currentKey === 'welcome' || currentKey === 'charging' || currentKey === 'docks') {
        current.classList.add('is-refresh');
        current.innerHTML = slideHtml(currentKey, ctx);
      }
    }
    if (clockEl && clockEl.textContent !== ctx.clock) clockEl.textContent = ctx.clock;
    const st = ctx.station;
    if (currentKey === 'welcome' && st) {
      const cells = current.querySelector<HTMLElement>('[data-strip]');
      const html = strip(ctx);
      if (cells && cells.innerHTML !== html) cells.innerHTML = html;
      const label = current.querySelector<HTMLElement>('[data-strip-label]');
      const text = st.free === 0 ? 'All docks in use' : `${st.free} ${freeLabel(st.free)}`;
      if (label && label.textContent !== text) label.textContent = text;
    } else if (currentKey === 'charging') {
      const cars = docked(ctx);
      const list = current.querySelector<HTMLElement>('[data-rows]');
      if (!list) return;
      if (list.dataset.rows !== cars.map((d) => d.dock).join(',')) {
        list.dataset.rows = cars.map((d) => d.dock).join(',');
        list.innerHTML = cars.slice(0, 4).map((d, i) => row(ctx, d.slot, d.dock, i)).join('');
        list.classList.add('a-rows--settled');
        list.classList.toggle('a-rows--dense', cars.length >= 4);
      } else {
        for (const d of cars.slice(0, 4)) {
          const el = list.querySelector<HTMLElement>(`[data-dock="${d.dock}"]`);
          if (!el) continue;
          const lvl = level(d.slot);
          const kind = kindOf(ctx, d.slot);
          el.className = `a-row a-row--${kind}`;
          el.querySelector<HTMLElement>('[data-bar]')!.style.width = `${lvl}%`;
          el.querySelector<HTMLElement>('[data-pct]')!.textContent = `${lvl}%`;
          const n = note(ctx, d.slot, kind);
          const noteEl = el.querySelector<HTMLElement>('[data-note]')!;
          if (noteEl.innerHTML !== n) noteEl.innerHTML = n;
        }
      }
      const title = current.querySelector<HTMLElement>('[data-charging-title]');
      if (title) title.textContent = chargingTitle(ctx);
    } else if (currentKey === 'docks' && st) {
      const total = st.slots.length;
      current.querySelector<SVGCircleElement>('[data-ring]')?.style.setProperty('stroke-dashoffset', String(ringOffset(st.free, total)));
      const free = current.querySelector<HTMLElement>('[data-free]');
      if (free) free.textContent = String(st.free);
      const label = current.querySelector<HTMLElement>('[data-free-label]');
      if (label) label.textContent = freeLabel(st.free);
    }
  }

  function stop(): void {
    window.clearTimeout(timer);
    host = stage = progress = clockEl = current = null;
    currentKey = null;
  }

  return {
    mount,
    update,
    stop,
    owns: (el: HTMLElement | null) => !!el && el === host,
  };
}
