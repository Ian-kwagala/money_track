import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/capture/capture_service.dart';
import '../theme/app_theme.dart';

/// "3 transactions to review" on Home, while auto-capture has any waiting.
class CaptureReviewBanner extends StatelessWidget {
  const CaptureReviewBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final n = context.watch<CaptureService>().pendingCount;
    if (n == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          onTap: () => Navigator.pushNamed(context, '/capture'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              children: [
                const Icon(Icons.sms_outlined, color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$n transaction${n == 1 ? '' : 's'} to review',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      const Text('From your MTN, Airtel and bank SMS',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
