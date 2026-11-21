import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';

class Backend {
  static bool ready = false;
  static const androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY',
      defaultValue: '');
  static const iosApiKey = String.fromEnvironment('FIREBASE_IOS_API_KEY');

  static Future<void> initialize() async {
    // flutterfire configure supplies the native GoogleService files. Explicit
    // mobile app IDs can alternatively be passed at build time.
    try {
      if (androidAppId.isNotEmpty || iosAppId.isNotEmpty) {
        // Avoid importing dart:io, keeping widget tests platform-independent.
        final isIos = defaultTargetPlatform == TargetPlatform.iOS;
        final appId = isIos ? iosAppId : androidAppId;
        if (appId.isEmpty) return;
        await Firebase.initializeApp(options: FirebaseOptions(
          apiKey: isIos ? iosApiKey : apiKey, appId: appId, messagingSenderId: '27384687475',
          projectId: 'ikill-4e337', storageBucket: 'ikill-4e337.firebasestorage.app',
          iosBundleId: 'net.ikill.app',
        ));
      } else {
        await Firebase.initializeApp();
      }
      ready = true;
    } catch (_) {
      ready = false;
    }
  }

  static FirebaseFirestore get db => FirebaseFirestore.instance;

  static Future<void> submit(Map<String, String> values) async {
    if (!ready) throw StateError('Firebase is not configured');
    await db.collection('contact_submissions').add({
      ...values, 'timestamp': FieldValue.serverTimestamp(),
    }).timeout(const Duration(seconds: 25));
  }
}
