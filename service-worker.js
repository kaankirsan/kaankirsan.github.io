const CACHE_NAME = 'portfolio-v2';
const IMAGE_CACHE = 'portfolio-images-v2';
const VIDEO_CACHE = 'portfolio-video-v2';
const ALL_CACHES  = [CACHE_NAME, IMAGE_CACHE, VIDEO_CACHE];

const STATIC_ASSETS = [
  '/',
  '/index.html',
  '/css/variables.css',
  '/css/style.css',
  '/css/responsive.css',
  '/css/project-detail.css',
  '/js/scripts.min.js',
  '/images/favicon.ico',
  '/images/robot-logo.png',
  '/images/profile.jpg',
  '/images/hero-bg.jpg'
];

// Helper: detect video URLs by extension (some browsers report destination as 'empty')
function isVideoUrl(url) {
  return /\.(mp4|webm|ogv|mov)$/i.test(new URL(url).pathname);
}

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

// Activate event - clean up old portfolio caches only
self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(cacheNames => {
      return Promise.all(
        cacheNames
          .filter(name => name.startsWith('portfolio-') && !ALL_CACHES.includes(name))
          .map(name => caches.delete(name))
      );
    })
  );
  self.clients.claim();
});

// Fetch event - optimized caching strategies
self.addEventListener('fetch', event => {
  const { request } = event;
  const url = new URL(request.url);

  // Skip non-GET requests
  if (request.method !== 'GET') return;

  // Video: network-first with cache fallback.
  // Must be checked before image -- some browsers report video destination as 'empty'.
  // Videos are large; we cache after first fetch but prefer network for range-request seeking.
  if (request.destination === 'video' || isVideoUrl(request.url)) {
    event.respondWith(
      fetch(request).then(response => {
        if (response.ok) {
          caches.open(VIDEO_CACHE).then(cache => {
            cache.put(request, response.clone());
          });
        }
        return response;
      }).catch(() => {
        return caches.match(request).then(cached =>
          cached || new Response('Video unavailable offline', { status: 503 })
        );
      })
    );
    return;
  }

  // Images: cache-first with stale-while-revalidate (update in background)
  if (request.destination === 'image') {
    event.respondWith(
      caches.match(request).then(response => {
        if (response) {
          // Return cached copy immediately; revalidate in background
          fetch(request).then(freshResponse => {
            if (freshResponse.ok) {
              caches.open(IMAGE_CACHE).then(cache => {
                cache.put(request, freshResponse);
              });
            }
          }).catch(() => {});
          return response;
        }
        // No cache hit: fetch, cache, and return
        return fetch(request).then(response => {
          if (response.ok) {
            const cloned = response.clone();
            caches.open(IMAGE_CACHE).then(cache => {
              cache.put(request, cloned);
            });
          }
          return response;
        });
      }).catch(() => {
        // Serve a small inline placeholder SVG if fully offline
        return new Response(
          '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100"><rect fill="#2d3235" width="100" height="100"/></svg>',
          { headers: { 'Content-Type': 'image/svg+xml' }, status: 200 }
        );
      })
    );
    return;
  }

  // CSS, JS, Fonts: cache first strategy
  if (request.destination === 'style' ||
      request.destination === 'script' ||
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
