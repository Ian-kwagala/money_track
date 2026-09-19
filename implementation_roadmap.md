# MoneyTrack Implementation Roadmap

## Phase 1 — Stabilize the MVP foundation

### Goal
Turn the current tracker into a more robust local-first finance app with a cleaner data model.

### Tasks
1. Strengthen the domain model
   - Add `User` profile support
   - Add `userId` to main records
   - Add timestamps and audit tracking
   - Add `RecurrenceRule` model

2. Improve transactions
   - Support split transactions
   - Add tags and filters
   - Improve category and wallet validation
   - Improve date range selection for reports

3. Refactor architecture
   - Split `MoneyRepository` into feature repositories or domain services
   - Split `TrackerViewModel` into smaller view models
   - Move complex analytics logic out of screens

4. Improve persistence safety
   - Add Hive migration strategy
   - Add backup export and local restore flow
   - Add data validation on import and seed

### Deliverable
A cleaner and more scalable base system before higher-value features are added.

---

## Phase 2 — Budget and alerting layer

### Goal
Move from passive tracking to active spending control.

### Tasks
1. Improve budgets
   - Add envelope budgeting
   - Add rollover settings
   - Add real-time budget remaining indicators
   - Add weekly/custom period budgets

2. Build alert engine
   - Add `AlertRule` model
   - Trigger alerts on budget thresholds
   - Trigger low-balance notifications
   - Add unusual spending detection
   - Add quiet hours and category-specific alert settings

3. Add notification integration
   - Use `flutter_local_notifications`
   - Schedule background checks for budget and balance alerts
   - Add daily/weekly digest generation

### Deliverable
The app starts warning users before overspending instead of only reporting after it happens.

---

## Phase 3 — Savings goals and recurrence

### Goal
Add the motivation layer described in the blueprint.

### Tasks
1. Add savings goals
   - Create model, repo, and view model
   - Add screens for goal creation and dashboard card
   - Add progress ring/bar visualizations
   - Add milestone states and celebration logic

2. Add recurring transactions and bill automation
   - Add recurrence rules
   - Allow auto-posting for recurring entries
   - Add bill creation and due-date reminders
   - Add subscriptions audit screen

3. Add smart contribution logic
   - Round-up savings rule
   - Auto-transfer from income to savings goals
   - Goal pace calculations

### Deliverable
Users can save intentionally and receive reminders and progress cues tied to real cash flow.

---

## Phase 4 — Bills, debt, and lifecycle tracking

### Goal
Cover the common personal finance edge cases that shape real-world spending behavior.

### Tasks
1. Add bill tracker
   - Bill model and due date management
   - Alert lead times
   - Calendar UI

2. Add debt tracker
   - Debt model
   - Owed to me / owed by me tracking
   - Repayment schedule and reminders

3. Add net worth and financial summary support
   - Include debt values in reporting
   - Add debt-impact widgets on dashboard

### Deliverable
The app becomes useful for real-life cash management, not just expense logging.

---

## Phase 5 — Analytics, health scoring, and insights

### Goal
Turn the app into an intelligent financial coach.

### Tasks
1. Add financial health score
   - savings rate
   - budget adherence
   - bill punctuality
   - debt management

2. Add insights engine
   - monthly spending patterns
   - category anomalies
   - suggestions to cut spending or save more

3. Add comparison reports
   - this month vs last month
   - month-over-month trends
   - category spike detection
   - annual summary reports

### Deliverable
The app gives proactive guidance, not just raw numbers.

---

## Phase 6 — Personalization and product polish

### Goal
Make the app feel premium and adaptable for different users.

### Tasks
1. Add profile management
   - Personal / Business / Family profiles
   - Separate settings and wallets by profile

2. Add theme and custom visuals
   - custom accent colors
   - icon library and uploaded assets
   - custom category images

3. Add onboarding and empty states
   - first-time setup wizard
   - feature introduction screens
   - polished empty states for goals, bills, and alerts

### Deliverable
The app becomes easier to onboard and more personalized for real users.

---

## Phase 7 — Backup, export, and scale

### Goal
Increase trust and operational readiness.

### Tasks
1. Add export expansion
   - PDF summary export
   - configurable date-range exports
   - annual report generation

2. Add backup and restore
   - encrypted local backup
   - restore flow with validation

3. Add optional cloud sync
   - Firebase or Supabase integration
   - offline-first conflict handling

### Deliverable
Users can trust the app with long-term financial data and multi-device use.

---

## Priority order recommendation

### Highest priority next
1. Savings goals
2. Alert engine and notifications
3. Bills and recurring transactions
4. Debt tracker
5. Budget enhancement layer

### Next wave
6. Financial health score
7. Insights engine
8. Custom category assets and personalization
9. Backup/export enhancements
10. Cloud sync

## Suggested delivery plan

### Sprint 1
- User model + profile structure
- Savings goal model + UI
- Budget enhancement groundwork

### Sprint 2
- Alert rules + notifications
- Recurrence rules + bill tracking

### Sprint 3
- Debt tracker + report integration
- Insights and trend analytics

### Sprint 4
- Export/backup + personalization + polish

## Final strategic note

The current app already successfully covers the accounting core. The next meaningful product leap is not more transaction fields; it is adding behavior-changing features that help users make better decisions before overspending happens.
