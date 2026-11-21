/* Deferred public SDK loading; native app uses supabase_flutter separately. */
(() => {
  let started = false;
  const load = src => new Promise((resolve, reject) => {
    const script = document.createElement('script');
    script.src = src; script.onload = resolve; script.onerror = reject;
    document.head.appendChild(script);
  });
  const start = async () => {
    if (started) return;
    started = true;
    try {
      await load('./vendor/supabase/supabase.js');
      await load('./supabase-config.js');
      await load('./supabase-backend.js');
      await load('./analytics.js');
    } catch (_) { console.warn('Backend unavailable. Static content remains available.'); }
  };
  ['pointerdown', 'touchstart', 'keydown'].forEach(name => window.addEventListener(name, start, { once: true, passive: true }));
  if ('requestIdleCallback' in window) window.requestIdleCallback(start, { timeout: 4500 });
  else window.setTimeout(start, 3000);
})();
