import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The placeholder a list shows when it has nothing in it yet: an icon, a
/// title, a short explanation and an optional button (e.g. "Add a bill").
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF141E30),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
                boxShadow: const [
                  BoxShadow(color: Color(0x1A000000), blurRadius: 10, offset: Offset(0, 4)),
                ],
              ),
              child: Icon(icon, size: 28, color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.mutedForeground,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}