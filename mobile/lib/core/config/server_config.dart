import 'package:shared_preferences/shared_preferences.dart';

import 'env.dart';

/// Runtime API base URL. Defaults to the build-time [Env.apiBaseUrl] but a tester can
/// point the app at any reachable server (hidden "Server address" dialog) without rebuilding.
class ServerConfig {
  const ServerConfig._();
  static const prefsKey = 'lumi.apiBaseUrl';
  static String _current = Env.apiBaseUrl;
  static final _listeners = <void Function(String)>[];

  static String get current => _current;
  static bool get isOverridden => _current != Env.apiBaseUrl;

  static void addListener(void Function(String) l) => _listeners.add(l);
  static void removeListener(void Function(String) l) => _listeners.remove(l);

  /// Returns a normalized `scheme://host[:port][/path]` (no trailing slash) or null if invalid.
  static String? normalize(String input) {
    var s = input.trim();
    if (s.isEmpty || s.contains(' ')) return null;
    if (!s.contains('://')) s = 'http://$s';
    final u = Uri.tryParse(s);
    if (u == null || !(u.scheme == 'http' || u.scheme == 'https') || u.host.isEmpty) return null;
    if (u.hasQuery || u.hasFragment || u.userInfo.isNotEmpty) return null;
    if (u.hasPort && (u.port <= 0 || u.port > 65535)) return null;
    final path = u.path.replaceAll(RegExp(r'/+$'), '');
    return '${u.scheme}://${u.host}${u.hasPort ? ':${u.port}' : ''}$path';
  }

  static void load(SharedPreferences prefs) {
    final saved = prefs.getString(prefsKey);
    _current = (saved != null ? normalize(saved) : null) ?? Env.apiBaseUrl;
  }

  /// Persists [url] (or resets to the build default when null). Throws [FormatException] if invalid.
  static Future<String> save(SharedPreferences prefs, String? url) async {
    if (url == null || url.trim().isEmpty) {
      await prefs.remove(prefsKey);
      _set(Env.apiBaseUrl);
      return _current;
    }
    final n = normalize(url);
    if (n == null) throw const FormatException('Invalid server URL');
    await prefs.setString(prefsKey, n);
    _set(n);
    return n;
  }

  static void _set(String v) {
    if (v == _current) return;
    _current = v;
    for (final l in List.of(_listeners)) {
      l(v);
    }
  }

  /// Test helper.
  static void debugReset() {
    _current = Env.apiBaseUrl;
    _listeners.clear();
  }
}
