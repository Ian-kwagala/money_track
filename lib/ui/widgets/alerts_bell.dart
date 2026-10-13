import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/alerts_service.dart';
import '../../viewmodels/tracker_view_model.dart';
import '../theme/app_theme.dart';

/// Bell in the Home header with a badge counting the alerts not yet
/// dismissed. Opens the Alerts screen.
class AlertsBell extends StatelessWidget {
  const AlertsBell({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TrackerViewModel>();
    final count = context.watch<AlertsService>().countFor(vm);

    return Semantics(
      button: true,
      label: count == 0 ? 'Alerts' : 'Alerts, $count unread',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, '/alerts'),
        borderRadius: BorderRadius.circular(28),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(color: AppColors.muted, shape: BoxShape.circle),
                child: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary, size: 18),
              ),
              if (count > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                    ),
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, height: 1.1),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
