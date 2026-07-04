import 'song.dart';

class ServicePlan {
  final String id;
  final String title;
  final DateTime date;
  final List<ServiceItem> items;

  ServicePlan({
    required this.id,
    required this.title,
    required this.date,
    required this.items,
  });
}

class ServiceItem {
  final Song song;
  final String? notes;

  ServiceItem({
    required this.song,
    this.notes,
  });
}
