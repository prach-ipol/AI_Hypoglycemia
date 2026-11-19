import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppConfig {
  // Build-time default, e.g.
  //   --dart-define=API_BASE_URL=http://192.168.x.x:5000   (physical phone)
  //   --dart-define=API_BASE_URL=https://your-api.example.com (deployment)
  static const _buildOverride = String.fromEnvironment('API_BASE_URL');

  // 10.0.2.2 is how the Android emulator reaches the host PC.
  static const _nativeDefault = 'http://10.0.2.2:5000';

  static const _storage = FlutterSecureStorage();
  static const _storageKey = 'api_base_url';

  // Address saved from the in-app "Server settings" dialog. It wins over the
  // build-time value so a phone keeps working when the PC's IP changes,
  // without rebuilding the APK.
  static String? _saved;

  static String get defaultBaseUrl {
    if (_buildOverride.isNotEmpty) return _buildOverride;
    // Flutter web runs on the same machine as the backend. Map "localhost"
    // to 127.0.0.1 because the backend listens on IPv4 only and browsers
    // may resolve localhost to IPv6 (::1).
    if (kIsWeb) {
      final host = Uri.base.host;
      return 'http://${host == 'localhost' ? '127.0.0.1' : host}:5000';
    }
    return _nativeDefault;
  }

  static String get apiBaseUrl => _saved ?? defaultBaseUrl;

  static Future<void> load() async {
    try {
      final value = await _storage.read(key: _storageKey);
      _saved = (value == null || value.isEmpty) ? null : value;
    } catch (_) {
      _saved = null;
    }
  }

  /// Saves [url] (normalised), or clears the saved value when null/empty.
  static Future<void> setApiBaseUrl(String? url) async {
    final normalised = normalise(url ?? '');
    _saved = normalised.isEmpty ? null : normalised;
    if (_saved == null) {
      await _storage.delete(key: _storageKey);
    } else {
      await _storage.write(key: _storageKey, value: _saved);
    }
  }

  /// Accepts "192.168.1.5", "192.168.1.5:5000" or a full URL.
  static String normalise(String input) {
    var value = input.trim();
    if (value.isEmpty) return '';
    if (!value.contains('://')) value = 'http://$value';
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return '';
    final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 5000);
    final defaultPort = uri.scheme == 'https' ? 443 : 80;
    final portPart = port == defaultPort ? '' : ':$port';
    return '${uri.scheme}://${uri.host}$portPart';
  }
}
