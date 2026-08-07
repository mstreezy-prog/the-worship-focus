import 'song.dart';

class ServicePacket {
  ServicePacket({
    required this.title,
    required this.songs,
    this.serviceOrder = const <ServicePacketEntry>[],
  });

  final String title;
  final List<Song> songs;
  final List<ServicePacketEntry> serviceOrder;
}

class ServicePacketEntry {
  const ServicePacketEntry.section(this.title) : isSection = true, notes = '';

  const ServicePacketEntry.song(this.title, {this.notes = ''})
    : isSection = false;

  final String title;
  final String notes;
  final bool isSection;
}
