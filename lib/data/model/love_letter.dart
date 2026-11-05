/// A note from a companion, shown in the Letters tab and as the letter banner.
class LoveLetter {
  final String id;
  final String companionId;
  final String name;
  final String imageUrl;
  final String text;

  /// When it arrived, in milliseconds since epoch.
  final int time;
  final bool read;

  const LoveLetter({
    required this.id,
    required this.companionId,
    required this.name,
    required this.imageUrl,
    required this.text,
    required this.time,
    this.read = false,
  });

  bool get canReply => companionId.isNotEmpty;

  LoveLetter copyWith({bool? read, String? imageUrl}) => LoveLetter(
    id: id,
    companionId: companionId,
    name: name,
    imageUrl: imageUrl ?? this.imageUrl,
    text: text,
    time: time,
    read: read ?? this.read,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'companionId': companionId,
    'name': name,
    'imageUrl': imageUrl,
    'text': text,
    'time': time,
    'read': read,
  };

  factory LoveLetter.fromJson(Map<String, dynamic> json) => LoveLetter(
    id: (json['id'] ?? '').toString(),
    companionId: (json['companionId'] ?? '').toString(),
    name: (json['name'] ?? '').toString(),
    imageUrl: (json['imageUrl'] ?? '').toString(),
    text: (json['text'] ?? '').toString(),
    time: json['time'] is int ? json['time'] as int : int.tryParse('${json['time']}') ?? 0,
    read: json['read'] == true,
  );
}
