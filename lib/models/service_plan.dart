/// A saved worship set. Songs are referenced by id so edits to a song are
/// immediately reflected in every plan that includes it.
class ServicePlan {
  const ServicePlan({
    required this.id,
    required this.title,
    required this.date,
    required this.songIds,
  });

  final String id;
  final String title;
  final DateTime date;
  final List<String> songIds;

  ServicePlan copyWith({
    String? id,
    String? title,
    DateTime? date,
    List<String>? songIds,
  }) {
    return ServicePlan(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      songIds: songIds ?? this.songIds,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'date': date.toIso8601String(),
    'songIds': songIds,
  };

  factory ServicePlan.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final title = json['title'];
    final rawDate = json['date'];
    final rawSongIds = json['songIds'];
    final date = rawDate is String ? DateTime.tryParse(rawDate) : null;
    if (id is! String ||
        title is! String ||
        date == null ||
        rawSongIds is! List<Object?> ||
        rawSongIds.any((value) => value is! String)) {
      throw const FormatException('Invalid saved service plan');
    }
    return ServicePlan(
      id: id,
      title: title,
      date: date,
      songIds: rawSongIds.cast<String>(),
    );
  }
}
