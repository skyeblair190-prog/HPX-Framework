(() => {
  'use strict';

  const params = new URLSearchParams(window.location.search);
  const isDui = params.get('mode') === 'dui';
  const resource = typeof GetParentResourceName === 'function'
    ? GetParentResourceName()
    : window.location.host.replace(/^cfx-nui-/, '');

  const STRINGS = {
    welcome: 'WELCOME',
    begin: 'PRESS E TO BEGIN',
    account: 'Account',
    balance: 'BALANCE',
    cash: 'CASH ON HAND',
    processing: 'PROCESSING',
    items: {
      balance: 'Check balance',
      withdraw: 'Withdraw cash',
      deposit: 'Deposit cash',
      transfer: 'Transfer funds',
      exit: 'Exit',
      custom: 'Other amount',
      back: 'Back'
    },
    headings: { menu: 'SELECT AN OPTION', withdraw: 'WITHDRAW CASH', deposit: 'DEPOSIT CASH' },
    results: {
      balance: 'Available balance {balance}',
      withdraw_ok: 'Withdrew {amount}',
      deposit_ok: 'Deposited {amount}',
      transfer_ok: 'Transferred {amount}',
      insufficient_cash: 'Not enough cash on hand',
      insufficient_funds: 'Insufficient funds',
      invalid: 'Invalid amount',
      account_not_found: 'Account not found',
      database_error: 'Service unavailable',
      transfer_failed: 'Transfer failed',
      cash_error: 'Cash dispenser error',
      error: 'Something went wrong'
    },
    hints: isDui
      ? [['UP DOWN', 'SELECT'], ['ENTER', 'CONFIRM'], ['BACKSPACE', 'BACK']]
      : [['CLICK', 'SELECT'], ['ESC', 'CLOSE']]
  };

  const screen = document.getElementById('screen');
  const content = document.getElementById('content');
  const meta = document.getElementById('meta');
  const hints = document.getElementById('hints');

  let clockNode = null;

  const post = (name, data) =>
    fetch(`https://${resource}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data || {})
    }).catch(() => {});

  const el = (tag, className, text) => {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
  };

  const money = (value, currency) =>
    `${currency || '$'}${Number(value || 0).toLocaleString('en-US', { maximumFractionDigits: 2 })}`;

  const fill = (text, values) => text.replace(/\{(\w+)\}/g, (_, key) => (key in values ? values[key] : ''));

  const maskAccount = (number) => `${STRINGS.account} •••• ${String(number || '').slice(-4)}`;

  const tick = () => {
    if (!clockNode) return;
    clockNode.textContent = new Date().toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' });
  };

  const renderHints = () => {
    hints.replaceChildren();
    for (const [key, label] of STRINGS.hints) {
      const span = el('span');
      span.append(el('b', '', key), document.createTextNode(label));
      hints.append(span);
    }
  };

  const stat = (label, value) => {
    const box = el('div', 'stat');
    box.append(el('div', 'label', label), el('div', 'value', value));
    return box;
  };

  const stats = (view) => {
    const wrap = el('div', 'stats');
    wrap.append(
      stat(STRINGS.balance, money(view.account && view.account.balance, view.currency)),
      stat(STRINGS.cash, money(view.cash, view.currency))
    );
    return wrap;
  };

  const itemLabel = (item, view) =>
    item.id === 'amount' ? money(item.value, view.currency) : STRINGS.items[item.id] || item.id;

  const list = (view) => {
    const wrap = el('div', view.screen === 'amounts' ? 'list two' : 'list');
    (view.items || []).forEach((item, i) => {
      const button = el('button', i + 1 === view.index ? 'item selected' : 'item', itemLabel(item, view));
      button.type = 'button';
      if (!isDui) button.addEventListener('click', () => post('select', { index: i + 1 }));
      wrap.append(button);
    });
    return wrap;
  };

  const renderIdle = () => {
    const hero = el('div', 'hero');
    clockNode = el('div', 'clock');
    hero.append(el('div', 'title', STRINGS.welcome), el('div', 'sub', STRINGS.begin), clockNode);
    content.replaceChildren(hero);
    meta.textContent = '';
    tick();
  };

  const renderResult = (view) => {
    const result = view.result || {};
    const text = fill(STRINGS.results[result.key] || STRINGS.results.error, {
      amount: money(result.amount, view.currency),
      balance: money(view.account && view.account.balance, view.currency)
    });
    const wrap = el('div', 'result');
    wrap.append(el('div', `mark ${result.kind === 'success' ? 'success' : 'error'}`, result.kind === 'success' ? 'OK' : '!'));
    wrap.append(el('div', 'text', text));
    content.replaceChildren(wrap);
  };

  const render = (view) => {
    clockNode = null;
    screen.classList.toggle('hidden', !isDui && view.screen === 'idle');

    if (view.screen === 'idle') {
      renderIdle();
      renderHints();
      hints.classList.add('hidden');
      return;
    }

    hints.classList.remove('hidden');
    renderHints();
    meta.textContent = view.account ? maskAccount(view.account.number) : '';

    if (view.busy) {
      content.replaceChildren(el('div', 'busy', STRINGS.processing));
      return;
    }

    if (view.screen === 'result') return renderResult(view);

    const heading = STRINGS.headings[view.screen === 'amounts' ? view.kind : 'menu'];
    content.replaceChildren(stats(view), el('div', 'heading', heading), list(view));
  };

  window.addEventListener('message', (event) => {
    let data = event.data;
    if (typeof data === 'string') {
      try { data = JSON.parse(data); } catch (e) { return; }
    }
    if (!data || data.action !== 'view' || typeof data.view !== 'object' || data.view === null) return;
    render(data.view);
  });

  if (!isDui) {
    screen.classList.add('hidden');
    window.addEventListener('keydown', (event) => {
      const keys = { ArrowUp: 'up', ArrowDown: 'down', Enter: 'enter', Backspace: 'back', Escape: 'close' };
      const key = keys[event.key];
      if (!key || screen.classList.contains('hidden')) return;
      event.preventDefault();
      post('input', { key });
    });
  } else {
    render({ screen: 'idle' });
  }

  setInterval(tick, 1000);
})();
