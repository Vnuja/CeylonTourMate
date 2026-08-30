import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
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

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCQ9XwaEWDPE3YEaD00AhKMN0dplkiTWAE',
    appId: '1:342502404771:web:91ba8e2eca1a09cad24516',
    messagingSenderId: '342502404771',
    projectId: 'vehiclemonitor-5b1e8',
    authDomain: 'vehiclemonitor-5b1e8.firebaseapp.com',
    storageBucket: 'vehiclemonitor-5b1e8.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBU80-7WH0zBN87uqPBtIwrhE-MvVIfJ7A',
    appId: '1:342502404771:android:407361204b173d9dd24516',
    messagingSenderId: '342502404771',
    projectId: 'vehiclemonitor-5b1e8',
    storageBucket: 'vehiclemonitor-5b1e8.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCQ9XwaEWDPE3YEaD00AhKMN0dplkiTWAE',
    appId: '1:342502404771:ios:mock-id',
    messagingSenderId: '342502404771',
    projectId: 'vehiclemonitor-5b1e8',
    storageBucket: 'vehiclemonitor-5b1e8.firebasestorage.app',
    iosBundleId: 'com.ceylontourmate.vehicle_monitor',
  );
}
