import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';
import 'package:matsue_castle_chatbot/src/network/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'src/app.dart';
import 'src/settings/settings_controller.dart';
import 'src/settings/settings_service.dart';
import 'src/view_model/chat_view_model.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  print("TNI main.dart start");
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print("TNI Error loading .env file: $e");
  }
  await Hive.initFlutter();
  print("TNI Hive initialized");
  final settingsController = SettingsController(SettingsService());
  await settingsController.loadSettings();
  print("TNI Settings loaded: theme=${settingsController.themeMode}, lang=${settingsController.langMode}");

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print("TNI Firebase initialized");
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
  print("TNI Crashlytics error handler set");
  await AppLogger.init();
  print("TNI AppLogger initialized");

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChatViewModel(settingsController)),
        ChangeNotifierProvider<SettingsController>.value(value: settingsController),
      ],
      child: MyApp(settingsController: settingsController),
    ),
  );
}
