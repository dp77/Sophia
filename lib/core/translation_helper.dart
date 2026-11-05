class TranslationHelper {
  static String getSayHiText(String? languageName, String companionName) {
    if (languageName == null || languageName.isEmpty) return "Say hi to $companionName!";

    final lang = languageName.toLowerCase();

    switch (lang) {
      case 'chinese':
        return "向 $companionName 问好！";
      case 'hindi':
        return "$companionName को नमस्ते कहें!";
      case 'spanish':
        return "¡Saluda a $companionName!";
      case 'arabic':
        return "قل مرحبًا لـ $companionName!";
      case 'french':
        return "Dis bonjour à $companionName !";
      case 'portuguese':
        return "Diga oi para $companionName!";
      case 'russian':
        return "Поздоровайся с $companionName!";
      case 'indonesian':
        return "Katakan halo pada $companionName!";
      case 'japanese':
        return "$companionNameに挨拶しよう！";
      case 'german':
        return "Sag Hallo zu $companionName!";
      case 'korean':
        return "$companionName에게 인사하세요!";
      case 'italian':
        return "Dì ciao a $companionName!";
      case 'turkish':
        return "$companionName'e merhaba de!";
      case 'vietnamese':
        return "Hãy chào $companionName!";
      case 'thai':
        return "ทักทาย $companionName!";
      case 'polish':
        return "Przywitaj się z $companionName!";
      case 'ukrainian':
        return "Привітайся з $companionName!";
      case 'dutch':
        return "Zeg hallo tegen $companionName!";
      case 'swedish':
        return "Säg hej till $companionName!";
      case 'romanian':
        return "Salut-o pe $companionName!";
      default:
        return "Say hi to $companionName!";
    }
  }

  static String getHeyyText(String? languageName) {
    if (languageName == null || languageName.isEmpty) return "Heyy!";

    final lang = languageName.toLowerCase();

    switch (lang) {
      case 'chinese':
        return "嘿！";
      case 'hindi':
        return "हेय!";
      case 'spanish':
        return "¡Hola!";
      case 'arabic':
        return "مرحبًا!";
      case 'french':
        return "Coucou !";
      case 'portuguese':
        return "Oie!";
      case 'russian':
        return "Привет!";
      case 'indonesian':
        return "Hai!";
      case 'japanese':
        return "ヘイ！";
      case 'german':
        return "Hey!";
      case 'korean':
        return "헤이!";
      case 'italian':
        return "Ehi!";
      case 'turkish':
        return "Selam!";
      case 'vietnamese':
        return "Chào!";
      case 'thai':
        return "เฮ้!";
      case 'polish':
        return "Hej!";
      case 'ukrainian':
        return "Привіт!";
      case 'dutch':
        return "Hoi!";
      case 'swedish':
        return "Hej!";
      case 'romanian':
        return "Bună!";
      default:
        return "Heyy!";
    }
  }

  static String getSendingPicText(String? languageName) {
    if (languageName == null || languageName.isEmpty) return "Sending Pic...";

    final lang = languageName.toLowerCase();

    switch (lang) {
      case 'chinese':
        return "发送图片中...";
      case 'hindi':
        return "तस्वीर भेज रहे हैं...";
      case 'spanish':
        return "Enviando foto...";
      case 'arabic':
        return "جارٍ إرسال الصورة...";
      case 'french':
        return "Envoi de la photo...";
      case 'portuguese':
        return "Enviando foto...";
      case 'russian':
        return "Отправка фото...";
      case 'indonesian':
        return "Mengirim foto...";
      case 'japanese':
        return "写真を送信中...";
      case 'german':
        return "Bild wird gesendet...";
      case 'korean':
        return "사진 전송 중...";
      case 'italian':
        return "Invio foto in corso...";
      case 'turkish':
        return "Fotoğraf gönderiliyor...";
      case 'vietnamese':
        return "Đang gửi ảnh...";
      case 'thai':
        return "กำลังส่งรูปภาพ...";
      case 'polish':
        return "Wysyłanie zdjęcia...";
      case 'ukrainian':
        return "Надсилання фото...";
      case 'dutch':
        return "Foto verzenden...";
      case 'swedish':
        return "Skickar bild...";
      case 'romanian':
        return "Se trimite poza...";
      default:
        return "Sending Pic...";
    }
  }
}
