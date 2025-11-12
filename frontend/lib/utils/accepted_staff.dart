/// Helper utilities for matching the current user inside `accepted_staff`.
String normalizeUserIdentifier(String? raw) {
  if (raw == null) return '';
  var value = raw.trim();
  if (value.isEmpty) return '';
  for (final separator in [':', '|']) {
    final index = value.lastIndexOf(separator);
    if (index != -1 && index < value.length - 1) {
      value = value.substring(index + 1);
    }
  }
  return value;
}

bool _matchesUserIdentifier(
  String? candidate,
  String originalTarget,
  String normalizedTarget,
) {
  if (candidate == null || candidate.trim().isEmpty) return false;
  if (candidate == originalTarget) return true;
  final normalizedCandidate = normalizeUserIdentifier(candidate);
  return normalizedCandidate.isNotEmpty && normalizedCandidate == normalizedTarget;
}

Map<String, dynamic>? findAcceptedStaffEntry(
  Map<String, dynamic> event,
  String? userKey,
) {
  if (userKey == null || userKey.trim().isEmpty) return null;
  final normalizedTarget = normalizeUserIdentifier(userKey);
  final accepted = event['accepted_staff'];
  if (accepted is! List) return null;

  for (final entry in accepted) {
    if (entry is String) {
      if (_matchesUserIdentifier(entry, userKey, normalizedTarget)) {
        return {'userKey': entry};
      }
    } else if (entry is Map) {
      final mapEntry = Map<String, dynamic>.from(entry);
      final candidates = [
        mapEntry['userKey'],
        mapEntry['sub'],
        mapEntry['id'],
        mapEntry['uid'],
        mapEntry['user_id'],
      ];
      for (final candidate in candidates) {
        final value = candidate?.toString();
        if (_matchesUserIdentifier(value, userKey, normalizedTarget)) {
          return mapEntry;
        }
      }
    }
  }
  return null;
}

bool isAcceptedByUser(Map<String, dynamic> event, String? userKey) =>
    findAcceptedStaffEntry(event, userKey) != null;
