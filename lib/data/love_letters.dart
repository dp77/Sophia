import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'model/love_letter.dart';

/// The Letters inbox: notes companions sent while the user was elsewhere.
/// Kept on the device, newest first, capped at [_max].
class LoveLetters extends ChangeNotifier {
  LoveLetters._();
  static final LoveLetters instance = LoveLetters._();

  static const _key = 'love_letters_v1';
  static const _max = 60;

  final List<LoveLetter> _letters = [];

  List<LoveLetter> get letters => List.unmodifiable(_letters);
  int get unreadCount => _letters.where((l) => !l.read).length;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return;
      final stored = (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((m) => LoveLetter.fromJson(Map<String, dynamic>.from(m)))
          .where((l) => _letters.every((e) => e.id != l.id));
      _letters.addAll(stored);
      _letters.sort((a, b) => b.time.compareTo(a.time));
      notifyListeners();
    } catch (e) {
      debugPrint('LoveLetters.load failed: $e');
    }
  }

  /// Keeps a new letter. Returns null when a letter with [id] is already kept.
  Future<LoveLetter?> add({
    String? id,
    required String companionId,
    required String name,
    required String imageUrl,
    required String text,
  }) async {
    final letterId = id ?? 'l${DateTime.now().microsecondsSinceEpoch}';
    if (_letters.any((l) => l.id == letterId)) return null;
    final letter = LoveLetter(
      id: letterId,
      companionId: companionId,
      name: name.trim().isEmpty ? 'Your companion' : name.trim(),
      imageUrl: imageUrl,
      text: text.trim(),
      time: DateTime.now().millisecondsSinceEpoch,
    );
    _letters.insert(0, letter);
    if (_letters.length > _max) _letters.removeRange(_max, _letters.length);
    notifyListeners();
    await _save();
    return letter;
  }

  Future<void> markRead(String id) async {
    final i = _letters.indexWhere((l) => l.id == id);
    if (i < 0 || _letters[i].read) return;
    _letters[i] = _letters[i].copyWith(read: true);
    notifyListeners();
    await _save();
  }

  Future<void> markAllRead() async {
    if (unreadCount == 0) return;
    for (var i = 0; i < _letters.length; i++) {
      _letters[i] = _letters[i].copyWith(read: true);
    }
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(_letters.map((l) => l.toJson()).toList()));
    } catch (e) {
      debugPrint('LoveLetters.save failed: $e');
    }
  }
}
