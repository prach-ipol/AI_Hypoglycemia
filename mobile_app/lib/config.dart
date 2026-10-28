class AppConfig {
  // Android emulator reaches the host machine through 10.0.2.2.
  // Set API_BASE_URL at build time to use a phone on the same LAN or HTTPS.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000',
  );
}
