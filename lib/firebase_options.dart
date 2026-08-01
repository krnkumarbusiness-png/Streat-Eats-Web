// lib/firebase_options.dart
// Generated manually from google-services.json
// Web config added for PWA support — fill in values from Firebase Console.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    // kIsWeb must be checked BEFORE defaultTargetPlatform —
    // on web, defaultTargetPlatform returns fuchsia (Flutter quirk).
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // ── Android ──────────────────────────────────────────────────
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCgrXhwTEoL09aiyfzf9sDe0V9yhTa565o',
    appId: '1:519115337121:android:0bad8221eb2370bf03efe0',
    messagingSenderId: '519115337121',
    projectId: 'street-eats-mvp',
    storageBucket: 'street-eats-mvp.firebasestorage.app',
  );

  // ── Web ───────────────────────────────────────────────────────
  // TODO: Replace placeholder values with real ones from Firebase Console:
  //   Firebase Console → Project Settings → Your apps → Add app → Web
  //   Copy the firebaseConfig object values below.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDKomQjr39HXuOvAmsqESHuL1ooq4kNelQ',
    appId: '1:519115337121:web:885ad879876d7c9803efe0',
    messagingSenderId: '519115337121',
    projectId: 'street-eats-mvp',
    storageBucket: 'street-eats-mvp.firebasestorage.app',
    authDomain: 'street-eats-mvp.firebaseapp.com',
    // measurementId: 'G-XXXXXXXXXX', // optional — for Analytics
  );
}
