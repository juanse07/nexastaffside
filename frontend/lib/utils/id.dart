String? resolveEventId(Map<String, dynamic> event) {
  final dynamic primary = event['id'] ?? event['_id'];
  if (primary == null) return null;
  if (primary is String) return primary;
  if (primary is Map) {
    final dynamic oid = primary['\$oid'] ?? primary['oid'] ?? primary['_id'];
    if (oid is String) return oid;
  }
  return null;
}
