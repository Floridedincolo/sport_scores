class Team {
  final int id;
  final String name;
  final String? logo;

  const Team({
    required this.id,
    required this.name,
    this.logo,
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: _parseId(json['id']),
      name: json['name'] as String? ?? 'Unknown',
      logo: json['logo'] as String?,
    );
  }

  static int _parseId(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
