import 'service_plan.dart';
import 'song.dart';

enum LibraryRestoreMode { replace, merge }

class LibraryBackup {
  const LibraryBackup({
    required this.createdAt,
    required this.songs,
    required this.servicePlans,
  });

  static const format = 'the-worship-focus-library';
  static const formatVersion = 1;

  final DateTime createdAt;
  final List<Song> songs;
  final List<ServicePlan> servicePlans;

  Map<String, Object> toJson() => {
    'format': format,
    'version': formatVersion,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'songs': [for (final song in songs) song.toJson()],
    'servicePlans': [for (final plan in servicePlans) plan.toJson()],
  };

  factory LibraryBackup.fromJson(Map<String, Object?> json) {
    final createdAt = json['createdAt'];
    final songs = json['songs'];
    final servicePlans = json['servicePlans'];
    if (json['format'] != format || json['version'] != formatVersion) {
      throw const FormatException(
        'This is not a compatible Worship Focus backup',
      );
    }
    final parsedDate = createdAt is String
        ? DateTime.tryParse(createdAt)
        : null;
    if (parsedDate == null || songs is! List || servicePlans is! List) {
      throw const FormatException('Library backup is incomplete');
    }
    final parsedSongs = [
      for (final song in songs)
        if (song is Map<String, Object?>)
          Song.fromJson(song)
        else
          throw const FormatException(
            'Library backup contains an invalid song',
          ),
    ];
    final parsedPlans = [
      for (final plan in servicePlans)
        if (plan is Map<String, Object?>)
          ServicePlan.fromJson(plan)
        else
          throw const FormatException(
            'Library backup contains an invalid service plan',
          ),
    ];
    _validate(parsedSongs, parsedPlans);
    return LibraryBackup(
      createdAt: parsedDate,
      songs: List.unmodifiable(parsedSongs),
      servicePlans: List.unmodifiable(parsedPlans),
    );
  }

  static void _validate(List<Song> songs, List<ServicePlan> plans) {
    final songIds = songs.map((song) => song.id).toSet();
    final planIds = plans.map((plan) => plan.id).toSet();
    if (songIds.length != songs.length || planIds.length != plans.length) {
      throw const FormatException('Library backup contains duplicate entries');
    }
    final missingSongReference = plans
        .expand((plan) => plan.songIds)
        .any((songId) => !songIds.contains(songId));
    if (missingSongReference) {
      throw const FormatException(
        'Library backup has a missing service-plan song',
      );
    }
  }
}

class LibraryRestoreResult {
  const LibraryRestoreResult({
    required this.mode,
    required this.songCount,
    required this.servicePlanCount,
  });

  final LibraryRestoreMode mode;
  final int songCount;
  final int servicePlanCount;
}
