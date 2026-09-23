import 'package:flutter_test/flutter_test.dart';
import 'package:money_track/models/alert_rule.dart';
import 'package:money_track/models/bill.dart';
import 'package:money_track/models/debt.dart';
import 'package:money_track/models/recurrence_rule.dart';
import 'package:money_track/models/savings_goal.dart';
import 'package:money_track/models/user.dart';

void main() {
  group('missing blueprint models', () {
    test('can construct user model with defaults', () {
      final user = User();
      expect(user.name, 'Ian');
      expect(user.currencyCode, 'UGX');
    });

    test('savings goal has calculated progress', () {
      final goal = SavingsGoal(
        id: 'goal-1',
        name: 'Laptop',
        targetAmount: 120000,
        currentAmount: 60000,
        deadline: DateTime(2027, 1, 1),
      );

      expect(goal.progressPercent, 50.0);
      expect(goal.isOnTrack, isTrue);
    });

    test('bill and debt models initialize', () {
      final bill = Bill(
        id: 'bill-1',
        name: 'Rent',
        amount: 25000,
        dueDate: DateTime(2026, 9, 15),
      );
      final debt = Debt(
        id: 'debt-1',
        counterparty: 'Mama',
        amount: 5000,
        direction: DebtDirection.owedToMe,
      );

      expect(bill.isRecurring, isFalse);
      expect(debt.amount, 5000);
    });

    test('alert rule and recurrence rule work', () {
      final recurrence = RecurrenceRule(
        id: 'rule-1',
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
      );
      final alert = AlertRule(
        id: 'alert-1',
        type: AlertType.budgetWarning,
        targetId: 'cat-1',
        threshold: 80,
      );

      expect(recurrence.frequency, RecurrenceFrequency.monthly);
      expect(alert.threshold, 80);
    });
  });
}
