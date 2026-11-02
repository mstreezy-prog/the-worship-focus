import 'package:flutter/material.dart';

import '../controllers/cloud_sync_controller.dart';

class CloudSyncDialog extends StatefulWidget {
  const CloudSyncDialog({required this.controller, super.key});
  final CloudSyncController controller;
  @override
  State<CloudSyncDialog> createState() => _CloudSyncDialogState();
}

class _CloudSyncDialogState extends State<CloudSyncDialog> {
  final _email = TextEditingController(),
      _password = TextEditingController(),
      _churchName = TextEditingController();
  String? _churchId, _error;
  bool _busy = false, _includeLocal = true;
  Future<void> _run(Future<void> Function() task) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await task();
    } on Object {
      if (mounted) {
        setState(
          () => _error =
              'Could not complete this step. Check your connection and account details, then try again.',
        );
      }
    } finally {
      _password.clear();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _churchName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final cloud = widget.controller;
      return AlertDialog(
        title: const Text('Cloud sync'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  cloud.status,
                  key: const ValueKey('cloud-sync-status'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                if (!cloud.available)
                  const Text(
                    'Cloud sync is not connected in this build yet. Your songs and service plans continue to save on this device.',
                  ),
                if (cloud.available && !cloud.signedIn) ...[
                  const Text(
                    'Use the same Worship Focus account on the website and iPad.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.username],
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(labelText: 'Password'),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _run(
                            () => cloud.signIn(_email.text, _password.text),
                          ),
                    child: const Text('Sign in to sync'),
                  ),
                ],
                if (cloud.signedIn) ...[
                  Text(cloud.email ?? 'Signed in'),
                  const SizedBox(height: 16),
                  if (!cloud.connected) ...[
                    if (cloud.churches.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        initialValue: _churchId,
                        decoration: const InputDecoration(
                          labelText: 'Church workspace',
                        ),
                        items: [
                          for (final church in cloud.churches)
                            DropdownMenuItem(
                              value: church['id'] as String,
                              child: Text(church['name'] as String),
                            ),
                        ],
                        onChanged: _busy
                            ? null
                            : (value) => setState(() => _churchId = value),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _includeLocal,
                        onChanged: _busy
                            ? null
                            : (value) => setState(
                                () => _includeLocal = value ?? false,
                              ),
                        title: const Text(
                          'Include plans from this iPad when connecting this church for the first time.',
                        ),
                      ),
                      FilledButton(
                        onPressed: _busy || _churchId == null
                            ? null
                            : () => _run(
                                () => cloud.connect(
                                  _churchId!,
                                  includeDevicePlans: _includeLocal,
                                ),
                              ),
                        child: const Text('Connect this iPad'),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      controller: _churchName,
                      maxLength: 150,
                      decoration: const InputDecoration(
                        labelText: 'New church workspace',
                      ),
                    ),
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                              final id = await cloud.createChurch(
                                _churchName.text,
                              );
                              if (mounted) setState(() => _churchId = id);
                            }),
                      child: const Text('Create workspace'),
                    ),
                  ] else ...[
                    const Text(
                      'Service plans, song order, planning keys, and notes sync with your website. Downloaded plans stay available offline. Charts and pencil marks remain on this iPad.',
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _run(cloud.syncNow),
                      icon: const Icon(Icons.sync),
                      label: const Text('Sync now'),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _busy ? null : () => _run(cloud.signOut),
                    child: const Text('Sign out of cloud sync'),
                  ),
                ],
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: LinearProgressIndicator(),
                  ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      );
    },
  );
}
