class MessageItem {
  final String companionId;
  final String messageId;
  final String role; // 'user' or 'assistant'
  final String content;
  final int time;
  final String imagePath;
  final String imageStatus;
  final String generationId;
  final String extraMessage;

  MessageItem({
    required this.companionId,
    required this.messageId,
    required this.role,
    required this.content,
    required this.time,
    this.imagePath = '',
    this.imageStatus = '',
    this.generationId = '',
    this.extraMessage = '',
  });

  factory MessageItem.fromJson(Map<String, dynamic> json, {String? companionIdOverride}) {
    return MessageItem(
      companionId: companionIdOverride ?? (json['companion_id'] ?? '') as String,
      messageId: (json['message_id'] ?? json['id'] ?? '').toString(),
      role: (json['role'] ?? 'assistant').toString(),
      content: (json['content'] ?? json['text'] ?? '').toString(),
      time: _parseTime(json['time']),
      imagePath: (json['image_path'] ?? '').toString(),
      imageStatus: (json['image_status'] ?? '').toString(),
      generationId: (json['generation_id'] ?? '').toString(),
      extraMessage: (json['extra_message'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'companion_id': companionId,
      'message_id': messageId,
      'role': role,
      'content': content,
      'time': time,
      'image_path': imagePath,
      'image_status': imageStatus,
      'generation_id': generationId,
      'extra_message': extraMessage,
    };
  }

  Map<String, dynamic> toDbMap() {
    return {
      'companion_id': companionId,
      'message_id': messageId,
      'role': role,
      'content': content,
      'time': time,
      'image_path': imagePath,
      'image_status': imageStatus,
      'generation_id': generationId,
      'extra_message': extraMessage,
    };
  }

  static int _parseTime(dynamic t) {
    if (t == null) return 0;
    if (t is int) return t;
    if (t is double) return t.toInt();
    if (t is String) return int.tryParse(t) ?? 0;
    return 0;
  }
}
