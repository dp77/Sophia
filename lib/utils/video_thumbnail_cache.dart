import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class VideoThumbnailCache {
  static Future<String?> getOrCreate({required String videoUrl, String? cachedVideoPath}) async {
    if (videoUrl.isEmpty) return null;
    try {
      final dir = await getTemporaryDirectory();
      final thumbDir = Directory('${dir.path}/video_thumbs');
      if (!await thumbDir.exists()) {
        await thumbDir.create(recursive: true);
      }
      final key = sha1.convert(utf8.encode(videoUrl)).toString();
      final outPath = '${thumbDir.path}/$key.png';
      final outFile = File(outPath);
      if (await outFile.exists()) return outPath;

      final source = (cachedVideoPath != null && cachedVideoPath.isNotEmpty) ? cachedVideoPath : videoUrl;
      final generated = await VideoThumbnail.thumbnailFile(
        video: source,
        thumbnailPath: thumbDir.path,
        imageFormat: ImageFormat.PNG,
        quality: 75,
      );
      if (generated == null) return null;
      if (generated == outPath) return outPath;

      final genFile = File(generated);
      if (await genFile.exists()) {
        await genFile.copy(outPath);
        return outPath;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

