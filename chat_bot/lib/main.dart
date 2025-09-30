import 'package:ai_shop_list/src/repository/rag_repository.dart';
import 'package:ai_shop_list/src/repository/shop_list_repository.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'src/app.dart';
import 'src/network/open_ai_client.dart';
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

  final box = await Hive.openBox('shoplistBox');
  final shopRepo = ShopListRepository(box);
  final ragRepo = RagRepository();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ChatViewModel(OpenAiClient(), ragRepo),
      child: MyApp(settingsController: settingsController),
    ),
  );
}
