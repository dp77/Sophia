import 'package:flutter/foundation.dart';

import '../../data/api_service/api_caller.dart';
import '../../data/model/girlfriend.dart';
import '../../utils/isolate_utils.dart';

class GirlfriendProvider with ChangeNotifier {
  final ApiCaller _apiCaller = ApiCaller();

  List<Girlfriend> _girlfriends = [];
  Girlfriend? _selectedGirlfriend;
  bool _loading = true;

  List<Girlfriend> get girlfriends => List.unmodifiable(_girlfriends);
  Girlfriend? get selectedGirlfriend => _selectedGirlfriend;
  bool get loading => _loading;

  GirlfriendProvider() {
    fetchCompanions();
  }

  Future<void> fetchCompanions() async {
    _loading = true;
    notifyListeners();

    final result = await _apiCaller.getCompanions();
    result.fold(
      (_) {
        _loading = false;
        notifyListeners();
      },
      (response) async {
        final data = response.data;
        if (data is! Map<String, dynamic> || data['companions'] is! List) {
          _loading = false;
          notifyListeners();
          return;
        }

        final raw = data['companions'] as List;
        final prepared = await compute(prepareGirlfriendsForDb, {'raw': raw});
        final list = prepared.map((m) => Girlfriend.fromMap(m)).where((g) => g.id.isNotEmpty).toList();

        _girlfriends = list;
        if (_selectedGirlfriend == null && _girlfriends.isNotEmpty) {
          _selectedGirlfriend = _girlfriends.first;
        } else if (_selectedGirlfriend != null) {
          final found = _girlfriends.where((g) => g.id == _selectedGirlfriend!.id).firstOrNull;
          _selectedGirlfriend = found ?? _girlfriends.firstOrNull;
        }

        _loading = false;
        notifyListeners();
      },
    );
  }

  void selectGirlfriend(Girlfriend girlfriend) {
    _selectedGirlfriend = girlfriend;
    notifyListeners();
  }

  String? getGirlfriendNameById(String id) {
    try {
      final girlfriend = _girlfriends.firstWhere((g) => g.id == id);
      return girlfriend.name;
    } catch (e) {
      return null;
    }
  }

  String? getGirlfriendImageUrlById(String id) {
    try {
      final girlfriend = _girlfriends.firstWhere((g) => g.id == id);
      return girlfriend.imageUrl;
    } catch (e) {
      return null;
    }
  }
}
