import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:girlfriend/data/api_service/server_failure.dart';
import 'package:girlfriend/data/chat_language_storage.dart';
import 'dio_client.dart';

mixin class ApiCaller {
  final Dio dio = DioClient.dio;
  Future<Either<Failure, Response>> registerLogin(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await dio.post('/auth/register-login', data: data);
      return right(response);
    } catch (e) {
      if (e is DioException) {
        return left(ServerFailure.fromDioError(e));
      }
      return left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, Response>> chat(
    String userId,
    String companionId,
    String message, {
    String? messageId,
  }) async {
    await ChatLanguageStorage.instance.ensureLoaded();
    final data = <String, dynamic>{
      'user_id': userId,
      'companion_id': companionId,
      'message': message,
      'language': ChatLanguageStorage.instance.code,
    };
    if (messageId != null && messageId.isNotEmpty) {
      data['message_id'] = messageId;
    }
    try {
      final response = await dio.post('/companions/message', data: data);
      return right(response);
    } catch (e) {
      if (e is DioException) {
        return left(ServerFailure.fromDioError(e));
      }
      return left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, Response>> getCompanions() async {
    try {
      final response = await dio.get(
        /*kDebugMode ? '/companions/dev' :*/ '/companions',
      );
      return right(response);
    } catch (e) {
      if (e is DioException) {
        return left(ServerFailure.fromDioError(e));
      }
      return left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, Response>> getCompanionProfile(
    String companionId,
  ) async {
    try {
      final response = await dio.get('/companions/$companionId');
      return right(response);
    } catch (e) {
      if (e is DioException) {
        return left(ServerFailure.fromDioError(e));
      }
      return left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, Response>> getProfile({required String userId}) async {
    try {
      final response = await dio.get('/users/$userId');
      return right(response);
    } catch (e) {
      if (e is DioException) {
        return left(ServerFailure.fromDioError(e));
      }
      return left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, Response>> getChatList(String userId) async {
    try {
      final response = await dio.get('/chats/$userId/list');
      return right(response);
    } catch (e) {
      if (e is DioException) {
        return left(ServerFailure.fromDioError(e));
      }
      return left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, Response>> getChatMessage(
    String userId,
    String companionId,
  ) async {
    try {
      final response = await dio.get('/chats/$userId/$companionId/messages');
      return right(response);
    } catch (e) {
      if (e is DioException) {
        return left(ServerFailure.fromDioError(e));
      }
      return left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, Response>> getChatImageStatusBatch(
    String userId,
    String companionId,
    List<String> generationIds,
  ) async {
    try {
      final response = await dio.post(
        '/chats/$userId/$companionId/image-status',
        data: {'generation_ids': generationIds},
      );
      return right(response);
    } catch (e) {
      if (e is DioException) {
        return left(ServerFailure.fromDioError(e));
      }
      return left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, Response>> getReels() async {
    try {
      final response = await dio.get('/reels');
      return right(response);
    } catch (e) {
      if (e is DioException) {
        return left(ServerFailure.fromDioError(e));
      }
      return left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, Response>> reportReels(
    String reelId,
    String gfId,
    String userId,
    String description,
  ) async {
    final data = {
      "reels_id": reelId,
      "gf_id": gfId,
      "user_id": userId,
      "description": description,
    };
    try {
      final response = await dio.post('/reels/report', data: data);
      return right(response);
    } catch (e) {
      if (e is DioException) {
        return left(ServerFailure.fromDioError(e));
      }
      return left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, Response>> clearChatHistory(
    String userId,
    String companionId,
  ) async {
    try {
      final response = await dio.delete('/chats/$userId/$companionId/clear');
      return right(response);
    } catch (e) {
      if (e is DioException) {
        return left(ServerFailure.fromDioError(e));
      }
      return left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, Response>> updateUserName(
    String userId,
    String name,
  ) async {
    try {
      final response = await dio.patch(
        '/users/$userId/name',
        data: {'name': name},
      );
      return right(response);
    } catch (e) {
      if (e is DioException) {
        return left(ServerFailure.fromDioError(e));
      }
      return left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, Response>> watchAndEarn(String userId) async {
    try {
      final response = await dio.post('/users/$userId/credits/watch-earn');
      return right(response);
    } catch (e) {
      if (e is DioException) {
        return left(ServerFailure.fromDioError(e));
      }
      return left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, Response>> registerOneSignal(
    String userId,
    String onesignalId,
  ) async {
    try {
      final response = await dio.post(
        '/users/$userId/onesignal',
        data: {'onesignal_id': onesignalId},
      );
      return right(response);
    } catch (e) {
      if (e is DioException) {
        return left(ServerFailure.fromDioError(e));
      }
      return left(ServerFailure(e.toString()));
    }
  }

  /// Sends feedback to the configured Discord webhook.
  Future<Either<Failure, Response>> giveFeedback(
    String userId,
    String description,
  ) async {
    const webhookUrl =
        'https://discord.com/api/webhooks/1557351458452668467/xuG8JxCGYJ5HBbJImoLV2paSTADLH4x2e0KEDgBylxESC1nnO8GeKIZyG-haUDAzOgBr';
    final packageInfo = await PackageInfo.fromPlatform();
    final appVersion =
        '${packageInfo.version} (build:${packageInfo.buildNumber})';
    final feedback = description.trim();
    final platform = Platform.isIOS
        ? 'iOS'
        : Platform.isAndroid
        ? 'Android'
        : 'Other';
    final submittedAt = DateTime.now().toIso8601String();

    try {
      final response = await Dio().post(
        webhookUrl,
        data: {
          'username': 'Sophia AI Feedback',
          'content': 'New feedback received',
          'embeds': [
            {
              'title': 'Feedback',
              'description': feedback.length > 3900
                  ? '${feedback.substring(0, 3900)}...'
                  : feedback,
              'color': 0x8B5CF6,
              'fields': [
                {'name': 'User ID', 'value': userId, 'inline': false},
                {'name': 'Platform', 'value': platform, 'inline': true},
                {'name': 'App', 'value': 'Sophia AI', 'inline': true},
                {'name': 'App Version', 'value': appVersion, 'inline': false},
                {'name': 'Submitted', 'value': submittedAt, 'inline': false},
              ],
            },
          ],
          'allowed_mentions': {'parse': <String>[]},
        },
      );
      return right(response);
    } catch (e) {
      if (e is DioException) {
        return left(ServerFailure.fromDioError(e));
      }
      return left(ServerFailure(e.toString()));
    }
  }

  /// Image Generate
  Future<Either<Failure, Response>> generateImage(
    String prompt,
    String userId,
    String gfId,
  ) async {
    final data = {
      "prompt": prompt,
      "user_id": userId,
      "companion_id": gfId,
      "aspect_ratio": "1:1",
    };
    try {
      final response = await dio.post('/image/generate', data: data);
      return right(response);
    } catch (e) {
      if (e is DioException) {
        return left(ServerFailure.fromDioError(e));
      }
      return left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, Response>> generateImageStatus(
    String requestId,
  ) async {
    try {
      final response = await dio.get('/character/generate_status/$requestId');
      return right(response);
    } catch (e) {
      if (e is DioException) {
        return left(ServerFailure.fromDioError(e));
      }
      return left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, Response>> creditsHistory(String userId) async {
    try {
      final response = await dio.get('/users/$userId/credits/history');
      return right(response);
    } catch (e) {
      if (e is DioException) {
        return left(ServerFailure.fromDioError(e));
      }
      return left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, Response>> generationHistory(
    String userId, {
    int limit = 10,
    int? before,
  }) async {
    try {
      final query = <String, dynamic>{'limit': limit};
      if (before != null) query['before'] = before;
      final response = await dio.get(
        '/users/$userId/generation/history',
        queryParameters: query,
      );
      return right(response);
    } catch (e) {
      if (e is DioException) {
        return left(ServerFailure.fromDioError(e));
      }
      return left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, Response>> deleteGenerationItem(
    String userId,
    String itemId,
  ) async {
    try {
      final response = await dio.delete('/users/$userId/generation/$itemId');
      return right(response);
    } catch (e) {
      if (e is DioException) {
        return left(ServerFailure.fromDioError(e));
      }
      return left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, Response>> deleteAccount(String userId) async {
    try {
      final response = await dio.delete('/users/$userId/account');
      return right(response);
    } catch (e) {
      if (e is DioException) {
        return left(ServerFailure.fromDioError(e));
      }
      return left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, Response>> purchasePremium(
    String billingDetails,
    String userId,
  ) async {
    try {
      final data = {'billing_details': billingDetails};
      final response = await dio.post(
        '/user/purchase-premium?user_id=$userId',
        data: data,
      );
      return right(response);
    } catch (e) {
      if (e is DioException) {
        return left(ServerFailure.fromDioError(e));
      }
      return left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, Response>> watchAndEarnStatus(String userId) async {
    try {
      final response = await dio.get(
        '/users/$userId/credits/watch-earn/status',
      );
      return right(response);
    } catch (e) {
      if (e is DioException) {
        return left(ServerFailure.fromDioError(e));
      }
      return left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, Response>> updateChatLanguage(
    String userId,
    String chatLanguage,
  ) async {
    try {
      final response = await dio.post(
        '/user/chat-language',
        data: {'user_id': userId, 'chat_language': chatLanguage},
      );
      return right(response);
    } catch (e) {
      if (e is DioException) {
        return left(ServerFailure.fromDioError(e));
      }
      return left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, Response>> userGirlfriendList(String userId) async {
    try {
      final response = await dio.get('/character/gf_list?user_id=$userId');
      return right(response);
    } catch (e) {
      if (e is DioException) {
        return left(ServerFailure.fromDioError(e));
      }
      return left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, Response>> generateCharacterImage(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await dio.post('/character/generate_image', data: data);
      return right(response);
    } catch (e) {
      if (e is DioException) {
        return left(ServerFailure.fromDioError(e));
      }
      return left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, Response>> createCharacter(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await dio.post('/character/gf_create', data: data);
      return right(response);
    } catch (e) {
      if (e is DioException) {
        return left(ServerFailure.fromDioError(e));
      }
      return left(ServerFailure(e.toString()));
    }
  }
}
