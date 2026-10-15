import 'dart:io';

import 'package:path_provider/path_provider.dart';

abstract interface class RecentServiceStore {
  Future<String?> read();
  Future<void> write(String id);
}

class FileRecentServiceStore implements RecentServiceStore {
  Future<File> _file() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/recent_service.txt');
  }

  @override
  Future<String?> read() async {
    final file = await _file();
    return await file.exists() ? file.readAsString() : null;
  }

  @override
  Future<void> write(String id) async {
    final file = await _file();
    await file.writeAsString(id, flush: true);
  }
}
