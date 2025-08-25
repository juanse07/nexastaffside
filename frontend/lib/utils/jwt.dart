import 'dart:convert';

String? decodeUserKeyFromJwt(String jwt) {
  try {
    final parts = jwt.split('.');
    if (parts.length != 3) return null;
    String normalized = parts[1].replaceAll('-', '+').replaceAll('_', '/');
    while (normalized.length % 4 != 0) {
      normalized += '=';
    }
    final payload = utf8.decode(base64.decode(normalized));
    final map = json.decode(payload) as Map<String, dynamic>;
    final provider = map['provider']?.toString();
    final sub = map['sub']?.toString();
    if (provider == null || sub == null) return null;
    return '$provider:$sub';
  } catch (_) {
    return null;
  }
}
