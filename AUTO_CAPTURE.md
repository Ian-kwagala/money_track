# Auto-capture: transactions from money SMS

MoneyTrack reads the MTN MoMo, Airtel Money, Centenary Bank and NSSF
Smartlife SMS a phone receives and lists each transaction for the user to
**Confirm**, change (**Category**/**Edit**) or **Ignore**. Nothing becomes a
transaction until it's confirmed.

## How it works

```
SMS arrives ─► SmsReceiver (Android, works while the app is closed)
                 │  personal phone numbers dropped here, never stored
                 ▼
               queue ─┐
SMS inbox ────────────┴─► CaptureService (Dart) ─► MoneyMessageParser
  (last 30 days on first run,                        │ not money → dropped
   then since the last scan)                         ▼
                                    captured_sms box (this phone only)
                                                     ▼
                         Auto-capture screen: Confirm · Category · Ignore
                                                     ▼ confirmed
                     normal transaction (+ fee as its own expense) → sync
```

| Piece | File |
|---|---|
| SMS receiver, inbox reader, queue, notification | `android/app/src/main/kotlin/.../SmsReceiver.kt`, `SmsCapture.kt`, `MainActivity.kt` |
| Dart ↔ Android channel, permission | `lib/services/capture/sms_bridge.dart` |
| Reading a message | `lib/services/capture/money_message_parser.dart` |
| Wallet / type / category suggestions | `lib/services/capture/capture_suggestions.dart` |
| Collecting, de-duplicating, confirming, undo | `lib/services/capture/capture_service.dart` |
| Screens | `lib/ui/auto_capture/`, Home banner `lib/ui/widgets/capture_review_banner.dart` |

### What gets suggested

- **Wallet:** MTN → MTN Mobile Money, Airtel → Airtel Money, Centenary →
  Bank, NSSF → a savings wallet (the review sheet offers to create one).
  A wallet the user picks for a provider is remembered.
- **Type:**
  - Sent, paid and card payments are expenses.
  - Received is income, filed under Other.
  - Interest is income, filed under Savings.
  - Withdrawals are transfers to Cash.
  - Deposits are transfers from Bank (when the sender is a bank) or from
    Cash (an agent).
  - Money to or from one of the user's own wallets is a transfer: a wallet
    named "MoKash savings" catches the "to MoKash" messages, and "Centenary
    Bank" matches the Bank wallet.
- **Category:** whatever the user chose for that counterparty before;
  otherwise keywords (UMEME → Electricity, Shell → Fuel, "Foods" → Food, and
  so on). People get no guess, so the first payment to someone needs a
  category; after that it's remembered.
- **Fees** are saved as a separate expense under **Fees & Charges**, so the
  main amount matches the SMS.
- **Balance:** when the newest SMS for a wallet shows a different balance
  from the app, MoneyTrack offers to update the wallet. Transactions are
  kept; only the wallet's opening balance changes.
- **Duplicates:**
  - The same SMS is captured once, whether it was seen live or in a scan.
  - The same transaction ID is captured once.
  - An SMS already confirmed on another phone (restored from backup) isn't
    offered again.
  - A hand-typed transaction with the same amount, wallet and day is flagged
    "Already recorded?" and skipped by **Confirm all**.

### Privacy

- SMS from phone numbers (people) are dropped on the Android side and never
  reach the app.
- Other messages are read on the phone. Only money messages are kept, in
  the local `captured_sms` box, which is **never synced** to Firebase or
  visible to the admin dashboard. Only confirmed transactions sync.
- Confirmed and ignored messages are deleted 60 days after they arrived.
- The new-transaction notification shows the sender, not the message text,
  because notifications appear on the lock screen.
- The receiver only accepts broadcasts from the system (`BROADCAST_SMS`),
  so another app can't feed it a fake SMS.

## Shipping it: this needs a full release (not a patch)

The Android receiver is native code, so this goes out as a **new release**,
version **1.0.1+2** (already set in `pubspec.yaml`). From then on, parser
and screen changes are Dart-only and can ship as Shorebird patches again.

On the Windows PC (PowerShell):

```powershell
cd "C:\Users\Mufasa\Desktop\Expense Tracker\money_track"
git pull
flutter pub get
shorebird release android --artifact apk
```

Install `build\app\outputs\flutter-apk\app-release.apk` on the phone **over
the existing app**. Do **not** uninstall first: uninstalling deletes the
data on the phone. Installing over it works because it's signed with the
same key (`android\key.properties`).

## Trying it on the phone

1. Open the app → **Settings → Auto-capture from SMS** → turn it on →
   **Continue** → allow SMS.
2. If Android says the setting is **restricted** or doesn't ask at all (this
   happens on Android 15+ for apps installed from an APK):
   **App info → ⋮ (top right) → Allow restricted settings → Permissions →
   SMS → Allow**. The app shows these steps and has an **Open settings**
   button.
3. It reads the last 30 days, and the Auto-capture screen lists what it
   found. Home shows "N transactions to review".
4. Confirm a couple, check they appear under Transactions, and accept the
   balance update if asked.
5. The next real MoMo/Airtel/bank SMS should show a notification and appear
   in the list. Texting yourself from another phone won't work: messages
   from personal numbers are ignored on purpose.

## When a message is read wrongly or not at all

1. Copy it into `test/capture/money_message_parser_test.dart` as a new
   sample (change names and numbers, keep the layout) with what it should
   read as.
2. Run `flutter test test/capture/`, fix the rule in
   `money_message_parser.dart`, and re-run.
3. Ship it with `shorebird patch android`. Messages already waiting for
   review are re-read with the fixed parser.

## Limits

- **Android only.** iPhones don't let apps read SMS; there, **Check a
  message** (paste an SMS) still works.
- **Google Play:** SMS permissions need Google's approval (a Permissions
  Declaration as a financial-management app). This doesn't affect sharing
  the APK directly.
- Known formats are listed in the parser tests. MTN *received / paid /
  withdrawn* and Airtel *withdrawal* follow the usual layout but haven't
  been checked against real messages yet.
