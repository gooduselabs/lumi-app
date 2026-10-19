import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPrefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());

final localeProvider = NotifierProvider<LocaleController, Locale>(LocaleController.new);

/// Vietnamese by default; English available in Settings.
class LocaleController extends Notifier<Locale> {
  static const _key = 'lumi.locale';

  @override
  Locale build() => Locale(ref.read(sharedPrefsProvider).getString(_key) ?? 'vi');

  Future<void> set(String code) async {
    state = Locale(code);
    await ref.read(sharedPrefsProvider).setString(_key, code);
  }
}
