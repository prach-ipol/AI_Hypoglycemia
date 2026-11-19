import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Scans every /24 private subnet the device is on for a host whose
/// `http://<ip>:<port>/health` endpoint answers like our backend.
/// Returns the base URL (e.g. `http://192.168.15.189:5000`) or null.
Future<String?> discoverServer({int port = 5000}) async {
  final prefixes = <String>{};
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        final parts = addr.address.split('.');
        if (parts.length == 4 && _isPrivate(parts)) {
          prefixes.add('${parts[0]}.${parts[1]}.${parts[2]}');
        }
      }
    }
  } catch (_) {
    return null;
  }
  // Android emulator: the host PC is always 10.0.2.2.
  final candidates = <String>['10.0.2.2'];
  for (final prefix in prefixes) {
    for (var i = 1; i < 255; i++) {
      candidates.add('$prefix.$i');
    }
  }

  // Quick TCP probe in parallel batches, then confirm with /health.
  const batchSize = 64;
  for (var start = 0; start < candidates.length; start += batchSize) {
    final batch = candidates.skip(start).take(batchSize);
    final open = await Future.wait(batch.map((ip) => _portOpen(ip, port)));
    for (final ip in open.whereType<String>()) {
      final url = 'http://$ip:$port';
      if (await _isOurBackend(url)) return url;
    }
  }
  return null;
}

bool _isPrivate(List<String> p) {
  final a = int.tryParse(p[0]) ?? 0, b = int.tryParse(p[1]) ?? 0;
  return a == 10 || (a == 192 && b == 168) || (a == 172 && b >= 16 && b <= 31);
}

Future<String?> _portOpen(String ip, int port) async {
  try {
    final socket = await Socket.connect(
      ip,
      port,
      timeout: const Duration(milliseconds: 600),
    );
    socket.destroy();
    return ip;
  } catch (_) {
    return null;
  }
}

Future<bool> _isOurBackend(String url) async {
  try {
    final response = await http
        .get(Uri.parse('$url/health'))
        .timeout(const Duration(seconds: 3));
    final body = jsonDecode(response.body);
    // /health returns 200 {"status":"ok",...} or 503 {"status":"degraded"}.
    return body is Map && body.containsKey('status');
  } catch (_) {
    return false;
  }
}
