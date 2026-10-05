const shopResource = typeof GetParentResourceName === "function" ? GetParentResourceName() : "hpx_peddialog";
const shopRoot = document.getElementById("shop");
const shopLabel = document.getElementById("shop-label");
const shopAddr1 = document.getElementById("shop-addr1");
const shopAddr2 = document.getElementById("shop-addr2");
const shopCats = document.getElementById("shop-cats");
const shopCatTitle = document.getElementById("shop-cat-title");
const shopGrid = document.getElementById("shop-grid");
const shopCart = document.getElementById("shop-cart");
const shopPriceType = document.getElementById("shop-price-type");
const shopSubtotal = document.getElementById("shop-subtotal");
const shopTaxLabel = document.getElementById("shop-tax-label");
const shopTax = document.getElementById("shop-tax");
const shopTotal = document.getElementById("shop-total");
const shopVersion = document.getElementById("shop-version");
const shopPayCard = document.getElementById("shop-pay-card");
const shopPayCash = document.getElementById("shop-pay-cash");

const CAT_LABELS = {
    armor: "ARMOR",
    weapons: "WEAPONS",
    melee: "MELEE COMBAT",
    ammo: "AMMO",
    magazines: "MAGAZINES",
    attachments: "ATTACHMENTS",
    food: "FOOD",
    drinks: "DRINKS",
    medical: "MEDICAL",
    tools: "TOOLS",
    general: "GENERAL",
};

const CAT_ICONS = {
    tools: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M20.4 7.2a4.7 4.7 0 0 1-6.4 4.4L8.6 17l-1.8-1.8 5.4-5.4A4.7 4.7 0 0 1 16.8 3.4L14 6.2 17.8 10l2.6-2.8zM6.2 18.2 5 21.2 8 20z"/></svg>',
    general: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M8.2 7.2V5.4A3.8 3.8 0 0 1 12 1.6a3.8 3.8 0 0 1 3.8 3.8v1.8h3.4l-1.2 15.2H6L4.8 7.2h3.4z"/></svg>',
    weapons: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M2.4 9.4h9.2l.55 1.55h7.2v2.05h-2.05l-.85 6.55H8.05L7.1 13H4.7v-1.7H2.4V9.4zm12.7 1.55h3.55v1.05h-4.05l.5-1.05z"/></svg>',
    armor: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2.2 3.6 5.8v6.4c0 5.6 3.6 10 8.4 11.6 4.8-1.6 8.4-6 8.4-11.6V5.8L12 2.2z"/></svg>',
    ammo: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2.2A9.8 9.8 0 1 0 21.8 12 9.8 9.8 0 0 0 12 2.2zm0 6.1a3.7 3.7 0 1 1 0 7.4 3.7 3.7 0 0 1 0-7.4z"/></svg>',
    food: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M5.2 2.8h1.8v8.2H5.2zm3.4 0h1.8v8.2H8.6zM6.1 11.6h2.6V21H6.1zM15.4 2.8c2.6 0 4.4 2.1 4.4 5.6 0 3.4-1.7 5.5-4.4 5.5V2.8zm0 11.1H17.2V21h-1.8z"/></svg>',
    drinks: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M7.4 2.8h9.2l-1.15 15.4A2.3 2.3 0 0 1 13.18 20.4h-2.36a2.3 2.3 0 0 1-2.27-2.2L7.4 2.8z"/></svg>',
    medical: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M8.4 3.2h7.2v5.2H21v7.2h-5.4v5.2H8.4v-5.2H3V8.4h5.4z"/></svg>',
};

let shopData = null;
let cart = [];
let categoryId = "";
let selectedSlot = null;
let shiftDown = false;
let busy = false;

const shopPost = (event, payload) => {
    fetch(`https://${shopResource}/${event}`, {
        method: "POST",
        headers: { "Content-Type": "application/json; charset=UTF-8" },
        body: JSON.stringify(payload || {}),
    }).catch(() => {});
};

const moneyText = (value) => `$${Number(value || 0).toLocaleString("en-US")}`;

const itemUrl = (item) => item.image || `nui://ox_inventory/web/images/${item.name}.png`;

const resolveCategory = (item) => {
    if (item.category) return String(item.category).toLowerCase();
    const n = String(item.name || "").toLowerCase();
    if (n.includes("armor") || n.includes("armour")) return "armor";
    if (n.includes("ammo")) return "ammo";
    if (n.startsWith("weapon_")) return "weapons";
    if (n.includes("burger") || n.includes("food")) return "food";
    if (n.includes("water") || n.includes("drink")) return "drinks";
    if (n.includes("bandage") || n.includes("medikit")) return "medical";
    return "general";
};

const categoryLabel = (id) => CAT_LABELS[id] || String(id || "GENERAL").toUpperCase();

const categories = () => {
    const seen = [];
    const items = (shopData && shopData.items) || [];
    for (let i = 0; i < items.length; i++) {
        const id = resolveCategory(items[i]);
        if (seen.indexOf(id) === -1) seen.push(id);
    }
    return seen;
};

const visibleItems = () => {
    const items = (shopData && shopData.items) || [];
    const active = categoryId || categories()[0] || "general";
    const out = [];
    for (let i = 0; i < items.length; i++) {
        if (resolveCategory(items[i]) === active) out.push(items[i]);
    }
    return out;
};

const showDialog = () => {
    const dialogEl = document.getElementById("dialog");
    if (dialogEl) dialogEl.removeAttribute("hidden");
};

const closeShop = (fromLua) => {
    shopData = null;
    cart = [];
    busy = false;
    shopRoot.setAttribute("hidden", "");
    shopRoot.style.pointerEvents = "auto";
    if (!fromLua) {
        showDialog();
        shopPost("clerkShopClose", {});
    }
};

const paintPay = () => {
    const empty = cart.length === 0 || busy;
    shopPayCard.disabled = empty;
    shopPayCash.disabled = empty;
};

const paintTotals = () => {
    const taxPct = (shopData && shopData.tax) || 0;
    let subtotal = 0;
    for (let i = 0; i < cart.length; i++) subtotal += cart[i].price * cart[i].count;
    const tax = Math.ceil(subtotal * (taxPct / 100));
    shopSubtotal.textContent = moneyText(subtotal);
    shopTaxLabel.textContent = `Tax (${taxPct}%)`;
    shopTax.textContent = moneyText(tax);
    shopTotal.textContent = moneyText(subtotal + tax);
    paintPay();
};

const paintCart = () => {
    shopCart.textContent = "";
    if (cart.length === 0) {
        const empty = document.createElement("span");
        empty.className = "clerk-shop-cart-empty";
        empty.textContent = "YOUR CART IS EMPTY";
        shopCart.appendChild(empty);
        paintTotals();
        return;
    }
    for (let i = 0; i < cart.length; i++) {
        const line = cart[i];
        const row = document.createElement("div");
        row.className = "clerk-shop-cart-line";
        const thumb = document.createElement("div");
        thumb.className = "clerk-shop-cart-thumb";
        thumb.style.backgroundImage = `url(${itemUrl(line)})`;
        const info = document.createElement("div");
        info.className = "clerk-shop-cart-info";
        const name = document.createElement("strong");
        name.textContent = String(line.label || "").toUpperCase();
        const cost = document.createElement("span");
        cost.textContent = moneyText(line.price * line.count);
        info.appendChild(name);
        info.appendChild(cost);
        const qty = document.createElement("div");
        qty.className = "clerk-shop-cart-qty";
        const minus = document.createElement("button");
        minus.type = "button";
        minus.textContent = "-";
        minus.addEventListener("click", () => changeQty(line.slot, -1));
        const count = document.createElement("span");
        count.textContent = String(line.count);
        const plus = document.createElement("button");
        plus.type = "button";
        plus.textContent = "+";
        plus.addEventListener("click", () => changeQty(line.slot, 1));
        qty.appendChild(minus);
        qty.appendChild(count);
        qty.appendChild(plus);
        row.appendChild(thumb);
        row.appendChild(info);
        row.appendChild(qty);
        shopCart.appendChild(row);
    }
    paintTotals();
};

const addToCart = (item, amount) => {
    if (!item || item.count === 0) return;
    const qty = Math.max(1, amount || 1);
    const stock = item.count ?? 9999;
    const existing = cart.find((line) => line.slot === item.slot);
    if (existing) {
        existing.count = Math.min(existing.count + qty, stock);
    } else {
        cart.push({
            slot: item.slot,
            name: item.name,
            label: item.label,
            count: Math.min(qty, stock),
            price: item.price || 0,
            image: item.image,
        });
    }
    paintCart();
};

const changeQty = (slot, delta) => {
    const items = (shopData && shopData.items) || [];
    const stock = (items.find((item) => item.slot === slot) || {}).count ?? 9999;
    cart = cart
        .map((line) => {
            if (line.slot !== slot) return line;
            return { ...line, count: Math.min(Math.max(line.count + delta, 0), stock) };
        })
        .filter((line) => line.count > 0);
    paintCart();
};

const paintGrid = () => {
    const cats = categories();
    const active = categoryId || cats[0] || "general";
    categoryId = active;
    shopCatTitle.textContent = categoryLabel(active);
    shopCats.textContent = "";
    for (let i = 0; i < cats.length; i++) {
        const id = cats[i];
        const button = document.createElement("button");
        button.type = "button";
        button.className = `clerk-shop-cat${id === active ? " is-active" : ""}`;
        const icon = document.createElement("span");
        icon.className = "clerk-shop-cat-icon";
        icon.innerHTML = CAT_ICONS[id] || CAT_ICONS.general;
        const label = document.createElement("span");
        label.className = "clerk-shop-cat-label";
        label.textContent = categoryLabel(id);
        button.appendChild(icon);
        button.appendChild(label);
        button.addEventListener("click", () => {
            categoryId = id;
            selectedSlot = null;
            paintGrid();
        });
        shopCats.appendChild(button);
    }
    const items = visibleItems();
    if (!items.some((item) => item.slot === selectedSlot)) selectedSlot = items[0] ? items[0].slot : null;
    shopGrid.textContent = "";
    for (let i = 0; i < items.length; i++) {
        const item = items[i];
        const locked = item.count === 0;
        const card = document.createElement("article");
        card.className = `clerk-shop-card${selectedSlot === item.slot ? " is-selected" : ""}${locked ? " is-locked" : ""}`;
        const body = document.createElement("div");
        body.className = "clerk-shop-card-body";
        const title = document.createElement("h3");
        title.textContent = String(item.label || item.name || "").toUpperCase();
        const price = document.createElement("p");
        price.textContent = moneyText(item.price || 0);
        const art = document.createElement("div");
        art.className = "clerk-shop-card-art";
        art.style.backgroundImage = `url(${itemUrl(item)})`;
        body.appendChild(title);
        body.appendChild(price);
        body.appendChild(art);
        const add = document.createElement("button");
        add.type = "button";
        add.className = "clerk-shop-card-add";
        add.textContent = "ADD TO CART";
        add.disabled = locked;
        const pick = (event) => {
            if (event) event.stopPropagation();
            selectedSlot = item.slot;
            if (!locked) addToCart(item, shiftDown ? 10 : 1);
            paintGrid();
        };
        card.addEventListener("click", pick);
        add.addEventListener("click", pick);
        card.appendChild(body);
        card.appendChild(add);
        shopGrid.appendChild(card);
    }
};

const pay = (method) => {
    if (!shopData || cart.length === 0 || busy || method === "giftcard") return;
    busy = true;
    shopRoot.style.pointerEvents = "none";
    paintPay();
    fetch(`https://${shopResource}/clerkShopCheckout`, {
        method: "POST",
        headers: { "Content-Type": "application/json; charset=UTF-8" },
        body: JSON.stringify({
            payment: method,
            items: cart.map((line) => ({ item: line.name, count: line.count })),
        }),
    })
        .then((res) => res.json())
        .then((data) => {
            if (data && data.success) {
                cart = [];
                paintCart();
            }
        })
        .catch(() => {})
        .finally(() => {
            busy = false;
            shopRoot.style.pointerEvents = "auto";
            paintPay();
        });
};

shopPayCard.addEventListener("click", () => pay("card"));
shopPayCash.addEventListener("click", () => pay("cash"));

window.addEventListener("message", (event) => {
    const msg = event.data;
    if (!msg || !msg.action) return;
    if (msg.action === "openClerkShop") {
        shopData = msg.data || { items: [] };
        cart = [];
        categoryId = "";
        selectedSlot = null;
        busy = false;
        shopLabel.textContent = String(shopData.label || "SHOP").toUpperCase();
        shopAddr1.textContent = String((shopData.address && shopData.address[0]) || "UNKNOWN STREET").toUpperCase();
        shopAddr2.textContent = String((shopData.address && shopData.address[1]) || "SAN ANDREAS").toUpperCase();
        shopPriceType.textContent = `PRICE TYPE: ${String(shopData.moneyType || "cash").toUpperCase()}`;
        shopVersion.textContent = shopData.version || "";
        shopRoot.removeAttribute("hidden");
        paintGrid();
        paintCart();
    } else if (msg.action === "closeClerkShop") {
        closeShop(true);
    }
});

window.addEventListener("keydown", (event) => {
    if (event.key === "Shift") shiftDown = true;
    if (!shopData || shopRoot.hasAttribute("hidden")) return;
    if (event.key === "Escape") {
        event.preventDefault();
        event.stopPropagation();
        closeShop(false);
        return;
    }
    const cats = categories();
    const items = visibleItems();
    const catIndex = Math.max(0, cats.indexOf(categoryId));
    let itemIndex = 0;
    for (let i = 0; i < items.length; i++) {
        if (items[i].slot === selectedSlot) itemIndex = i;
    }
    if (event.key === "ArrowUp") {
        event.preventDefault();
        event.stopPropagation();
        categoryId = cats[Math.max(0, catIndex - 1)] || categoryId;
        selectedSlot = null;
        paintGrid();
    } else if (event.key === "ArrowDown") {
        event.preventDefault();
        event.stopPropagation();
        categoryId = cats[Math.min(cats.length - 1, catIndex + 1)] || categoryId;
        selectedSlot = null;
        paintGrid();
    } else if (event.key === "ArrowLeft") {
        event.preventDefault();
        event.stopPropagation();
        const next = items[Math.max(0, itemIndex - 1)];
        if (next) selectedSlot = next.slot;
        paintGrid();
    } else if (event.key === "ArrowRight") {
        event.preventDefault();
        event.stopPropagation();
        const next = items[Math.min(items.length - 1, itemIndex + 1)];
        if (next) selectedSlot = next.slot;
        paintGrid();
    } else if (event.key === "Enter") {
        event.preventDefault();
        event.stopPropagation();
        const selected = items.find((item) => item.slot === selectedSlot);
        if (selected) addToCart(selected, event.shiftKey ? 10 : 1);
    }
}, true);

window.addEventListener("keyup", (event) => {
    if (event.key === "Shift") shiftDown = false;
});
