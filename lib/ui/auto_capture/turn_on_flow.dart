import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/capture/capture_service.dart';

/// Explains what auto-capture reads, asks Android for SMS permission and
/// helps when Android refuses. Used by the Auto-capture screen and Settings.
Future<void> turnOnAutoCapture(BuildContext context) async {
  final capture = context.read<CaptureService>();
  final messenger = ScaffoldMessenger.of(context);

  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Read your money SMS?'),
      content: const Text(
        'MoneyTrack will read the MTN, Airtel and bank messages your phone receives and list the '
        'transactions for you to confirm.\n\n'
        '• Messages from people\'s phone numbers are skipped.\n'
        '• Everything is read on this phone. Message text is never uploaded.\n'
        '• Nothing is saved as a transaction until you confirm it.\n\n'
        'It also looks back over the last 30 days.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue')),
      ],
    ),
  );
  if (go != true || !context.mounted) return;

  switch (await capture.turnOn()) {
    case TurnOnResult.on:
      final n = capture.pendingCount;
      messenger.showSnackBar(SnackBar(
        content: Text(n == 0
            ? 'Auto-capture is on. New money SMS will appear here.'
            : 'Auto-capture is on — found $n transaction${n == 1 ? '' : 's'} to review.'),
      ));
    case TurnOnResult.denied:
      messenger.showSnackBar(SnackBar(
        content: const Text('SMS permission wasn\'t allowed.'),
        action: context.mounted
            ? SnackBarAction(label: 'How to allow', onPressed: () => showAllowSmsSteps(context))
            : null,
      ));
    case TurnOnResult.blocked:
      if (context.mounted) await showAllowSmsSteps(context);
    case TurnOnResult.unsupported:
      messenger.showSnackBar(const SnackBar(
        content: Text('Reading SMS only works on Android. You can still paste messages with Check a message.'),
      ));
  }
}

/// Steps for allowing SMS in App info, including Android 15's "restricted
/// settings" for apps installed from an APK.
Future<void> showAllowSmsSteps(BuildContext context) async {
  final capture = context.read<CaptureService>();
  final open = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Allow SMS in settings'),
      content: const Text(
        '1. Tap Open settings below.\n'
        '2. If there is a ⋮ menu at the top right, tap it and choose "Allow restricted settings". '
        '(Android asks for this on newer phones when an app was installed from an APK.)\n'
        '3. Tap Permissions → SMS → Allow.\n'
        '4. Come back and turn auto-capture on again.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Open settings')),
      ],
    ),
  );
  if (open == true) await capture.openSettings();
}
