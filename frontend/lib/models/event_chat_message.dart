class EventChatMessage {
  const EventChatMessage({
    required this.id,
    required this.eventId,
    required this.senderId,
    required this.senderType,
    required this.senderName,
    required this.message,
    required this.createdAt,
    this.senderAvatar,
    this.messageType = 'text',
  });

  factory EventChatMessage.fromJson(Map<String, dynamic> json) {
    return EventChatMessage(
      id: json['_id'] as String,
      eventId: json['eventId'] as String,
      senderId: json['senderId'] as String,
      senderType: json['senderType'] as String,
      senderName: json['senderName'] as String,
      senderAvatar: json['senderAvatar'] as String?,
      message: json['message'] as String,
      messageType: json['messageType'] as String? ?? 'text',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String eventId;
  final String senderId;
  final String senderType; // 'user' or 'manager'
  final String senderName;
  final String? senderAvatar;
  final String message;
  final String messageType; // 'text' or 'system'
  final DateTime createdAt;

  bool get isSystemMessage => messageType == 'system';
  bool get isFromManager => senderType == 'manager';

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      '_id': id,
      'eventId': eventId,
      'senderId': senderId,
      'senderType': senderType,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'message': message,
      'messageType': messageType,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
