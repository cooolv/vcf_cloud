import 'dart:io';
import 'package:firebase_core/firebase_core.dart';

/// القيم بتتحقن وقت البناء بـ --dart-define (من GitHub Secrets أو env.json).
/// ملحوظة: دي إعدادات تعريف مش أسرار؛ الحماية الحقيقية في firestore.rules.
class FirebaseConfig {
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const androidApiKey = String.fromEnvironment('FIREBASE_ANDROID_API_KEY');
  static const androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const webApiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY');
  static const webAppId = String.fromEnvironment('FIREBASE_WEB_APP_ID');

  static bool get configured {
    final android = Platform.isAndroid;
    return projectId.isNotEmpty &&
        senderId.isNotEmpty &&
        (android
            ? androidApiKey.isNotEmpty && androidAppId.isNotEmpty
            : webApiKey.isNotEmpty && webAppId.isNotEmpty);
  }

  static FirebaseOptions get options {
    final android = Platform.isAndroid;
    return FirebaseOptions(
      apiKey: android ? androidApiKey : webApiKey,
      appId: android ? androidAppId : webAppId,
      messagingSenderId: senderId,
      projectId: projectId,
      authDomain: '$projectId.firebaseapp.com',
      storageBucket: '$projectId.firebasestorage.app',
    );
  }
}
