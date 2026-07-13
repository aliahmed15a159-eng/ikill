// ============================================================
// analytics.js — Global Standard Script (Non-Module)
// Tracks page views anonymously. Requires firebase-config.js.
// ============================================================

(function trackPageView() {
  // Wait until window.db is initialized
  const checkInterval = setInterval(() => {
    if (typeof firebase !== 'undefined' && window.db) {
      clearInterval(checkInterval);
      
      try {
        const rawPage = window.location.pathname.split('/').pop();
        const page = rawPage && rawPage.length > 0 ? rawPage : 'index.html';

        // Skip admin and login pages to avoid polluting stats
        if (page === 'admin.html' || page === 'admin-login.html') return;

        window.db.collection('page_views').add({
          page: page,
          timestamp: firebase.firestore.FieldValue.serverTimestamp(),
          referrer: document.referrer ? 'referral' : 'direct'
        });
      } catch (err) {
        // Silent catch for security/network issues
      }
    }
  }, 100);

  // Auto-clear interval after 5 seconds to prevent memory leaks if offline or blocked
  setTimeout(() => clearInterval(checkInterval), 5000);
})();
