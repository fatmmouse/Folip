import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../domain/devices_notifier.dart';
import '../domain/send_notifier.dart';
import 'device_selector_widget.dart';
import 'upload_progress_widget.dart';

/// The Send tab screen.
///
/// Per UI-SPEC Send Screen contract:
///   - AppBar: "Send" title (Source Serif 4) + gear icon to Settings
///   - Device Selector: horizontal chip row with DeviceSelectorWidget
///   - File Entry Zone: "Choose a file" picker button, shows progress when uploading
///
/// Auto-send logic (D-02):
///   When file is picked AND device is selected, upload starts immediately —
///   no confirmation step.
///
/// File validation:
///   Files > 500MB (524288000 bytes) are rejected with a snackbar error.
class SendScreen extends ConsumerStatefulWidget {
  const SendScreen({super.key});

  @override
  ConsumerState<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends ConsumerState<SendScreen> {
  // Currently selected file (cleared on upload start)
  PlatformFile? _selectedFile;
  bool _isPickingFile = false;

  @override
  Widget build(BuildContext context) {
    final sendState = ref.watch(sendNotifierProvider);
    final selectedDeviceId = ref.watch(selectedDeviceProvider);

    // Auto-send listener: when device selection changes and we have a file
    ref.listen<String?>(selectedDeviceProvider, (prev, next) {
      if (next != null &&
          _selectedFile != null &&
          sendState.status == SendStatus.idle) {
        _triggerSend(ref, next);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Send'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.go('/settings'),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Device selector chips
          const DeviceSelectorWidget(),

          const SizedBox(height: AppSpacing.lg),

          // File entry / upload progress zone
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0),
            child: _buildFileZone(context, sendState, selectedDeviceId),
          ),
        ],
      ),
    );
  }

  /// Builds the file picker button or upload progress display.
  Widget _buildFileZone(
    BuildContext context,
    SendState sendState,
    String? selectedDeviceId,
  ) {
    // Show progress widget while uploading, on success, or on error
    if (sendState.status == SendStatus.uploading ||
        sendState.status == SendStatus.success ||
        sendState.status == SendStatus.error) {
      return UploadProgressWidget(
        sendState: sendState,
        onRetry: () {
          ref.read(sendNotifierProvider.notifier).reset();
          setState(() {
            _selectedFile = null;
          });
        },
      );
    }

    // Idle state: file picker button
    return _buildFilePickerButton(context, selectedDeviceId);
  }

  /// The "Choose a file" button (or file-selected state with border color change).
  Widget _buildFilePickerButton(
    BuildContext context,
    String? selectedDeviceId,
  ) {
    final hasFile = _selectedFile != null;
    final borderColor =
        hasFile ? AppColors.accent : AppColors.textSecondary;

    return GestureDetector(
      onTap: _isPickingFile ? null : () => _pickFile(selectedDeviceId),
      child: Container(
        height: 56,
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.dominant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: borderColor,
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: hasFile
            ? _buildFileSelectedContent()
            : const Text(
                'Choose a file',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
      ),
    );
  }

  /// Content shown when a file has been selected but upload hasn't started.
  Widget _buildFileSelectedContent() {
    final file = _selectedFile!;
    final sizeLabel = _formatBytes(file.size);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.insert_drive_file,
            size: 16, color: AppColors.textPrimary),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            '${file.name}  $sizeLabel',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Opens the system file picker and handles the result.
  Future<void> _pickFile(String? selectedDeviceId) async {
    setState(() => _isPickingFile = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: false, // stream path only — avoids loading 500MB into memory
      );

      if (result == null || result.files.isEmpty) {
        // User cancelled — no action
        return;
      }

      final file = result.files.first;

      // Validate file path
      if (file.path == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Could not access file path. Please try a different file.'),
            ),
          );
        }
        return;
      }

      // Validate file size — 500MB limit (524288000 bytes)
      if (file.size > 524288000) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File exceeds 500MB limit'),
            ),
          );
        }
        return;
      }

      setState(() {
        _selectedFile = file;
      });

      // Auto-send (D-02): if device is already selected, start upload immediately
      if (selectedDeviceId != null) {
        _triggerSend(ref, selectedDeviceId);
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingFile = false);
      }
    }
  }

  /// Triggers the send flow using the current selected file + target device.
  void _triggerSend(WidgetRef ref, String targetDeviceId) {
    final file = _selectedFile;
    if (file == null || file.path == null) return;

    // Clear the selected file immediately — UI switches to progress display
    setState(() {
      _selectedFile = null;
    });

    ref.read(sendNotifierProvider.notifier).sendFile(
          targetDeviceId: targetDeviceId,
          filePath: file.path!,
          fileName: file.name,
          fileSize: file.size,
        );
  }

  /// Formats bytes to a human-readable string (e.g., "12.5 MB", "340 KB").
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      final kb = bytes / 1024;
      return '${kb.toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      final mb = bytes / (1024 * 1024);
      return '${mb.toStringAsFixed(1)} MB';
    }
    final gb = bytes / (1024 * 1024 * 1024);
    return '${gb.toStringAsFixed(2)} GB';
  }
}
