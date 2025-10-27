import 'package:hive/hive.dart';

part 'pending_clock_action.g.dart';

@HiveType(typeId: 0)
class PendingClockAction extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String action; // 'clock-in' or 'clock-out'

  @HiveField(2)
  late String eventId;

  @HiveField(3)
  late DateTime timestamp;

  @HiveField(4)
  late double? latitude;

  @HiveField(5)
  late double? longitude;

  @HiveField(6)
  late String locationSource; // 'live' or 'cached'

  @HiveField(7)
  late int retryCount;

  @HiveField(8)
  late String status; // 'pending', 'syncing', 'failed', 'success'

  @HiveField(9)
  String? errorMessage;

  @HiveField(10)
  DateTime? lastRetryAt;

  PendingClockAction({
    required this.id,
    required this.action,
    required this.eventId,
    required this.timestamp,
    this.latitude,
    this.longitude,
    this.locationSource = 'live',
    this.retryCount = 0,
    this.status = 'pending',
    this.errorMessage,
    this.lastRetryAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'action': action,
      'eventId': eventId,
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'locationSource': locationSource,
      'retryCount': retryCount,
      'status': status,
      'errorMessage': errorMessage,
      'lastRetryAt': lastRetryAt?.toIso8601String(),
    };
  }

  factory PendingClockAction.fromJson(Map<String, dynamic> json) {
    return PendingClockAction(
      id: json['id'] as String,
      action: json['action'] as String,
      eventId: json['eventId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
      locationSource: json['locationSource'] as String? ?? 'live',
      retryCount: json['retryCount'] as int? ?? 0,
      status: json['status'] as String? ?? 'pending',
      errorMessage: json['errorMessage'] as String?,
      lastRetryAt: json['lastRetryAt'] != null
          ? DateTime.parse(json['lastRetryAt'] as String)
          : null,
    );
  }
}
