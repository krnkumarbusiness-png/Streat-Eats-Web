// lib/firebase_options.dart
// Generated manually from google-services.json

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCgrXhwTEoL09aiyfzf9sDe0V9yhTa565o',
    appId: '1:519115337121:android:0bad8221eb2370bf03efe0',
    messagingSenderId: '519115337121',
    projectId: 'street-eats-mvp',
    storageBucket: 'street-eats-mvp.firebasestorage.app',
  );
}
