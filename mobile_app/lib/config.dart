import 'package:flutter/foundation.dart';

class AppConfig {
  // Browsers reach the local backend through localhost. The Android emulator
  // reaches the host machine through 10.0.2.2. Set API_BASE_URL at build time
  // to use a physical phone on the same LAN or an HTTPS deployment.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kIsWeb ? 'http://127.0.0.1:5000' : 'http://10.0.2.2:5000',
  );
}
