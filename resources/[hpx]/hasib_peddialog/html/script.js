const resource = typeof GetParentResourceName === "function" ? GetParentResourceName() : "hasib_peddialog";

const root = document.getElementById("dialog");
const nameEl = document.getElementById("name");
const roleEl = document.getElementById("role");
const textEl = document.getElementById("text");
const optionsEl = document.getElementById("options");
const versionEl = document.getElementById("version");
const hintMove = document.getElementById("hint-move");
const hintSelect = document.getElementById("hint-select");
const hintSelectLabel = document.getElementById("hint-select-label");
const hintBack = document.getElementById("hint-back");
const hintBackLabel = document.getElementById("hint-back-label");

let dialog = null;
let selected = 1;
let rows = [];

const post = (event, payload) => {
    fetch(`https://${resource}/${event}`, {
        method: "POST",
        headers: { "Content-Type": "application/json; charset=UTF-8" },
        body: JSON.stringify(payload || {}),
    }).catch(() => {});
};

const paintSelected = () => {
    for (let i = 0; i < rows.length; i++) {
        rows[i].classList.toggle("is-selected", i + 1 === selected);
    }
};

const setHidden = (el, hidden) => {
    if (hidden) el.setAttribute("hidden", "");
    else el.removeAttribute("hidden");
};

const render = () => {
    if (!dialog) {
        setHidden(root, true);
        rows = [];
        optionsEl.textContent = "";
        return;
    }
    setHidden(root, false);
    nameEl.textContent = dialog.name || "";
    roleEl.textContent = dialog.role || "";
    setHidden(roleEl, !dialog.role);
    textEl.textContent = dialog.text || "";
    setHidden(textEl, !dialog.text);
    hintMove.textContent = (dialog.hints && dialog.hints.move) || "MOVE";
    hintSelectLabel.textContent = (dialog.hints && dialog.hints.select) || "SELECT";
    hintBackLabel.textContent = (dialog.hints && dialog.hints.back) || "BACK";
    versionEl.textContent = dialog.version || "";
    setHidden(versionEl, !dialog.version);
    optionsEl.textContent = "";
    rows = [];
    const labels = dialog.options || [];
    for (let i = 0; i < labels.length; i++) {
        const index = i + 1;
        const row = document.createElement("div");
        row.className = "ped-dialog-option";
        const span = document.createElement("span");
        span.textContent = labels[i];
        row.appendChild(span);
        row.addEventListener("mouseenter", () => {
            selected = index;
            paintSelected();
            post("pedDialogHover", { index });
        });
        row.addEventListener("click", () => {
            selected = index;
            paintSelected();
            post("pedDialogConfirm", { index });
        });
        optionsEl.appendChild(row);
        rows.push(row);
    }
    paintSelected();
};

window.addEventListener("message", (event) => {
    const msg = event.data;
    if (!msg || !msg.action) return;
    if (msg.action === "openPedDialog") {
        dialog = msg.data || null;
        selected = Math.max(1, (dialog && dialog.selected) || 1);
        render();
    } else if (msg.action === "closePedDialog") {
        dialog = null;
        render();
    } else if (msg.action === "pedDialogSelect") {
        if (!dialog || !msg.data || !msg.data.selected) return;
        selected = msg.data.selected;
        paintSelected();
    } else if (msg.action === "openClerkShop") {
        setHidden(root, true);
    }
});

window.addEventListener("keydown", (event) => {
    if (!dialog) return;
    const shopEl = document.getElementById("shop");
    if (shopEl && !shopEl.hasAttribute("hidden")) return;
    if (event.key === "ArrowUp") {
        event.preventDefault();
        post("pedDialogNav", { dir: "up" });
    } else if (event.key === "ArrowDown") {
        event.preventDefault();
        post("pedDialogNav", { dir: "down" });
    } else if (event.key === "Enter") {
        event.preventDefault();
        post("pedDialogNav", { dir: "confirm" });
    } else if (event.key === "Escape") {
        event.preventDefault();
        post("pedDialogClose", {});
    }
});

hintSelect.addEventListener("click", () => {
    if (!dialog) return;
    post("pedDialogNav", { dir: "confirm" });
});

hintBack.addEventListener("click", () => {
    if (!dialog) return;
    post("pedDialogNav", { dir: "back" });
});
