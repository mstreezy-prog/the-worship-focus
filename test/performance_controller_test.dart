import 'package:flutter_test/flutter_test.dart';
import 'package:worship_focus_studio/controllers/performance_controller.dart';
import 'package:worship_focus_studio/models/performance_preferences.dart';
import 'package:worship_focus_studio/services/performance_services.dart';

class _MemoryPreferencesStore implements PerformancePreferencesStore {
  PerformancePreferences? saved;

  @override
  Future<PerformancePreferences?> read() async => saved;

  @override
  Future<void> write(PerformancePreferences preferences) async {
    saved = PerformancePreferences.fromJson(preferences.toJson());
  }
}

class _FakeKeepAwakeService implements KeepAwakeService {
  final List<bool> calls = [];

  @override
  Future<void> setEnabled(bool enabled) async {
    calls.add(enabled);
  }
}

void main() {
  test('performance preferences round-trip and enforce safe ranges', () {
    final preferences = PerformancePreferences.fromJson({
      'fontSize': 100,
      'theme': 'light',
      'scrollSpeed': 2,
      'keepAwake': true,
    });

    expect(preferences.fontSize, 36);
    expect(preferences.theme, PerformanceTheme.light);
    expect(preferences.scrollSpeed, 8);
    expect(preferences.keepAwake, isTrue);
  });

  test('controller remembers controls and releases the wake lock', () async {
    final store = _MemoryPreferencesStore();
    final wakeLock = _FakeKeepAwakeService();
    final controller = PerformanceController(
      store: store,
      keepAwakeService: wakeLock,
    );
    await controller.initialize();

    controller.increaseFontSize();
    controller.toggleTheme();
    controller.setScrollSpeed(40);
    await controller.toggleKeepAwake();
    await Future<void>.delayed(Duration.zero);

    expect(store.saved!.fontSize, 22);
    expect(store.saved!.theme, PerformanceTheme.light);
    expect(store.saved!.scrollSpeed, 40);
    expect(store.saved!.keepAwake, isTrue);
    expect(wakeLock.calls, [true]);

    await controller.deactivate();
    expect(wakeLock.calls, [true, false]);
    controller.dispose();

    final restored = PerformanceController(
      store: store,
      keepAwakeService: _FakeKeepAwakeService(),
    );
    await restored.initialize();
    expect(restored.preferences.fontSize, 22);
    expect(restored.preferences.theme, PerformanceTheme.light);
    restored.dispose();
  });
}
