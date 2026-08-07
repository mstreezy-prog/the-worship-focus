enum ServicePlanItemType { song, section }

/// One ordered entry in a saved worship set.
class ServicePlanItem {
  const ServicePlanItem.song({
    required this.id,
    required this.songId,
    this.notes = '',
  }) : type = ServicePlanItemType.song,
       title = null;

  const ServicePlanItem.section({required this.id, required String this.title})
    : type = ServicePlanItemType.section,
      songId = null,
      notes = '';

  final String id;
  final ServicePlanItemType type;
  final String? songId;
  final String? title;
  final String notes;

  bool get isSong => type == ServicePlanItemType.song;
  bool get isSection => type == ServicePlanItemType.section;

  ServicePlanItem copyWith({String? title, String? notes}) {
    return switch (type) {
      ServicePlanItemType.song => ServicePlanItem.song(
        id: id,
        songId: songId!,
        notes: notes ?? this.notes,
      ),
      ServicePlanItemType.section => ServicePlanItem.section(
        id: id,
        title: title ?? this.title!,
      ),
    };
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type.name,
    if (songId != null) 'songId': songId,
    if (title != null) 'title': title,
    if (notes.isNotEmpty) 'notes': notes,
  };

  factory ServicePlanItem.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final rawType = json['type'];
    if (id is! String || rawType is! String) {
      throw const FormatException('Invalid service plan item');
    }
    return switch (rawType) {
      'song' => _songFromJson(id, json),
      'section' => _sectionFromJson(id, json),
      _ => throw const FormatException('Unknown service plan item type'),
    };
  }

  static ServicePlanItem _songFromJson(String id, Map<String, Object?> json) {
    final songId = json['songId'];
    final notes = json['notes'];
    if (songId is! String || (notes != null && notes is! String)) {
      throw const FormatException('Invalid service plan song item');
    }
    return ServicePlanItem.song(
      id: id,
      songId: songId,
      notes: notes is String ? notes : '',
    );
  }

  static ServicePlanItem _sectionFromJson(
    String id,
    Map<String, Object?> json,
  ) {
    final title = json['title'];
    if (title is! String || title.trim().isEmpty) {
      throw const FormatException('Invalid service plan section');
    }
    return ServicePlanItem.section(id: id, title: title);
  }
}

/// A saved worship set. Song entries reference ids so song edits are reflected
/// everywhere the song is used. Section entries and song notes belong to the
/// plan itself.
class ServicePlan {
  ServicePlan({
    required this.id,
    required this.title,
    required this.date,
    List<ServicePlanItem>? items,
    List<String>? songIds,
  }) : assert(items != null || songIds != null),
       items = List.unmodifiable(
         items ??
             songIds!
                 .map(
                   (songId) =>
                       ServicePlanItem.song(id: 'song-$songId', songId: songId),
                 )
                 .toList(),
       );

  final String id;
  final String title;
  final DateTime date;
  final List<ServicePlanItem> items;

  /// Kept as a convenient compatibility view of the song entries.
  List<String> get songIds =>
      items.map((item) => item.songId).whereType<String>().toList();

  ServicePlan copyWith({
    String? id,
    String? title,
    DateTime? date,
    List<ServicePlanItem>? items,
    List<String>? songIds,
  }) {
    return ServicePlan(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      items:
          items ??
          (songIds == null
              ? this.items
              : songIds
                    .map(
                      (songId) => ServicePlanItem.song(
                        id: 'song-$songId',
                        songId: songId,
                      ),
                    )
                    .toList()),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'date': date.toIso8601String(),
    'items': items.map((item) => item.toJson()).toList(),
    // Retain a song-only view for plans written by earlier app versions.
    'songIds': songIds,
  };

  factory ServicePlan.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final title = json['title'];
    final rawDate = json['date'];
    final rawItems = json['items'];
    final rawSongIds = json['songIds'];
    final date = rawDate is String ? DateTime.tryParse(rawDate) : null;
    if (id is! String || title is! String || date == null) {
      throw const FormatException('Invalid saved service plan');
    }
    if (rawItems is List<Object?>) {
      return ServicePlan(
        id: id,
        title: title,
        date: date,
        items: rawItems
            .map((value) {
              if (value is! Map<String, Object?>) {
                throw const FormatException('Invalid service plan item');
              }
              return ServicePlanItem.fromJson(value);
            })
            .toList(growable: false),
      );
    }
    if (rawSongIds is! List<Object?> ||
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
