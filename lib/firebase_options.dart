import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Temporary stub so the project compiles until FlutterFire generates the
/// real file. Run `flutterfire configure` to replace this file with actual
/// Firebase app options.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'FlutterFire has not been configured for web yet. '
        'Run flutterfire configure.',
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'FlutterFire has not been configured for macOS yet. '
          'Run flutterfire configure.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'FlutterFire has not been configured for Windows yet. '
          'Run flutterfire configure.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'FlutterFire has not been configured for Linux yet. '
          'Run flutterfire configure.',
        );
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'FlutterFire has not been configured for Fuchsia yet. '
          'Run flutterfire configure.',
        );
    }
  }

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDatLR_3QxtRo61DJdrq7rnos9wUXI_TMU',
    appId: '1:588852404405:ios:e314b981428e4a28a85efc',
    messagingSenderId: '588852404405',
    projectId: 'fairbid-5394a',
    storageBucket: 'fairbid-5394a.firebasestorage.app',
    iosClientId: '588852404405-ekd78i29nqn7kom8lecr4l5jrcsu90i0.apps.googleusercontent.com',
    iosBundleId: 'com.example.fairbid',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDrxODcP3ICgZNSyqSvBioN3WEdnUBXxIc',
    appId: '1:588852404405:android:1040cc142fefb1faa85efc',
    messagingSenderId: '588852404405',
    projectId: 'fairbid-5394a',
    storageBucket: 'fairbid-5394a.firebasestorage.app',
  );

}