Performance optimisation patch
==============================
Copy all root files over the matching files in your project.
Copy img/eco-environment-hero.webp into your project's img folder.

Key performance changes:
- Replaced Tailwind CDN with utilities.css
- Deferred public Firebase / analytics through firebase-loader.js
- WebP hero image preload and image fallback
- Lazy partner-logo image decoding
- Cache headers in firebase.json
