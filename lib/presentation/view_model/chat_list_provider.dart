import 'package:flutter/foundation.dart';
import '../../data/api_service/api_caller.dart';
import '../../data/model/chat_item.dart';
import '../../data/db/database_helper.dart';
import '../../utils/isolate_utils.dart';

class ChatListProvider with ChangeNotifier {
  final ApiCaller _apiCaller = ApiCaller();
  final DatabaseHelper _db = DatabaseHelper();

  List<ChatItem> _chats = [];
  bool _loading = true;

  List<ChatItem> get chats => List.unmodifiable(_chats);
  bool get loading => _loading;

  void clear() {
    _chats = [];
    _loading = false;
    notifyListeners();
  }

  Future<void> updateLastMessage(
    String companionId,
    String lastMessage, {
    String? name,
    String? imageUrl,
    int? epoch,
  }) async {
    final now = epoch ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final idx = _chats.indexWhere((c) => c.companionId == companionId);
    // Optimized: Move to top instead of full sort
    if (idx >= 0) {
      final updated = _chats[idx].copyWith(
        lastText: lastMessage,
        time: now,
        imageUrl: imageUrl ?? _chats[idx].imageUrl,
      );
      _chats.removeAt(idx);
      _chats.insert(0, updated);
    } else {
      final item = ChatItem(
        companionId: companionId,
        girlfriendName: name ?? '',
        lastText: lastMessage,
        imageUrl: imageUrl ?? '',
        time: now,
      );
      _chats.insert(0, item);
    }

    try {
      await _db.upsertChatItem(_chats.first);
    } catch (e) {
      debugPrint('ChatListProvider: Failed to upsert chat item: $e');
    }
    notifyListeners();
  }

  Future<void> refresh(String userId) async {
    _loading = true;
    notifyListeners();
    try {
      final cached = await _db.getCachedChats();
      if (cached.isNotEmpty) {
        _chats = cached;
        _loading = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('ChatListProvider: Failed to load cached chats: $e');
    }

    if (userId.isEmpty) {
      _chats = [];
      _loading = false;
      notifyListeners();
      return;
    }

    final result = await _apiCaller.getChatList(userId);
    result.fold(
      (_) {
        _loading = false;
        notifyListeners();
      },
      (response) async {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          final raw = data['chats'] ?? data['data'] ?? [];
          if (raw is List) {
            final prepared = await compute(prepareChatsForDb, {'raw': raw});
            final remote = prepared.map((e) => ChatItem.fromJson(e)).where((m) => m.companionId.isNotEmpty).toList();
            _chats = remote;
            _chats.sort((a, b) => b.time.compareTo(a.time));
            try {
              await _db.replaceCachedChats(_chats);
            } catch (e) {
              debugPrint('ChatListProvider: Failed to cache chats: $e');
            }
          }
        }
        _loading = false;
        notifyListeners();
      },
    );
  }
}
