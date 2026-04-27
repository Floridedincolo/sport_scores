import 'package:flutter/material.dart';

enum SportType {
  football,
  basketball,
  hockey,
  baseball,
  formula1,
  tennis,
  handball,
}

extension SportTypeExtension on SportType {
  String get displayName {
    return switch (this) {
      SportType.football => 'Football',
      SportType.basketball => 'Basketball',
      SportType.hockey => 'Hockey',
      SportType.baseball => 'Baseball',
      SportType.formula1 => 'Formula 1',
      SportType.tennis => 'Tennis',
      SportType.handball => 'Handball',
    };
  }

  IconData get icon {
    return switch (this) {
      SportType.football => Icons.sports_soccer,
      SportType.basketball => Icons.sports_basketball,
      SportType.hockey => Icons.sports_hockey,
      SportType.baseball => Icons.sports_baseball,
      SportType.formula1 => Icons.directions_car,
      SportType.tennis => Icons.sports_tennis,
      SportType.handball => Icons.sports_handball,
    };
  }
}
