import 'package:shared_preferences/shared_preferences.dart';

class ChatLanguageOption {
  final String code;
  final String englishName;
  final String nativeName;

  const ChatLanguageOption({required this.code, required this.englishName, required this.nativeName});
}

class ChatLanguageStorage {
  ChatLanguageStorage._();
  static final ChatLanguageStorage instance = ChatLanguageStorage._();

  static const String _prefKey = 'chat_language_code';
  static const String defaultCode = 'en';

  static final List<ChatLanguageOption> options = List.unmodifiable([
    ChatLanguageOption(code: 'en', englishName: 'English', nativeName: 'English'),
    ChatLanguageOption(code: 'zh', englishName: 'Chinese', nativeName: '简体中文 · 繁體中文'),
    ChatLanguageOption(code: 'hi', englishName: 'Hindi', nativeName: 'हिंदी'),
    ChatLanguageOption(code: 'es', englishName: 'Spanish', nativeName: 'Español'),
    ChatLanguageOption(code: 'ar', englishName: 'Arabic', nativeName: 'العربية'),
    ChatLanguageOption(code: 'fr', englishName: 'French', nativeName: 'Français'),
    ChatLanguageOption(code: 'pt', englishName: 'Portuguese', nativeName: 'Português'),
    ChatLanguageOption(code: 'ru', englishName: 'Russian', nativeName: 'Русский'),
    ChatLanguageOption(code: 'id', englishName: 'Indonesian', nativeName: 'Bahasa Indonesia'),
    ChatLanguageOption(code: 'ja', englishName: 'Japanese', nativeName: '日本語'),
    ChatLanguageOption(code: 'de', englishName: 'German', nativeName: 'Deutsch'),
    ChatLanguageOption(code: 'ko', englishName: 'Korean', nativeName: '한국어'),
    ChatLanguageOption(code: 'it', englishName: 'Italian', nativeName: 'Italiano'),
    ChatLanguageOption(code: 'tr', englishName: 'Turkish', nativeName: 'Türkçe'),
    ChatLanguageOption(code: 'vi', englishName: 'Vietnamese', nativeName: 'Tiếng Việt'),
    ChatLanguageOption(code: 'th', englishName: 'Thai', nativeName: 'ไทย'),
    ChatLanguageOption(code: 'pl', englishName: 'Polish', nativeName: 'Polski'),
    ChatLanguageOption(code: 'uk', englishName: 'Ukrainian', nativeName: 'Українська'),
    ChatLanguageOption(code: 'nl', englishName: 'Dutch', nativeName: 'Nederlands'),
    ChatLanguageOption(code: 'sv', englishName: 'Swedish', nativeName: 'Svenska'),
    ChatLanguageOption(code: 'ro', englishName: 'Romanian', nativeName: 'Română'),
  ]);

  String _code = defaultCode;
  bool _loaded = false;

  String get code => _code;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefKey);
    if (stored != null && options.any((o) => o.code == stored)) {
      _code = stored;
    } else {
      _code = defaultCode;
    }
    _loaded = true;
  }

  Future<void> setCode(String code) async {
    if (!options.any((o) => o.code == code)) return;
    _code = code;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, code);
  }
}
