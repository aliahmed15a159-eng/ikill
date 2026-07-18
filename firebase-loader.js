/* Deferred Firebase loader for public pages.
   Keeps Firebase/Firestore off the critical rendering path; it starts after
   first interaction or during idle time, while preserving forms and analytics. */
(function () {
  let started = false;

  function loadScript(src) {
    return new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = src;
      script.async = true;
      script.onload = resolve;
      script.onerror = reject;
      document.head.appendChild(script);
    });
  }

  async function startFirebase() {
    if (started) return;
    started = true;
    try {
      await loadScript('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
      await loadScript('https://www.gstatic.com/firebasejs/10.12.2/firebase-firestore-compat.js');
      await loadScript('./firebase-config.js');
      await loadScript('./analytics.js');
    } catch (error) {
      // The public UI remains fully usable if optional telemetry is blocked.
      console.warn('Optional Firebase services could not be loaded.', error);
    }
  }

  // Load immediately when a visitor starts interacting; otherwise use idle time.
  ['pointerdown', 'touchstart', 'keydown'].forEach(eventName => {
    window.addEventListener(eventName, startFirebase, { once: true, passive: true });
  });
  if ('requestIdleCallback' in window) {
    window.requestIdleCallback(startFirebase, { timeout: 4500 });
  } else {
    window.setTimeout(startFirebase, 3000);
  }
})();
