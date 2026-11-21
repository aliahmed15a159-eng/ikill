// ============================================================
// analytics.js — Global Standard Script (Non-Module)
// Tracks page views anonymously. Requires supabase-config.js.
// ============================================================

(function trackPageView() {
  // Wait until window.db is initialized
  const checkInterval = setInterval(() => {
    if (window.supabaseClient && window.db) {
      clearInterval(checkInterval);
      
      try {
        const rawPage = window.location.pathname.split('/').pop();
        const page = rawPage && rawPage.length > 0 ? rawPage : 'index.html';

        // Skip admin and login pages to avoid polluting stats
        if (page === 'admin.html' || page === 'admin-login.html') return;

        window.db.table('page_events').add({
          page: page,
          timestamp: new Date().toISOString(),
          referrer: document.referrer ? 'referral' : 'direct'
        }).catch(() => {}); // Optional analytics must not reject unhandled.
      } catch (err) {
        // Silent catch for security/network issues
      }
    }
  }, 100);

  // Auto-clear interval after 5 seconds to prevent memory leaks if offline or blocked
  setTimeout(() => clearInterval(checkInterval), 5000);
})();
