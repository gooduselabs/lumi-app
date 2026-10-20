import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/server_config.dart';
import 'core/locale_controller.dart';
import 'core/providers.dart';
import 'core/storage/token_storage.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/lumi_logo.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Color(0xFF0B0816),
  ));
  // Render the first frame immediately; everything else loads behind a Flutter splash.
  runApp(const LumiBootstrap());
}

class BootResult {
  const BootResult(this.prefs, this.tokens);
  final SharedPreferences prefs;
  final TokenStorage tokens;
}

/// Local-only startup work, each step bounded so a slow plugin can never freeze the app.
Future<BootResult> bootstrap({TokenStorage? tokens, Future<SharedPreferences> Function()? prefs}) async {
  final t = tokens ?? TokenStorage();
  final results = await Future.wait<Object?>([
    (prefs ?? SharedPreferences.getInstance)().timeout(const Duration(seconds: 8)),
    t.load(timeout: const Duration(seconds: 5)),
    initializeDateFormatting().timeout(const Duration(seconds: 3)).catchError((_) {}),
  ]);
  final p = results[0]! as SharedPreferences;
  ServerConfig.load(p);
  return BootResult(p, t);
}

class LumiBootstrap extends StatefulWidget {
  const LumiBootstrap({super.key, this.boot = bootstrap, this.app = const LumiApp()});
  final Future<BootResult> Function() boot;
  final Widget app;
  @override
  State<LumiBootstrap> createState() => _LumiBootstrapState();
}

class _LumiBootstrapState extends State<LumiBootstrap> {
  BootResult? _result;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() => _error = null);
    try {
      final r = await widget.boot();
      if (mounted) setState(() => _result = r);
    } catch (e, st) {
      debugPrint('Lumi bootstrap failed: $e\n$st');
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    if (r != null) {
      return ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(r.tokens),
          sharedPrefsProvider.overrideWithValue(r.prefs),
        ],
        child: widget.app,
      );
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: Scaffold(
        key: const Key('boot-splash'),
        backgroundColor: AppColors.bg,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const LumiLogo(size: 96, showWordmark: true),
            const SizedBox(height: 32),
            if (_error == null)
              const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.4))
            else ...[
              const Text('Lumi could not start / Không khởi động được', textAlign: TextAlign.center),
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 8, 32, 0),
                child: Text('$_error', textAlign: TextAlign.center, maxLines: 4, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textFaint, fontSize: 11)),
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: _run, child: const Text('Retry / Thử lại')),
            ],
          ]),
        ),
      ),
    );
  }
}
