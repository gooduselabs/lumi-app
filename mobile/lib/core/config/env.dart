/// Build-time configuration. Override with:
///   flutter build apk --dart-define=API_BASE_URL=https://api.example.com
class Env {
  const Env._();

  /// Default works for the Android emulator talking to a backend on the host machine.
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:3000');

  static const appName = 'Lumi';
  static const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');
}
