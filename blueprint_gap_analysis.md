 MoneyTrack Blueprint Gap Analysis

This file compares the current Flutter app against the blueprint in [money-tracker-app-blueprint.md](money-tracker-app-blueprint.md).

 1. What the current project already covers well

The current app already includes the foundation for a solid MVP:

- Wallets and wallet types
- Income, expense, and transfer transactions
- Categories with icon/color mapping
- Monthly budgets by category
- Dashboard summaries
- Reports by date range
- Settings such as dark mode, currency, notifications
- Local persistence with Hive
- Provider-based MVVM structure
- Receipt attachment using local file paths

Core implementation files:

- [lib/models/wallet.dart](lib/models/wallet.dart)
- [lib/models/transaction.dart](lib/models/transaction.dart)
- [lib/models/category.dart](lib/models/category.dart)
- [lib/models/budget.dart](lib/models/budget.dart)
- [lib/models/app_settings.dart](lib/models/app_settings.dart)
- [lib/data/money_repository.dart](lib/data/money_repository.dart)
- [lib/viewmodels/tracker_view_model.dart](lib/viewmodels/tracker_view_model.dart)
- [lib/ui/home_shell.dart](lib/ui/home_shell.dart)

 2. Missing models from the blueprint

The blueprint defines several models that are not yet represented in the current app.

 A. User model
Missing:
- user id
- name
- currency preferences
- locale defaults
- profile settings / app preferences per user
- multi-profile or multi-tenant support

Current status:
- App settings are stored in a single `AppSettings` object, but there is no dedicated `User` model or user relationship layer.

 B. SavingsGoal model
Missing:
- goal id
- name
- target amount
- current amount
- deadline
- icon/image reference
- auto-contribution rule
- round-up saving rule
- progress tracking

Current status:
- There is no goal savings module and no UI or repository logic for it.

 C. Bill model
Missing:
- bill name
- amount
- due date
- recurring pattern
- reminder lead time
- wallet association
- recurring bill calendar

Current status:
- Bills are not modeled or tracked anywhere.

 D. Debt model
Missing:
- counterparty
- owed amount
- direction (owed to me / owed by me)
- due date
- repayment schedule
- reminder state

Current status:
- There is no debt tracker, despite being a valuable real-world requirement in the blueprint.

 E. AlertRule model
Missing:
- alert type
- threshold
- target category/wallet/goal
- is active
- notification schedule / quiet hours

Current status:
- Notification switch exists, but there is no rule engine or structured alerts system.

 F. Recurrence rule / rule metadata
Missing:
- transaction recurrence structure
- frequency type (daily / weekly / monthly / yearly)
- next occurrence date
- recurrence end date
- auto-posting flag

Current status:
- `TxRecord` has `isRecurring`, but no recurrence schema or automation logic.

 G. Parent/child category hierarchy model
Current category model includes `parentCategoryId`, but the app does not really implement:
- sub-category trees
- category grouping
- nested UI and analytics by parent category

 H. Multi-currency / multi-wallet user data model
Current app supports a single default currency and default settings, but not:
- multiple currency wallets
- exchange-rate-aware summaries
- multi-currency conversion tracking

 3. Missing features from the blueprint

 Authentication & profile
Missing:
- login/signup flow
- biometric / PIN / app lock
- multi-profile support
- user-specific data isolation

Improvement needed:
- Add a simple auth layer, or at least a local PIN/biometric lock screen if privacy is a priority.

 Budgeting depth
Current app supports simple category budgets, but the blueprint expects more:
- envelope-style budgeting
- rollover rules
- real-time remaining budget indicator during entry
- weekly and custom budget views
- per-wallet or per-period budget logic

 Savings goals
Missing entirely:
- goal creation
- target vs saved progress
- goal deadline tracking
- milestones
- auto-contribution and round-up logic

 Alerts and notifications engine
Current app only has a general notification toggle in settings.
Missing:
- expense alerts at 80% / 100% budget usage
- unusual spending alert
- low balance alert
- goal pace alerts
- deadline reminders
- daily/weekly digest
- quiet hours

 Bills and recurring deadlines
Missing:
- bill calendar
- recurring reminder flows
- subscription audit view
- renewal tracking

 Debt tracker
Missing:
- debt capture and repayment monitoring
- real-time debt summary in net worth/reporting

 Insights / intelligence engine
Missing:
- pattern detection
- suggestions to save more
- anomaly detection
- spending score / financial health score

 Gamification layer
Missing:
- no-spend streaks
- badges
- milestone celebrations
- discretionary allowance style budgeting

 Backup / restore / export expansion
Current project has CSV export only.
Missing:
- PDF export
- backup/restore
- cloud sync or encrypted local backup
- annual tax summary

 Custom category images and richer icon handling
Current category system supports icons, but not:
- custom uploaded images
- emoji library
- icon organization / library management
- custom visual assets tied to categories

 Search and filtering depth
Current app supports search and day filter, but not the full blueprint capabilities:
- date range filtering
- category filtering
- wallet filtering
- amount-based filtering
- tag filtering
- advanced query combinations

 Multi-profile / business-personal split
There is a `profileName` field, but no real profile management or multiple personas like:
- Personal
- Business
- Family

 4. Improvement areas in the current app

 A. Repository architecture
The repository is already functional, but it would benefit from:
- separate domain services for wallets, categories, budgets, goals, bills, debts, alerts
- helper methods for period calculations and totals
- support for advanced query filters instead of ad hoc logic in screens
- clearer separation between persistence and business rules

 B. View model structure
Current view model is good for MVP, but it is getting full of UI-facing queries. It should probably be split into smaller view models or feature-specific services, especially when goals, alerts, debt, and bills are added.

 C. Transaction model limitations
The current transaction model is strong, but it needs more power:
- split transactions
- recurrence rule metadata
- tags
- transaction attachments beyond receipt path
- better support for transfer semantics and overlapping wallet logic

 D. Data modeling improvements
Recommended changes in the models:
- add `userId` to wallets, categories, budgets, goals, bills, and debts
- add explicit `recurrenceRule` object or nested model
- add `createdAt`, `updatedAt`, `deletedAt` timestamps
- add `imagePath` or `assetRef` to category and savings goal
- add `alertId` and alert thresholds to settings

 E. UI behavior improvements
- add onboarding flow for first-time setup
- add empty-state panels for budgets, goals, alerts, and bills
- add quick-add shortcuts for common expense categories
- add better validation for amount, transfer wallet, and budget entry
- improve date filtering and chart range selection
- add pull-to-refresh or refresh state on screens

 F. Theme and customization
The app already has light/dark mode, but the blueprint expects more:
- custom accent color
- custom theme presets
- per-profile styling
- richer icon and image library management

 G. Reporting and exports
The app should expand beyond CSV export:
- PDF report generation
- yearly financial summary
- monthly statement export
- backup and restore import/export

 H. Notifications and background logic
There is a notification toggle, but not the actual behavior engine.
Need:
- scheduler for periodic checks
- local notification plugin integration
- daily digest logic
- budget threshold alerts
- low-balance reminders

 5. Suggested model additions to implement next

These are the most important additions for the blueprint roadmap:

- User
- SavingsGoal
- Bill
- Debt
- AlertRule
- RecurrenceRule
- CategoryImageAsset or custom icon reference
- UserProfile / MultiProfile

 6. Recommended priority order

 MVP next steps
1. Add savings goals model and screen
2. Add recurring transaction logic and bill tracker
3. Add alert engine and notification rules
4. Add debt tracking
5. Improve budgets with rollover + envelope options
6. Add better custom categories and media support

 Later product stages
1. Insights engine
2. Financial health score
3. Gamification
4. Cloud sync / backup / restore
5. Multi-user profiles and advanced personalization

 7. Final assessment

The project is already a strong MVP and honestly exceeds a basic expense tracker. It has a good foundation in Hive, Provider, UI structure, and dashboard/reporting.

The biggest gaps are not the core tracking features, but the behavior-change modules from the blueprint:
- savings goals
- alerts and nudges
- bills and recurrence
- debt tracking
- insights and motivation layers
- deeper personalization and user model support

In other words: the app is already great as a personal finance tracker, but it is not yet a full “behavior-change money app” as described in the blueprint.
