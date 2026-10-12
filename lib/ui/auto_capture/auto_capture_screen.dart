import 'package:flutter/material.dart';

import '../home_shell.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import 'check_message_sheet.dart';

class AutoCaptureScreen extends StatelessWidget {
  const AutoCaptureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: PageHeader(title: 'Auto-capture', subtitle: '0 detected transactions'),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppColors.radiusMd),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.notifications_active_outlined, color: AppColors.primary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Read from your MTN, Airtel and bank notifications. Nothing is saved until you confirm it.',
                            style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Empty state
                  const EmptyState(
                    icon: Icons.sms_outlined,
                    title: 'No transactions detected',
                    message: 'Automatic reading of your money SMS arrives in the next app update. Until then, tap Check a message to try one of your MTN, Airtel or bank messages.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => CheckMessageSheet.show(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.content_paste_search),
        label: const Text('Check a message'),
      ),
    );
  }
}