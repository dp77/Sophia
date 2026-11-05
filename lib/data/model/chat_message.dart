class ChatMessage {
  final String role;
  final String text;
  final int time;
  final String imagePath;
  final String imageStatus;
  final String generationId;
  final String extraMessage;

  const ChatMessage({
    required this.role,
    required this.text,
    required this.time,
    this.imagePath = '',
    this.imageStatus = '',
    this.generationId = '',
    this.extraMessage = '',
  });

  bool get isMe => role == 'user';

  factory ChatMessage.fromApiJson(Map<String, dynamic> json) {
    final role = json['role'] as String? ?? 'assistant';
    final content = json['content'] as String? ?? '';
    final time = json['time'] as int? ?? 0;
    final imagePath = json['image_path'] as String? ?? '';
    final imageStatus = json['image_status'] as String? ?? '';
    final generationId = (json['generation_id'] ?? '').toString();
    final extraMessage = (json['extra_message'] ?? '').toString();
    return ChatMessage(
        role: role, text: content, time: time, imagePath: imagePath, imageStatus: imageStatus, generationId: generationId, extraMessage: extraMessage);
  }

  Map<String, dynamic> toMap() => {
        'role': role,
        'content': text,
        'image_path': imagePath,
        'image_status': imageStatus,
        'generation_id': generationId,
        'extra_message': extraMessage,
      };
}
