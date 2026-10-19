import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../home_shell.dart';
import '../../services/alerts_service.dart';
import '../../viewmodels/tracker_view_model.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';

/// The list of active alerts (budgets, bills, unusual spending, weekly
/// summary). The alerts themselves are built by AlertsService; this screen
/// only shows them and lets the user dismiss each one.
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TrackerViewModel>();
    final service = context.watch<AlertsService>();
    final alerts = service.active(vm);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        top: false,
        child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: PageHeader(
              title: 'Alerts',
              subtitle: '${alerts.length} unread',
              // A tab on wide screens (no back); opened from Home on phones.
              back: ModalRoute.of(context)?.canPop ?? false,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (alerts.isEmpty)
                    const EmptyState(
                      icon: Icons.notifications_none_rounded,
                      title: 'No alerts yet',
                      message: 'Set a budget or add a bill and you\'ll be\nnotified right here when something needs attention.',
                    )
                  else
                    ...alerts.map((a) => _AlertCard(alert: a, onDismiss: () => service.dismiss(a.id))),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

/// One alert: icon, title, description, relative time and a Dismiss button.
class _AlertCard extends StatelessWidget {
  final AlertItem alert;
  final VoidCallback onDismiss;

  const _AlertCard({required this.alert, required this.onDismiss});

  /// "5 min ago", "3 hr ago", "2 days ago". Never shows less than a minute.
  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes.clamp(1, 59)} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} days ago';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusXl)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: alert.iconBg, shape: BoxShape.circle),
                  child: Icon(alert.icon, color: alert.iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(alert.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
              ],
            ),
            const SizedBox(height: 10),
            Text(alert.description, style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground, height: 1.4)),
            const SizedBox(height: 6),
            Text(_timeAgo(alert.when), style: const TextStyle(fontSize: 10, color: AppColors.mutedForeground)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onDismiss,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusMd)),
                  side: BorderSide(color: AppColors.border),
                  foregroundColor: AppColors.mutedForeground,
                ),
                child: const Text('Dismiss', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
