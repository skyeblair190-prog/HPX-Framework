class NotificationManager {
    constructor(containerId) {
        this.container = document.getElementById(containerId);
        this.icons = {
            success: '✓',
            inform: '!',
            error: '×'
        };
        this.minDuration = 500;
        this.maxDuration = 30000;
        this.defaultDuration = 4000;
        this.exitAnimationMs = 320;
    }

    normalizeType(rawType) {
        const type = String(rawType || 'inform').toLowerCase();
        if (type === 'sucess') return 'success';
        return this.icons[type] ? type : 'inform';
    }

    clampDuration(rawDuration) {
        const duration = Number(rawDuration) || this.defaultDuration;
        return Math.max(this.minDuration, Math.min(duration, this.maxDuration));
    }

    buildElement(type, message) {
        const item = document.createElement('div');
        item.className = `notification ${type}`;

        const iconBox = document.createElement('div');
        iconBox.className = 'icon-box';

        const icon = document.createElement('span');
        icon.className = 'icon';
        icon.textContent = this.icons[type];
        iconBox.appendChild(icon);

        const messageBox = document.createElement('div');
        messageBox.className = 'message-box';

        const messageEl = document.createElement('span');
        messageEl.className = 'message';
        messageEl.textContent = message;
        messageBox.appendChild(messageEl);

        item.append(iconBox, messageBox);
        return item;
    }

    show(data) {
        const type = this.normalizeType(data.type);
        const duration = this.clampDuration(data.duration);
        const message = String(data.message ?? '');

        const item = this.buildElement(type, message);
        this.container.appendChild(item);

        requestAnimationFrame(() => requestAnimationFrame(() => item.classList.add('show')));

        setTimeout(() => this.dismiss(item), duration);
    }

    dismiss(item) {
        item.classList.remove('show');
        item.classList.add('hide');
        setTimeout(() => item.remove(), this.exitAnimationMs);
    }
}

const notifications = new NotificationManager('codera-notifications');

window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || data.action !== 'notify') return;
    notifications.show(data);
});
