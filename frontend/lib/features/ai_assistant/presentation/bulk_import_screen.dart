import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/presentation/theme/app_colors.dart';
import '../../../shared/widgets/personal_event_bottom_sheet.dart';
import '../services/bulk_personal_event_provider.dart';
import 'subscription_paywall_screen.dart';

/// Full-screen bulk import flow for personal events.
/// Entry: schedule app bar button, chat attachment menu, or single-file redirect.
class BulkImportScreen extends StatelessWidget {
  /// Pre-extracted events to jump straight to preview (from single-file flow).
  final File? preloadedFile;
  final List<Map<String, dynamic>>? preloadedEvents;

  const BulkImportScreen({super.key})
      : preloadedFile = null,
        preloadedEvents = null;

  /// Constructor for when a single-file extraction found multiple events.
  /// Skips file selection + extraction, goes straight to preview.
  const BulkImportScreen.preloaded({
    super.key,
    required this.preloadedFile,
    required this.preloadedEvents,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final provider = BulkPersonalEventProvider();
        if (preloadedFile != null && preloadedEvents != null && preloadedEvents!.isNotEmpty) {
          provider.loadPreExtractedEvents(
            file: preloadedFile!,
            events: preloadedEvents!,
          );
        }
        return provider;
      },
      child: const _BulkImportBody(),
    );
  }
}

class _BulkImportBody extends StatelessWidget {
  const _BulkImportBody();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BulkPersonalEventProvider>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(l10n.bulkImportTitle),
        backgroundColor: AppColors.personalEvent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildPhase(context, provider, l10n),
      ),
    );
  }

  Widget _buildPhase(
    BuildContext context,
    BulkPersonalEventProvider provider,
    AppLocalizations l10n,
  ) {
    switch (provider.phase) {
      case BulkPhase.selectFiles:
        return _SelectFilesPhase(key: const ValueKey('select'));
      case BulkPhase.extracting:
        return _ExtractingPhase(key: const ValueKey('extracting'));
      case BulkPhase.preview:
        return _PreviewPhase(key: const ValueKey('preview'));
      case BulkPhase.creating:
        return _CreatingPhase(key: const ValueKey('creating'));
      case BulkPhase.complete:
        return _CompletePhase(key: const ValueKey('complete'));
    }
  }
}

// ─── Phase 1: Select Files ───

class _SelectFilesPhase extends StatelessWidget {
  const _SelectFilesPhase({super.key});

  Future<void> _pickFiles(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'heic'],
    );
    if (result != null && context.mounted) {
      final files = result.paths
          .where((p) => p != null)
          .map((p) => File(p!))
          .toList();
      context.read<BulkPersonalEventProvider>().addFiles(files);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BulkPersonalEventProvider>();
    final l10n = AppLocalizations.of(context)!;

    if (!provider.hasFiles) {
      // Empty state
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.personalEventLight,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.folder_copy_outlined,
                  size: 40,
                  color: AppColors.personalEvent,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.bulkImportTitle,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.bulkImportSubtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.supportedFormats,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => _pickFiles(context),
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(l10n.selectFiles),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.personalEvent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Files selected — show list + extract button
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.files.length,
            itemBuilder: (context, index) {
              final f = provider.files[index];
              return _FileCard(
                file: f,
                onRemove: () => provider.removeFile(index),
              );
            },
          ),
        ),
        // Bottom action bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _pickFiles(context),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.addMoreFiles),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.personalEvent,
                  side: const BorderSide(color: AppColors.personalEvent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => provider.extractAllFiles(),
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: Text(l10n.extractFiles(provider.totalFiles)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.personalEvent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Phase 2: Extracting ───

class _ExtractingPhase extends StatelessWidget {
  const _ExtractingPhase({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BulkPersonalEventProvider>();
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        // Progress bar
        LinearProgressIndicator(
          value: provider.extractionProgress,
          backgroundColor: AppColors.personalEventLight,
          color: AppColors.personalEvent,
          minHeight: 3,
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.personalEvent,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.extractingFiles,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: provider.files.length,
            itemBuilder: (context, index) {
              final f = provider.files[index];
              return _FileStatusCard(file: f);
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextButton(
              onPressed: () => provider.cancel(),
              child: const Text('Cancel'),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Phase 3: Preview ───

class _PreviewPhase extends StatelessWidget {
  const _PreviewPhase({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BulkPersonalEventProvider>();
    final l10n = AppLocalizations.of(context)!;
    final allEvents = provider.allExtractedEvents;
    final allSelected = allEvents.every((e) => e.isSelected);

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.eventsFoundAcrossFiles(
                  provider.totalExtractedEvents,
                  provider.extractedFileCount,
                ),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.tapToEdit,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 8),
              // Select all toggle + Edit All button
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (allSelected) {
                        provider.deselectAll();
                      } else {
                        provider.selectAll();
                      }
                    },
                    child: Row(
                      children: [
                        Icon(
                          allSelected
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          color: AppColors.personalEvent,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          allSelected ? l10n.deselectAll : l10n.selectAll,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.personalEvent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: provider.selectedCount > 0
                        ? () => _showBulkEditSheet(context, provider)
                        : null,
                    icon: const Icon(Icons.edit_note, size: 18),
                    label: Text(l10n.editAllSelected),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.personalEvent,
                      side: const BorderSide(color: AppColors.personalEvent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Event cards grouped by file
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: provider.files.length,
            itemBuilder: (context, fileIdx) {
              final file = provider.files[fileIdx];
              if (file.extractedEvents.isEmpty && file.status != BulkFileStatus.failed) {
                return const SizedBox.shrink();
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // File header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
                    child: Row(
                      children: [
                        Icon(
                          file.isImage ? Icons.image_outlined : Icons.picture_as_pdf_outlined,
                          size: 16,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            file.fileName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (file.status == BulkFileStatus.failed)
                          Text(
                            file.errorMessage ?? l10n.noEventsFoundInFile,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.red,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Event cards from this file
                  ...file.extractedEvents.asMap().entries.map((entry) {
                    final eventIdx = entry.key;
                    final event = entry.value;
                    return _ExtractedEventCard(
                      event: event,
                      onToggle: () => provider.toggleEvent(fileIdx, eventIdx),
                      onTap: () => _editEvent(
                        context, provider, fileIdx, eventIdx, event,
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
        ),

        // Bottom action bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: provider.selectedCount > 0
                  ? () => provider.createSelectedEvents()
                  : null,
              icon: const Icon(Icons.check_circle_outline, size: 20),
              label: Text(l10n.createNSelected(provider.selectedCount)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.personalEvent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _editEvent(
    BuildContext context,
    BulkPersonalEventProvider provider,
    int fileIdx,
    int eventIdx,
    BulkExtractedEvent event,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: PersonalEventBottomSheet(
          existingEvent: event.data,
          onLocalEdit: (editedData) {
            provider.updateEventData(fileIdx, eventIdx, editedData);
          },
        ),
      ),
    );
  }

  void _showBulkEditSheet(
    BuildContext context,
    BulkPersonalEventProvider provider,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: _BulkEditBottomSheet(
          selectedCount: provider.selectedCount,
          onApply: (edits) => provider.applyBulkEdit(edits),
        ),
      ),
    );
  }
}

// ─── Phase 4: Creating ───

class _CreatingPhase extends StatelessWidget {
  const _CreatingPhase({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BulkPersonalEventProvider>();

    final selected = provider.allExtractedEvents
        .where((e) => e.isSelected)
        .toList();
    final done = selected.where((e) => e.created || e.errorMessage != null).length;
    final progress = selected.isNotEmpty ? done / selected.length : 0.0;

    return Column(
      children: [
        LinearProgressIndicator(
          value: progress,
          backgroundColor: AppColors.personalEventLight,
          color: AppColors.personalEvent,
          minHeight: 3,
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: selected.length,
            itemBuilder: (context, index) {
              final e = selected[index];
              final title = _buildTitle(e.data);

              IconData icon;
              Color iconColor;
              if (e.created) {
                icon = Icons.check_circle;
                iconColor = Colors.green;
              } else if (e.errorMessage != null) {
                icon = Icons.error;
                iconColor = Colors.red;
              } else {
                icon = Icons.hourglass_top;
                iconColor = Colors.orange;
              }

              return ListTile(
                leading: Icon(icon, color: iconColor, size: 22),
                title: Text(
                  title.toString(),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                subtitle: e.errorMessage != null
                    ? Text(
                        e.errorMessage!,
                        style: const TextStyle(fontSize: 12, color: Colors.red),
                      )
                    : null,
                dense: true,
              );
            },
          ),
        ),
        if (provider.hitPaywall)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SubscriptionPaywallScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.personalEvent,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Upgrade to Continue'),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Phase 5: Complete ───

class _CompletePhase extends StatelessWidget {
  const _CompletePhase({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BulkPersonalEventProvider>();
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.check_circle_outline,
                size: 44,
                color: Colors.green.shade600,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.bulkImportComplete,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.nCreatedNFailed(provider.createdCount, provider.failedCount),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.personalEvent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: Text(l10n.viewSchedule),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => provider.reset(),
              child: Text(
                l10n.importMore,
                style: const TextStyle(color: AppColors.personalEvent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bulk Edit Bottom Sheet ───

class _BulkEditBottomSheet extends StatefulWidget {
  final int selectedCount;
  final void Function(Map<String, dynamic> edits) onApply;

  const _BulkEditBottomSheet({
    required this.selectedCount,
    required this.onApply,
  });

  @override
  State<_BulkEditBottomSheet> createState() => _BulkEditBottomSheetState();
}

class _BulkEditBottomSheetState extends State<_BulkEditBottomSheet> {
  // Toggle states for each field
  bool _useStartTime = false;
  bool _useEndTime = false;
  bool _useRole = false;
  bool _useClient = false;
  bool _useLocation = false;
  bool _useRate = false;
  bool _useNotes = false;

  // Field values
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  final _roleController = TextEditingController();
  final _clientController = TextEditingController();
  final _locationController = TextEditingController();
  final _rateController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _roleController.dispose();
    _clientController.dispose();
    _locationController.dispose();
    _rateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(BuildContext context, bool isStart) async {
    final initial = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
          _useStartTime = true;
        } else {
          _endTime = picked;
          _useEndTime = true;
        }
      });
    }
  }

  void _apply() {
    final edits = <String, dynamic>{};
    if (_useStartTime) edits['startTime'] = _formatTime(_startTime);
    if (_useEndTime) edits['endTime'] = _formatTime(_endTime);
    if (_useRole && _roleController.text.trim().isNotEmpty) {
      edits['role'] = _roleController.text.trim();
    }
    if (_useClient && _clientController.text.trim().isNotEmpty) {
      edits['client'] = _clientController.text.trim();
    }
    if (_useLocation && _locationController.text.trim().isNotEmpty) {
      edits['location'] = _locationController.text.trim();
    }
    if (_useRate && _rateController.text.trim().isNotEmpty) {
      final rate = double.tryParse(_rateController.text.trim());
      if (rate != null && rate > 0) edits['hourlyRate'] = rate;
    }
    if (_useNotes && _notesController.text.trim().isNotEmpty) {
      edits['notes'] = _notesController.text.trim();
    }

    if (edits.isNotEmpty) {
      widget.onApply(edits);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.edit_note,
                    color: AppColors.personalEvent, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.bulkEditTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.personalEventLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${widget.selectedCount}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.personalEvent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.bulkEditHint,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),

          // Scrollable fields
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  // Start Time
                  _ToggleFieldRow(
                    checked: _useStartTime,
                    onChecked: (v) => setState(() => _useStartTime = v),
                    label: l10n.startTime,
                    child: InkWell(
                      onTap: () => _pickTime(context, true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.access_time,
                                size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 6),
                            Text(
                              _startTime.format(context),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // End Time
                  _ToggleFieldRow(
                    checked: _useEndTime,
                    onChecked: (v) => setState(() => _useEndTime = v),
                    label: l10n.endTime,
                    child: InkWell(
                      onTap: () => _pickTime(context, false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.access_time,
                                size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 6),
                            Text(
                              _endTime.format(context),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Role
                  _ToggleFieldRow(
                    checked: _useRole,
                    onChecked: (v) => setState(() => _useRole = v),
                    label: l10n.role,
                    child: Expanded(
                      child: TextField(
                        controller: _roleController,
                        onTap: () => setState(() => _useRole = true),
                        decoration: InputDecoration(
                          hintText: 'e.g. Bartender',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),

                  // Client
                  _ToggleFieldRow(
                    checked: _useClient,
                    onChecked: (v) => setState(() => _useClient = v),
                    label: l10n.client,
                    child: Expanded(
                      child: TextField(
                        controller: _clientController,
                        onTap: () => setState(() => _useClient = true),
                        decoration: InputDecoration(
                          hintText: 'e.g. Marriott',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),

                  // Location
                  _ToggleFieldRow(
                    checked: _useLocation,
                    onChecked: (v) => setState(() => _useLocation = v),
                    label: l10n.location,
                    child: Expanded(
                      child: TextField(
                        controller: _locationController,
                        onTap: () => setState(() => _useLocation = true),
                        decoration: InputDecoration(
                          hintText: 'e.g. Grand Ballroom',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),

                  // Hourly Rate
                  _ToggleFieldRow(
                    checked: _useRate,
                    onChecked: (v) => setState(() => _useRate = v),
                    label: l10n.hourlyRate,
                    child: SizedBox(
                      width: 120,
                      child: TextField(
                        controller: _rateController,
                        onTap: () => setState(() => _useRate = true),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          hintText: '\$/hr',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),

                  // Notes
                  _ToggleFieldRow(
                    checked: _useNotes,
                    onChecked: (v) => setState(() => _useNotes = v),
                    label: l10n.notes,
                    child: Expanded(
                      child: TextField(
                        controller: _notesController,
                        onTap: () => setState(() => _useNotes = true),
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'e.g. Bring black vest',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Apply button
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _apply,
                icon: const Icon(Icons.check, size: 20),
                label: Text(
                  '${l10n.applyToSelected} (${widget.selectedCount})',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.personalEvent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A row with a leading checkbox, a label, and a field widget.
class _ToggleFieldRow extends StatelessWidget {
  final bool checked;
  final ValueChanged<bool> onChecked;
  final String label;
  final Widget child;

  const _ToggleFieldRow({
    required this.checked,
    required this.onChecked,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: checked,
              onChanged: (v) => onChecked(v ?? false),
              activeColor: AppColors.personalEvent,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: checked ? AppColors.textDark : Colors.grey.shade500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          child,
        ],
      ),
    );
  }
}

// ─── Shared Widgets ───

class _FileCard extends StatelessWidget {
  final BulkFileItem file;
  final VoidCallback onRemove;

  const _FileCard({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: Colors.white,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.personalEventLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            file.isImage ? Icons.image_outlined : Icons.picture_as_pdf_outlined,
            color: AppColors.personalEvent,
            size: 22,
          ),
        ),
        title: Text(
          file.fileName,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          file.formattedSize,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
        trailing: IconButton(
          icon: Icon(Icons.close, size: 18, color: Colors.grey.shade400),
          onPressed: onRemove,
        ),
      ),
    );
  }
}

class _FileStatusCard extends StatelessWidget {
  final BulkFileItem file;

  const _FileStatusCard({required this.file});

  @override
  Widget build(BuildContext context) {
    Widget trailing;
    switch (file.status) {
      case BulkFileStatus.pending:
        trailing = Icon(Icons.hourglass_empty, size: 18, color: Colors.grey.shade400);
        break;
      case BulkFileStatus.extracting:
        trailing = const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.personalEvent,
          ),
        );
        break;
      case BulkFileStatus.extracted:
        trailing = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${file.extractedEvents.length}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.check_circle, size: 18, color: Colors.green),
          ],
        );
        break;
      case BulkFileStatus.failed:
        trailing = const Icon(Icons.error, size: 18, color: Colors.red);
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 0,
      color: Colors.white,
      child: ListTile(
        dense: true,
        leading: Icon(
          file.isImage ? Icons.image_outlined : Icons.picture_as_pdf_outlined,
          size: 20,
          color: AppColors.personalEvent,
        ),
        title: Text(
          file.fileName,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: file.errorMessage != null
            ? Text(
                file.errorMessage!,
                style: const TextStyle(fontSize: 11, color: Colors.red),
              )
            : null,
        trailing: trailing,
      ),
    );
  }
}

/// Build a display title from extracted event data.
/// Mirrors the backend logic: title → role @ client → location → date.
String _buildTitle(Map<String, dynamic> data) {
  final rawTitle = data['title'] ?? data['event_name'];
  if (rawTitle != null && rawTitle.toString().trim().isNotEmpty) {
    return rawTitle.toString().trim();
  }
  final role = (data['role'] ?? data['personal_role'])?.toString().trim() ?? '';
  final client = (data['client'] ?? data['personal_client'])?.toString().trim() ?? '';
  final location = (data['location'] ?? data['venue_name'])?.toString().trim() ?? '';
  final parts = <String>[
    if (role.isNotEmpty) role,
    if (client.isNotEmpty) '@ $client',
    if (role.isEmpty && client.isEmpty && location.isNotEmpty) location,
  ];
  if (parts.isNotEmpty) return parts.join(' ');
  return data['date']?.toString() ?? 'Job';
}

class _ExtractedEventCard extends StatelessWidget {
  final BulkExtractedEvent event;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  const _ExtractedEventCard({
    required this.event,
    required this.onToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final data = event.data;
    final title = _buildTitle(data);
    final date = data['date']?.toString() ?? '';
    final startTime = data['startTime'] ?? data['start_time'] ?? '';
    final endTime = data['endTime'] ?? data['end_time'] ?? '';
    final role = data['role'] ?? data['personal_role'] ?? '';
    final client = data['client'] ?? data['personal_client'] ?? '';

    String timeStr = '';
    if (startTime.toString().isNotEmpty) {
      timeStr = startTime.toString();
      if (endTime.toString().isNotEmpty) {
        timeStr += ' - ${endTime.toString()}';
      }
    }

    // Format date nicely
    String dateStr = date;
    if (date.isNotEmpty) {
      final parsed = DateTime.tryParse(date);
      if (parsed != null) {
        dateStr = DateFormat('EEE, MMM d').format(parsed);
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: event.isSelected ? Colors.white : Colors.grey.shade100,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Checkbox
              GestureDetector(
                onTap: onToggle,
                child: Icon(
                  event.isSelected
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  color: event.isSelected
                      ? AppColors.personalEvent
                      : Colors.grey.shade400,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toString(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: event.isSelected
                            ? AppColors.textDark
                            : Colors.grey.shade500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (dateStr.isNotEmpty) ...[
                          Icon(Icons.calendar_today,
                              size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 3),
                          Text(
                            dateStr,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                          const SizedBox(width: 10),
                        ],
                        if (timeStr.isNotEmpty) ...[
                          Icon(Icons.access_time,
                              size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              timeStr,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (role.toString().isNotEmpty ||
                        client.toString().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (role.toString().isNotEmpty) role.toString(),
                          if (client.toString().isNotEmpty) client.toString(),
                        ].join(' \u2022 '),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Edit indicator
              Icon(Icons.edit_outlined,
                  size: 16, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
