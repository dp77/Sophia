class Girlfriend {
  final String id;
  final String name;
  final String imageUrl;
  final int? age;
  final List<String> tags;

  const Girlfriend({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.age,
    this.tags = const [],
  });

  factory Girlfriend.fromMap(Map<String, dynamic> map) {
    final tagsRaw = map['tags'];
    List<String> tagsList = [];
    if (tagsRaw is List) {
      tagsList = (tagsRaw).map((e) => e.toString()).toList();
    } else if (tagsRaw is String && tagsRaw.isNotEmpty) {
      tagsList = tagsRaw.split(',');
    }
    return Girlfriend(
      id: map['companion_id']?.toString() ?? map['id']?.toString() ?? '',
      name: map['name'] as String? ?? '',
      imageUrl: map['image_url'] as String? ?? map['image'] as String? ?? '',
      age: map['age'] as int?,
      tags: tagsList,
    );
  }

  factory Girlfriend.fromCompanionJson(Map<String, dynamic> json) {
    final tagsRaw = json['tags'];
    return Girlfriend(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      imageUrl: json['image'] as String? ?? '',
      age: json['age'] as int?,
      tags: tagsRaw is List ? (tagsRaw).map((e) => e.toString()).toList() : [],
    );
  }

  Map<String, dynamic> toMap() => {
        'companion_id': id,
        'name': name,
        'image_url': imageUrl,
        'age': age,
        'tags': tags.isNotEmpty ? tags.join(',') : '',
      };
}
