import 'package:flutter_test/flutter_test.dart';
import 'package:worship_focus_studio/controllers/library_controller.dart';

void main() {
  test('editing and transposition update the selected song', () {
    final controller = LibraryController();

    controller.updateChordPro('[C]Grace');
    expect(controller.selectedSong!.chordPro, '[C]Grace');

    controller.transpose(2);
    expect(controller.selectedSong!.chordPro, '[D]Grace');
  });
}
