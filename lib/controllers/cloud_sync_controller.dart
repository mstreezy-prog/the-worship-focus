import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/service_plan.dart';
import '../models/song.dart';
import '../services/cloud_plan_codec.dart';
import '../services/service_plan_sync.dart';
import 'library_controller.dart';

class CloudConnection {
  // Public development-project settings; never put administrative keys here.
  // Build-time values can override these for a separate environment.
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://pmmxucapanhsnuyoqxde.supabase.co',
  );
  static const key = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_HkoGNQcl-LQQ5Xb37GoPzQ_pWCuR16O',
  );
  static SupabaseClient? client;
  static Future<void> initialize() async {
    if (url.isEmpty ||
        key.isEmpty ||
        !url.startsWith('https://') ||
        key.startsWith('sb_secret_'))
      return;
    if (key.split('.').length == 3) {
      try {
        final claims = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(key.split('.')[1]))),
        ) as Map;
        if (claims['role'] != 'anon') return;
      } on Object {
        return;
      }
    }
    try {
      await Supabase.initialize(url: url, publishableKey: key);
      client = Supabase.instance.client;
    } on Object {
      /* Device-only planning remains available. */
    }
  }
}

class CloudSyncController extends ChangeNotifier implements CloudPlanLocal {
  CloudSyncController(this.library, {SupabaseClient? client})
    : _client = client ?? CloudConnection.client;
  final LibraryController library;
  final SupabaseClient? _client;
  Session? _session;
  String? _churchId;
  String get status => _status;
  String _status = 'Device only';
  String? get email => _session?.user.email;
  bool get available => _client != null;
  bool get signedIn => _session != null;
  bool get connected => _sync != null;
  List<Map<String, dynamic>> churches = [];
  Map<String, Map<String, Object?>> _baselines = {};
  Map<String, String> _songIds = {};
  ServicePlanSync? _sync;
  File? _stateFile;
  StreamSubscription<AuthState>? _auth;
  Timer? _timer, _poll;
  bool _applying = false, _disposed = false;
  Future<void> _writes = Future.value();

  void _setStatus(String value) {
    _status = value;
    if (!_disposed) notifyListeners();
  }

  Future<File> _file(String name) async =>
      File('${(await getApplicationDocumentsDirectory()).path}/$name');
  Future<void> _writeFile(File file, Object data) async {
    final encoded = jsonEncode(data);
    _writes = _writes.catchError((Object _) {}).then((_) async {
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(encoded, flush: true);
      await temp.rename(file.path);
    });
    await _writes;
  }

  Future<void> _saveState() async {
    final file = _stateFile;
    if (file != null)
      await _writeFile(file, {'baselines': _baselines, 'songIds': _songIds});
  }

  Future<void> initialize() async {
    library.addListener(_queue);
    if (_client == null) return;
    _auth = _client.auth.onAuthStateChange.listen(
      (event) {
        unawaited(_sessionChanged(event.session));
      },
      onError: (_) {
        _setStatus('Saved on device · sign-in needs attention');
      },
    );
    await _sessionChanged(_client.auth.currentSession);
  }

  Future<void> _sessionChanged(Session? session) async {
    if (_disposed || _session?.user.id == session?.user.id) return;
    await _sync?.stop();
    _sync = null;
    _timer?.cancel();
    _poll?.cancel();
    _churchId = null;
    _applying = true;
    library.setCloudScope(null);
    _applying = false;
    _session = session;
    if (session == null) {
      churches = [];
      _setStatus('Device only');
      return;
    }
    try {
      final file = await _file('worship_focus_last_cloud.json');
      Map? saved;
      if (await file.exists()) {
        saved = jsonDecode(await file.readAsString()) as Map;
      }
      try {
        await loadChurches();
      } on Object {
        final cachedId = saved?['churchId'];
        if (saved?['userId'] == session.user.id &&
            cachedId is String &&
            RegExp(r'^[a-f0-9-]{36}$').hasMatch(cachedId)) {
          final cache = await _file(
            'worship_focus_cloud_${session.user.id}_$cachedId.json',
          );
          if (await cache.exists()) {
            churches = [
              {'id': cachedId, 'name': 'Downloaded church workspace'},
            ];
            await connect(cachedId);
            return;
          }
        }
        rethrow;
      }
      if (saved != null) {
        if (saved['userId'] == session.user.id &&
            churches.any((church) => church['id'] == saved['churchId']))
          await connect(saved['churchId'] as String);
      }
    } on Object {
      _setStatus('Cloud sync waiting for a connection');
    }
    if (_sync == null) _setStatus('Choose a church workspace');
  }

  Future<void> signIn(String email, String password) async {
    final response = await _client!.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    await _sessionChanged(response.session);
  }

  Future<void> signOut() async {
    await _client!.auth.signOut();
    await _sessionChanged(null);
  }

  Future<void> loadChurches() async {
    final data = await _client!
        .from('twf_churches')
        .select('id,name')
        .order('name');
    churches = data.map((row) => Map<String, dynamic>.from(row)).toList();
    if (!_disposed) notifyListeners();
  }

  Future<String> createChurch(String name) async {
    final id = await _client!.rpc(
      'twf_create_church',
      params: {'p_name': name.trim()},
    ) as String;
    await loadChurches();
    return id;
  }

  Future<void> connect(
    String churchId, {
    bool includeDevicePlans = false,
  }) async {
    if (_session == null || !churches.any((church) => church['id'] == churchId))
      throw StateError('Select your church');
    await _sync?.stop();
    _timer?.cancel();
    _poll?.cancel();
    _churchId = churchId;
    _stateFile = await _file(
      'worship_focus_cloud_${_session!.user.id}_$churchId.json',
    );
    _baselines = {};
    _songIds = {};
    final firstConnect = !await _stateFile!.exists();
    if (!firstConnect) {
      final stored = jsonDecode(await _stateFile!.readAsString()) as Map;
      _baselines = {
        for (final entry in (stored['baselines'] as Map).entries)
          entry.key as String: Map<String, Object?>.from(entry.value as Map),
      };
      _songIds = Map<String, String>.from(stored['songIds'] as Map);
    }
    _applying = true;
    try {
      if (includeDevicePlans && firstConnect) {
        final copies = [
          for (final plan in library.allDeviceServicePlans.where(
            (plan) => plan.cloudChurchId == null,
          ))
            plan.copyWith(id: newSyncId(), cloudChurchId: churchId),
        ];
        await library.applyCloudPlans(copies, const [], const [], churchId);
      }
      library.setCloudScope(churchId);
    } finally {
      _applying = false;
    }
    await _writeFile(await _file('worship_focus_last_cloud.json'), {
      'userId': _session!.user.id,
      'churchId': churchId,
    });
    _sync = ServicePlanSync(
      remote: _SupabasePlanRemote(_client!, churchId),
      local: this,
      metadata: _CloudMetadata(this),
      onStatus: (state, conflicts) {
        _setStatus(switch (state) {
          'syncing' => 'Syncing…',
          'synced' =>
            conflicts > 0
                ? 'Synced · both edits kept as separate plans'
                : 'Saved on device & in cloud',
          _ => 'Saved on device · sync pending',
        });
      },
    );
    _poll = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(syncNow()),
    );
    await syncNow();
  }

  void _queue() {
    if (_applying || _sync == null || _disposed) return;
    _timer?.cancel();
    _timer = Timer(
      const Duration(milliseconds: 1200),
      () => unawaited(syncNow()),
    );
  }

  Future<void> syncNow() async {
    if (_sync == null || _disposed) return;
    try {
      await library.flushPendingSave();
      if (library.saveState == LibrarySaveState.error)
        throw StateError('Device save failed');
      read();
      await _saveState();
      await _sync!.sync();
    } on Object {
      _setStatus('Saved on device · sync pending');
    }
  }

  @override
  List<SyncDocument> read() => [
    for (final plan in library.allDeviceServicePlans.where(
      (plan) => plan.cloudChurchId == _churchId,
    ))
      CloudPlanCodec.encode(plan, library.songs, _songIds),
  ];
  @override
  Future<void> apply(List<SyncDocument> upserts, List<String> deletes) async {
    final churchId = _churchId;
    if (churchId == null) return;
    final existing = library.allDeviceServicePlans
        .where((plan) => plan.cloudChurchId == churchId)
        .toList();
    final links = {
      for (final plan in existing)
        for (final item in plan.items)
          if (item.cloudSongId != null && item.songId != null)
            item.cloudSongId!: item.songId!,
    };
    final plans = <ServicePlan>[], songs = <Song>[];
    for (final document in upserts) {
      final previous = existing
          .where((plan) => (plan.cloudPlanId ?? plan.id) == document['id'])
          .firstOrNull;
      final (plan, added) = CloudPlanCodec.decode(
        document,
        churchId,
        [...library.songs, ...songs],
        localPlanId: previous?.id,
        linkedSongs: links,
      );
      plans.add(plan);
      songs.addAll(added);
    }
    _applying = true;
    try {
      await library.applyCloudPlans(plans, songs, deletes, churchId);
    } finally {
      _applying = false;
    }
  }

  // Metadata is implemented through a view to keep its read method distinct
  // from the local document reader above.
  Future<void> saveBaselines(Map<String, Map<String, Object?>> value) async {
    _baselines = value;
    await _saveState();
  }

  @override
  void dispose() {
    _disposed = true;
    library.removeListener(_queue);
    _sync?.stop();
    _auth?.cancel();
    _timer?.cancel();
    _poll?.cancel();
    super.dispose();
  }
}

class _CloudMetadata implements CloudSyncMetadata {
  _CloudMetadata(this.owner);
  final CloudSyncController owner;
  @override
  Map<String, Map<String, Object?>> read() => {
    for (final entry in owner._baselines.entries)
      entry.key: Map<String, Object?>.from(entry.value),
  };
  @override
  Future<void> write(Map<String, Map<String, Object?>> value) =>
      owner.saveBaselines(value);
}

class _SupabasePlanRemote implements CloudPlanRemote {
  _SupabasePlanRemote(this.client, this.churchId);
  final SupabaseClient client;
  final String churchId;
  @override
  Future<List<CloudPlanRow>> list() async {
    final rows = <CloudPlanRow>[];
    var start = 0;
    for (;;) {
      final data = await client
          .from('twf_service_plans')
          .select('id,revision,document,deleted')
          .eq('church_id', churchId)
          .order('id')
          .range(start, start + 499);
      rows.addAll(data.map(CloudPlanRow.fromJson));
      if (data.length < 500) return rows;
      start += 500;
    }
  }

  @override
  Future<CloudPlanRow> save(
    String id,
    int revision,
    SyncDocument? document,
    bool deleted,
  ) async {
    try {
      final data = await client.rpc(
        'twf_save_service_plan',
        params: {
          'p_church_id': churchId,
          'p_id': id,
          'p_expected_revision': revision,
          'p_document': document,
          'p_deleted': deleted,
        },
      );
      return CloudPlanRow.fromJson(Map<String, dynamic>.from(data as Map));
    } on PostgrestException catch (error) {
      if (error.code == '40001') throw const CloudSyncConflict();
      rethrow;
    }
  }
}
