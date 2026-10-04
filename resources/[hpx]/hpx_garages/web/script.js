(() => {
    const $ = (id) => document.getElementById(id);
    const app = $('app'), stage = $('stage'), grid = $('grid'), search = $('search');
    const overlay = $('overlay'), mBtn = $('m-btn');

    let vehicles = [], filter = 'all', selected = 0, current = null, imageUrl = '', currency = '$';
    const FILTERS = ['all', 'personal', 'shared'];

    const post = (name, data = {}) =>
        fetch(`https://${GetParentResourceName()}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data),
        }).catch(() => {});

    function rescale() {
        const s = window.innerHeight / 1080;
        stage.style.transform = `scale(${s})`;
        stage.style.marginLeft = `${-960 * s}px`;
    }
    window.addEventListener('resize', rescale);
    rescale();

    const img = (model) => imageUrl.replace('{model}', model);
    const statusInfo = (v) => v.state === 1 ? ['STORED', ''] : v.state === 2 ? ['IMPOUNDED', 'imp'] : ['OUT', 'out'];
    const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

    function visible() {
        const q = search.value.trim().toLowerCase();
        return vehicles.filter((v) => {
            if (filter === 'personal' && !v.owned) return false;
            if (filter === 'shared' && v.owned) return false;
            if (q && !(v.label.toLowerCase().includes(q) || v.plate.toLowerCase().includes(q))) return false;
            return true;
        });
    }

    function render() {
        const list = visible();
        if (selected >= list.length) selected = Math.max(0, list.length - 1);
        if (!list.length) { grid.innerHTML = '<div class="empty">No vehicles found.</div>'; return; }
        grid.innerHTML = list.map((v, i) => {
            const [st, cls] = statusInfo(v);
            return `<div class="card${i === selected ? ' sel' : ''}" data-i="${i}">
                <div class="c-top"></div>
                <div class="c-name">${esc(v.label)}</div>
                <div class="c-status ${cls}">${st}</div>
                <div class="plate"><small>SAN ANDREAS</small><span>${esc(v.plate)}</span></div>
                <div class="c-img"><img src="${esc(img(v.model))}" onerror="this.style.display='none'"></div>
                <div class="c-stats"><span><em>FUEL</em>${v.fuel}%</span><span><em>ENGINE</em>${v.engine}%</span><span><em>BODY</em>${v.body}%</span></div>
            </div>`;
        }).join('');
    }

    function setFilter(f) {
        filter = f; selected = 0;
        document.querySelectorAll('.tab').forEach((t) => t.classList.toggle('active', t.dataset.filter === f));
        render();
    }

    function openModal(v) {
        current = v;
        const [st, cls] = statusInfo(v);
        $('m-title').textContent = v.label;
        $('m-img').src = img(v.model);
        $('m-img').style.display = '';
        $('m-img').onerror = function () { this.style.display = 'none'; };
        const rows = [
            ['VEHICLE PLATE', esc(v.plate), ''],
            ['VEHICLE STATUS', st, cls || 'green'],
            ['VEHICLE SEATS', v.seats, ''],
            ['FUEL', v.fuel + '%', ''],
            ['ENGINE', v.engine + '%', ''],
            ['BODY', v.body + '%', ''],
        ];
        if (v.depotPrice && v.state !== 1) rows.splice(3, 0, ['IMPOUND FEE', currency + v.depotPrice, '']);
        $('m-rows').innerHTML = rows.map((r) => `<div class="m-row"><span>${r[0]}</span><span class="${r[2]}">${r[1]}</span></div>`).join('');

        if (v.state === 1) { mBtn.textContent = 'RETRIEVE VEHICLE'; mBtn.disabled = false; }
        else if (v.state === 0 && v.depot) { mBtn.textContent = `RETRIEVE VEHICLE - ${currency}${v.depotPrice}`; mBtn.disabled = false; }
        else if (v.state === 2) { mBtn.textContent = 'VEHICLE IMPOUNDED'; mBtn.disabled = true; }
        else { mBtn.textContent = 'VEHICLE IS ALREADY OUT'; mBtn.disabled = true; }
        overlay.classList.remove('hidden');
    }
    const closeModal = () => { current = null; overlay.classList.add('hidden'); };

    function closeAll() {
        closeModal();
        app.classList.add('hidden');
        post('close');
    }

    // Events
    grid.addEventListener('click', (e) => {
        const c = e.target.closest('.card'); if (!c) return;
        selected = +c.dataset.i; render(); openModal(visible()[selected]);
    });
    document.querySelectorAll('.tab').forEach((t) => t.addEventListener('click', () => setFilter(t.dataset.filter)));
    search.addEventListener('input', () => { selected = 0; render(); });
    $('m-close').addEventListener('click', closeModal);
    mBtn.addEventListener('click', () => {
        if (!current || mBtn.disabled) return;
        const id = current.id;
        closeModal();
        app.classList.add('hidden');
        post('retrieve', { id });
    });

    window.addEventListener('keydown', (e) => {
        if (app.classList.contains('hidden')) return;
        const typing = document.activeElement === search;
        if (e.key === 'Escape') {
            e.preventDefault();
            if (!overlay.classList.contains('hidden')) closeModal(); else closeAll();
            return;
        }
        if (!overlay.classList.contains('hidden')) {
            if (e.key === 'Enter') mBtn.click();
            return;
        }
        if (typing) { if (e.key === 'Enter') search.blur(); return; }
        const k = e.key.toLowerCase();
        if (k === 'q') setFilter(FILTERS[(FILTERS.indexOf(filter) + 2) % 3]);
        else if (k === 'e') setFilter(FILTERS[(FILTERS.indexOf(filter) + 1) % 3]);
        else if (['arrowright', 'arrowleft', 'arrowdown', 'arrowup'].includes(k)) {
            e.preventDefault();
            const n = visible().length; if (!n) return;
            const d = { arrowright: 1, arrowleft: -1, arrowdown: 3, arrowup: -3 }[k];
            selected = Math.min(n - 1, Math.max(0, selected + d));
            render();
            const el = grid.querySelector('.card.sel'); if (el) el.scrollIntoView({ block: 'nearest' });
        } else if (k === 'enter') { const v = visible()[selected]; if (v) openModal(v); }
    });

    window.addEventListener('message', (e) => {
        const d = e.data;
        if (d.action === 'open') {
            vehicles = d.vehicles || []; imageUrl = d.imageUrl || ''; currency = d.currency || '$';
            filter = 'all'; selected = 0; search.value = '';
            document.querySelectorAll('.tab').forEach((t) => t.classList.toggle('active', t.dataset.filter === 'all'));
            closeModal(); render();
            app.classList.remove('hidden');
        } else if (d.action === 'close') {
            closeModal(); app.classList.add('hidden');
        }
    });
})();
