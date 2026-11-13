const test = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const source = fs.readFileSync(`${__dirname}/../Resources/player.js`, 'utf8');

function fixture({volume = 50, metadata = true, sliderCount = 2, hostname = 'music.youtube.com'} = {}) {
    const messages = [], timers = [], observers = [], listeners = {};
    const video = {volume: (volume / 100) ** 2, paused: false, ended: false};
    let changes = 0, previous = 0, next = 0, toggles = 0;
    const controls = Array.from({length: sliderCount}, () => ({value: volume, dispatchEvent(event) {
        assert.equal(event.type, 'change');
        assert.equal(event.bubbles, true);
        changes++;
        video.volume = (this.value / 100) ** 2; // Website's slider-change handler.
    }}));
    const button = fn => ({click: fn, getAttribute: () => null});
    const nodes = {
        video, 'ytmusic-player-bar': {},
        '.title.ytmusic-player-bar': metadata ? {textContent: ' Track '} : null,
        '.byline.ytmusic-player-bar a': metadata ? {textContent: ' Artist '} : null,
        '.previous-button': button(() => previous++), '.next-button': button(() => next++),
        '#play-pause-button': button(() => { toggles++; video.paused = !video.paused; })
    };
    const context = {
        location: {hostname}, Event: class { constructor(type, init) { this.type = type; Object.assign(this, init); } },
        MutationObserver: class {
            constructor(callback) { this.callback = callback; observers.push(this); }
            observe(target, options) { this.target = target; this.options = options; }
            disconnect() { this.disconnected = true; }
        },
        setTimeout(callback) { timers.push(callback); return timers.length; },
        document: {readyState: 'complete', body: {}, querySelector: s => nodes[s], querySelectorAll: () => controls,
            addEventListener(name, handler) { listeners[name] = handler; }},
        window: {webkit: {messageHandlers: Object.fromEntries(['playerState', 'shortcut'].map(name => [name, {
            postMessage: body => messages.push({name, body})
        }]))}, addEventListener(name, handler) { listeners[name] = handler; }}
    };
    vm.runInNewContext(source, context);
    return {
        context, controls, nodes, video, messages, observers, timers,
        counts: () => ({changes, previous, next, toggles}),
        perform: action => context.window.ytmMini.perform(action),
        flush() { while (timers.length) timers.shift()(); },
        state: () => messages.filter(m => m.name === 'playerState').at(-1)?.body,
        key(key, options = {}) {
            const event = {key, composedPath: () => [], preventDefault() { this.prevented = true; },
                stopImmediatePropagation() { this.stopped = true; }, ...options};
            listeners.keydown(event); return event;
        }
    };
}

test('j/k update audio, both sliders and native bar without skipping tracks', () => {
    const f = fixture();
    for (const [key, expected] of [['j', 45], ['j', 40], ['k', 45]]) {
        const event = f.key(key);
        assert.equal(event.prevented, true); assert.equal(event.stopped, true);
        assert.deepEqual(f.controls.map(s => s.value), [expected, expected]);
        assert.equal(f.state().volume, expected / 100);
        assert.equal(f.video.volume, (expected / 100) ** 2);
    }
    assert.equal(f.counts().previous + f.counts().next, 0);
});
test('volume clamps at both ends and supports held keys', () => {
    const f = fixture({volume: 99});
    f.key('k', {repeat: true}); assert.equal(f.state().volume, 1);
    for (let i = 0; i < 25; i++) f.key('j', {repeat: true});
    assert.equal(f.state().volume, 0);
});
test('volume publishes without track metadata and with only one slider', () => {
    const f = fixture({metadata: false, sliderCount: 1});
    f.perform('volumeDown'); assert.equal(f.state().volume, .45);
});
test('missing or malformed sliders are not reported as successful volume changes', () => {
    assert.equal(fixture({sliderCount: 0}).perform('volumeUp'), false);
    const f = fixture(); f.controls.forEach(s => s.value = 'invalid');
    assert.equal(f.perform('volumeUp'), false);
});
test('search, shadow DOM inputs, contenteditable, selects, and IME preserve typing', () => {
    const f = fixture();
    for (const target of [{tagName:'INPUT', type:'search'}, {tagName:'TEXTAREA'}, {tagName:'SELECT'}, {isContentEditable:true}]) {
        for (const key of ['j','k','h','l','q','e']) {
            const event = f.key(key, {composedPath: () => [{}, target]});
            assert.equal(event.prevented, undefined);
        }
    }
    assert.equal(f.key('j', {isComposing:true}).prevented, undefined);
    assert.equal(f.counts().changes, 0);
});
test('modified shortcuts pass through; focused range slider does not disable j/k', () => {
    const f = fixture();
    for (const modifier of ['metaKey','ctrlKey','altKey','shiftKey']) assert.equal(f.key('j', {[modifier]:true}).prevented, undefined);
    f.key('j', {composedPath: () => [{tagName:'INPUT', type:'range'}]});
    assert.equal(f.state().volume, .45);
});
test('h/l skip once and consume repeats without skipping again', () => {
    const f = fixture(); f.key('h'); f.key('l');
    assert.equal(f.key('h', {repeat:true}).prevented, true);
    f.key('l', {repeat:true});
    assert.equal(f.counts().previous, 1); assert.equal(f.counts().next, 1);
});
test('remote play and pause are idempotent', () => {
    const f = fixture(); f.perform('play'); f.perform('pause'); f.perform('pause');
    assert.equal(f.counts().toggles, 1);
    f.perform('play'); assert.equal(f.counts().toggles, 2);
});
test('bursts are coalesced and unchanged state is not sent again', () => {
    const f = fixture();
    for (let i = 0; i < 500; i++) f.observers.forEach(o => o.callback());
    assert.equal(f.timers.length, 1);
    f.flush(); assert.equal(f.messages.length, 1);
    f.nodes['.title.ytmusic-player-bar'].textContent = 'New track';
    f.observers[0].callback(); f.flush(); assert.equal(f.state().title, 'New track');
    assert.equal(f.messages.length, 2);
    assert.equal(f.observers.find(o => o.target === f.context.document.body).options.attributes, undefined);
});
test('a replaced player bar is observed and old observer is disconnected', () => {
    const f = fixture(); const old = f.observers[0];
    f.nodes['ytmusic-player-bar'] = {};
    f.observers[1].callback(); f.flush();
    assert.equal(old.disconnected, true);
    assert.equal(f.observers.at(-1).target, f.nodes['ytmusic-player-bar']);
});
test('window actions are dispatched once and repeated toggles are ignored', () => {
    const f = fixture(); f.key('e'); f.key('e', {repeat:true});
    assert.equal(f.messages.filter(m => m.name === 'shortcut').length, 1);
    assert.equal(f.messages.at(-1).body, 'toggleSize');
});
test('scripts stay inactive on sign-in and unrelated origins', () => {
    const f = fixture({hostname:'accounts.google.com'});
    assert.equal(f.context.window.ytmMini, undefined);
});
