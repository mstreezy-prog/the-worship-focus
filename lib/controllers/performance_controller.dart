import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/performance_preferences.dart';
import '../services/performance_services.dart';

class PerformanceController extends ChangeNotifier {
  PerformanceController({
    PerformancePreferencesStore? store,
    KeepAwakeService? keepAwakeService,
  }) : _store = store ?? JsonPerformancePreferencesStore(),
       _keepAwakeService = keepAwakeService ?? WakelockKeepAwakeService();

  final PerformancePreferencesStore _store;
  final KeepAwakeService _keepAwakeService;
  PerformancePreferences _preferences = const PerformancePreferences();
  bool _autoScrolling = false;
  bool _wakeLockActive = false;
  Future<void> _writeQueue = Future<void>.value();

  PerformancePreferences get preferences => _preferences;
  bool get autoScrolling => _autoScrolling;

  Future<void> initialize() async {
    try {
      _preferences = await _store.read() ?? const PerformancePreferences();
    } on Object {
      _preferences = const PerformancePreferences();
    }
    if (_preferences.keepAwake) {
      try {
        await _keepAwakeService.setEnabled(true);
        _wakeLockActive = true;
      } on Object {
        _preferences = _preferences.copyWith(keepAwake: false);
      }
    }
    notifyListeners();
  }

  void increaseFontSize() {
    _update(_preferences.copyWith(fontSize: _preferences.fontSize + 2));
  }

  void decreaseFontSize() {
    _update(_preferences.copyWith(fontSize: _preferences.fontSize - 2));
  }

  void toggleTheme() {
    _update(
      _preferences.copyWith(
        theme: _preferences.theme == PerformanceTheme.dark
            ? PerformanceTheme.light
            : PerformanceTheme.dark,
      ),
    );
  }

  void setScrollSpeed(double value) {
    _update(_preferences.copyWith(scrollSpeed: value));
  }

  void toggleAutoScroll() {
    _autoScrolling = !_autoScrolling;
    notifyListeners();
  }

  Future<void> toggleKeepAwake() async {
    final enabled = !_preferences.keepAwake;
    try {
      await _keepAwakeService.setEnabled(enabled);
      _wakeLockActive = enabled;
      _update(_preferences.copyWith(keepAwake: enabled));
    } on Object {
      // Keep the previous preference when the platform rejects the request.
    }
  }

  Future<void> deactivate() async {
    if (!_wakeLockActive) return;
    _wakeLockActive = false;
    try {
      await _keepAwakeService.setEnabled(false);
    } on Object {
      // The operating system may already have released the wake lock.
    }
  }

  void _update(PerformancePreferences preferences) {
    _preferences = PerformancePreferences(
      fontSize: preferences.fontSize.clamp(14, 36).toDouble(),
      theme: preferences.theme,
      scrollSpeed: preferences.scrollSpeed.clamp(8, 60).toDouble(),
      keepAwake: preferences.keepAwake,
    );
    notifyListeners();
    _schedulePersistence();
  }

  void _schedulePersistence() {
    final snapshot = _preferences;
    _writeQueue = _writeQueue.then((_) async {
      try {
        await _store.write(snapshot);
      } on Object {
        // Preferences are non-critical and can be retried on the next change.
      }
    });
  }

  @override
  void dispose() {
    if (_wakeLockActive) unawaited(deactivate());
    super.dispose();
  }
}
