class ChatItem {
  final String companionId;
  final String girlfriendName;
  final String lastText;
  final String imageUrl;
  final int time;

  ChatItem({
    required this.companionId,
    required this.girlfriendName,
    required this.lastText,
    required this.imageUrl,
    required this.time,
  });

  factory ChatItem.fromJson(Map<String, dynamic> json) {
    return ChatItem(
      companionId: (json['companion_id'] ?? json['id'] ?? '').toString(),
      girlfriendName: (json['companion_name'] ?? json['name'] ?? json['girlfriend_name'] ?? '').toString(),
      lastText: (json['message'] ?? json['last_message'] ?? json['last_text'] ?? 'Let\'s talk!').toString(),
      imageUrl: (json['photo'] ?? json['image_url'] ?? json['image'] ?? json['photo_url'] ?? '').toString(),
      time: _parseTime(json['time']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'companion_id': companionId,
      'companion_name': girlfriendName,
      'message': lastText,
      'photo': imageUrl,
      'time': time,
    };
  }

  ChatItem copyWith({String? companionId, String? girlfriendName, String? lastText, String? imageUrl, int? time}) {
    return ChatItem(
      companionId: companionId ?? this.companionId,
      girlfriendName: girlfriendName ?? this.girlfriendName,
      lastText: lastText ?? this.lastText,
      imageUrl: imageUrl ?? this.imageUrl,
      time: time ?? this.time,
    );
  }

  static int _parseTime(dynamic t) {
    if (t == null) return 0;
    if (t is int) return t;
    if (t is double) return t.toInt();
    if (t is String) return int.tryParse(t) ?? 0;
    return 0;
  }
}
