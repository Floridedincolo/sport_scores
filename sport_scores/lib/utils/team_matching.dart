class TeamMatching {
  /// Format a DateTime as YYYY-MM-DD.
  static String formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Common filler words stripped before matching.
  static const _stopwords = {
    'fc', 'cf', 'afc', 'sc', 'ac', 'cd',
    'de', 'da', 'do', 'la', 'le', 'el', 'los', 'las',
    'club', 'team'
  };

  /// Fold common Latin diacritics to ASCII so "Atlético" matches "Atletico".
  static const _diacritics = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a', 'ā': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', 'ø': 'o', 'ō': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u',
    'ý': 'y', 'ÿ': 'y',
    'ñ': 'n', 'ç': 'c', 'ß': 'ss',
    'ș': 's', 'ş': 's', 'ț': 't', 'ţ': 't', 'ă': 'a',
  };

  static String _stripDiacritics(String s) {
    final buf = StringBuffer();
    for (final ch in s.split('')) {
      buf.write(_diacritics[ch] ?? ch);
    }
    return buf.toString();
  }

  /// Normalize a team name: lowercase + strip diacritics + strip punctuation
  /// + collapse spaces.
  static String _normalize(String s) {
    return _stripDiacritics(s.toLowerCase())
        .replaceAll(RegExp(r"[.,'\-:/()]"), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Split + filter: keep words >2 chars, drop stopwords.
  static Set<String> _significantWords(String s) {
    return s
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2 && !_stopwords.contains(w))
        .toSet();
  }

  /// Fuzzy match two team names from different APIs.
  /// Returns true if the names likely refer to the same team.
  static bool teamsMatch(String nameA, String nameB) {
    if (nameA.isEmpty || nameB.isEmpty) return false;
    final a = _normalize(nameA);
    final b = _normalize(nameB);
    if (a == b) return true;
    if (a.contains(b) || b.contains(a)) return true;

    final wordsA = _significantWords(a);
    final wordsB = _significantWords(b);
    if (wordsA.isEmpty || wordsB.isEmpty) return false;

    final overlap = wordsA.intersection(wordsB);
    final shorter = wordsA.length < wordsB.length ? wordsA : wordsB;
    if (overlap.length >= 2) return true;
    if (overlap.length == shorter.length) return true;

    // Prefix-match pass: handles abbreviations like "atl" ↔ "atletico",
    // "man" ↔ "manchester". Count a word as matched if it equals a word
    // in the other set, OR if it is a ≥3-char prefix of one.
    int matched = 0;
    for (final wa in wordsA) {
      for (final wb in wordsB) {
        if (wa == wb ||
            (wa.length >= 3 && wb.startsWith(wa)) ||
            (wb.length >= 3 && wa.startsWith(wb))) {
          matched++;
          break;
        }
      }
    }
    return matched >= shorter.length;
  }

  /// Get dates to try for game lookup, accounting for UTC timezone offset.
  /// Late-night US games have early UTC hours, so try previous day first.
  static List<DateTime> datesToTry(DateTime fixtureDate) {
    final dates = <DateTime>[];
    if (fixtureDate.hour < 12) {
      dates.add(fixtureDate.subtract(const Duration(days: 1)));
    }
    dates.add(fixtureDate);
    return dates;
  }
}
