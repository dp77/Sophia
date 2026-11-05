import 'package:girlfriend/data/api_service/decode_data.dart';

class ReelItem {
  final String reelId;
  final String gfid;
  final String description;
  final String thumb;
  final String video;

  ReelItem({
    required this.reelId,
    required this.gfid,
    required this.description,
    required this.thumb,
    required this.video,
  });

  factory ReelItem.fromJson(Map<String, dynamic> json) {
    return ReelItem(
      reelId: json['reels_id'] ?? '',
      gfid: json['gfid'] ?? '',
      description: json['description'] ?? '',
      thumb: json['thumb'] ?? '',
      video: json['video'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'reels_id': reelId, 'gfid': gfid, 'description': description, 'thumb': thumb, 'video': video};
  }
}

class ReelsData {
  final List<ReelItem> reels;

  ReelsData({required this.reels});

  static Future<ReelsData> getReelsData() async {
    return getReels();
  }
}
