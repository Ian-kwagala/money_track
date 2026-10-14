/// Names of the Hive boxes (local on-device tables) the app stores data in.
///
/// Each name is also the on-disk file name, so renaming one makes the app
/// start with an empty box and lose what was saved under the old name.
/// The names double as collection keys for cloud sync (see CloudCodec).
class HiveBoxes {
  // Synced to the user's cloud account (see SyncService).
  static const wallets = 'wallets';
  static const categories = 'categories';
  static const transactions = 'transactions';
  static const budgets = 'budgets';
  static const settings = 'settings';
  static const users = 'users';
  static const savingsGoals = 'savings_goals';
  static const bills = 'bills';
  static const debts = 'debts';
  static const recurrenceRules = 'recurrence_rules';
  static const alertRules = 'alert_rules';

  // Auto-capture. Local to this phone: never synced (see CaptureService).
  static const capturedSms = 'captured_sms';
  static const captureMeta = 'capture_meta';
}
