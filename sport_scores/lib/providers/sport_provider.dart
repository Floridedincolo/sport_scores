import 'package:flutter/foundation.dart';
import '../models/sport.dart';

class SportProvider extends ChangeNotifier {
  SportType _selectedSport = SportType.football;

  SportType get selectedSport => _selectedSport;
  static const _hiddenSports = {
    SportType.formula1,
    SportType.handball,
  };

  List<SportType> get availableSports =>
      SportType.values.where((s) => !_hiddenSports.contains(s)).toList();

  void selectSport(SportType sport) {
    if (_selectedSport != sport) {
      _selectedSport = sport;
      notifyListeners();
    }
  }
}
