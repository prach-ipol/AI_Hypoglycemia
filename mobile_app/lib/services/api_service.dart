import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config.dart';

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

  Future<Map<String, dynamic>> get(String path) async {
    try {
      return _read(await http.get(_uri(path), headers: _headers));
    } on http.ClientException {
      throw ApiException(
        'Cannot reach the backend at ${AppConfig.apiBaseUrl}. '
        'For a physical Android phone, rebuild with your computer LAN IP '
        'using --dart-define=API_BASE_URL=http://YOUR_PC_IP:5000.',
      );
    }
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      return _read(
        await http.post(_uri(path), headers: _headers, body: jsonEncode(body)),
      );
    } on http.ClientException {
      throw ApiException(
        'Cannot reach the backend at ${AppConfig.apiBaseUrl}. '
        'For a physical Android phone, rebuild with your computer LAN IP '
        'using --dart-define=API_BASE_URL=http://YOUR_PC_IP:5000.',
      );
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
    await post('/api/auth/login', {'contact': contact, 'password': password}),
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

  Future<List<dynamic>> foods(String query) async =>
      (await get(
            '/api/foods?q=${Uri.encodeQueryComponent(query)}&limit=30',
          ))['items']
          as List<dynamic>;

  Future<Map<String, dynamic>> analyzeIntake({
    required String name,
    required double grams,
    required String time,
  }) => post('/api/intake/analyze', {
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
