# MoneyTrack — Personal Finance & Behavior-Change App
## Product Blueprint v1.0

## 1. Vision & Problem Statement

Most budgeting apps just *record* what happened. They rarely stop people from overspending in the moment, and they rarely make saving feel rewarding. MoneyTrack is built around three jobs:

1. **Capture** — every expense/income, fast, with visual context (icons/photos).
2. **Warn** — before and as overspending happens, not a month later in a report nobody reads.
3. **Motivate** — turn saving goals into something that feels like progress, not deprivation.

Target user: an individual (student, young professional, small-business owner) managing personal or side-hustle finances who tends to lose track of discretionary spending.

---

## 2. Core Modules

### 2.1 Authentication & Profile
- Sign up/login (email, phone, or biometric-only local mode for privacy-first users)
- PIN / Face ID / Fingerprint app-lock (separate from account login)
- Multi-profile support (e.g., "Personal" vs "Business" — useful given your Mufasa Car Hire context)
- Currency & locale settings (multi-currency wallets, e.g., UGX + USD)

### 2.2 Accounts / Wallets Module
- Multiple wallets: Cash, Mobile Money (MTN/Airtel), Bank, Credit Card, Savings Jar
- Each wallet has its own balance, icon, and color
- Transfer function between wallets (not counted as income/expense, just a move)
- Opening balance + running balance auto-calculated

### 2.3 Transaction Management (Income & Expense)
- Quick-add floating button — log a transaction in under 5 seconds
- Fields: amount, wallet, category, date/time, note, custom icon/photo attachment (e.g., snap a receipt)
- Split transactions (e.g., one payment split across "Food" and "Household")
- Recurring transactions (rent, salary, subscriptions) with auto-posting
- Search & filter by date range, category, wallet, amount, tag

### 2.4 Categories & Custom Icons/Images
- Default category set (Food, Transport, Rent, Bills, Health, Entertainment, etc.)
- User-created categories with custom icon picker or uploaded image/emoji
- Sub-categories (e.g., "Transport" → "Fuel", "Boda", "Uber")
- Per-category color tagging used consistently across charts

### 2.5 Budgeting Module
- Set monthly/weekly budgets per category or overall
- **Envelope-style budgeting** option: allocate income into virtual envelopes at the start of the period
- Rollover rule setting: unused budget carries to next period or resets
- Real-time "remaining budget" indicator shown when logging a new expense in that category

### 2.6 Savings Goals Module
- Create goals with target amount, deadline, and a custom icon/photo (e.g., photo of the laptop/car/trip you're saving for)
- Auto-contribution rules (e.g., "move 10% of every income entry to Goal X")
- Round-up savings (round each expense up to nearest 1,000/1,00 and sweep the difference into a goal)
- Progress visualization (progress ring/bar) and milestone celebrations (25%, 50%, 75%, 100%)

### 2.7 Alerts & Notifications Engine
This is the module that actually changes behavior. Rule-based, not just reminders:
- **Expense alerts**: push notification when a category crosses 80%/100% of its budget
- **Unusual spending alert**: flags a transaction that's significantly above your average for that category
- **Saving alerts**: nudge if a savings goal is falling behind its needed pace to hit the deadline
- **Deadline alerts**: bill due dates, subscription renewals, goal deadlines — configurable lead time (1 day, 3 days, 1 week)
- **Low balance alert**: wallet balance under a user-set threshold
- **Daily/weekly digest**: "You've spent X today, Y% of your daily average"
- Quiet hours setting so alerts don't spam at night

### 2.8 Analytics & Graphical Summaries
- Dashboard home screen: total balance, this month's income vs expense, top 3 categories
- Charts: pie/donut (spend by category), line (balance over time), bar (income vs expense by month), heatmap (spending by day of week)
- Trend comparison: this month vs last month, this month vs same month last year
- **Financial health score**: a single 0–100 score combining savings rate, budget adherence, and bill punctuality
- Exportable PDF/CSV monthly report

### 2.9 Bills & Recurring Deadlines
- Bill calendar view
- Auto-reminders and optional auto-log on due date
- Track subscriptions specifically, with a "subscription audit" view showing total monthly recurring spend — helps people notice forgotten subscriptions

### 2.10 Debt & Lending Tracker (extra, addresses a very common real-world pain point)
- Track money you owe or are owed (friends, loans, "borrowed from Mama")
- Repayment schedule + reminders
- Included in the net-worth calculation

### 2.11 Reports & Export
- CSV/Excel/PDF export by date range
- Tax-season style annual summary
- Backup & restore (cloud sync or local encrypted file)

### 2.12 Insights Engine (light AI/rules layer)
- Pattern detection: "You spend 30% more on weekends"
- Suggestions: "Cutting eating-out by 20% would let you hit your 'New Laptop' goal 2 months earlier"
- Anomaly detection for possible fraud/duplicate charges

### 2.13 Gamification & Behavior Nudges (extra features for the "spends more than intended" problem)
- Streaks for staying under budget
- Badges for savings milestones
- "No-spend day" challenges and a monthly no-spend calendar
- A friendly "guilt-free spending" allowance — a small discretionary bucket you're allowed to spend freely, so budgeting doesn't feel purely restrictive

### 2.14 Settings & Customization
- Theme (light/dark/custom accent color)
- Custom icon/image library management (add, delete, organize)
- Notification preferences per alert type
- Data privacy controls (local-only mode vs cloud sync)

---

## 3. Suggested Data Model (high-level)

- **User**(id, name, currency, settings)
- **Wallet**(id, user_id, name, type, icon, balance)
- **Category**(id, user_id, name, icon/image, color, parent_category_id)
- **Transaction**(id, wallet_id, category_id, type[income/expense/transfer], amount, date, note, receipt_image, is_recurring, recurrence_rule)
- **Budget**(id, category_id, period, amount, rollover_flag)
- **SavingsGoal**(id, name, target_amount, current_amount, deadline, icon/image, auto_contribution_rule)
- **Bill**(id, name, amount, due_date, recurrence, wallet_id, reminder_lead_time)
- **Debt**(id, counterparty, amount, direction[owed_to_me/owed_by_me], due_date)
- **AlertRule**(id, type, threshold, target_id, is_active)

---

## 4. Suggested Architecture (building on your Flutter/MVVM background)

Given the Flutter expense tracker you already built with MVVM + Provider + Hive, this app extends naturally from that foundation:

- **Presentation**: Flutter, MVVM, Provider (or Riverpod if you want to reduce boilerplate as the app grows)
- **Local storage**: Hive (fast, works offline-first — critical since this is a daily-use app)
- **Background work**: Isolates for recalculating budgets/analytics without blocking UI, as you did before
- **Notifications**: `flutter_local_notifications` for on-device alerts; a lightweight rule engine that runs on every transaction write and on a daily scheduled check
- **Charts**: `fl_chart` or `syncfusion_flutter_charts`
- **Image/icon handling**: local file storage for receipt photos + a bundled custom icon set, with permanent storage (as you refined previously) rather than temp cache
- **Optional cloud sync**: Firebase or Supabase for backup/multi-device, kept optional to respect offline-first/privacy-first users

---

## 5. Suggested Build Order (MVP → Full Product)

1. Wallets + Transactions (income/expense) + Categories with icons
2. Budgets + basic expense alerts
3. Dashboard with core charts
4. Savings goals + deadline alerts
5. Bills/recurring transactions
6. Insights engine + financial health score
7. Debt tracker + gamification layer
8. Cloud sync/export/backup

---

*This blueprint is a living document — happy to turn any module into detailed screen flows, a database schema, or Flutter widget/file structure next.*
