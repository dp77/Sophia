import 'package:flutter/foundation.dart';
import 'package:girlfriend/data/api_service/api_caller.dart';
import 'package:girlfriend/data/model/charcter_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<CharacterModel> _parseCharacters(List<dynamic> rawCharacters) {
  return rawCharacters
      .whereType<Map>()
      .map((item) => CharacterModel.fromJson(Map<String, dynamic>.from(item)))
      .toList();
}

class UserCharacterProvider with ChangeNotifier {
  final ApiCaller _apiCaller = ApiCaller();
  List<CharacterModel> _characterList = [];
  bool _loading = true;

  List<CharacterModel> get characterList => _characterList;
  bool get loading => _loading;

  UserCharacterProvider() {
    fetchCompanions();
  }

  Future<void> fetchCompanions() async {
    _loading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_backend_id') ?? '';
    if (userId.isEmpty) {
      _characterList = [];
      _loading = false;
      notifyListeners();
      return;
    }

    final result = await _apiCaller.userGirlfriendList(userId);
    result.fold(
      (_) {
        _characterList = [];
        _loading = false;
        notifyListeners();
      },
      (response) async {
        final data = response.data;
        if (data is Map<String, dynamic> && data['status'] == true) {
          final rawCharacters = data['characters'];
          if (rawCharacters is List && rawCharacters.isNotEmpty) {
            _characterList = await compute(_parseCharacters, rawCharacters);
          } else {
            _characterList = [];
          }
        } else {
          _characterList = [];
        }

        _loading = false;
        notifyListeners();
      },
    );
  }

  Future<void> fetchCompanionsSilently() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_backend_id') ?? '';
    if (userId.isEmpty) {
      if (_characterList.isNotEmpty) {
        _characterList = [];
        notifyListeners();
      }
      return;
    }

    final result = await _apiCaller.userGirlfriendList(userId);
    result.fold(
      (_) {
        if (_characterList.isNotEmpty) {
          _characterList = [];
          notifyListeners();
        }
      },
      (response) async {
        List<CharacterModel> updated = [];
        final data = response.data;
        if (data is Map<String, dynamic> && data['status'] == true) {
          final rawCharacters = data['characters'];
          if (rawCharacters is List && rawCharacters.isNotEmpty) {
            updated = await compute(_parseCharacters, rawCharacters);
          }
        }
        _characterList = updated;
        notifyListeners();
      },
    );
  }
}
