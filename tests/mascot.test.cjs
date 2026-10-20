'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '../Scorpion/Mascot.js'), 'utf8');
let checks = 0;
function test(condition, message) { assert.ok(condition, message); checks++; }

function environment(origin = 'https://cobalt.meowing.de', nativeShare = null, mainFrame = true) {
  const mutations = [], links = [], timers = [], revoked = [], alerts = [];
  let callback, creations = 0;
  class Element {
    constructor(tag, attrs = {}) { this.tagName = tag.toUpperCase(); this.nodeType = 1; this.attrs = { ...attrs }; this.children = []; this.classList = { contains: value => (this.attrs.class || '').split(/\s+/).includes(value) }; }
    getAttribute(key) { return this.attrs[key] ?? null; }
    hasAttribute(key) { return Object.hasOwn(this.attrs, key); }
    setAttribute(key, value) { this.attrs[key] = value; mutations.push({ type: 'attributes', target: this }); }
    removeAttribute(key) { if (this.hasAttribute(key)) { delete this.attrs[key]; mutations.push({ type: 'attributes', target: this }); } }
    appendChild(child) { this.children.push(child); mutations.push({ type: 'childList', addedNodes: [child] }); return child; }
    querySelectorAll() { return this.children.flatMap(child => [ ...(child.tagName === 'IMG' ? [child] : []), ...child.querySelectorAll('img') ]); }
    click() { links.push({ href: this.href, download: this.download }); }
    remove() {}
  }
  class TestFile { constructor(name) { this.name = name; } }
  class TestURL extends URL {
    static createObjectURL() { creations++; return 'blob:' + origin + '/' + creations; }
    static revokeObjectURL(url) { revoked.push(url); }
  }
  const root = new Element('html');
  const navigator = nativeShare ? { share: nativeShare } : {};
  const window = {};
  window.alert = message => alerts.push(message);
  window.top = mainFrame ? window : {};
  const context = { location: { origin }, navigator, window, URL: TestURL, File: TestFile, DOMException,
    document: { baseURI: origin + '/', documentElement: root, body: root, createElement: tag => new Element(tag) },
    MutationObserver: class { constructor(fn) { callback = fn; } observe() {} },
    setTimeout(fn, milliseconds) { timers.push({ fn, milliseconds }); }
  };
  vm.runInNewContext(source, context);
  function flush() {
    let rounds = 0;
    while (mutations.length) {
      assert.ok(++rounds < 30, 'Mutation observer loop');
      const batch = mutations.splice(0);
      if (callback) callback(batch);
    }
    return rounds;
  }
  return { context, root, Element, TestFile, flush, links, timers, revoked, alerts, creations: () => creations };
}

(async function () {
  const env = environment();
  const cat = new env.Element('img', { class: 'meowbalt', src: '/meowbalt/happy.png', srcset: 'cat@2x.png 2x' });
  env.root.appendChild(cat); env.flush();
  test(cat.getAttribute('src') === '__SCORPION_DATA_URL__', 'Added mascot replaced');
  test(!cat.hasAttribute('srcset'), 'Responsive source cannot override mascot');
  test(env.flush() === 0, 'Observer settles without recursion');
  cat.setAttribute('src', '/meowbalt/sad.png'); env.flush();
  test(cat.getAttribute('src') === '__SCORPION_DATA_URL__', 'Changed source replaced');
  for (const src of ['/photos/cat.png', 'https://foreign.test/meowbalt/cat.png']) {
    const photo = new env.Element('img', { src }); env.root.appendChild(photo); env.flush();
    test(photo.getAttribute('src') === src, 'Unrelated and foreign image preserved');
  }
  const byURL = new env.Element('img', { src: '/meowbalt/cat.png' }); env.root.appendChild(byURL); env.flush();
  test(byURL.getAttribute('src') === '__SCORPION_DATA_URL__', 'Same-origin mascot URL replaced');
  const foreign = environment('https://foreign.test');
  const foreignCat = new foreign.Element('img', { class: 'meowbalt', src: '/meowbalt/cat.png' }); foreign.root.appendChild(foreignCat); foreign.flush();
  test(foreignCat.getAttribute('src') === '/meowbalt/cat.png', 'Foreign document untouched');
  test(typeof foreign.context.navigator.share === 'undefined', 'No foreign-origin share injection');
  const native = async () => {};
  test(environment(undefined, native).context.navigator.share === native, 'Working Web Share preserved');
  test(typeof environment(undefined, null, false).context.navigator.share === 'undefined', 'No subframe fallback');
  await assert.rejects(env.context.navigator.share({ files: [new env.TestFile('movie.mp4'), new env.TestFile('audio.m4a')] }), /sent to Downloads/); checks++;
  test(env.links.length === 2 && env.links[0].download === 'movie.mp4', 'Files use download anchors');
  test(env.alerts[0].includes('Download requested'), 'Fallback status is visibly reported without claiming completion');
  test(env.links.every(link => link.href.startsWith('blob:https://cobalt.meowing.de/')), 'Files stay local blobs');
  test(env.revoked.length === 0 && env.timers.every(timer => timer.milliseconds >= 600000), 'Blob lifetime retained');
  env.timers.forEach(timer => timer.fn());
  test(env.revoked.length === 2, 'Blob resources eventually released');
  for (const data of [null, {}, { files: [] }, { files: [{}] }, { files: 'x' }, { url: 'file:///a' }, { url: 'https://user:password@example.test' }, { url: 'invalid' }]) {
    await assert.rejects(env.context.navigator.share(data)); checks++;
  }
  test(env.creations() === 2, 'Malformed shares do not create blobs');
  await assert.rejects(env.context.navigator.share({ url: 'https://example.test/' }), /URL sharing is unavailable/); checks++;
  console.log(`Passed ${checks} mascot and share-fallback checks`);
})().catch(error => { console.error(error); process.exitCode = 1; });
