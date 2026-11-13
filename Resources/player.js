(() => {
    'use strict';
    if (location.hostname !== 'music.youtube.com' || window.ytmMini) return;
    const post = (name, body) => window.webkit.messageHandlers[name].postMessage(body);
    const sliders = () => Array.from(document.querySelectorAll('#volume-slider, #expand-volume-slider'));
    const clamp = value => Math.max(0, Math.min(100, value));
    let lastState = '', pending = null, playerBar = null, barObserver = null;

    function publish() {
        const video = document.querySelector('video');
        const slider = sliders().find(control => Number.isFinite(Number(control.value)));
        const state = {
            title: document.querySelector('.title.ytmusic-player-bar')?.textContent.trim() || 'Not Playing',
            artist: document.querySelector('.byline.ytmusic-player-bar a')?.textContent.trim() || 'Unknown Artist',
            isPlaying: !!video && !video.paused && !video.ended,
            hasTrack: !!video && !!document.querySelector('.title.ytmusic-player-bar'),
            volume: slider ? clamp(Number(slider.value)) / 100 : (video ? Math.sqrt(video.volume) : 1)
        };
        const serialized = JSON.stringify(state);
        if (serialized !== lastState) { lastState = serialized; post('playerState', state); }
    }
    function scheduleUpdate() {
        if (pending !== null) return;
        pending = setTimeout(() => { pending = null; bindPlayerBar(); publish(); }, 50);
    }
    function bindPlayerBar() {
        const next = document.querySelector('ytmusic-player-bar');
        if (next === playerBar) return;
        barObserver?.disconnect();
        playerBar = next;
        if (!next) return;
        barObserver = new MutationObserver(scheduleUpdate);
        barObserver.observe(next, { childList: true, subtree: true, characterData: true,
            attributes: true, attributeFilter: ['value', 'aria-valuenow', 'title'] });
    }
    function adjustVolume(delta) {
        const controls = sliders();
        const slider = controls.find(control => Number.isFinite(Number(control.value)));
        if (!slider) return false;
        const value = clamp(Number(slider.value) + delta);
        for (const control of controls) control.value = value;
        // Music owns audio mapping and persistence. Its change event keeps the
        // actual volume, both sliders, and our mini-player display synchronized.
        slider.dispatchEvent(new Event('change', { bubbles: true, composed: true }));
        publish();
        return true;
    }
    function perform(action) {
        if (action === 'volumeUp') return adjustVolume(5);
        if (action === 'volumeDown') return adjustVolume(-5);
        const video = document.querySelector('video');
        if (action === 'play' && video && !video.paused) return true;
        if (action === 'pause' && (!video || video.paused)) return true;
        const selector = { play: '#play-pause-button', pause: '#play-pause-button',
            togglePlayback: '#play-pause-button', next: '.next-button', previous: '.previous-button' }[action];
        if (!selector) return false;
        const button = document.querySelector(selector);
        if (!button || button.disabled || button.getAttribute('aria-disabled') === 'true') return false;
        button.click();
        scheduleUpdate();
        return true;
    }
    function isEditing(event) {
        return event.composedPath().some(element => element && (
            element.isContentEditable || element.tagName === 'TEXTAREA' || element.tagName === 'SELECT' ||
            (element.tagName === 'INPUT' && !['range', 'button', 'checkbox', 'radio', 'submit'].includes(element.type))
        ));
    }
    // Installed at document start, before Music's own shortcuts. Check the actual
    // event target rather than an asynchronous native copy of input focus.
    window.addEventListener('keydown', event => {
        if (event.defaultPrevented || event.isComposing || event.metaKey || event.ctrlKey || event.altKey || event.shiftKey || isEditing(event)) return;
        const action = { j: 'volumeDown', k: 'volumeUp', '-': 'volumeDown', '=': 'volumeUp',
            h: 'previous', l: 'next', p: 'togglePlayback', e: 'toggleSize', f: 'toggleAutoHide',
            s: 'snap', t: 'toggleTransparency', q: 'quit' }[event.key];
        if (!action) return;
        event.preventDefault();
        event.stopImmediatePropagation();
        if (event.repeat && action !== 'volumeDown' && action !== 'volumeUp') return;
        if (['volumeDown', 'volumeUp', 'previous', 'next', 'togglePlayback'].includes(action)) perform(action);
        else post('shortcut', action);
    }, true);
    window.ytmMini = { perform };
    function start() {
        bindPlayerBar();
        publish();
        // Ignore high-frequency style/progress attributes outside the player bar.
        new MutationObserver(scheduleUpdate).observe(document.body, { childList: true, subtree: true });
        for (const event of ['play', 'pause', 'ended', 'volumechange', 'change', 'value-changed']) {
            document.addEventListener(event, scheduleUpdate, true);
        }
    }
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start, { once: true });
    else start();
})();
