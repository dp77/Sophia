import 'package:dio/dio.dart';
import 'package:girlfriend/data/model/reel_model.dart';
import 'dio_client.dart';

final Dio dio = DioClient.dio;

Future<List<dynamic>> requestReelsData() async {
  try {
    final response = await dio.get("/reels");
    if (response.data['status'] == true && response.data['reels'] != null) {
      return response.data['reels'];
    } else {
      throw Exception("Invalid response: status is not true or reels data is null");
    }
  } on DioException catch (e) {
    throw Exception(e.response?.data ?? "Failed to load reels");
  }
}

Future<ReelsData> getReels() async {
  var reelsData = await requestReelsData();
  List<ReelItem> reelsList = [];
  for (var reelData in reelsData) {
    reelsList.add(ReelItem.fromJson(reelData));
  }
  return ReelsData(reels: reelsList);
}
