const root = document.getElementById('mc'), view = document.getElementById('view')
const S = { chars: [], max: 0, bg: [], spawns: [], sel: 1, mode: 'list', pending: null, busy: false, form: null, err: '' }
const post = (name, body) => fetch(`https://${GetParentResourceName()}/${name}`, { method: 'POST', body: JSON.stringify(body || {}) }).then(r => r.json())
const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]))
const money = n => '$' + Number(n || 0).toLocaleString('en-US')
const ERR = { invalid_charinfo: 'Those details were not accepted.', slot_taken: 'That slot is already used.', invalid_slot: 'Invalid slot.', confirm_mismatch: 'Name does not match.', already_loaded: 'Character is already online.', database_error: 'Database error, try again.' }
const bySlot = n => S.chars.find(c => Number(c.slot) === n)

function ago(v) {
  const t = typeof v === 'number' ? v : Date.parse(v)
  if (!t) return 'Never'
  const m = Math.max(0, (Date.now() - t) / 60000)
  if (m < 2) return 'Just now'
  if (m < 60) return Math.floor(m) + 'm ago'
  if (m < 1440) return Math.floor(m / 60) + 'h ago'
  if (m < 43200) return Math.floor(m / 1440) + 'd ago'
  return new Date(t).toLocaleDateString()
}

function card(slot) {
  const c = bySlot(slot), on = S.sel === slot
  if (!c) return `<div class="card empty ${on ? 'on' : ''}" data-slot="${slot}"><span class="slot">SLOT ${slot}</span><div class="name">Empty slot</div><div class="cid">Create a new life</div>${on ? '<div class="row"><button class="primary grow" data-act="new">Create character</button></div>' : ''}</div>`
  const i = c.charinfo || {}, job = (c.job && (c.job.label || c.job.name)) || 'Unemployed', m = c.money || {}
  const body = on ? `<div class="meta">
      <div><label>Born</label><span>${esc(i.birthdate)}</span></div><div><label>Background</label><span>${esc(i.background || 'Local')}</span></div>
      <div><label>Occupation</label><span>${esc(job)}</span></div><div><label>Phone</label><span>${esc(c.phone || 'None')}</span></div>
      <div><label>Cash</label><span>${money(m.cash)}</span></div><div><label>Bank</label><span>${money(m.bank)}</span></div>
      <div><label>Last seen</label><span>${ago(c.last_seen)}</span></div><div><label>Nationality</label><span>${esc(i.nationality)}</span></div></div>
    <div class="row"><button class="primary grow" data-act="play">Play</button><button class="danger" data-act="del">Delete</button></div>` : ''
  return `<div class="card ${on ? 'on' : ''}" data-slot="${slot}"><span class="slot">SLOT ${slot}</span><div class="name">${esc(i.firstname)} ${esc(i.lastname)}</div><div class="cid">${esc(c.citizenid)}</div><div class="bar"></div>${body}</div>`
}

function renderList() {
  let h = '<div class="title">Your characters</div>'
  for (let s = 1; s <= S.max; s++) h += card(s)
  view.innerHTML = h
}

function renderSpawn() {
  const c = S.pending
  let h = `<div class="title">Where to?</div>`
  S.spawns.filter(s => s.key !== 'last' || (c && c.position)).forEach(s => {
    h += `<div class="card" data-spawn="${esc(s.key)}"><div class="spawn"><div class="name" style="font-size:16px">${esc(s.label)}</div><div class="d">${esc(s.desc)}</div></div></div>`
  })
  h += '<div class="row"><button class="grow" data-act="back">Back</button></div>'
  view.innerHTML = h
}

function renderCreate() {
  const f = S.form, y = new Date().getFullYear(), months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']
  let days = '', yrs = ''
  for (let d = 1; d <= 31; d++) days += `<option ${f.day == d ? 'selected' : ''}>${d}</option>`
  for (let n = y - 18; n >= 1930; n--) yrs += `<option ${f.year == n ? 'selected' : ''}>${n}</option>`
  view.innerHTML = `<div class="title">New character · Slot ${f.slot}</div>
    <div class="field"><label>First name</label><input id="f-first" maxlength="24" value="${esc(f.first)}"/></div>
    <div class="field"><label>Last name</label><input id="f-last" maxlength="24" value="${esc(f.last)}"/></div>
    <div class="field"><label>Nationality</label><input id="f-nat" maxlength="32" value="${esc(f.nat)}"/></div>
    <div class="field"><label>Date of birth</label><div class="three"><select id="f-day">${days}</select><select id="f-month">${months.map((m, i) => `<option value="${i + 1}" ${f.month == i + 1 ? 'selected' : ''}>${m}</option>`).join('')}</select><select id="f-year">${yrs}</select></div></div>
    <div class="field"><label>Gender</label><div class="chips"><button class="chip ${f.gender === 'male' ? 'on' : ''}" data-gender="male">Male</button><button class="chip ${f.gender === 'female' ? 'on' : ''}" data-gender="female">Female</button></div></div>
    <div class="field"><label>Background</label><div class="chips">${S.bg.map(b => `<button class="chip ${f.bg === b ? 'on' : ''}" data-bg="${esc(b)}">${esc(b)}</button>`).join('')}</div></div>
    <div class="err">${esc(S.err)}</div>
    <div class="row" style="margin-top:0"><button class="grow" data-act="back">Back</button><button class="primary grow" data-act="submit" ${S.busy ? 'disabled' : ''}>Create</button></div>`
}

function renderDelete() {
  const i = S.pending.charinfo || {}
  view.innerHTML = `<div class="title">Delete character</div><div class="card"><div class="name">${esc(i.firstname)} ${esc(i.lastname)}</div><div class="cid">${esc(S.pending.citizenid)}</div>
    <p class="warn">This permanently removes the character, its items, vehicles and money. Type <b>${esc(i.firstname)}</b> to confirm.</p>
    <input id="d-confirm" autocomplete="off" placeholder="${esc(i.firstname)}"/><div class="err" style="margin-top:8px">${esc(S.err)}</div>
    <div class="row"><button class="grow" data-act="back">Cancel</button><button class="danger solid grow" id="d-go" data-act="confirmdel" disabled>Delete forever</button></div></div>`
  const input = document.getElementById('d-confirm'), go = document.getElementById('d-go')
  input.addEventListener('input', () => { go.disabled = input.value.trim().toLowerCase() !== String(i.firstname).toLowerCase() })
  input.focus()
}

function render() {
  if (S.mode === 'list') renderList()
  else if (S.mode === 'spawn') renderSpawn()
  else if (S.mode === 'create') renderCreate()
  else renderDelete()
}

function select(slot) {
  S.sel = slot
  render()
  post('mc:focus', { slot })
}

function readForm() {
  const g = id => document.getElementById(id)
  if (!g('f-first')) return
  Object.assign(S.form, { first: g('f-first').value, last: g('f-last').value, nat: g('f-nat').value, day: g('f-day').value, month: g('f-month').value, year: g('f-year').value })
}

async function submit() {
  readForm()
  const f = S.form, name = /^[A-Za-z][A-Za-z '\-]{1,23}$/
  if (!name.test(f.first.trim()) || !name.test(f.last.trim())) { S.err = 'Enter a valid first and last name.'; return render() }
  if (!/^[A-Za-z][A-Za-z '\-]{1,31}$/.test(f.nat.trim())) { S.err = 'Enter a valid nationality.'; return render() }
  if (!f.gender) { S.err = 'Choose a gender.'; return render() }
  S.err = ''; S.busy = true; render()
  const r = await post('mc:create', { slot: f.slot, charinfo: { firstname: f.first.trim(), lastname: f.last.trim(), nationality: f.nat.trim(), gender: f.gender, background: f.bg, birthdate: `${String(f.day).padStart(2, '0')}/${String(f.month).padStart(2, '0')}/${f.year}` } })
  S.busy = false
  if (!r.ok) { S.err = ERR[r.err] || 'Character could not be created.'; render() }
}

async function confirmDelete() {
  const i = S.pending.charinfo || {}, input = document.getElementById('d-confirm')
  const r = await post('mc:delete', { id: S.pending.id, confirm: input.value.trim() })
  if (!r.ok) { S.err = ERR[r.err] || 'Character could not be deleted.'; return render() }
  S.mode = 'list'; S.err = ''; S.pending = null
}

async function play(spawn) {
  const r = await post('mc:play', { id: S.pending.id, spawn })
  if (!r.ok) { S.err = ERR[r.err] || 'Character could not be loaded.'; S.mode = 'list'; render() }
}

function startCreate(slot) {
  S.form = { slot, first: '', last: '', nat: 'American', day: 1, month: 1, year: new Date().getFullYear() - 25, gender: '', bg: S.bg[0] }
  S.err = ''; S.mode = 'create'; render()
}

view.addEventListener('click', e => {
  const t = e.target.closest('[data-act],[data-slot],[data-spawn],[data-gender],[data-bg]')
  if (!t) return
  if (t.dataset.gender) { readForm(); S.form.gender = t.dataset.gender; return render() }
  if (t.dataset.bg) { readForm(); S.form.bg = t.dataset.bg; return render() }
  if (t.dataset.spawn) return play(t.dataset.spawn)
  switch (t.dataset.act) {
    case 'new': return startCreate(S.sel)
    case 'play': S.pending = bySlot(S.sel); S.mode = 'spawn'; return render()
    case 'del': S.pending = bySlot(S.sel); S.err = ''; S.mode = 'delete'; return render()
    case 'back': S.mode = 'list'; S.err = ''; return render()
    case 'submit': return submit()
    case 'confirmdel': return confirmDelete()
  }
  if (t.dataset.slot) select(Number(t.dataset.slot))
})

document.addEventListener('keydown', e => {
  if (root.classList.contains('hidden')) return
  const typing = ['INPUT', 'SELECT'].includes(document.activeElement.tagName)
  if (e.key === 'Escape') { if (S.mode !== 'list') { S.mode = 'list'; S.err = ''; render() } return }
  if (typing || S.mode !== 'list') return
  if (e.key === 'ArrowDown') select(Math.min(S.max, S.sel + 1))
  else if (e.key === 'ArrowUp') select(Math.max(1, S.sel - 1))
  else if (e.key === 'Enter') { const c = bySlot(S.sel); if (c) { S.pending = c; S.mode = 'spawn'; render() } else startCreate(S.sel) }
})

window.addEventListener('message', e => {
  const m = e.data
  if (m.action === 'open' || m.action === 'data') {
    S.chars = m.data.characters || []; S.max = m.data.max; S.bg = m.data.backgrounds || []; S.spawns = m.data.spawns || []
    if (m.action === 'open') { S.sel = 1; S.mode = 'list'; S.err = ''; root.classList.remove('hidden') }
    else if (S.mode === 'delete' || S.mode === 'spawn') S.mode = 'list'
    render()
  } else if (m.action === 'close') { root.classList.add('hidden'); S.mode = 'list' }
})
