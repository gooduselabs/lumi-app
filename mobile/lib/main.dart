import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/locale_controller.dart';
import 'core/providers.dart';
import 'core/storage/token_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Color(0xFF0B0816),
  ));
  await initializeDateFormatting();
  final tokens = TokenStorage();
  final prefs = await SharedPreferences.getInstance();
  await tokens.load();
  runApp(ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(tokens),
      sharedPrefsProvider.overrideWithValue(prefs),
    ],
    child: const LumiApp(),
  ));
}
