import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../theme/app_theme.dart';

/// Where receipt photos come from and where they're kept. The picker's own
/// files are temporary, so each receipt is copied into the app's documents.
class Receipts {
  /// Swapped in tests.
  static Future<XFile?> Function(ImageSource source) pick = (source) =>
      ImagePicker().pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 80);
  static Future<Directory> Function() documents = getApplicationDocumentsDirectory;

  /// Copies [file] into the receipts folder and returns its new path.
  static Future<String> keep(XFile file) async {
    final dir = Directory('${(await documents()).path}/receipts');
    if (!await dir.exists()) await dir.create(recursive: true);
    final dot = file.path.lastIndexOf('.');
    final ext = dot == -1 ? '.jpg' : file.path.substring(dot);
    final dest = '${dir.path}/receipt_${DateTime.now().millisecondsSinceEpoch}$ext';
    await file.saveTo(dest);
    return dest;
  }
}

/// "Attach receipt": take a photo or pick one; once attached it shows a
/// thumbnail, and tapping it offers View, Replace and Remove.
///
/// It doesn't save anything on the transaction itself. It reports the new
/// path (or null when removed) through [onChanged], and the form saves it.
class ReceiptPicker extends StatefulWidget {
  /// The attached receipt's file path, or null/empty for none.
  final String? path;
  final ValueChanged<String?> onChanged;

  const ReceiptPicker({super.key, required this.path, required this.onChanged});

  @override
  State<ReceiptPicker> createState() => _ReceiptPickerState();
}

/// What the user picked in the options sheet.
enum _Choice { camera, gallery, view, remove }

class _ReceiptPickerState extends State<ReceiptPicker> {
  /// True while a photo is being taken/picked and copied.
  bool _working = false;

  bool get _has => widget.path != null && widget.path!.isNotEmpty;

  /// Shows the options sheet; View and Remove only appear once a receipt is
  /// attached.
  Future<void> _open() async {
    final choice = await showModalBottomSheet<_Choice>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        // Material (not a coloured Container) so the options' ripples show.
        child: Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _has ? 'Receipt' : 'Attach receipt',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                if (_has)
                  ListTile(
                    leading: const Icon(Icons.visibility_outlined),
                    title: const Text('View receipt'),
                    onTap: () => Navigator.pop(ctx, _Choice.view),
                  ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: Text(_has ? 'Take a new photo' : 'Take a photo'),
                  onTap: () => Navigator.pop(ctx, _Choice.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Choose from gallery'),
                  onTap: () => Navigator.pop(ctx, _Choice.gallery),
                ),
                if (_has)
                  ListTile(
                    leading: const Icon(Icons.delete_outline, color: AppColors.danger),
                    title: const Text('Remove receipt', style: TextStyle(color: AppColors.danger)),
                    onTap: () => Navigator.pop(ctx, _Choice.remove),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case _Choice.view:
        await ReceiptViewer.open(context, widget.path!);
      case _Choice.remove:
        widget.onChanged(null);
      case _Choice.camera:
      case _Choice.gallery:
        await _pick(choice == _Choice.camera ? ImageSource.camera : ImageSource.gallery);
    }
  }

  /// Gets a photo from [source], keeps a copy and reports its path. Errors
  /// (permission denied, no camera...) become a snackbar.
  Future<void> _pick(ImageSource source) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _working = true);
    try {
      final file = await Receipts.pick(source);
      if (file == null) return; // cancelled
      final kept = await Receipts.keep(file);
      HapticFeedback.selectionClick();
      widget.onChanged(kept);
    } on PlatformException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_explain(e))));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Couldn\'t attach the receipt: $e')));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  /// Plain-language messages for image_picker's error codes.
  static String _explain(PlatformException e) => switch (e.code) {
    'camera_access_denied' => 'Camera permission is off. Allow it in App info → Permissions to take receipt photos.',
    'photo_access_denied' => 'Photo access is off. Allow it in App info → Permissions to pick receipts.',
    'no_available_camera' => 'No camera found on this phone. Choose a photo from the gallery instead.',
    _ => 'Couldn\'t attach the receipt (${e.message ?? e.code}).',
  };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _working ? null : _open,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_working)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              else if (_has)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.file(
                    File(widget.path!),
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                    cacheWidth: 96,
                    errorBuilder: (_, _, _) => const Icon(Icons.receipt_long, size: 20, color: AppColors.textSecondary),
                  ),
                )
              else
                const Icon(Icons.camera_alt_outlined, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  _working ? 'Attaching…' : (_has ? 'Receipt attached · tap to view' : 'Attach receipt'),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _has ? AppColors.textPrimary : AppColors.textSecondary,
                    fontWeight: _has ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
              if (_has && !_working) ...[
                const SizedBox(width: 6),
                const Icon(Icons.check_circle, size: 16, color: AppColors.success),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A receipt full screen, with pinch to zoom.
///
/// Receipt files aren't synced (only their path is), so on another phone
/// the image won't be found and the error text below is shown instead.
class ReceiptViewer extends StatelessWidget {
  final String path;

  const ReceiptViewer({super.key, required this.path});

  static Future<void> open(BuildContext context, String path) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => ReceiptViewer(path: path)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Receipt', style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 5,
          child: Image.file(
            File(path),
            errorBuilder: (_, _, _) => const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'This receipt isn\'t on this phone. Receipt photos stay on the phone they were taken on.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
