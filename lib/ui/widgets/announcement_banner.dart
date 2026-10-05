import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/cloud/announcement_service.dart';
import '../theme/app_theme.dart';

/// Shows the newest announcement from the admin dashboard, if any.
class AnnouncementBanner extends StatelessWidget {
  const AnnouncementBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<AnnouncementService>();
    final items = service.visible;
    if (items.isEmpty) return const SizedBox.shrink();
    final a = items.first;

    final (IconData icon, Color color) = switch (a.level) {
      'warning' => (Icons.warning_amber_rounded, AppColors.warning),
      'update' => (Icons.system_update_alt_outlined, AppColors.info),
      _ => (Icons.campaign_outlined, AppColors.primary),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (a.title.isNotEmpty)
                    Text(a.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  if (a.body.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(a.body, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, height: 1.4)),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Dismiss',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, size: 18, color: AppColors.mutedForeground),
              onPressed: () => service.dismiss(a.id),
            ),
          ],
        ),
      ),
    );
  }
}
