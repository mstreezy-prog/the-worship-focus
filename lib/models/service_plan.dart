enum ServicePlanItemType { song, section }

/// One ordered entry in a saved worship set.
class ServicePlanItem {
  const ServicePlanItem.song({
    required this.id,
    required this.songId,
    this.notes = '',
    this.title = '',
    this.planningKey,
    this.cloudSongId,
    this.cloudData = const {},
  }) : type = ServicePlanItemType.song;

  const ServicePlanItem.section({
    required this.id,
    required this.title,
    this.notes = '',
  }) : type = ServicePlanItemType.section,
       songId = null,
       planningKey = null,
       cloudSongId = null,
       cloudData = const {};

  final String id;
  final ServicePlanItemType type;
  final String? songId;
  final String title;
  final String notes;
  final String? planningKey;
  final String? cloudSongId;
  final Map<String, Object?> cloudData;

  bool get isSong => type == ServicePlanItemType.song;
  bool get isSection => type == ServicePlanItemType.section;

  ServicePlanItem copyWith({
    String? title,
    String? notes,
    String? songId,
    String? planningKey,
    bool clearPlanningKey = false,
    String? cloudSongId,
    Map<String, Object?>? cloudData,
  }) {
    return switch (type) {
      ServicePlanItemType.song => ServicePlanItem.song(
        id: id,
        songId: songId ?? this.songId!,
        notes: notes ?? this.notes,
        title: title ?? this.title,
        planningKey: clearPlanningKey ? null : planningKey ?? this.planningKey,
        cloudSongId: cloudSongId ?? this.cloudSongId,
        cloudData: cloudData ?? this.cloudData,
      ),
      ServicePlanItemType.section => ServicePlanItem.section(
        id: id,
        title: title ?? this.title,
        notes: notes ?? this.notes,
      ),
    };
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type.name,
    if (songId != null) 'songId': songId,
    if (title.isNotEmpty) 'title': title,
    if (notes.isNotEmpty) 'notes': notes,
    if (planningKey != null) 'planningKey': planningKey,
    if (cloudSongId != null) 'cloudSongId': cloudSongId,
    if (cloudData.isNotEmpty) 'cloudData': cloudData,
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
      title: json['title'] as String? ?? '',
      planningKey: json['planningKey'] as String?,
      cloudSongId: json['cloudSongId'] as String?,
      cloudData: json['cloudData'] is Map
          ? Map<String, Object?>.from(json['cloudData'] as Map)
          : const {},
    );
  }

  static ServicePlanItem _sectionFromJson(
    String id,
    Map<String, Object?> json,
  ) {
    final title = json['title'];
    final notes = json['notes'];
    if (title is! String ||
        title.trim().isEmpty ||
        (notes != null && notes is! String)) {
      throw const FormatException('Invalid service plan section');
    }
    return ServicePlanItem.section(
      id: id,
      title: title,
      notes: notes is String ? notes : '',
    );
  }
}

/// A saved worship set. Song entries reference ids so song edits are reflected
/// everywhere the song is used. Section text and song notes belong to the plan
/// itself.
class ServicePlan {
  ServicePlan({
    required this.id,
    required this.title,
    required this.date,
    this.notes = '',
    this.cloudChurchId,
    this.cloudPlanId,
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
  final String notes;
  final String? cloudChurchId;
  final String? cloudPlanId;

  /// Kept as a convenient compatibility view of the song entries.
  List<String> get songIds =>
      items.map((item) => item.songId).whereType<String>().toList();

  ServicePlan copyWith({
    String? id,
    String? title,
    DateTime? date,
    List<ServicePlanItem>? items,
    List<String>? songIds,
    String? notes,
    String? cloudChurchId,
    String? cloudPlanId,
  }) {
    return ServicePlan(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      cloudChurchId: cloudChurchId ?? this.cloudChurchId,
      cloudPlanId: cloudPlanId ?? this.cloudPlanId,
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
    if (notes.isNotEmpty) 'notes': notes,
    if (cloudChurchId != null) 'cloudChurchId': cloudChurchId,
    if (cloudPlanId != null) 'cloudPlanId': cloudPlanId,
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
        notes: json['notes'] as String? ?? '',
        cloudChurchId: json['cloudChurchId'] as String?,
        cloudPlanId: json['cloudPlanId'] as String?,
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
      notes: json['notes'] as String? ?? '',
      cloudChurchId: json['cloudChurchId'] as String?,
      cloudPlanId: json['cloudPlanId'] as String?,
      songIds: rawSongIds.cast<String>(),
    );
  }
}
