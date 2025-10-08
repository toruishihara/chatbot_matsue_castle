import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:matsue_castle_chat_bot/src/network/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'src/app.dart';
import 'src/settings/settings_controller.dart';
import 'src/settings/settings_service.dart';
import 'src/view_model/chat_view_model.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Hive.initFlutter();

  final settingsController = SettingsController(SettingsService());
  await settingsController.loadSettings();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await AppLogger.init();

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
