// Kill switch for the legacy portfolio service worker.
//
// The previous site registered a caching service worker (portfolio-v3) that
// served CSS/JS/images cache-first. The redesigned site registers no service
// worker at all, but returning visitors still have the old one installed.
// This replacement takes over on their next visit, drops the old caches and
// unregisters itself, so everyone lands on the current site.
//
// It deliberately has no fetch handler: requests go straight to the network.

self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    // Purge every cache on this origin. The old worker used the 'portfolio-'
    // prefix, but this site stores nothing in Cache Storage, so deleting
    // unconditionally also catches any older naming scheme. This runs once.
    try {
      const names = await caches.keys();
      await Promise.all(names.map((n) => caches.delete(n)));
    } catch (e) {}

    try {
      await self.registration.unregister();
    } catch (e) {}
  })());
});
