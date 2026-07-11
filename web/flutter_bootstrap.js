// ════════════════════════════════════════════════════════════════
// web/flutter_bootstrap.js — Streat Eats custom Flutter bootstrap
// ════════════════════════════════════════════════════════════════

{{flutter_js}}
{{flutter_build_config}}

// ── 1. Register our custom service worker ─────────────────────────
(function registerServiceWorker() {
  if (!('serviceWorker' in navigator)) return;

  navigator.serviceWorker.register('/sw.js', { scope: '/' })
    .then((reg) => {
      console.log('[App] Service worker registered, scope:', reg.scope);

      if (reg.waiting) {
        showUpdateBanner(reg.waiting);
      }

      reg.addEventListener('updatefound', () => {
        const newWorker = reg.installing;
        if (!newWorker) return;

        newWorker.addEventListener('statechange', () => {
          if (newWorker.state === 'installed' && navigator.serviceWorker.controller) {
            showUpdateBanner(newWorker);
          }
        });
      });
    })
    .catch((err) => console.warn('[App] SW registration failed:', err));

  navigator.serviceWorker.addEventListener('message', (event) => {
    if (event.data && event.data.type === 'UPDATE_AVAILABLE') {
      navigator.serviceWorker.getRegistration().then((reg) => {
        if (reg && reg.waiting) showUpdateBanner(reg.waiting);
      });
    }
  });

  let refreshing = false;
  navigator.serviceWorker.addEventListener('controllerchange', () => {
    if (!refreshing) { refreshing = true; window.location.reload(); }
  });
})();

// ── 2. Update banner ──────────────────────────────────────────────
function showUpdateBanner(waitingWorker) {
  if (document.getElementById('se-update-banner')) return;

  const banner = document.createElement('div');
  banner.id = 'se-update-banner';
  banner.setAttribute('role', 'alert');
  banner.innerHTML = `
    <style>
      #se-update-banner {
        position: fixed;
        bottom: 24px;
        left: 50%;
        transform: translateX(-50%);
        z-index: 100000;
        background: #1A1A1A;
        color: #fff;
        border-radius: 16px;
        padding: 14px 20px;
        display: flex;
        align-items: center;
        gap: 14px;
        box-shadow: 0 8px 32px rgba(0,0,0,0.28);
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        font-size: 14px;
        max-width: calc(100vw - 32px);
        animation: se-slide-up 0.35s cubic-bezier(0.34,1.56,0.64,1) both;
      }
      @keyframes se-slide-up {
        from { transform: translateX(-50%) translateY(80px); opacity: 0; }
        to   { transform: translateX(-50%) translateY(0);   opacity: 1; }
      }
      #se-update-banner .se-icon { font-size: 20px; flex-shrink: 0; }
      #se-update-banner .se-text { flex: 1; line-height: 1.4; }
      #se-update-banner .se-text strong { display: block; font-size: 14px; color: #fff; }
      #se-update-banner .se-text span   { font-size: 12px; color: #9CA3AF; }
      #se-update-banner .se-btn {
        background: #FF6B35;
        color: #fff;
        border: none;
        border-radius: 10px;
        padding: 8px 16px;
        font-size: 13px;
        font-weight: 700;
        cursor: pointer;
        flex-shrink: 0;
        transition: background 0.15s;
        -webkit-tap-highlight-color: transparent;
      }
      #se-update-banner .se-btn:hover { background: #e05a28; }
      #se-update-banner .se-close {
        background: none; border: none; color: #6B7280;
        font-size: 18px; cursor: pointer; padding: 0 0 0 4px;
        line-height: 1; flex-shrink: 0;
      }
    </style>
    <span class="se-icon">🎉</span>
    <div class="se-text">
      <strong>New version available</strong>
      <span>Tap Refresh to update Streat Eats</span>
    </div>
    <button class="se-btn" id="se-update-btn">Refresh</button>
    <button class="se-close" id="se-update-dismiss" aria-label="Dismiss">✕</button>
  `;

  document.body.appendChild(banner);

  document.getElementById('se-update-btn').addEventListener('click', () => {
    banner.remove();
    waitingWorker.postMessage({ type: 'SKIP_WAITING' });
  });

  document.getElementById('se-update-dismiss').addEventListener('click', () => {
    banner.remove();
  });
}

// ── 3. Offline / online status banner ────────────────────────────
(function trackConnectivity() {
  let offlineBanner = null;

  function showOfflineBanner() {
    if (offlineBanner) return;
    offlineBanner = document.createElement('div');
    offlineBanner.id = 'se-offline-banner';
    offlineBanner.setAttribute('role', 'status');
    offlineBanner.innerHTML = `
      <style>
        #se-offline-banner {
          position: fixed;
          top: 0; left: 0; right: 0;
          z-index: 99999;
          background: #1F2937;
          color: #fff;
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
          font-size: 13px;
          padding: 10px 16px;
          display: flex;
          align-items: center;
          justify-content: center;
          gap: 8px;
          animation: se-drop-down 0.25s ease both;
        }
        @keyframes se-drop-down {
          from { transform: translateY(-100%); }
          to   { transform: translateY(0); }
        }
        #se-offline-banner .se-dot {
          width: 8px; height: 8px; border-radius: 50%;
          background: #EF4444; flex-shrink: 0;
          animation: se-blink 1.2s ease-in-out infinite;
        }
        @keyframes se-blink {
          0%, 100% { opacity: 1; } 50% { opacity: 0.3; }
        }
      </style>
      <span class="se-dot"></span>
      You're offline — some features may not be available
    `;
    document.body.prepend(offlineBanner);
  }

  function hideOfflineBanner() {
    if (offlineBanner) {
      offlineBanner.style.transition = 'transform 0.2s ease';
      offlineBanner.style.transform = 'translateY(-100%)';
      setTimeout(() => { offlineBanner?.remove(); offlineBanner = null; }, 220);
    }
  }

  window.addEventListener('offline', showOfflineBanner);
  window.addEventListener('online',  hideOfflineBanner);

  if (!navigator.onLine) showOfflineBanner();
})();

// ── 4. Start Flutter ──────────────────────────────────────────────
_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
    if (typeof removeSplashFromWeb === 'function') {
      removeSplashFromWeb();
    }
  }
});
