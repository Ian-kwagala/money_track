import '../models/bill.dart';
import '../models/frequency.dart';
import '../models/recurrence_rule.dart';
import '../models/transaction.dart';
import '../viewmodels/tracker_view_model.dart';

/// Processes scheduled recurring expenses (stored as [Bill] + [RecurrenceRule]
/// with [RecurrenceRule.autoPost] enabled) and automatically posts due entries
/// into the user's transaction ledger.
class RecurringTransactionService {
  /// Caps how many missed occurrences a single bill can catch up in one pass
  /// so a very old anchor date can never flood the ledger.
  static const int maxCatchUpPerRun = 24;

  /// Checks every active recurring bill with [RecurrenceRule.autoPost] enabled
  /// and automatically adds ledger transactions for any scheduled date on or
  /// before [now].
  ///
  /// Uses deterministic transaction IDs (`recurring_<billId>_YYYY_M_D`) so
  /// calling this multiple times on the same day never creates duplicates.
  /// Returns the number of transactions newly added.
  static Future<int> processDueRecurring(
    TrackerViewModel vm, {
    DateTime? now,
  }) async {
    final current = now ?? DateTime.now();
    // End of today so anything scheduled for today posts immediately.
    final todayEnd = DateTime(current.year, current.month, current.day, 23, 59, 59, 999);

    final rulesById = <String, RecurrenceRule>{
      for (final r in vm.recurrenceRules) r.id: r,
    };
    final existingTxIds = vm.transactions.map((t) => t.id).toSet();
    final fallbackWalletId = vm.wallets.isNotEmpty ? vm.wallets.first.id : '';

    var postedCount = 0;

    for (final bill in vm.bills) {
      if (bill.isPaused || bill.isSettled) continue;
      final ruleId = bill.recurrenceRuleId;
      if (ruleId == null || ruleId.isEmpty) continue;
      final rule = rulesById[ruleId];
      if (rule == null || !rule.autoPost) continue;

      final walletId = bill.walletId.isNotEmpty ? bill.walletId : fallbackWalletId;
      if (walletId.isEmpty) continue;

      var iterations = 0;
      var changed = false;

      while (iterations < maxCatchUpPerRun) {
        final scheduled = bill.nextDueDate;
        if (scheduled.isAfter(todayEnd)) break;
        if (rule.endDate != null && scheduled.isAfter(rule.endDate!)) break;

        final txId = occurrenceId(bill.id, scheduled);
        if (!existingTxIds.contains(txId)) {
          await vm.addTransaction(TxRecord(
            id: txId,
            type: TxType.expense,
            amount: bill.amount,
            walletId: walletId,
            categoryId: bill.categoryId ?? '',
            note: bill.name,
            dateTime: scheduled,
            isRecurring: true,
            frequency: bill.frequency,
          ));
          existingTxIds.add(txId);
          postedCount++;
        }

        // Advance the bill's lastPaidDate so nextDueDate moves to the next cycle.
        bill.isPaid = true;
        bill.lastPaidDate = scheduled;
        changed = true;
        iterations++;

        // One-off items stop after posting once.
        if (bill.frequency == Frequency.once || bill.frequency == Frequency.random) {
          break;
        }
      }

      if (changed) {
        await vm.updateBill(bill);
        rule.nextRunAt = bill.nextDueDate;
        await vm.addRecurrenceRule(rule);
      }
    }

    return postedCount;
  }

  /// Maps a shared [Frequency] to the [RecurrenceFrequency] stored on
  /// [RecurrenceRule], along with its cycle interval.
  static (RecurrenceFrequency, int) toRuleSchedule(Frequency frequency, {int? customDays}) {
    switch (frequency) {
      case Frequency.daily:
        return (RecurrenceFrequency.daily, 1);
      case Frequency.weekly:
        return (RecurrenceFrequency.weekly, 1);
      case Frequency.biweekly:
        return (RecurrenceFrequency.weekly, 2);
      case Frequency.monthly:
        return (RecurrenceFrequency.monthly, 1);
      case Frequency.quarterly:
        return (RecurrenceFrequency.monthly, 3);
      case Frequency.yearly:
        return (RecurrenceFrequency.yearly, 1);
      case Frequency.custom:
        return (RecurrenceFrequency.daily, (customDays != null && customDays > 0) ? customDays : 30);
      case Frequency.once:
      case Frequency.random:
        return (RecurrenceFrequency.monthly, 1);
    }
  }

  /// Deterministic ID for a specific bill occurrence on [date], preventing
  /// duplicate auto-posts if [processDueRecurring] runs more than once.
  static String occurrenceId(String billId, DateTime date) =>
      'recurring_${billId}_${date.year}_${date.month}_${date.day}';
}
