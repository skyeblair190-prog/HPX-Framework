import '@fontsource/barlow-semi-condensed/500.css';
import '@fontsource/barlow-semi-condensed/700.css';
import '@fontsource/barlow-semi-condensed/800.css';
import './screen.css';
import './attract.css';
import { createAttract } from './attract';
import type { Charging, Method, Pricing, Slot, StationView, Toast } from './types';
interface ScreenMessage {
  station?: StationView | null;
  colours?: Record<number, string>;
  time?: string;
  pricing?: Pricing;
  payment?: { methods: Method[] };
  charging?: Charging;
  toast?: Toast;
  brightness?: number;
  panel?: 'close';
  wakeMs?: number;
  viewing?: boolean;
}
type ViewKind = 'idle' | 'docks' | 'dock' | 'charge' | 'confirm';
const VIEW_RANK: Record<ViewKind, number> = { idle: 0, docks: 1, dock: 2, charge: 3, confirm: 4 };
const METHOD_LABEL: Record<Method, { name: string; hint: string }> = {
  bank: { name: 'Card', hint: 'Paid from your bank account' },
  cash: { name: 'Cash', hint: 'Paid from the cash you carry' },
};

const TOAST_MS = 4000;
const BUSY_MS = 6000;
const VIEW_MS = 280;
const HANDOFF_MS = 1250;
let wakeMs = 120000;

const root = document.getElementById('root')!;
let colours: Record<number, string> = {};
let station: StationView | null = null;
let clock = '';
let pricing: Pricing = { unlock: 5, currency: '$' };
let methods: Method[] = ['bank'];
let charging: Charging = { paid: false, pricePerPercent: 0, minimumFee: 0, step: 5, presets: [50, 75, 100], perMinute: 5, drainPerMinute: 2.5, minToRent: 15, fullAt: 100 };
let busySlot: number | null = null;
let busyTimer = 0;
let toast: Toast | null = null;
let toastTimer = 0;
let panel: { slot: number; scooterId: number; target: number } | null = null;
let detail: { slot: number; scooterId: number } | null = null;
let confirm: { kind: 'charge' | 'unlock'; slot: number; scooterId: number; target?: number; method: Method } | null = null;
let dragging = false;
let viewing = false;
let awakeUntil = 0;
let awakeFor: string | null = null;
let sleepTimer = 0;
let currentView: ViewKind | null = null;
let viewEl: HTMLElement | null = null;
let viewHtml = '';
let headEl: HTMLElement | null = null;
let bodyEl: HTMLElement | null = null;

const BOLT = '<svg class="bolt" viewBox="0 0 24 32" aria-hidden="true"><path d="M14.5 1 3 18h8l-1.5 13L21 13h-8z"/></svg>';
const CARD = '<svg viewBox="0 0 32 24" aria-hidden="true"><rect x="1.5" y="2.5" width="29" height="19" rx="3" fill="none" stroke="currentColor" stroke-width="2.5"/><rect x="1.5" y="7" width="29" height="4" fill="currentColor"/><rect x="5" y="14.5" width="9" height="3" rx="1" fill="currentColor"/></svg>';
const CASH = '<svg viewBox="0 0 32 24" aria-hidden="true"><rect x="1.5" y="4.5" width="29" height="15" rx="2.5" fill="none" stroke="currentColor" stroke-width="2.5"/><circle cx="16" cy="12" r="4" fill="none" stroke="currentColor" stroke-width="2.5"/><circle cx="6.5" cy="12" r="1.5" fill="currentColor"/><circle cx="25.5" cy="12" r="1.5" fill="currentColor"/></svg>';

function resourceName(): string {
  const w = window as unknown as { GetParentResourceName?: () => string };
  return typeof w.GetParentResourceName === 'function' ? w.GetParentResourceName() : location.hostname;
}

function post(action: string, body: Record<string, unknown>): Promise<Response> {
  return fetch(`https://${resourceName()}/${action}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(body),
  });
}

function level(slot: Exclude<Slot, false>): number {
  return Math.max(0, Math.min(100, Math.round(slot.battery ?? 0)));
}

function state(lvl: number, full: boolean): 'ready' | 'low' | 'charging' {
  if (full || lvl >= charging.fullAt) return 'ready';
  if (lvl < charging.minToRent) return 'low';
  return 'charging';
}

function minutesFor(percent: number): number {
  return Math.max(0, Math.ceil(percent / Math.max(0.01, charging.perMinute)));
}

function rideMinutes(lvl: number): number {
  return Math.max(0, Math.floor(lvl / Math.max(0.01, charging.drainPerMinute)));
}

function money(amount: number): string {
  const whole = Number.isInteger(amount) ? String(amount) : amount.toFixed(2);
  return `${pricing.currency}${whole}`;
}

function priceFor(adds: number): number {
  return Math.max(charging.minimumFee, Math.ceil(adds * charging.pricePerPercent));
}

function slotAt(n: number): Exclude<Slot, false> | null {
  const s = station?.slots[n - 1];
  return s ? s : null;
}

function gauge(lvl: number, extra = 0): string {
  const cells = 5;
  const lit = Math.round((lvl / 100) * cells);
  const planned = Math.round(((lvl + extra) / 100) * cells);
  let out = '';
  for (let i = 0; i < cells; i++) out += `<i class="${i < lit ? 'on' : i < planned ? 'plan' : ''}"></i>`;
  return `<div class="gauge" aria-hidden="true">${out}</div>`;
}

function rowNote(slot: Exclude<Slot, false>, lvl: number, kind: 'ready' | 'low' | 'charging'): string {
  if (slot.target && slot.target > lvl) return `Charging to ${slot.target}%, ${minutesFor(slot.target - lvl)} min left`;
  if (kind === 'ready') return 'Ready to ride';
  if (!charging.paid) return `${kind === 'low' ? 'Low, ' : 'Charging, '}${minutesFor(charging.fullAt - lvl)} min to full`;
  return kind === 'low' ? 'Low, not charging' : 'Docked, not charging';
}

function dockRow(slot: Slot, index: number): string {
  const number = index + 1;
  if (!slot) {
    return `<li class="dock dock--free">
      <div class="dock__tile">${number}</div>
      <div class="dock__text"><div class="dock__title">Free</div><div class="dock__note">Roll a scooter in to charge it</div></div>
    </li>`;
  }
  const lvl = level(slot);
  const kind = state(lvl, slot.full);
  const paint = colours[slot.colour ?? 0] ?? '#8a9199';
  const active = !!slot.target && slot.target > lvl;
  return `<li class="dock dock--${kind}${active ? ' dock--active' : ''} dock--open" data-open="${number}">
    <div class="dock__tile">${number}</div>
    <div class="dock__text">
      <div class="dock__title"><span class="dock__paint" style="background:${paint}"></span>${slot.plate ?? 'Scooter'}</div>
      <div class="dock__note">${rowNote(slot, lvl, kind)}</div>
      ${gauge(lvl, active ? (slot.target ?? lvl) - lvl : 0)}
    </div>
    <div class="dock__level">${lvl}<span>%</span></div>
    <div class="dock__chev" aria-hidden="true"></div>
  </li>`;
}

function dockDetail(): string {
  if (!detail) return '';
  const slot = slotAt(detail.slot);
  if (!slot) return '';
  const lvl = level(slot);
  const kind = state(lvl, slot.full);
  const paint = colours[slot.colour ?? 0] ?? '#8a9199';
  const active = !!slot.target && slot.target > lvl;
  const busy = busySlot === detail.slot;
  const toFull = charging.fullAt - lvl;
  const facts = [
    { label: 'Ride time', value: `${rideMinutes(lvl)} min`, hint: 'at this charge' },
    { label: 'Unlock', value: money(pricing.unlock), hint: 'one-time fare' },
    toFull > 0 ? { label: 'To full', value: `${minutesFor(toFull)} min`, hint: active ? `charging to ${slot.target}%` : 'once charging' } : { label: 'Battery', value: 'Full', hint: 'ready to go' },
    charging.paid && toFull > 0 ? { label: 'Full charge', value: money(priceFor(toFull)), hint: `${toFull}% at ${money(charging.pricePerPercent * 10)} per 10%` } : { label: 'Charging', value: charging.paid ? 'Done' : 'Free', hint: charging.paid ? 'nothing to add' : 'at this station' },
  ];
  const grid = facts.map((f) => `<div class="fact"><div class="fact__label">${f.label}</div><div class="fact__value">${f.value}</div><div class="fact__hint">${f.hint}</div></div>`).join('');
  let chargeBtn = '';
  if (charging.paid && lvl < charging.fullAt) {
    const more = slot.target && slot.target >= charging.fullAt
      ? '<button class="btn btn--big btn--grow btn--quiet" type="button" disabled>Charging to full</button>'
      : `<button class="btn btn--big ${active ? 'btn--grow' : 'btn--full'} btn--dark" type="button" data-charge="${detail.slot}" ${busy ? 'disabled' : ''}>${active ? 'Charge further' : 'Charge this scooter'}</button>`;
    chargeBtn = active
      ? `<div class="charge__actions">${more}<button class="btn btn--big btn--grow btn--stop" type="button" data-stop="${detail.slot}" ${busy ? 'disabled' : ''}>${busy ? 'Working' : 'Stop charging'}</button></div>`
      : more;
  }
  const unlockBtn = lvl < charging.minToRent
    ? '<button class="btn btn--big btn--grow btn--quiet" type="button" disabled>Needs charge to unlock</button>'
    : `<button class="btn btn--big btn--grow btn--pay" type="button" data-unlock="${detail.slot}" ${busy ? 'disabled' : ''}>${busy ? 'Working' : `Unlock for ${money(pricing.unlock)}`}</button>`;
  return `<section class="detail detail--${kind}${active ? ' detail--active' : ''}">
    <div class="charge__head">
      <div class="charge__eyebrow">Dock ${detail.slot}</div>
      <h2 class="charge__title"><span class="dock__paint dock__paint--lg" style="background:${paint}"></span>${slot.plate ?? 'Scooter'}</h2>
      <div class="charge__now">${rowNote(slot, lvl, kind)}</div>
    </div>
    <div class="detail__battery">
      <div class="detail__level">${lvl}<span>%</span></div>
      <div class="detail__bar"><div class="detail__now" style="width:${lvl}%"></div>${active ? `<div class="detail__plan" style="left:${lvl}%;width:${(slot.target ?? lvl) - lvl}%"></div>` : ''}</div>
      <div class="detail__scale"><span>0</span><span>50</span><span>100</span></div>
    </div>
    <div class="facts">${grid}</div>
    <div class="detail__actions">
      ${chargeBtn}
      <div class="charge__actions">
        <button class="btn btn--big btn--back" type="button" data-back>Back</button>
        ${unlockBtn}
      </div>
    </div>
  </section>`;
}

interface PanelMath { slot: Exclude<Slot, false>; lvl: number; bought: number | null; min: number; target: number; adds: number; cost: number; minutes: number }

function panelMath(): PanelMath | null {
  if (!panel) return null;
  const slot = slotAt(panel.slot);
  if (!slot) return null;
  const lvl = level(slot);
  const bought = slot.target && slot.target > lvl ? slot.target : null;
  const floor = (bought ?? lvl) + charging.step;
  const min = Math.min(charging.fullAt, Math.ceil(floor / charging.step) * charging.step);
  const target = Math.max(min, Math.min(charging.fullAt, panel.target));
  panel.target = target;
  const adds = target - (bought ?? lvl);
  return { slot, lvl, bought, min, target, adds, cost: priceFor(adds), minutes: minutesFor(target - lvl) };
}

function chargePanel(): string {
  const m = panelMath();
  if (!m || !panel) return '';
  const presets = charging.presets.filter((p) => p >= m.min && p <= charging.fullAt);
  const chips = presets.map((p) => `<button class="chip${p === m.target ? ' chip--on' : ''}" type="button" data-target="${p}">${p >= charging.fullAt ? 'Full' : `${p}%`}</button>`).join('');
  return `<section class="charge">
    <div class="charge__head">
      <div class="charge__eyebrow">Dock ${panel.slot}</div>
      <h2 class="charge__title">Charge ${m.slot.plate ?? 'scooter'}</h2>
      <div class="charge__now">Battery now ${m.lvl}%${m.bought ? `, already charging to ${m.bought}%` : ''}</div>
    </div>
    <div class="picker">
      <button class="picker__step" type="button" data-step="-1" ${m.target <= m.min ? 'disabled' : ''} aria-label="Lower">&minus;</button>
      <div class="picker__value">${m.target}<span>%</span></div>
      <button class="picker__step" type="button" data-step="1" ${m.target >= charging.fullAt ? 'disabled' : ''} aria-label="Higher">+</button>
    </div>
    <div class="chips">${chips}</div>
    <div class="slider" data-slider>
      <div class="slider__rail">
        <div class="slider__now" style="width:${m.lvl}%"></div>
        <div class="slider__plan" style="left:${m.lvl}%;width:${m.target - m.lvl}%"></div>
      </div>
      <div class="slider__knob" style="left:${m.target}%"><span>${m.target}</span></div>
      <div class="slider__hint">Drag to set the charge</div>
    </div>
    <dl class="quote">
      <div><dt>Adds</dt><dd data-adds>${m.adds}%</dd></div>
      <div><dt>Takes about</dt><dd data-minutes>${m.minutes} min</dd></div>
      <div class="quote__cost"><dt>Cost</dt><dd data-cost>${money(m.cost)}</dd></div>
    </dl>
    <div class="charge__actions">
      <button class="btn btn--back" type="button" data-back>Back</button>
      <button class="btn btn--pay" type="button" data-continue>Continue</button>
    </div>
  </section>`;
}

function patchPanel(): void {
  const m = panelMath();
  if (!m || !viewEl || currentView !== 'charge') return render();
  const q = <T extends Element>(s: string) => viewEl!.querySelector<T>(s);
  const value = q<HTMLElement>('.picker__value');
  if (value) value.innerHTML = `${m.target}<span>%</span>`;
  q<HTMLButtonElement>('[data-step="-1"]')!.disabled = m.target <= m.min;
  q<HTMLButtonElement>('[data-step="1"]')!.disabled = m.target >= charging.fullAt;
  viewEl.querySelectorAll<HTMLButtonElement>('.chip').forEach((c) => c.classList.toggle('chip--on', Number(c.dataset.target) === m.target));
  const plan = q<HTMLElement>('.slider__plan');
  if (plan) plan.style.width = `${m.target - m.lvl}%`;
  const knob = q<HTMLElement>('.slider__knob');
  if (knob) {
    knob.style.left = `${m.target}%`;
    knob.firstElementChild!.textContent = String(m.target);
  }
  q<HTMLElement>('[data-adds]')!.textContent = `${m.adds}%`;
  q<HTMLElement>('[data-minutes]')!.textContent = `${m.minutes} min`;
  q<HTMLElement>('[data-cost]')!.textContent = money(m.cost);
}

function confirmView(): string {
  if (!confirm) return '';
  const slot = slotAt(confirm.slot);
  if (!slot) return '';
  const lvl = level(slot);
  const busy = busySlot === confirm.slot;
  let rows = '';
  let total = 0;
  let title = '';
  if (confirm.kind === 'charge') {
    const target = confirm.target ?? charging.fullAt;
    const bought = slot.target && slot.target > lvl ? slot.target : null;
    const adds = target - (bought ?? lvl);
    total = priceFor(adds);
    title = 'Confirm charge';
    rows = `<div><dt>Scooter</dt><dd>${slot.plate ?? 'Scooter'}</dd></div>
      <div><dt>Charge</dt><dd>${bought ?? lvl}% to ${target}%</dd></div>
      <div><dt>Takes about</dt><dd>${minutesFor(target - lvl)} min</dd></div>`;
  } else {
    total = pricing.unlock;
    title = 'Confirm unlock';
    rows = `<div><dt>Scooter</dt><dd>${slot.plate ?? 'Scooter'}</dd></div>
      <div><dt>Battery</dt><dd>${lvl}%, about ${rideMinutes(lvl)} min</dd></div>
      <div><dt>Ride</dt><dd>As long as you like</dd></div>`;
  }
  const options = methods.map((m) => `<button class="method${confirm!.method === m ? ' method--on' : ''}" type="button" data-method="${m}">
      <span class="method__icon">${m === 'bank' ? CARD : CASH}</span>
      <span class="method__text"><span class="method__name">${METHOD_LABEL[m].name}</span><span class="method__hint">${METHOD_LABEL[m].hint}</span></span>
      <span class="method__tick" aria-hidden="true"><svg viewBox="0 0 16 16"><polyline points="3.2,8.4 6.6,11.6 12.8,4.6" fill="none" stroke="#ffffff" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/></svg></span>
    </button>`).join('');
  return `<section class="confirm">
    <div class="charge__head">
      <div class="charge__eyebrow">Dock ${confirm.slot}</div>
      <h2 class="charge__title">${title}</h2>
    </div>
    <dl class="quote">
      ${rows}
      <div class="quote__cost"><dt>Total</dt><dd>${money(total)}</dd></div>
    </dl>
    <div class="confirm__label">Pay with</div>
    <div class="methods">${options}</div>
    <div class="charge__actions">
      <button class="btn btn--back" type="button" data-back>Back</button>
      <button class="btn btn--pay" type="button" data-confirm ${busy ? 'disabled' : ''}>${busy ? 'Paying' : `Pay ${money(total)} by ${METHOD_LABEL[confirm.method].name.toLowerCase()}`}</button>
    </div>
  </section>`;
}

function shell(): void {
  if (headEl && bodyEl) return;
  root.innerHTML = `<div class="screen">
    <header class="head" id="head">
      <div class="head__row"><div class="brand">${BOLT}<span>Scoot</span></div><div class="clock" data-clock></div></div>
      <h1 class="head__name" data-name></h1>
      <div class="head__summary"><span data-summary></span><span class="head__sub" data-sub></span></div>
    </header>
    <div class="screen__body" id="body"></div>
  </div>`;
  headEl = document.getElementById('head');
  bodyEl = document.getElementById('body');
}

function setText(sel: string, text: string): void {
  const el = headEl?.querySelector<HTMLElement>(sel);
  if (el && el.textContent !== text) el.textContent = text;
}

function renderHead(): void {
  if (!headEl || !station) return;
  headEl.hidden = false;
  const inUse = station.slots.filter(Boolean).length;
  setText('[data-clock]', clock);
  setText('[data-name]', station.name);
  setText('[data-summary]', station.free === 0 ? 'All docks in use' : station.free === 1 ? '1 dock free' : `${station.free} docks free`);
  setText('[data-sub]', `${inUse} of ${station.slots.length} docked`);
}

function swapView(kind: ViewKind, html: string): void {
  shell();
  if (currentView === kind && viewEl) {
    if (viewHtml !== html) {
      viewEl.innerHTML = html;
      viewHtml = html;
    }
    return;
  }
  viewHtml = html;
  const forward = !currentView || VIEW_RANK[kind] > VIEW_RANK[currentView];
  const old = viewEl;
  const next = document.createElement('div');
  const waking = !!old && currentView === 'idle' && kind !== 'idle';
  const sleeping = !!old && currentView !== 'idle' && kind === 'idle';
  const enter = waking ? 'view--wake' : sleeping ? 'view--sleep' : old ? (forward ? 'view--enter-right' : 'view--enter-left') : 'view--enter-fade';
  next.className = `view view--${kind} ${enter}`;
  next.innerHTML = html;
  bodyEl!.appendChild(next);
  if (old) {
    old.style.pointerEvents = 'none';
    if (waking) {
      old.classList.add('view--handoff');
      root.appendChild(old);
      headEl?.classList.remove('head--wake');
      void headEl?.offsetWidth;
      headEl?.classList.add('head--wake');
      window.setTimeout(() => old.remove(), HANDOFF_MS + 40);
      window.setTimeout(() => {
        next.classList.remove('view--wake');
        headEl?.classList.remove('head--wake');
      }, HANDOFF_MS + 40);
    } else if (sleeping) {
      old.classList.add('view--dismiss');
      window.setTimeout(() => old.remove(), HANDOFF_MS + 40);
    } else {
      old.classList.add(forward ? 'view--leave-left' : 'view--leave-right');
      window.setTimeout(() => old.remove(), VIEW_MS + 40);
    }
  }
  viewEl = next;
  currentView = kind;
}

const attract = createAttract(() => ({ station, clock, pricing, charging, colours }));

function wake(ms: number, forStation: string | null): void {
  awakeUntil = Date.now() + ms;
  awakeFor = forStation;
  window.clearTimeout(sleepTimer);
  sleepTimer = window.setTimeout(render, ms + 50);
}

function asleep(): boolean {
  if (viewing || panel || detail || confirm) return false;
  return Date.now() >= awakeUntil || station?.name !== awakeFor;
}

function newlyDocked(prev: StationView | null, next: StationView | null): boolean {
  if (!prev || !next || prev.name !== next.name) return false;
  return next.slots.some((slot, i) => {
    const before = prev.slots[i];
    return !!slot && (!before || before.scooterId !== slot.scooterId);
  });
}

function render(): void {
  shell();
  if (!station || asleep()) {
    panel = null;
    detail = null;
    confirm = null;
    if (headEl) headEl.hidden = true;
    if (currentView === 'idle' && attract.owns(viewEl)) {
      attract.update();
    } else {
      swapView('idle', '');
      attract.mount(viewEl!);
    }
    return;
  }
  attract.stop();
  if (panel) {
    const slot = slotAt(panel.slot);
    if (!slot || slot.scooterId !== panel.scooterId || level(slot) >= charging.fullAt) panel = null;
  }
  if (confirm) {
    const slot = slotAt(confirm.slot);
    if (!slot || slot.scooterId !== confirm.scooterId) confirm = null;
  }
  if (detail) {
    const slot = slotAt(detail.slot);
    if (!slot || slot.scooterId !== detail.scooterId) {
      detail = null;
      panel = null;
      confirm = null;
    }
  }
  renderHead();
  if (confirm) swapView('confirm', confirmView());
  else if (panel) swapView('charge', chargePanel());
  else if (detail) swapView('dock', dockDetail());
  else swapView('docks', `<ol class="docks">${station.slots.map(dockRow).join('')}</ol>${footer()}`);
}

function footer(): string {
  if (charging.paid) return `<footer class="foot">Tap a dock to charge or unlock its scooter. Charging costs ${money(charging.pricePerPercent * 10)} per 10%.</footer>`;
  return `<footer class="foot">Tap a dock to unlock its scooter for ${money(pricing.unlock)}, or use the Scoot app.</footer>`;
}

let toastEl: HTMLElement | null = null;
let toastHideTimer = 0;

function paintToast(): void {
  if (!toastEl) {
    toastEl = document.createElement('div');
    toastEl.className = 'toast toast--off';
    root.appendChild(toastEl);
  }
  window.clearTimeout(toastHideTimer);
  if (!toast) {
    if (!toastEl.classList.contains('toast--off')) {
      toastEl.classList.add('toast--out');
      const el = toastEl;
      toastHideTimer = window.setTimeout(() => el.classList.add('toast--off'), 260);
    }
    return;
  }
  toastEl.className = `toast toast--${toast.kind}`;
  toastEl.innerHTML = `<span class="toast__dot"></span><span class="toast__text">${toast.text}</span>`;
}

function showToast(next: Toast): void {
  toast = next;
  window.clearTimeout(toastTimer);
  toastTimer = window.setTimeout(() => {
    toast = null;
    paintToast();
  }, TOAST_MS);
  if (busySlot !== null) {
    busySlot = null;
    window.clearTimeout(busyTimer);
  }
  if (next.kind === 'ok') {
    confirm = null;
    panel = null;
  }
  render();
  paintToast();
}

function setBusy(slot: number): void {
  busySlot = slot;
  window.clearTimeout(busyTimer);
  busyTimer = window.setTimeout(() => {
    busySlot = null;
    render();
  }, BUSY_MS);
  render();
}

function openDetail(slot: number): void {
  const s = slotAt(slot);
  if (!s) return;
  detail = { slot, scooterId: s.scooterId };
  panel = null;
  confirm = null;
  render();
}

function openPanel(slot: number): void {
  const s = slotAt(slot);
  if (!s) return;
  const lvl = level(s);
  const base = s.target && s.target > lvl ? s.target : lvl;
  const preset = charging.presets.find((p) => p > base) ?? charging.fullAt;
  detail = detail ?? { slot, scooterId: s.scooterId };
  panel = { slot, scooterId: s.scooterId, target: preset };
  render();
}

function openConfirm(kind: 'charge' | 'unlock', slot: number): void {
  const s = slotAt(slot);
  if (!s) return;
  confirm = { kind, slot, scooterId: s.scooterId, target: kind === 'charge' ? panel?.target : undefined, method: confirm?.method ?? methods[0] ?? 'bank' };
  render();
}

function stopCharge(slot: number): void {
  if (busySlot !== null) return;
  setBusy(slot);
  post('scoot:screen:stopCharge', { slot, account: methods[0] }).catch(() => showToast({ text: 'The station did not answer. Try again.', kind: 'error' }));
}

function submit(): void {
  if (!confirm || busySlot !== null) return;
  setBusy(confirm.slot);
  const fail = () => showToast({ text: 'The station did not answer. Try again.', kind: 'error' });
  if (confirm.kind === 'charge') post('scoot:screen:charge', { slot: confirm.slot, target: confirm.target, account: confirm.method }).catch(fail);
  else post('scoot:screen:unlock', { slot: confirm.slot, account: confirm.method }).catch(fail);
}

function targetFromPointer(clientX: number): void {
  if (!panel || !viewEl) return;
  const rail = viewEl.querySelector<HTMLElement>('.slider__rail');
  if (!rail) return;
  const r = rail.getBoundingClientRect();
  const ratio = Math.max(0, Math.min(1, (clientX - r.left) / r.width));
  panel.target = Math.round((ratio * charging.fullAt) / charging.step) * charging.step;
  patchPanel();
}

root.addEventListener('mousedown', (event) => {
  const target = event.target as HTMLElement | null;
  if (!target?.closest('[data-slider]') || !panel) return;
  dragging = true;
  viewEl?.querySelector('.slider')?.classList.add('slider--drag');
  targetFromPointer(event.clientX);
  event.preventDefault();
});

window.addEventListener('mousemove', (event) => {
  if (dragging) targetFromPointer(event.clientX);
});

window.addEventListener('mouseup', () => {
  if (!dragging) return;
  dragging = false;
  viewEl?.querySelector('.slider')?.classList.remove('slider--drag');
});

root.addEventListener('click', (event) => {
  const target = event.target as HTMLElement | null;
  const button = target?.closest<HTMLButtonElement>('button');
  if (!button) {
    const row = target?.closest<HTMLElement>('[data-open]');
    if (row) openDetail(Number(row.dataset.open));
    return;
  }
  if (button.disabled) return;
  const d = button.dataset;
  if (d.unlock) return openConfirm('unlock', Number(d.unlock));
  if (d.charge) return openPanel(Number(d.charge));
  if (d.stop) return stopCharge(Number(d.stop));
  if (d.method && confirm) {
    confirm.method = d.method as Method;
    return render();
  }
  if (d.target && panel) {
    panel.target = Number(d.target);
    return patchPanel();
  }
  if (d.step && panel) {
    panel.target += Number(d.step) * charging.step;
    return patchPanel();
  }
  if ('continue' in d && panel) return openConfirm('charge', panel.slot);
  if ('back' in d) {
    if (confirm) confirm = null;
    else if (panel) panel = null;
    else detail = null;
    return render();
  }
  if ('confirm' in d) return submit();
});

window.addEventListener('message', (event: MessageEvent<ScreenMessage>) => {
  const data = event.data;
  if (!data || typeof data !== 'object') return;
  if (data.colours) colours = data.colours;
  if (data.pricing) pricing = data.pricing;
  if (data.payment?.methods?.length) methods = data.payment.methods.filter((m): m is Method => m === 'bank' || m === 'cash');
  if (data.charging) charging = data.charging;
  if (typeof data.wakeMs === 'number' && data.wakeMs >= 0) wakeMs = data.wakeMs;
  if (typeof data.brightness === 'number') root.style.filter = `brightness(${Math.max(0.05, Math.min(1, data.brightness))})`;
  if (data.station !== undefined) {
    if (newlyDocked(station, data.station)) wake(wakeMs, data.station!.name);
    station = data.station;
  }
  if (data.time !== undefined) clock = data.time;
  if (data.panel === 'close') {
    panel = null;
    confirm = null;
  }
  if (typeof data.viewing === 'boolean') {
    const wasViewing = viewing;
    viewing = data.viewing;
    if (!viewing) {
      panel = null;
      confirm = null;
      detail = null;
      if (wasViewing) wake(wakeMs, station?.name ?? null);
    }
  }
  if (data.toast) {
    showToast(data.toast);
    return;
  }
  if (dragging && currentView === 'charge') {
    patchPanel();
    return;
  }
  render();
});

render();
post('scoot:screen:ready', {}).catch(() => undefined);
