import 'package:flutter/material.dart';

import '../models/service_plan.dart';
import '../models/song.dart';

Future<T?> _showServicePlanDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<T>(context: context, builder: builder);
  final result = await navigator.push(route);
  await route.completed;
  return result;
}

Future<T?> _showServicePlanSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) async {
  final navigator = Navigator.of(context);
  final localizations = MaterialLocalizations.of(context);
  final route = ModalBottomSheetRoute<T>(
    builder: builder,
    capturedThemes: InheritedTheme.capture(
      from: context,
      to: navigator.context,
    ),
    isScrollControlled: false,
    barrierLabel: localizations.scrimLabel,
    barrierOnTapHint: localizations.scrimOnTapHint(
      localizations.bottomSheetLabel,
    ),
    modalBarrierColor: Theme.of(context).bottomSheetTheme.modalBarrierColor,
    showDragHandle: true,
  );
  final result = await navigator.push(route);
  await route.completed;
  return result;
}

class ServicePlanWorkspace extends StatelessWidget {
  const ServicePlanWorkspace({
    required this.plans,
    required this.selectedPlan,
    required this.items,
    required this.librarySongs,
    required this.onPlanSelected,
    required this.onCreatePlan,
    required this.onRenamePlan,
    required this.onChangePlanDate,
    required this.onDeletePlan,
    required this.onAddSong,
    required this.onAddSection,
    required this.onUpdateItemNotes,
    required this.onRemoveItem,
    required this.onReorderItems,
    required this.onPerform,
    required this.onExport,
    super.key,
  });

  final List<ServicePlan> plans;
  final ServicePlan? selectedPlan;
  final List<ServicePlanItem> items;
  final List<Song> librarySongs;
  final ValueChanged<ServicePlan> onPlanSelected;
  final VoidCallback onCreatePlan;
  final ValueChanged<String> onRenamePlan;
  final ValueChanged<DateTime> onChangePlanDate;
  final ValueChanged<ServicePlan> onDeletePlan;
  final ValueChanged<Song> onAddSong;
  final ValueChanged<String> onAddSection;
  final void Function(ServicePlanItem item, String notes) onUpdateItemNotes;
  final ValueChanged<ServicePlanItem> onRemoveItem;
  final ReorderCallback onReorderItems;
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
                hasSongs: items.isNotEmpty,
                onPlanSelected: onPlanSelected,
                onRenamePlan: onRenamePlan,
                onChangePlanDate: onChangePlanDate,
                onDeletePlan: () => onDeletePlan(plan),
                onAddSong: () => _showSongPicker(context, plan),
                onAddSection: () => _showSectionDialog(context),
                onPerform: onPerform,
                onExport: onExport,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: items.isEmpty
                    ? _EmptyPlan(
                        message:
                            'Add songs and section headers to build this service order.',
                        actionLabel: 'Add song',
                        onCreatePlan: () => _showSongPicker(context, plan),
                      )
                    : ReorderableListView.builder(
                        key: const ValueKey('service-plan-song-list'),
                        buildDefaultDragHandles: false,
                        itemCount: items.length,
                        onReorderItem: onReorderItems,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final song = item.songId == null
                              ? null
                              : librarySongs
                                    .where((song) => song.id == item.songId)
                                    .firstOrNull;
                          return _PlanItemCard(
                            key: ValueKey('service-plan-item-${item.id}'),
                            item: item,
                            song: song,
                            index: index,
                            onRemove: () => onRemoveItem(item),
                            onEditNotes: (notes) =>
                                onUpdateItemNotes(item, notes),
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
    final selected = await _showServicePlanSheet<Song>(
      context,
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
    if (selected != null && context.mounted) onAddSong(selected);
  }

  Future<void> _showSectionDialog(BuildContext context) async {
    final controller = TextEditingController();
    final title = await _showServicePlanDialog<String>(
      context,
      builder: (context) => AlertDialog(
        title: const Text('Add section header'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'For example: Welcome or Message',
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (title != null && context.mounted) onAddSection(title);
  }

  static String _songTitle(Song song) =>
      song.title.trim().isEmpty ? 'Untitled Song' : song.title;
}

class _PlanItemCard extends StatelessWidget {
  const _PlanItemCard({
    required this.item,
    required this.song,
    required this.index,
    required this.onRemove,
    required this.onEditNotes,
    super.key,
  });

  final ServicePlanItem item;
  final Song? song;
  final int index;
  final VoidCallback onRemove;
  final ValueChanged<String> onEditNotes;

  @override
  Widget build(BuildContext context) {
    final isSection = item.isSection;
    final title = isSection
        ? item.title
        : song == null
        ? 'Song no longer in library'
        : ServicePlanWorkspace._songTitle(song!);
    final details = isSection
        ? item.notes.trim().isEmpty
              ? 'Section header'
              : item.notes.trim()
        : [
            if (song?.artist?.trim().isNotEmpty == true) song!.artist!,
            if (item.notes.trim().isNotEmpty) item.notes.trim(),
            if (song == null) 'Remove this entry or add the song again.',
          ].join('\n');
    return Card(
      color: isSection
          ? Theme.of(context).colorScheme.secondaryContainer
          : null,
      child: ListTile(
        minTileHeight: isSection ? 56 : 72,
        leading: ReorderableDragStartListener(
          index: index,
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.drag_handle),
          ),
        ),
        title: Text(
          title,
          style: isSection
              ? Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontFamily: 'CMG Sans',
                  fontWeight: FontWeight.w700,
                )
              : null,
        ),
        subtitle: details.isEmpty
            ? Text('Song ${index + 1}')
            : Text(
                details,
                maxLines: isSection ? null : 2,
                overflow: isSection ? null : TextOverflow.ellipsis,
                style: isSection
                    ? const TextStyle(
                        fontFamily: 'CMG Sans',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      )
                    : null,
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: isSection ? 'Edit section text' : 'Edit song note',
              onPressed: () => _editNotes(context),
              icon: Icon(
                item.notes.trim().isEmpty
                    ? Icons.sticky_note_2_outlined
                    : Icons.sticky_note_2,
              ),
            ),
            IconButton(
              tooltip: isSection ? 'Remove section' : 'Remove from plan',
              onPressed: onRemove,
              icon: const Icon(Icons.remove_circle_outline),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editNotes(BuildContext context) async {
    final controller = TextEditingController(text: item.notes);
    final notes = await _showServicePlanDialog<String>(
      context,
      builder: (context) => AlertDialog(
        title: Text(
          item.isSection
              ? 'Text for ${item.title}'
              : 'Notes for ${song == null ? 'song' : ServicePlanWorkspace._songTitle(song!)}',
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          style: const TextStyle(
            fontFamily: 'CMG Sans',
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: item.isSection
                ? 'Add a welcome, prayer, reading, or other service text.'
                : 'For example: Start in G; repeat chorus twice.',
            border: OutlineInputBorder(),
          ),
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
    if (notes != null && context.mounted) onEditNotes(notes.trim());
  }
}

class _PlanToolbar extends StatelessWidget {
  const _PlanToolbar({
    required this.plans,
    required this.selectedPlan,
    required this.hasSongs,
    required this.onPlanSelected,
    required this.onRenamePlan,
    required this.onChangePlanDate,
    required this.onDeletePlan,
    required this.onAddSong,
    required this.onAddSection,
    required this.onPerform,
    required this.onExport,
  });

  final List<ServicePlan> plans;
  final ServicePlan selectedPlan;
  final bool hasSongs;
  final ValueChanged<ServicePlan> onPlanSelected;
  final ValueChanged<String> onRenamePlan;
  final ValueChanged<DateTime> onChangePlanDate;
  final VoidCallback onDeletePlan;
  final VoidCallback onAddSong;
  final VoidCallback onAddSection;
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
          onPressed: () => _selectDate(context),
          icon: const Icon(Icons.calendar_today_outlined),
          label: Text(
            MaterialLocalizations.of(
              context,
            ).formatMediumDate(selectedPlan.date),
          ),
        ),
        OutlinedButton.icon(
          onPressed: onAddSong,
          icon: const Icon(Icons.playlist_add),
          label: const Text('Add song'),
        ),
        OutlinedButton.icon(
          onPressed: onAddSection,
          icon: const Icon(Icons.title),
          label: const Text('Add section'),
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
    final title = await _showServicePlanDialog<String>(
      context,
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
    if (title != null && context.mounted) onRenamePlan(title);
  }

  Future<void> _selectDate(BuildContext context) async {
    final date = await _showServicePlanDialog<DateTime>(
      context,
      builder: (context) => DatePickerDialog(
        initialDate: selectedPlan.date,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        helpText: 'Service date',
      ),
    );
    if (date != null && context.mounted) onChangePlanDate(date);
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final shouldDelete = await _showServicePlanDialog<bool>(
      context,
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
    if (shouldDelete == true && context.mounted) onDeletePlan();
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
