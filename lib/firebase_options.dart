import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return ios;
      default:
        return ios;
    }
  }

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDDqXH6l3yrHdxLckGvt7Nn1rVfAq0sFKo',
    appId: '1:1097051657980:ios:dacf15029d24c61d8d6979',
    messagingSenderId: '1097051657980',
    projectId: 'fidelitypass-c4a88',
    storageBucket: 'fidelitypass-c4a88.firebasestorage.app',
    iosBundleId: 'com.yassin.qarta',
  );
}
