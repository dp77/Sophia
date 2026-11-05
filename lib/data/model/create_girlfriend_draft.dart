import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CreateGirlfriendDraft {
  final List<String> vibeTags;
  final String? customVibe;
  final String name;
  final int age;
  final String look;
  final String relationship;
  final String chatStyle;
  final bool rememberDetails;
  final bool initiateMessages;
  final bool jealousMoody;

  const CreateGirlfriendDraft({
    required this.vibeTags,
    this.customVibe,
    required this.name,
    required this.age,
    required this.look,
    required this.relationship,
    required this.chatStyle,
    required this.rememberDetails,
    required this.initiateMessages,
    required this.jealousMoody,
  });

  String get resolvedVibe {
    final parts = vibeTags.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final c = customVibe?.trim();
    if (c != null && c.isNotEmpty) parts.add(c);
    return parts.join(', ');
  }

  Map<String, dynamic> toJson() => {
        'vibeTags': vibeTags,
        'customVibe': customVibe,
        'name': name,
        'age': age,
        'look': look,
        'relationship': relationship,
        'chatStyle': chatStyle,
        'rememberDetails': rememberDetails,
        'initiateMessages': initiateMessages,
        'jealousMoody': jealousMoody,
      };

  static CreateGirlfriendDraft? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    List<String> tags = [];
    final rawTags = j['vibeTags'];
    if (rawTags is List) {
      tags = rawTags.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    } else {
      final legacy = j['vibe'] as String? ?? '';
      if (legacy.isNotEmpty) tags = [legacy];
    }
    return CreateGirlfriendDraft(
      vibeTags: tags,
      customVibe: j['customVibe'] as String?,
      name: j['name'] as String? ?? '',
      age: (j['age'] as num?)?.toInt() ?? 22,
      look: j['look'] as String? ?? '',
      relationship: j['relationship'] as String? ?? '',
      chatStyle: j['chatStyle'] as String? ?? '',
      rememberDetails: j['rememberDetails'] as bool? ?? true,
      initiateMessages: j['initiateMessages'] as bool? ?? true,
      jealousMoody: j['jealousMoody'] as bool? ?? false,
    );
  }

  static const String prefKey = 'create_girlfriend_draft_json';

  static Future<void> persist(CreateGirlfriendDraft d) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(prefKey, jsonEncode(d.toJson()));
  }

  static Future<CreateGirlfriendDraft?> loadPersisted() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(prefKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static String buildImagePromptHint(CreateGirlfriendDraft d) {
    final v = d.resolvedVibe;
    return 'Portrait of ${d.name}, ${d.age}, ${d.look} aesthetic, $v personality, photorealistic soft lighting';
  }

  static String sampleFirstMessage(CreateGirlfriendDraft d) {
    final n = d.name.isEmpty ? 'you' : d.name;
    switch (d.chatStyle) {
      case 'Short and cute':
        return "hey… been thinking about u a little today 💕";
      case 'Romantic and emotional':
        return "I’m really glad we’re talking. You feel easy to open up to, $n.";
      case 'Flirty and teasing':
        return "So… are you always this charming, or is it just for me? 😏";
      case 'Sexy and confident':
        return "You’ve got my attention. Don’t waste it.";
      case 'Funny and chaotic':
        return "okay okay listen—if we were a movie we’d already be the chaotic subplot";
      case 'Mature and calm':
        return "I hope your day’s been kind to you. I’m here when you want to unwind.";
      default:
        return "Hey $n… I’ve been waiting to hear from you.";
    }
  }
}
