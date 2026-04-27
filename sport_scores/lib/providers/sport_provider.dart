import 'package:flutter/foundation.dart';
import '../models/sport.dart';

class SportProvider extends ChangeNotifier {
  SportType _selectedSport = SportType.football;

  SportType get selectedSport => _selectedSport;
  List<SportType> get availableSports => SportType.values;

  void selectSport(SportType sport) {
    if (_selectedSport != sport) {
      _selectedSport = sport;
      notifyListeners();
    }
  }
}
