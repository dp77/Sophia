import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:girlfriend/presentation/widget/sophia_toast.dart';
import 'dart:async';
import 'package:uuid/uuid.dart';
import '../../data/api_service/api_caller.dart';
import '../../data/db/database_helper.dart';
import '../../data/notification_helper.dart';
import '../../data/model/message_item.dart';
import '../../utils/isolate_utils.dart';
import 'chat_list_provider.dart';
import '../../data/model/chat_item.dart';

import 'package:girlfriend/presentation/view_model/user_provider.dart';

class MessageProvider with ChangeNotifier {
  final ApiCaller _apiCaller = ApiCaller();
  final DatabaseHelper _db = DatabaseHelper();

  String _companionId = '';
  List<MessageItem> _messages = [];
  final Map<String, bool> _typingStatus = {};
  bool _loading = false;
  bool _isFetching = false;
  int _chatLoadEpoch = 0;
  Timer? _imageStatusTimer;
  String _activeUserId = '';
  bool _isChatScreenActive = false;
  UserProvider? _userForBalanceRefresh;

  List<MessageItem> get messages => List.unmodifiable(_messages);
  bool get loading => _loading;
  String get companionId => _companionId;

  bool isTyping(String companionId) => _typingStatus[companionId] ?? false;

  void setChatScreenActive(bool active) {
    _isChatScreenActive = active;
    if (!active) {
      _stopImageStatusPolling();
      return;
    }
    _refreshImageStatusPolling();
  }

  void setUserForBalanceRefresh(UserProvider? user) {
    _userForBalanceRefresh = user;
  }

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  Future<void> loadMessages(String companionId, String userId) async {
    _chatLoadEpoch++;
    _companionId = companionId;
    _activeUserId = userId;
    _messages = [];
    _typingStatus.clear();
    _stopImageStatusPolling();
    _setLoading(true);
    debugPrint("MessageProvider: Switching to companionId: $companionId");

    try {
      final cached = await _db.getCachedMessages(companionId);
      if (cached.isNotEmpty) {
        _messages = cached
            .whereType<Map<String, dynamic>>()
            .map(
              (e) => MessageItem.fromJson(e, companionIdOverride: companionId),
            )
            .toList();
        _refreshImageStatusPolling();
        debugPrint(
          "MessageProvider: Loaded ${_messages.length} messages from cache.",
        );
        _setLoading(false);
      } else {
        debugPrint("MessageProvider: No messages in cache for $companionId.");
      }
    } catch (e) {
      debugPrint('MessageProvider: Failed to load cached messages: $e');
    }

    notifyListeners();

    // 4. Sync with API (Background)
    if (userId.isNotEmpty) {
      _fetchRemoteMessages(userId, companionId);
    } else {
      _setLoading(false);
    }
  }

  Future<void> _fetchRemoteMessages(String userId, String companionId) async {
    final expectedEpoch = _chatLoadEpoch;
    if (_isFetching) return;
    _isFetching = true;

    // Only show loading if we have absolutely no data
    if (_messages.isEmpty) {
      _setLoading(true);
    }

    debugPrint("MessageProvider: Fetching remote messages for $companionId...");

    try {
      final result = await _apiCaller.getChatMessage(userId, companionId);
      await result.fold(
        (failure) async {
          debugPrint(
            'MessageProvider: getChatMessage failed: ${failure.errMessage}',
          );
        },
        (response) async {
          final data = response.data as Map<String, dynamic>?;
          if (data == null) return;
          final raw = data['messages'];
          if (raw is List) {
            debugPrint(
              "MessageProvider: Received ${raw.length} messages from API.",
            );

            // Prepare data (assign IDs, format)
            final prepared = await compute(prepareMessagesForDb, {
              'raw': raw,
              'companionId': companionId,
            });

            // Sync with DB (Upsert new + Trim old)
            await _db.syncMessages(companionId, prepared);

            // RELOAD from DB to get the merged result (Local History + New API Data)
            final allMessages = await _db.getCachedMessages(companionId);
            if (expectedEpoch != _chatLoadEpoch ||
                _companionId != companionId) {
              return;
            }

            _messages = allMessages
                .whereType<Map<String, dynamic>>()
                .map(
                  (e) =>
                      MessageItem.fromJson(e, companionIdOverride: companionId),
                )
                .toList();
            _refreshImageStatusPolling();

            debugPrint(
              "MessageProvider: Updated UI with ${_messages.length} total messages after sync.",
            );
            notifyListeners();
          }
        },
      );
    } catch (e) {
      debugPrint('MessageProvider: background fetch error: $e');
    } finally {
      _isFetching = false;
      _setLoading(false);
    }
  }

  Future<void> addLocalMessage(MessageItem m) async {
    if (_hasDuplicateInMemory(m)) {
      return;
    }
    _messages.add(m);
    // Optimization: Only sort if the new message is older than the last one (rare)
    if (_messages.length > 1 && m.time < _messages[_messages.length - 2].time) {
      _messages.sort((a, b) => a.time.compareTo(b.time));
    }
    notifyListeners();
    try {
      await _db.upsertMessageItem(m.toJson());
      _refreshImageStatusPolling();
    } catch (e) {
      debugPrint('MessageProvider: failed to upsert local message: $e');
    }
  }

  Future<void> addRemoteMessage(MessageItem m) async {
    /// with this condition its not showing toast
    if (m.companionId == _companionId) {
      final index = _messages.indexWhere((it) => _sameMessage(it, m));
      if (index != -1) {
        _messages[index] = m;
      } else {
        _messages.add(m);
        if (_messages.length > 1 &&
            m.time < _messages[_messages.length - 2].time) {
          _messages.sort((a, b) => a.time.compareTo(b.time));
        }
      }
      notifyListeners();
    }
    try {
      await _db.upsertMessageItem(m.toJson());
      _refreshImageStatusPolling();
    } catch (e) {
      debugPrint('MessageProvider: failed to upsert remote message: $e');
    }
  }

  bool _needsImageStatusRefresh() {
    for (final m in _messages) {
      if (m.role != 'assistant') continue;
      final status = m.imageStatus.trim().toLowerCase();
      if ((status == 'pending' || status == 'processing') &&
          m.generationId.trim().isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  List<String> _pendingGenerationIds() {
    final seen = <String>{};
    for (final m in _messages) {
      if (m.role != 'assistant') continue;
      final status = m.imageStatus.trim().toLowerCase();
      if (status != 'pending' && status != 'processing') continue;
      final gid = m.generationId.trim();
      if (gid.isEmpty) continue;
      seen.add(gid);
    }
    return seen.toList();
  }

  Future<void> _pollImageStatusBatch() async {
    final generationIds = _pendingGenerationIds();
    if (generationIds.isEmpty ||
        _activeUserId.isEmpty ||
        _companionId.isEmpty) {
      _stopImageStatusPolling();
      return;
    }
    final result = await _apiCaller.getChatImageStatusBatch(
      _activeUserId,
      _companionId,
      generationIds,
    );
    await result.fold((_) async {}, (response) async {
      final data = response.data as Map<String, dynamic>?;
      if (data == null) return;
      final rawItems = data['items'];
      if (rawItems is! List) return;
      bool changed = false;
      var creditsRefreshNeeded = false;
      for (final item in rawItems) {
        if (item is! Map) continue;
        final mapped = Map<String, dynamic>.from(item);
        final gid = (mapped['generation_id'] ?? '').toString().trim();
        if (gid.isEmpty) continue;
        final idx = _messages.indexWhere((m) => m.generationId == gid);
        if (idx < 0) continue;
        final existing = _messages[idx];
        final oldSt = existing.imageStatus.trim().toLowerCase();
        final next = MessageItem(
          companionId: existing.companionId,
          messageId: (mapped['message_id'] ?? existing.messageId).toString(),
          role: existing.role,
          content: existing.content,
          time: existing.time,
          imagePath: (mapped['image_path'] ?? existing.imagePath).toString(),
          imageStatus: (mapped['image_status'] ?? existing.imageStatus)
              .toString(),
          generationId: gid,
          extraMessage: (mapped['extra_message'] ?? existing.extraMessage)
              .toString(),
        );
        final newSt = next.imageStatus.trim().toLowerCase();
        if ((oldSt == 'pending' || oldSt == 'processing') &&
            (newSt == 'completed' || newSt == 'failed')) {
          creditsRefreshNeeded = true;
        }
        if (next.imagePath != existing.imagePath ||
            next.imageStatus != existing.imageStatus ||
            next.extraMessage != existing.extraMessage ||
            next.messageId != existing.messageId) {
          _messages[idx] = next;
          await _db.upsertMessageItem(next.toJson());
          changed = true;
        }
      }
      if (changed) {
        notifyListeners();
      }
      if (creditsRefreshNeeded) {
        final u = _userForBalanceRefresh;
        if (u != null) await u.refreshProfile();
      }
    });
  }

  void _refreshImageStatusPolling() {
    if (!_isChatScreenActive ||
        _companionId.isEmpty ||
        _activeUserId.isEmpty ||
        !_needsImageStatusRefresh()) {
      _stopImageStatusPolling();
      return;
    }
    if (_imageStatusTimer != null && _imageStatusTimer!.isActive) {
      return;
    }
    _imageStatusTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!_isChatScreenActive ||
          _companionId.isEmpty ||
          _activeUserId.isEmpty) {
        _stopImageStatusPolling();
        return;
      }
      await _pollImageStatusBatch();
      if (!_needsImageStatusRefresh()) {
        _stopImageStatusPolling();
      }
    });
  }

  void _stopImageStatusPolling() {
    _imageStatusTimer?.cancel();
    _imageStatusTimer = null;
  }

  bool _hasDuplicateInMemory(MessageItem message) {
    return _messages.any((item) => _sameMessage(item, message));
  }

  bool _sameMessage(MessageItem a, MessageItem b) {
    if (a.messageId.isNotEmpty && b.messageId.isNotEmpty) {
      return a.messageId == b.messageId;
    }
    return a.companionId == b.companionId &&
        a.role == b.role &&
        a.time == b.time &&
        a.content == b.content;
  }

  Future<void> removeMessageByGeneratedKey(
    String role,
    int time,
    String content,
  ) async {
    _messages.removeWhere(
      (m) => m.role == role && m.time == time && m.content == content,
    );
    notifyListeners();
    try {
      final db = await _db.database;
      await db.delete(
        'messages',
        where: 'companion_id = ? AND role = ? AND time = ? AND content = ?',
        whereArgs: [_companionId, role, time, content],
      );
    } catch (e) {
      debugPrint('MessageProvider: failed to remove local message: $e');
    }
  }

  Future<bool> clearHistory(
    String userId,
    String companionId, {
    ChatListProvider? chatListProvider,
  }) async {
    final result = await _apiCaller.clearChatHistory(userId, companionId);
    return result.fold(
      (failure) {
        debugPrint(
          'MessageProvider: clearHistory failed: ${failure.errMessage}',
        );
        return false;
      },
      (response) async {
        await _db.deleteMessagesByCompanion(companionId);
        if (_companionId == companionId) {
          _messages.clear();
          _stopImageStatusPolling();
          notifyListeners();
        }

        if (chatListProvider != null) {
          // Set time to 0 to move it to the bottom of the list
          await chatListProvider.updateLastMessage(
            companionId,
            "Let's talk!",
            epoch: 0,
          );
        } else {
          // If no provider, try to update DB directly by fetching existing chat item first
          try {
            final chats = await _db.getCachedChats();
            final existing = chats.firstWhere(
              (c) => c.companionId == companionId,
              orElse: () => ChatItem(
                companionId: companionId,
                girlfriendName: '',
                lastText: '',
                imageUrl: '',
                time: 0,
              ),
            );
            if (existing.companionId.isNotEmpty) {
              await _db.upsertChatItem(
                existing.copyWith(
                  lastText: "Let's talk!",
                  time: 0, // Move to bottom
                ),
              );
            }
          } catch (e) {
            debugPrint('MessageProvider: failed to update chat list in DB: $e');
          }
        }

        return true;
      },
    );
  }

  /// Send message: optimistic local insert, background API call which upserts assistant response.
  /// If [chatListProvider] is provided, updates last-message there as well.
  void sendMessage({
    required String userId,
    required String companionId,
    required String text,
    String? name,
    String? imageUrl,
    ChatListProvider? chatListProvider,
    UserProvider? userProvider,
  }) {
    final epochWhenSendStarted = _chatLoadEpoch;
    final epoch = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    // Generate a UUID for the message so backend uses the same ID
    final messageId = const Uuid().v4();

    final userMsg = MessageItem(
      companionId: companionId,
      messageId: messageId,
      role: 'user',
      content: text,
      time: epoch,
    );
    // optimistic add
    addLocalMessage(userMsg);
    // update chat list immediately
    if (chatListProvider != null) {
      chatListProvider.updateLastMessage(
        companionId,
        text,
        name: name,
        imageUrl: imageUrl,
        epoch: epoch,
      );
    } else {
      // best-effort DB update so other screens see it
      _db.upsertChatItem(
        ChatItem(
          companionId: companionId,
          girlfriendName: name ?? '',
          lastText: text,
          imageUrl: imageUrl ?? '',
          time: epoch,
        ),
      );
    }

    // Fire-and-forget API call in background
    _typingStatus[companionId] = true;
    notifyListeners();

    Future.microtask(() async {
      try {
        // Pass the generated messageId to the backend
        final result = await _apiCaller.chat(
          userId,
          companionId,
          text,
          messageId: messageId,
        );
        result.fold(
          (failure) {
            debugPrint(
              'MessageProvider.sendMessage failed: ${failure.errMessage}',
            );
          },
          (response) async {
            final data = response.data as Map<String, dynamic>?;
            if (data == null) return;
            if (data['status'] != true) {
              final errorMsg =
                  data['message'] as String? ?? 'Error sending message';
              SophiaToast.show(msg: errorMsg, type: ToastType.error);
              // Also update credits if present (e.g. 0) so UI reflects reality
              if (data.containsKey('credits') && userProvider != null) {
                final credits = data['credits'];
                final intVal = (credits is int)
                    ? credits
                    : int.tryParse(credits.toString()) ?? 0;
                Future.microtask(() => userProvider.updateCredits(intVal));
              }
              return;
            }

            // Update credits if available in response
            if (data.containsKey('credits') && userProvider != null) {
              final credits = data['credits'];
              final intVal = (credits is int)
                  ? credits
                  : int.tryParse(credits.toString()) ?? 0;
              // Run on UI thread as it updates listeners
              Future.microtask(() => userProvider.updateCredits(intVal));
            }

            final responseText = data['message'] as String? ?? '';
            final msgId = data['message_id']?.toString() ?? '';
            final time = (data['time'] is int)
                ? data['time'] as int
                : int.tryParse((data['time'] ?? '').toString()) ?? epoch;
            final imageStatus = (data['image_status'] ?? '').toString();
            final extraMsg = (data['extra_message'] ?? '').toString();
            if (imageStatus == 'failed' &&
                extraMsg.trim().isNotEmpty &&
                _chatLoadEpoch == epochWhenSendStarted) {
              SophiaToast.show(msg: extraMsg, type: ToastType.info, duration: const Duration(seconds: 4));
            }

            final assistantItem = MessageItem(
              companionId: companionId,
              messageId: msgId,
              role: 'assistant',
              content: responseText,
              imagePath: (data['image_path'] ?? '').toString(),
              imageStatus: imageStatus,
              generationId: (data['generation_id'] ?? '').toString(),
              extraMessage: extraMsg,
              time: time,
            );
            await addRemoteMessage(assistantItem);
            _refreshImageStatusPolling();

            if (NotificationHelper.currentCompanionId != companionId) {
              SophiaToast.show(msg: 'You have a new message from $name! ✨', type: ToastType.info, duration: const Duration(seconds: 4));
            }
            // update chat list with assistant reply
            if (chatListProvider != null) {
              await chatListProvider.updateLastMessage(
                companionId,
                responseText,
                name: name,
                imageUrl: imageUrl,
                epoch: time,
              );
            } else {
              await _db.upsertChatItem(
                ChatItem(
                  companionId: companionId,
                  girlfriendName: name ?? '',
                  lastText: responseText,
                  imageUrl: imageUrl ?? '',
                  time: time,
                ),
              );
            }
          },
        );
      } catch (e) {
        debugPrint('MessageProvider.sendMessage exception: $e');
      } finally {
        _typingStatus[companionId] = false;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _stopImageStatusPolling();
    super.dispose();
  }
}
