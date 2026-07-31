import 'song.dart';

class ServicePacket {
  final String title;
  final List<Song> songs;

  ServicePacket({required this.title, required this.songs});
}
