// Top-level helpers to run in background isolate via compute.
List<Map<String, dynamic>> prepareMessagesForDb(Map<String, dynamic> args) {
  final raw = args['raw'] as List? ?? [];
  final companionId = args['companionId'] as String? ?? '';
  final List<Map<String, dynamic>> out = [];
  for (final e in raw) {
    if (e is Map) {
      var messageId = (e['message_id'] ?? e['id'] ?? '').toString();
      final role = (e['role'] ?? 'assistant').toString();
      final content = (e['content'] ?? e['text'] ?? '').toString();
      final imagePath = (e['image_path'] ?? '').toString();
      final imageStatus = (e['image_status'] ?? '').toString();
      final generationId = (e['generation_id'] ?? '').toString();
      final extraMessage = (e['extra_message'] ?? '').toString();
      final timeRaw = e['time'];
      int time = 0;
      if (timeRaw is int) time = timeRaw;
      else if (timeRaw is double) time = timeRaw.toInt();
      else if (timeRaw is String) time = int.tryParse(timeRaw) ?? 0;

      // Ensure unique message_id to prevent DB overwrites
      if (messageId.isEmpty) {
        // Create a deterministic ID based on content properties
        messageId = 'gen_${role}_${time}_${content.hashCode}';
      }

      out.add({
        'companion_id': companionId,
        'message_id': messageId,
        'role': role,
        'content': content,
        'image_path': imagePath,
        'image_status': imageStatus,
        'generation_id': generationId,
        'extra_message': extraMessage,
        'time': time,
      });
    }
  }
  out.sort((a, b) => (a['time'] as int).compareTo(b['time'] as int));
  return out;
}

List<Map<String, dynamic>> prepareChatsForDb(Map<String, dynamic> args) {
  final raw = args['raw'] as List? ?? [];
  final List<Map<String, dynamic>> out = [];
  for (final e in raw) {
    if (e is Map) {
      final companionId = (e['companion_id'] ?? e['id'] ?? '').toString();
      final name = (e['companion_name'] ?? e['name'] ?? e['girlfriend_name'] ?? '').toString();
      final lastText = (e['message'] ?? e['last_message'] ?? e['last_text'] ?? '').toString();
      final imageUrl = (e['photo'] ?? e['image_url'] ?? e['image'] ?? e['photo_url'] ?? '').toString();
      final timeRaw = e['time'];
      int time = 0;
      if (timeRaw is int) time = timeRaw;
      else if (timeRaw is double) time = timeRaw.toInt();
      else if (timeRaw is String) time = int.tryParse(timeRaw) ?? 0;
      if (companionId.isNotEmpty) {
        out.add({
          'companion_id': companionId,
          'name': name,
          'image_url': imageUrl,
          'last_text': lastText,
          'time': time,
        });
      }
    }
  }
  out.sort((a, b) => (b['time'] as int).compareTo(a['time'] as int));
  return out;
}

List<Map<String, dynamic>> prepareGirlfriendsForDb(Map<String, dynamic> args) {
  final raw = args['raw'] as List? ?? [];
  final List<Map<String, dynamic>> out = [];
  for (final e in raw) {
    if (e is Map) {
      final id = (e['id'] ?? e['companion_id'] ?? '').toString();
      final name = (e['name'] ?? '').toString();
      final image = (e['image'] ?? e['image_url'] ?? '').toString();
      final age = e['age'] is int ? e['age'] as int : null;
      final tags = e['tags'];
      final tagsStr = tags is List ? tags.map((t) => t.toString()).join(',') : (tags is String ? tags : '');
      if (id.isNotEmpty) {
        out.add({
          'companion_id': id,
          'name': name,
          'image_url': image,
          'age': age,
          'tags': tagsStr,
        });
      }
    }
  }
  return out;
}

