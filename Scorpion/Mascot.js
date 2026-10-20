(function () {
  'use strict';
  if (location.origin !== 'https://cobalt.meowing.de') return;
  const replacement = '__SCORPION_DATA_URL__';
  // Web Share is absent in some WKWebView versions. Keep file bytes in WebKit.
  // The rejection is intentional: queued downloads are not a completed share.
  if (window.top === window && typeof navigator.share !== 'function') {
    Object.defineProperty(navigator, 'share', { configurable: true, value: async function (data) {
      if (!data || typeof data !== 'object') throw new TypeError('Share data is required.');
      if (data.files !== undefined) {
        if (!Array.isArray(data.files) || data.files.length === 0 || data.files.length > 16 ||
            !data.files.every(file => file instanceof File)) {
          throw new TypeError('Share requires between 1 and 16 files.');
        }
        for (const file of data.files) {
          const url = URL.createObjectURL(file);
          const link = document.createElement('a');
          link.href = url;
          link.download = file.name || 'download';
          (document.body || document.documentElement).appendChild(link);
          link.click();
          link.remove();
          // Revoking immediately can race WKDownload's ownership of the blob.
          setTimeout(() => URL.revokeObjectURL(url), 10 * 60 * 1000);
        }
        window.alert('Download requested. Check the Downloads folder button for status, then tap a completed file to share it.');
        throw new DOMException('Files were sent to Downloads. Check the folder button for completion, then tap a file to share it.', 'NotSupportedError');
      }
      if (typeof data.url === 'string') {
        let url;
        try { url = new URL(data.url); } catch (_) { throw new TypeError('A valid HTTPS URL is required.'); }
        if (url.protocol !== 'https:' || url.username || url.password) throw new TypeError('A valid HTTPS URL is required.');
        window.alert('URL sharing is unavailable in this browser. Copy the website link or open it in Safari.');
        throw new DOMException('URL sharing is unavailable in this browser. Copy the website link or open it in Safari.', 'NotSupportedError');
      }
      window.alert('This share type is unavailable. Use Downloads to export completed files.');
      throw new DOMException('This share type is unavailable. Use Downloads to export completed files.', 'NotSupportedError');
    }});
  }
  function replace(image) {
    if (!image || image.tagName !== 'IMG') return;
    if (image.getAttribute('src') === replacement && !image.hasAttribute('srcset')) return;
    let mascot = image.classList.contains('meowbalt');
    try {
      const url = new URL(image.getAttribute('src') || '', document.baseURI);
      mascot = mascot || (url.origin === location.origin && url.pathname.startsWith('/meowbalt/'));
    } catch (_) {}
    if (!mascot) return;
    image.removeAttribute('srcset');
    image.setAttribute('src', replacement);
  }
  function scan(node) {
    if (node.nodeType !== 1) return;
    replace(node);
    node.querySelectorAll('img').forEach(replace);
  }
  const observer = new MutationObserver(function (records) {
    for (const record of records) {
      if (record.type === 'attributes') replace(record.target);
      else record.addedNodes.forEach(scan);
    }
  });
  observer.observe(document, { subtree: true, childList: true, attributes: true, attributeFilter: ['src', 'srcset', 'class'] });
  if (document.documentElement) scan(document.documentElement);
})();
