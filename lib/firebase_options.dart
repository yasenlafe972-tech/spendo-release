import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Generated directly from google-services.json & GoogleService-Info.plist
/// to ensure robust initialization on both Android and iOS (even when sideloaded).
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Web not supported');
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBLbHVGjMk7Rj6XU8Hzb-UOFjPGSmu8atU',
    appId: '1:86073315564:android:f3a609506325dbe0f695c9',
    messagingSenderId: '86073315564',
    projectId: 'spendo-4813f',
    storageBucket: 'spendo-4813f.firebasestorage.app',
    databaseURL:
        'https://spendo-4813f-default-rtdb.europe-west1.firebasedatabase.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBLbHVGjMk7Rj6XU8Hzb-UOFjPGSmu8atU',
    appId: '1:86073315564:ios:f3a609506325dbe0f695c9',
    messagingSenderId: '86073315564',
    projectId: 'spendo-4813f',
    storageBucket: 'spendo-4813f.firebasestorage.app',
    databaseURL:
        'https://spendo-4813f-default-rtdb.europe-west1.firebasedatabase.app',
    iosBundleId: 'com.personal.sanad.sanadApp',
  );
}
