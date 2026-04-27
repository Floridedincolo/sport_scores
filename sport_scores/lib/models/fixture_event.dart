class FixtureEvent {
  final int? elapsed;
  final int? extraElapsed;
  final String type;
  final String? detail;
  final String? teamName;
  final int? teamId;
  final String? playerName;
  final String? assistName;
  final String? comments;

  const FixtureEvent({
    this.elapsed,
    this.extraElapsed,
    required this.type,
    this.detail,
    this.teamName,
    this.teamId,
    this.playerName,
    this.assistName,
    this.comments,
  });

  factory FixtureEvent.fromFootballJson(Map<String, dynamic> json) {
    final time = json['time'] as Map<String, dynamic>?;
    final team = json['team'] as Map<String, dynamic>?;
    final player = json['player'] as Map<String, dynamic>?;
    final assist = json['assist'] as Map<String, dynamic>?;

    return FixtureEvent(
      elapsed: time?['elapsed'] as int?,
      extraElapsed: time?['extra'] as int?,
      type: json['type'] as String? ?? '',
      detail: json['detail'] as String?,
      teamName: team?['name'] as String?,
      teamId: team?['id'] as int?,
      playerName: player?['name'] as String?,
      assistName: assist?['name'] as String?,
      comments: json['comments'] as String?,
    );
  }

  factory FixtureEvent.fromMlbJson(Map<String, dynamic> json) {
    final result = json['result'] as Map<String, dynamic>?;
    final eventName = result?['event'] as String? ?? result?['type'] as String? ?? '';
    final about = json['about'] as Map<String, dynamic>?;
    final matchup = json['matchup'] as Map<String, dynamic>?;
    final inning = about?['inning'] as int?;
    final halfInning = about?['halfInning'] as String? ?? '';

    final batter = matchup?['batter'] as Map<String, dynamic>?;
    final pitcher = matchup?['pitcher'] as Map<String, dynamic>?;
    final count = json['count'] as Map<String, dynamic>?;

    final batterName = batter?['fullName'] as String?;
    final pitcherName = pitcher?['fullName'] as String?;
    final resultDesc = result?['description'] as String? ?? eventName;

    final lower = eventName.toLowerCase();
    final String displayType;
    if (lower.contains('strikeout')) {
      displayType = 'Strikeout';
    } else if (lower.contains('walk')) {
      displayType = 'Walk';
    } else if (lower.contains('home run')) {
      displayType = 'Home Run';
    } else if (lower.contains('single')) {
      displayType = 'Single';
    } else if (lower.contains('double') && !lower.contains('double play')) {
      displayType = 'Double';
    } else if (lower.contains('triple') && !lower.contains('triple play')) {
      displayType = 'Triple';
    } else if (lower.contains('flyout') || lower.contains('fly out') || lower.contains('pop out')) {
      displayType = 'Fly Out';
    } else if (lower.contains('groundout') || lower.contains('ground out')) {
      displayType = 'Ground Out';
    } else if (lower.contains('lineout') || lower.contains('line out')) {
      displayType = 'Line Out';
    } else if (lower.contains('double play')) {
      displayType = 'Double Play';
    } else if (lower.contains('sac fly') || lower.contains('sacrifice')) {
      displayType = 'Sacrifice';
    } else if (lower.contains('error')) {
      displayType = 'Error';
    } else if (lower.contains('hit by pitch')) {
      displayType = 'Hit By Pitch';
    } else if (lower.contains('field') && lower.contains('choice')) {
      displayType = "Fielder's Choice";
    } else {
      displayType = eventName;
    }

    // Encode half-inning in elapsed: top = inning, bottom = inning + 100
    final encodedInning = halfInning == 'bottom' ? (inning ?? 1) + 100 : (inning ?? 1);

    return FixtureEvent(
      elapsed: encodedInning,
      type: displayType,
      detail: resultDesc,
      playerName: batterName,
      assistName: pitcherName,
      comments: count != null ? '${count['balls']}-${count['strikes']}' : null,
    );
  }

  factory FixtureEvent.fromNbaJson(Map<String, dynamic> json) {
    final period = json['period'] as Map<String, dynamic>?;
    final periodNumber = period?['number'] as int? ?? 1;
    final clock = json['clock'] as Map<String, dynamic>?;
    final displayValue = clock?['displayValue'] as String? ?? '';
    final text = json['text'] as String? ?? '';
    final type = json['type'] as Map<String, dynamic>?;
    final typeName = type?['text'] as String? ?? '';
    final scoringPlay = json['scoringPlay'] as bool? ?? false;
    final team = json['team'] as Map<String, dynamic>?;
    final teamName = team?['displayName'] as String? ?? team?['name'] as String?;

    // Classify event type
    final String displayType;
    final lower = typeName.toLowerCase();
    if (scoringPlay) {
      if (lower.contains('three') || lower.contains('3-pt') || lower.contains('3pt')) {
        displayType = 'Three Pointer';
      } else if (lower.contains('free throw')) {
        displayType = 'Free Throw';
      } else if (lower.contains('dunk')) {
        displayType = 'Dunk';
      } else if (lower.contains('layup')) {
        displayType = 'Layup';
      } else {
        displayType = 'Field Goal';
      }
    } else if (lower.contains('foul')) {
      displayType = 'Foul';
    } else if (lower.contains('turnover')) {
      displayType = 'Turnover';
    } else if (lower.contains('timeout')) {
      displayType = 'Timeout';
    } else {
      displayType = typeName;
    }

    // Extract score from scoreValue or text
    final scoreValue = json['scoreValue'] as int?;
    String? comments;
    if (scoreValue != null && scoreValue > 0) {
      final homeScore = json['homeScore']?.toString() ?? '';
      final awayScore = json['awayScore']?.toString() ?? '';
      if (homeScore.isNotEmpty) comments = '$awayScore - $homeScore';
    }

    return FixtureEvent(
      elapsed: periodNumber,
      type: displayType,
      detail: text,
      teamName: teamName,
      playerName: null,
      comments: comments ?? displayValue,
    );
  }

  factory FixtureEvent.fromNhlJson(Map<String, dynamic> json) {
    final typeCode = json['typeCode'] as int? ?? 0;
    final typeDescKey = json['typeDescKey'] as String? ?? '';
    final periodDescriptor = json['periodDescriptor'] as Map<String, dynamic>?;
    final periodNumber = periodDescriptor?['number'] as int? ?? 1;
    final timeInPeriod = json['timeInPeriod'] as String? ?? '';
    final details = json['details'] as Map<String, dynamic>?;

    final String displayType;
    switch (typeCode) {
      case 505:
        displayType = 'Goal';
      case 509:
        displayType = 'Penalty';
      case 502:
        displayType = 'Faceoff';
      case 506:
        displayType = 'Stoppage';
      default:
        displayType = typeDescKey.isNotEmpty
            ? typeDescKey[0].toUpperCase() + typeDescKey.substring(1).replaceAll('-', ' ')
            : 'Event';
    }

    // Extract player names from details
    String? scorerName;
    String? assistName;
    String? description;
    if (typeCode == 505) {
      scorerName = details?['scoringPlayerTotal'] != null
          ? 'Goal #${details!['scoringPlayerTotal']}'
          : null;
      final assist1 = details?['assist1PlayerTotal'];
      final assist2 = details?['assist2PlayerTotal'];
      if (assist1 != null || assist2 != null) {
        assistName = [if (assist1 != null) 'A1', if (assist2 != null) 'A2'].join(', ');
      }
      final shotType = details?['shotType'] as String?;
      description = shotType != null ? 'Shot: $shotType' : null;
    } else if (typeCode == 509) {
      final descKey = details?['descKey'] as String? ?? '';
      final duration = details?['duration'] as int?;
      description = '${descKey.replaceAll('-', ' ')}${duration != null ? ' ($duration min)' : ''}';
    }

    return FixtureEvent(
      elapsed: periodNumber,
      type: displayType,
      detail: description,
      playerName: scorerName,
      assistName: assistName,
      comments: timeInPeriod,
    );
  }

  factory FixtureEvent.fromF1RaceControlJson(Map<String, dynamic> json, int order) {
    final category = json['category'] as String? ?? '';
    final message = json['message'] as String? ?? '';
    final flag = json['flag'] as String?;

    final String displayType;
    if (category == 'SafetyCar') {
      displayType = message.contains('VSC') ? 'VSC' : 'Safety Car';
    } else if (flag == 'RED') {
      displayType = 'Red Flag';
    } else if (flag == 'CHEQUERED') {
      displayType = 'Chequered Flag';
    } else if (message.contains('PENALTY')) {
      displayType = 'Penalty';
    } else {
      displayType = 'Race Control';
    }

    return FixtureEvent(
      elapsed: order,
      type: displayType,
      detail: message,
      comments: flag,
    );
  }

  factory FixtureEvent.fromF1PitJson(Map<String, dynamic> json, Map<String, String>? driver, int order) {
    final driverNum = json['driver_number'] as int?;
    final lap = json['lap_number'] as int?;
    final duration = json['pit_duration'] as num?;
    final name = driver?['name'] ?? '#${driverNum ?? '?'}';
    final team = driver?['team'];

    return FixtureEvent(
      elapsed: order,
      type: 'Pit Stop',
      detail: 'Lap $lap${duration != null ? ' - ${duration.toStringAsFixed(1)}s' : ''}',
      playerName: name,
      teamName: team,
    );
  }

  factory FixtureEvent.fromF1PositionJson(Map<String, dynamic> json, Map<String, String>? driver, int order) {
    final driverNum = json['driver_number'] as int?;
    final position = json['position'] as int? ?? 0;
    final name = driver?['name'] ?? '#${driverNum ?? '?'}';
    final team = driver?['team'];

    return FixtureEvent(
      elapsed: order,
      type: 'P$position',
      detail: name,
      teamName: team,
    );
  }

  String get timeDisplay {
    if (elapsed == null) return '';
    if (extraElapsed != null) return "$elapsed'+$extraElapsed";
    return "$elapsed'";
  }

  bool get isGoal => type == 'Goal';
  bool get isCard => type == 'Card';
  bool get isSubstitution => type == 'subst';
  bool get isVar => type == 'Var';
}
