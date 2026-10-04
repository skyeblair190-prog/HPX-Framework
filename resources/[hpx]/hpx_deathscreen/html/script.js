const deathContainer = document.getElementById('death-container');
const timerBox = document.getElementById('timer-box');
const timerText = document.getElementById('timer-text');
const deathTitle = document.getElementById('death-title');
const deathSubtitle = document.getElementById('death-subtitle');
const waitState = document.getElementById('wait-state');
const respawnState = document.getElementById('respawn-state');
const holdSeconds = document.getElementById('hold-seconds');
const respawnPrefix = document.getElementById('respawn-prefix');
const respawnSuffix = document.getElementById('respawn-suffix');
const keyBadge = document.getElementById('key-badge');

window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data) return;

    if (data.action === 'update' || data.action === 'open') {
        deathContainer.classList.remove('hidden');

        // Position (default: bottom)
        if (data.position === 'top') {
            deathContainer.classList.remove('bottom');
            deathContainer.classList.add('top');
        } else {
            deathContainer.classList.remove('top');
            deathContainer.classList.add('bottom');
        }

        // Title & Subtitle
        if (data.title) {
            deathTitle.textContent = data.title;
        }
        if (data.subtitle) {
            deathSubtitle.textContent = data.subtitle;
        }

        // Timer
        if (data.timer !== undefined) {
            timerText.textContent = data.timer;
        }

        // Toggle Timer Box and Respawn State
        if (data.showRespawn) {
            timerBox.classList.add('hidden');
            waitState.classList.add('hidden');
            respawnState.classList.remove('hidden');

            if (data.holdTime !== undefined) {
                holdSeconds.textContent = `${data.holdTime}s`;
            }
            if (data.holdKey) {
                keyBadge.textContent = data.holdKey;
            }
            if (data.holdPrefix) {
                respawnPrefix.textContent = data.holdPrefix;
            }
            if (data.holdSuffix) {
                respawnSuffix.textContent = data.holdSuffix;
            }
        } else {
            if (data.showTimer !== false) {
                timerBox.classList.remove('hidden');
            } else {
                timerBox.classList.add('hidden');
            }
            waitState.classList.remove('hidden');
            respawnState.classList.add('hidden');
        }
    } else if (data.action === 'updateHold') {
        if (data.holdTime !== undefined) {
            holdSeconds.textContent = `${data.holdTime}s`;
        }
    } else if (data.action === 'hide') {
        deathContainer.classList.add('hidden');
    }
});
