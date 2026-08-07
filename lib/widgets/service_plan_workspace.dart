import 'package:flutter/material.dart';

import '../models/service_plan.dart';
import '../models/song.dart';

class ServicePlanWorkspace extends StatelessWidget {
  const ServicePlanWorkspace({
    required this.plans,
    required this.selectedPlan,
    required this.planSongs,
    required this.librarySongs,
    required this.onPlanSelected,
    required this.onCreatePlan,
    required this.onRenamePlan,
    required this.onDeletePlan,
    required this.onAddSong,
    required this.onRemoveSong,
    required this.onReorderSongs,
    required this.onPerform,
    required this.onExport,
    super.key,
  });

  final List<ServicePlan> plans;
  final ServicePlan? selectedPlan;
  final List<Song> planSongs;
  final List<Song> librarySongs;
  final ValueChanged<ServicePlan> onPlanSelected;
  final VoidCallback onCreatePlan;
  final ValueChanged<String> onRenamePlan;
  final ValueChanged<ServicePlan> onDeletePlan;
  final ValueChanged<Song> onAddSong;
  final ValueChanged<Song> onRemoveSong;
  final ReorderCallback onReorderSongs;
  final VoidCallback onPerform;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final plan = selectedPlan;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                Text(
                  'Service plans',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                FilledButton.icon(
                  key: const ValueKey('new-service-plan'),
                  onPressed: onCreatePlan,
                  icon: const Icon(Icons.add),
                  label: const Text('New plan'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (plan == null)
              Expanded(child: _EmptyPlan(onCreatePlan: onCreatePlan))
            else ...[
              _PlanToolbar(
                plans: plans,
                selectedPlan: plan,
                hasSongs: planSongs.isNotEmpty,
                onPlanSelected: onPlanSelected,
                onRenamePlan: onRenamePlan,
                onDeletePlan: () => onDeletePlan(plan),
                onAddSong: () => _showSongPicker(context, plan),
                onPerform: onPerform,
                onExport: onExport,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: planSongs.isEmpty
                    ? _EmptyPlan(
                        message:
                            'Add songs from your library to build this service order.',
                        actionLabel: 'Add song',
                        onCreatePlan: () => _showSongPicker(context, plan),
                      )
                    : ReorderableListView.builder(
                        key: const ValueKey('service-plan-song-list'),
                        buildDefaultDragHandles: false,
                        itemCount: planSongs.length,
                        onReorderItem: onReorderSongs,
                        itemBuilder: (context, index) {
                          final song = planSongs[index];
                          return Card(
                            key: ValueKey('service-plan-song-${song.id}'),
                            child: ListTile(
                              minTileHeight: 64,
                              leading: ReorderableDragStartListener(
                                index: index,
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(Icons.drag_handle),
                                ),
                              ),
                              title: Text(_songTitle(song)),
                              subtitle: song.artist == null
                                  ? Text('Song ${index + 1}')
                                  : Text('${song.artist} • Song ${index + 1}'),
                              trailing: IconButton(
                                tooltip: 'Remove from plan',
                                onPressed: () => onRemoveSong(song),
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showSongPicker(BuildContext context, ServicePlan plan) async {
    final existingIds = plan.songIds.toSet();
    final availableSongs = librarySongs
        .where((song) => !existingIds.contains(song.id))
        .toList(growable: false);
    final selected = await showModalBottomSheet<Song>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: 440,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                child: Text(
                  'Add song to ${plan.title}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: availableSongs.isEmpty
                    ? const Center(
                        child: Text(
                          'Every library song is already in this plan.',
                        ),
                      )
                    : ListView.builder(
                        itemCount: availableSongs.length,
                        itemBuilder: (context, index) {
                          final song = availableSongs[index];
                          return ListTile(
                            minTileHeight: 60,
                            leading: const Icon(Icons.add_circle_outline),
                            title: Text(_songTitle(song)),
                            subtitle: song.artist == null
                                ? null
                                : Text(song.artist!),
                            onTap: () => Navigator.pop(context, song),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) onAddSong(selected);
  }

  static String _songTitle(Song song) =>
      song.title.trim().isEmpty ? 'Untitled Song' : song.title;
}

class _PlanToolbar extends StatelessWidget {
  const _PlanToolbar({
    required this.plans,
    required this.selectedPlan,
    required this.hasSongs,
    required this.onPlanSelected,
    required this.onRenamePlan,
    required this.onDeletePlan,
    required this.onAddSong,
    required this.onPerform,
    required this.onExport,
  });

  final List<ServicePlan> plans;
  final ServicePlan selectedPlan;
  final bool hasSongs;
  final ValueChanged<ServicePlan> onPlanSelected;
  final ValueChanged<String> onRenamePlan;
  final VoidCallback onDeletePlan;
  final VoidCallback onAddSong;
  final VoidCallback onPerform;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 280,
          child: Semantics(
            label: 'Current service plan',
            child: DecoratedBox(
              decoration: ShapeDecoration(
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    key: const ValueKey('service-plan-picker'),
                    value: selectedPlan.id,
                    isExpanded: true,
                    items: [
                      for (final plan in plans)
                        DropdownMenuItem(
                          value: plan.id,
                          child: Text(
                            plan.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (id) {
                      final plan = plans
                          .where((plan) => plan.id == id)
                          .firstOrNull;
                      if (plan == null) return;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        onPlanSelected(plan);
                      });
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => _rename(context),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Rename'),
        ),
        OutlinedButton.icon(
          onPressed: onAddSong,
          icon: const Icon(Icons.playlist_add),
          label: const Text('Add song'),
        ),
        FilledButton.tonalIcon(
          onPressed: hasSongs ? onPerform : null,
          icon: const Icon(Icons.fullscreen),
          label: const Text('Go live'),
        ),
        IconButton(
          tooltip: 'Export plan PDF',
          onPressed: hasSongs ? onExport : null,
          icon: const Icon(Icons.picture_as_pdf_outlined),
        ),
        IconButton(
          tooltip: 'Delete plan',
          onPressed: () => _confirmDelete(context),
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }

  Future<void> _rename(BuildContext context) async {
    final controller = TextEditingController(text: selectedPlan.title);
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename service plan'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Plan name'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (title != null) onRenamePlan(title);
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete service plan?'),
        content: Text(
          '“${selectedPlan.title}” and its song order will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete == true) onDeletePlan();
  }
}

class _EmptyPlan extends StatelessWidget {
  const _EmptyPlan({
    required this.onCreatePlan,
    this.message =
        'Create a plan for an upcoming service, then choose songs and set their order.',
    this.actionLabel = 'Create service plan',
  });

  final VoidCallback onCreatePlan;
  final String message;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_note_outlined, size: 56),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreatePlan,
              icon: const Icon(Icons.add),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
