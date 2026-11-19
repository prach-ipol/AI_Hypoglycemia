import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import 'server_discovery.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.code, this.statusCode});
  final String message;
  final String? code;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiService {
  static const _storage = FlutterSecureStorage();
  String? token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Uri _uri(String path) => Uri.parse('${AppConfig.apiBaseUrl}$path');

  static const _timeout = Duration(seconds: 10);

  static String _unreachable(String baseUrl) =>
      'Cannot reach the backend at $baseUrl, and it was not found on this '
      'Wi-Fi network. Make sure the backend is running on the PC, the phone '
      'and PC are on the same Wi-Fi/hotspot, and Windows Firewall allows '
      'port 5000. You can also set the address with the gear icon.';

  static Future<String?>? _discovery;

  /// Scans the local network for the backend and saves the address found.
  /// Concurrent callers share one scan. Returns the new base URL or null.
  static Future<String?> rediscover() {
    return _discovery ??= () async {
      try {
        final found = await discoverServer();
        if (found != null) await AppConfig.setApiBaseUrl(found);
        return found;
      } finally {
        _discovery = null;
      }
    }();
  }

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request,
  ) async {
    final attemptedUrl = AppConfig.apiBaseUrl;
    try {
      return _read(await request().timeout(_timeout));
    } on TimeoutException {
      // Fall through to discovery below.
    } on http.ClientException {
      // Fall through to discovery below.
    }
    // The PC's IP probably changed: find the backend again and retry once.
    final found = await rediscover();
    if (found != null && found != attemptedUrl) {
      try {
        return _read(await request().timeout(_timeout));
      } on TimeoutException {
        // Report below.
      } on http.ClientException {
        // Report below.
      }
    }
    throw ApiException(_unreachable(AppConfig.apiBaseUrl));
  }

  Future<Map<String, dynamic>> get(String path) =>
      _send(() => http.get(_uri(path), headers: _headers));

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) =>
      _send(
        () => http.post(_uri(path), headers: _headers, body: jsonEncode(body)),
      );

  /// Checks that [baseUrl] answers /health. Returns null on success or an
  /// error message.
  static Future<String?> checkServer(String baseUrl) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) return null;
      return 'Server answered with status ${response.statusCode}. '
          'Is MongoDB running?';
    } on TimeoutException {
      return _unreachable(baseUrl);
    } on http.ClientException {
      return _unreachable(baseUrl);
    } on FormatException {
      return 'That is not a valid address.';
    }
  }

  Map<String, dynamic> _read(http.Response response) {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw ApiException('The server returned an invalid response.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = data['error'] as Map<String, dynamic>?;
      throw ApiException(
        error?['message'] as String? ??
            'Request failed (${response.statusCode}).',
        code: error?['code'] as String?,
        statusCode: response.statusCode,
      );
    }
    return data;
  }

  Future<void> restoreToken() async {
    token = await _storage.read(key: 'auth_token');
  }

  Future<void> _saveToken(Map<String, dynamic> data) async {
    token = data['token'] as String;
    await _storage.write(key: 'auth_token', value: token);
  }

  Future<void> login(String contact, String password) async => _saveToken(
        await post(
            '/api/auth/login', {'contact': contact, 'password': password}),
      );

  Future<void> register(
    String name,
    String email,
    String contact,
    String password,
  ) async {
    await post('/api/auth/register', {
      'name': name,
      'email': email,
      'contact': contact,
      'password': password,
    });
  }

  Future<void> logout() async {
    token = null;
    await _storage.delete(key: 'auth_token');
  }

  Future<List<dynamic>> foods(String query) async => (await get(
        '/api/foods?q=${Uri.encodeQueryComponent(query)}&limit=30',
      ))['items'] as List<dynamic>;

  Future<Map<String, dynamic>> analyzeIntake({
    required String name,
    required double grams,
    required String time,
  }) =>
      post('/api/intake/analyze', {
        'intake_name': name,
        'portion_grams': grams,
        'intake_time': time,
      });

  Future<void> sendFeedback(String name, String contact, String message) async {
    await post('/api/feedback', {
      'name': name,
      'contact': contact,
      'message': message,
    });
  }

  Future<Map<String, dynamic>> dashboard() => get('/api/dashboard/summary');
}
