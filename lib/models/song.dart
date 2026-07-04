class Song {
  final String id;
  final String title;
  final String content;

  Song({
    required this.id,
    required this.title,
    required this.content,
  });

  Song copyWith({
    String? id,
    String? title,
    String? content,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
    );
  }
}
