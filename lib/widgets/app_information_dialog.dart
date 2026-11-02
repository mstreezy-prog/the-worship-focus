import 'package:flutter/material.dart';

import '../services/app_links.dart';

class AppInformationDialog extends StatefulWidget {
  const AppInformationDialog({super.key, this.openLink = AppLinks.open});
  final Future<bool> Function(Uri) openLink;
  @override
  State<AppInformationDialog> createState() => _AppInformationDialogState();
}

class _AppInformationDialogState extends State<AppInformationDialog> {
  String? _error;

  Future<void> _open(Uri uri) async {
    final opened = await widget.openLink(uri);
    if (!mounted) return;
    setState(
      () => _error = opened
          ? null
          : 'Could not open this page. Visit $uri in your browser.',
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('About The Worship Focus'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your charts and pencil marks stay on this device. Service plans also sync to your church workspace when Cloud Sync is connected. Keep a library backup before changing devices.',
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacy policy'),
              onTap: () => _open(AppLinks.privacy),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.help_outline),
              title: const Text('Support'),
              subtitle: const Text('mikes@ssefc.org'),
              onTap: () => _open(AppLinks.support),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.description_outlined),
              title: const Text('Open-source licenses'),
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'The Worship Focus',
              ),
            ),
            if (_error != null)
              SelectableText(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
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
}
