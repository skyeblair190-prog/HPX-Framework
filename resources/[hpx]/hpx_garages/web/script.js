(() => {
  'use strict';

  const $ = (id) => document.getElementById(id);
  const app = $('app');
  const grid = $('grid');
  const empty = $('empty');
  const title = $('title');
  const search = $('search');
  const overlay = $('overlay');
  const mName = $('m-name');
  const mPlate = $('m-plate');
  const mStats = $('m-stats');
  const mInfo = $('m-info');
  const mBtn = $('m-btn');

  let vehicles = [];
  let depot = false;
  let selected = null;

  const post = (name, data) =>
    fetch(`https://${GetParentResourceName()}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data || {}),
    }).catch(() => {});

  const el = (tag, className, text) => {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
  };

  const clamp = (n) => Math.max(0, Math.min(100, Number(n) || 0));
  const money = (n) => `$${Number(n || 0).toLocaleString('en-US')}`;

  const stat = (label, value) => {
    const pct = clamp(value);
    const row = el('div', 'stat');
    const bar = el('div', 'bar');
    const fill = el('i', pct < 35 ? 'low' : '');
    fill.style.width = `${pct}%`;
    bar.append(fill);
    row.append(el('span', '', label), bar, el('span', 'stat-value', `${pct}%`));
    return row;
  };

  const stats = (v) => {
    const wrap = el('div', 'stats');
    wrap.append(stat('ENG', v.engine), stat('BODY', v.body), stat('FUEL', v.fuel));
    return wrap;
  };

  const closeModal = () => {
    selected = null;
    overlay.classList.add('hidden');
  };

  const openModal = (v) => {
    selected = v;
    mName.textContent = v.name;
    mPlate.textContent = v.plate;
    mStats.replaceChildren(...stats(v).children);
    mInfo.textContent = v.impounded ? 'Impounded vehicle.' : depot ? 'Vehicle is out of the garage.' : '';
    mBtn.disabled = !v.available;
    mBtn.textContent = !v.available ? 'UNAVAILABLE' : depot ? `RETRIEVE - ${money(v.price)}` : 'RETRIEVE VEHICLE';
    overlay.classList.remove('hidden');
  };

  const render = () => {
    const query = search.value.trim().toLowerCase();
    const shown = vehicles.filter(
      (v) => !query || String(v.name).toLowerCase().includes(query) || String(v.plate).toLowerCase().includes(query)
    );
    grid.replaceChildren();
    empty.classList.toggle('hidden', shown.length > 0);

    for (const v of shown) {
      const card = el('button', 'card');
      card.type = 'button';
      const top = el('div', 'card-top');
      top.append(el('span', 'card-name', v.name));
      if (v.impounded) top.append(el('span', 'tag warn', 'IMPOUNDED'));
      else if (depot) top.append(el('span', 'tag', 'OUT'));
      card.append(top, el('div', 'plate', v.plate), stats(v));
      if (depot) card.append(el('div', 'fee', money(v.price)));
      card.addEventListener('click', () => openModal(v));
      grid.append(card);
    }
  };

  mBtn.addEventListener('click', () => {
    if (!selected || mBtn.disabled) return;
    mBtn.disabled = true;
    post('retrieve', { id: selected.id });
  });

  $('close').addEventListener('click', () => post('close'));
  $('m-close').addEventListener('click', closeModal);
  overlay.addEventListener('click', (e) => { if (e.target === overlay) closeModal(); });
  search.addEventListener('input', render);

  window.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape' || app.classList.contains('hidden')) return;
    if (selected) closeModal();
    else post('close');
  });

  window.addEventListener('message', (event) => {
    const msg = event.data || {};
    switch (msg.action) {
      case 'open':
        depot = !!msg.depot;
        title.textContent = String(msg.title || 'GARAGE').toUpperCase();
        vehicles = Array.isArray(msg.vehicles) ? msg.vehicles : [];
        search.value = '';
        closeModal();
        render();
        app.classList.remove('hidden');
        break;
      case 'update':
        vehicles = Array.isArray(msg.vehicles) ? msg.vehicles : [];
        closeModal();
        render();
        break;
      case 'close':
        closeModal();
        app.classList.add('hidden');
        break;
    }
  });
})();
