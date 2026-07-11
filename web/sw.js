// ════════════════════════════════════════════════════════════════
// web/sw.js — Streat Eats custom service worker
//
// Strategy overview:
//   SHELL assets  → Cache-First  (icons, splash images, offline.html)
//   Flutter assets → Network-First with cache fallback
//                   (Flutter updates these with version hashes anyway)
//   API / Supabase → Network-Only (never cache live data)
//   Everything else → Network-First, serve cached on failure
//
// Update flow:
//   1. Browser checks sw.js on every page load (it's served no-cache)
//   2. If sw.js changed → new worker installs alongside old one
//   3. New worker fires 'message' to all clients → they show the
//      "New version available" banner
//   4. When user taps Refresh, client sends {type:'SKIP_WAITING'}
//   5. Worker calls skipWaiting() → takes over → page reloads
// ════════════════════════════════════════════════════════════════

const APP_SHELL_CACHE = 'streat-shell-v1';
const RUNTIME_CACHE  = 'streat-runtime-v1';

// Assets pre-cached on install — must all exist in web/
const SHELL_ASSETS = [
  '/offline.html',
  '/manifest.json',
  '/icons/Icon-192.png',
  '/icons/Icon-512.png',
  '/icons/Icon-maskable-192.png',
  '/favicon.png',
];

// Domains whose requests are never cached (live data)
const NEVER_CACHE = [
  'supabase.co',
  'supabase.in',
  'razorpay.com',
  'googleapis.com',
  'firebaseio.com',
  'fcm.googleapis.com',
];

// ── Install: pre-cache the app shell ─────────────────────────────
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(APP_SHELL_CACHE).then((cache) => {
      // addAll() fails silently per-item; use individual adds so one
      // missing splash image doesn't abort the entire install
      return Promise.allSettled(
        SHELL_ASSETS.map((url) => cache.add(url).catch((err) => {
          console.warn(`[SW] Shell cache miss: ${url}`, err);
        }))
      );
    })
  );
  // Don't call skipWaiting() here — we wait for the user to confirm
  // the update so they don't lose in-progress actions (e.g. checkout)
});

// ── Activate: clean up old caches ────────────────────────────────
self.addEventListener('activate', (event) => {
  const CURRENT_CACHES = [APP_SHELL_CACHE, RUNTIME_CACHE];
  event.waitUntil(
    caches.keys().then((cacheNames) =>
      Promise.all(
        cacheNames
          .filter((name) => !CURRENT_CACHES.includes(name))
          .map((name) => {
            console.log(`[SW] Deleting old cache: ${name}`);
            return caches.delete(name);
          })
      )
    ).then(() => {
      // Notify all open clients that this worker is now controlling them
      return self.clients.claim();
    })
  );
});

// ── Fetch: routing logic ──────────────────────────────────────────
self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);

  // 1. Skip non-GET and chrome-extension requests
  if (request.method !== 'GET') return;
  if (url.protocol === 'chrome-extension:') return;

  // 2. Never cache live API / payment calls
  if (NEVER_CACHE.some((domain) => url.hostname.includes(domain))) {
    event.respondWith(fetch(request));
    return;
  }

  // 3. For navigate (HTML page) requests: network-first, offline fallback
  if (request.mode === 'navigate') {
    event.respondWith(
      fetch(request)
        .then((res) => {
          // Also cache the fresh navigation response
          if (res.ok) {
            const clone = res.clone();
            caches.open(RUNTIME_CACHE).then((c) => c.put(request, clone));
          }
          return res;
        })
        .catch(() =>
          caches.match(request).then((cached) => cached || caches.match('/offline.html'))
        )
    );
    return;
  }

  // 4. Flutter core assets (main.dart.js, flutter.js, engine .wasm/.wasm.gz,
  //    canvaskit) — network-first so updates arrive promptly.
  //    Version hashes in filenames mean stale caches self-invalidate anyway.
  if (
    url.pathname.includes('main.dart.js') ||
    url.pathname.includes('flutter.js') ||
    url.pathname.includes('flutter_bootstrap.js') ||
    url.pathname.includes('flutter_service_worker.js') ||
    url.pathname.includes('.wasm') ||
    url.pathname.includes('canvaskit')
  ) {
    event.respondWith(
      fetch(request)
        .then((res) => {
          if (res.ok) {
            const clone = res.clone();
            caches.open(RUNTIME_CACHE).then((c) => c.put(request, clone));
          }
          return res;
        })
        .catch(() => caches.match(request))
    );
    return;
  }

  // 5. Shell assets (icons, splash, manifest) — cache-first, very stable
  if (SHELL_ASSETS.some((a) => url.pathname.endsWith(a))) {
    event.respondWith(
      caches.match(request).then((cached) => cached || fetch(request))
    );
    return;
  }

  // 6. Everything else (fonts from CDN, images, etc.) — stale-while-revalidate
  event.respondWith(
    caches.open(RUNTIME_CACHE).then((cache) =>
      cache.match(request).then((cached) => {
        const networkFetch = fetch(request).then((res) => {
          if (res.ok) cache.put(request, res.clone());
          return res;
        }).catch(() => cached);   // network failed → serve stale

        // Return cached immediately if available, update in background
        return cached || networkFetch;
      })
    )
  );
});

// ── Message handler: skipWaiting on user confirmation ─────────────
self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    console.log('[SW] Skipping waiting — activating new version');
    self.skipWaiting();
  }
});
