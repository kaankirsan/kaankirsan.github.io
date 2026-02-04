const CACHE_NAME = 'portfolio-v1';
const STATIC_ASSETS = [
  '/',
  '/index.html',
  '/css/variables.css',
  '/css/style.css',
  '/css/responsive.css',
  '/css/project-detail.css',
  '/css/styles.min.css',
  '/js/main.js',
  '/js/navigation.js',
  '/js/animations.js',
  '/js/scripts.min.js',
  '/images/favicon.ico',
  '/images/robot-logo.png',
  '/images/profile.jpg'
];

// Install event - cache assets
self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache => {
      return cache.addAll(STATIC_ASSETS).catch(() => {
        // Gracefully handle missing files
        return Promise.resolve();
      });
    })
  );
  self.skipWaiting();
});

// Activate event - clean up old caches
self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(cacheNames => {
      return Promise.all(
        cacheNames.map(cacheName => {
          if (cacheName !== CACHE_NAME) {
            return caches.delete(cacheName);
          }
        })
      );
    })
  );
  self.clients.claim();
});

// Fetch event - cache first strategy for assets, network first for HTML
self.addEventListener('fetch', event => {
  const { request } = event;
  const url = new URL(request.url);

  // Skip non-GET requests
  if (request.method !== 'GET') return;

  // Cache first for static assets
  if (request.destination === 'style' ||
      request.destination === 'script' ||
      request.destination === 'image' ||
      request.destination === 'font') {
    event.respondWith(
      caches.match(request).then(response => {
        return response || fetch(request).then(response => {
          return caches.open(CACHE_NAME).then(cache => {
            cache.put(request, response.clone());
            return response;
          });
        });
      }).catch(() => {
        // Return placeholder if offline
        return new Response('Offline - asset not cached', { status: 503 });
      })
    );
    return;
  }

  // Network first for HTML
  event.respondWith(
    fetch(request)
      .then(response => {
        if (response.ok) {
          const clonedResponse = response.clone();
          caches.open(CACHE_NAME).then(cache => {
            cache.put(request, clonedResponse);
          });
        }
        return response;
      })
      .catch(() => {
        return caches.match(request).then(response => {
          return response || new Response(
            '<!DOCTYPE html><html><body><h1>Offline</h1><p>You are offline. Please check your connection.</p></body></html>',
            { headers: { 'Content-Type': 'text/html' } }
          );
        });
      })
  );
});
