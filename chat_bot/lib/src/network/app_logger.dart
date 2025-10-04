import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:matsue_castle_chat_bot/firebase_options.dart';

class AppLogger {
  static late FirebaseAnalytics _analytics;

  /// Initialize Firebase & Analytics
  static Future<void> init() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _analytics = FirebaseAnalytics.instance;
  }

  /// Send a custom debug log event to Firebase
  static Future<void> logDebugEvent(String message) async {
    if (kDebugMode) {
      print("debug_log:" + message);
    }
    await _analytics.logEvent(
      name: "debug_log",
      parameters: {
        "message": message,
        "timestamp": DateTime.now().toIso8601String(),
      },
    );
  }
}