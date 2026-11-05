class GenerationHistoryResponse {
  final bool status;
  final List<GenerationHistoryItem> items;
  final int? nextCursor;
  final bool hasMore;

  const GenerationHistoryResponse({
    required this.status,
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  factory GenerationHistoryResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return GenerationHistoryResponse(
      status: json['status'] == true,
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map((e) => GenerationHistoryItem.fromJson(Map<String, dynamic>.from(e)))
                .toList()
          : const [],
      nextCursor: _toInt(json['next_cursor']),
      hasMore: json['has_more'] == true,
    );
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

class GenerationHistoryItem {
  final String id;
  final String generationType;
  final String url;
  final int createdAt;

  const GenerationHistoryItem({
    required this.id,
    required this.generationType,
    required this.url,
    required this.createdAt,
  });

  factory GenerationHistoryItem.fromJson(Map<String, dynamic> json) {
    return GenerationHistoryItem(
      id: (json['id'] ?? '').toString(),
      generationType: (json['generation_type'] ?? '').toString(),
      url: (json['url'] ?? '').toString(),
      createdAt: _toInt(json['created_at']) ?? 0,
    );
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
