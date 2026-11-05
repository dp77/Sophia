class CharacterModel {
  final String id;
  final String characterName;
  final int age;
  final List<String> traits;
  final List<String> lookVibe;
  final String relationshipType;
  final String imageUrl;
  final int createdAt;

  CharacterModel({
    required this.id,
    required this.characterName,
    required this.age,
    required this.traits,
    required this.lookVibe,
    required this.relationshipType,
    required this.imageUrl,
    required this.createdAt,
  });

  factory CharacterModel.fromJson(Map<String, dynamic> json) {
    return CharacterModel(
      id: json['gf_id'] ?? '',
      characterName: json['character_name'] ?? '',
      age: json['age'] ?? 0,
      traits: List<String>.from(json['traits'] ?? []),
      lookVibe: List<String>.from(json['look_vibe'] ?? []),
      relationshipType: json['relationship_type'] ?? '',
      imageUrl: json['image_url'] ?? '',
      createdAt: json['created_at'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'character_name': characterName,
      'age': age,
      'traits': traits,
      'look_vibe': lookVibe,
      'relationship_type': relationshipType,
      's3_object_name': imageUrl,
      'created_at': createdAt,
    };
  }
}
