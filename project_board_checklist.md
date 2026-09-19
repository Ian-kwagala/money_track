# MoneyTrack Project Board Checklist

## Product backlog / MVP gap list

### Core data foundation
- [ ] Add `User` model and profile support
- [ ] Add `SavingsGoal` model and persistence
- [ ] Add `Bill` model and recurring schedule support
- [ ] Add `Debt` model and repayment tracking
- [ ] Add `AlertRule` model and rule engine data
- [ ] Add `RecurrenceRule` model for recurring transactions and bills
- [ ] Add `userId` relationships to wallets, categories, budgets, bills, debts, and goals
- [ ] Add timestamps: `createdAt`, `updatedAt`, `deletedAt`

### Wallets and transactions
- [ ] Improve transaction split support
- [ ] Add tag support for transactions
- [ ] Add richer attachment metadata beyond receipt path
- [ ] Improve transfer logic for multi-wallet workflows
- [ ] Add advanced search filters: date range, wallet, category, amount, tags
- [ ] Add transaction editing improvements and validation

### Categories and customization
- [ ] Add custom category images and emoji support
- [ ] Add category library / icon management panel
- [ ] Support sub-categories and nested hierarchy
- [ ] Improve category color consistency in charts and UI

### Budgeting
- [ ] Add envelope-style budgeting
- [ ] Add rollover rule configuration
- [ ] Add remaining-budget indicators during entry
- [ ] Add weekly and custom budget views
- [ ] Add budget alerts when close to or over limit

### Savings goals
- [ ] Create savings goal creation screen
- [ ] Add target and deadline management
- [ ] Add progress tracking UI
- [ ] Add milestone states and celebration flow
- [ ] Add auto-contribution logic
- [ ] Add round-up savings logic
- [ ] Add goal pace alerts

### Alerts and notifications
- [ ] Add spending alert rules for 80% / 100% budget thresholds
- [ ] Add unusual spending warnings
- [ ] Add low-balance warnings
- [ ] Add daily/weekly digest notifications
- [ ] Add deadline reminders for bills and goals
- [ ] Add quiet hours and notification preferences per alert type

### Bills and recurring items
- [ ] Add bill calendar view
- [ ] Add recurring bill creation and reminders
- [ ] Add subscription audit view
- [ ] Add due-date alert integration

### Debt tracking
- [ ] Add debt entry screen
- [ ] Add repayment schedule support
- [ ] Add debt summary in reports/dashboard
- [ ] Add reminder logic for due debt payments

### Analytics and insights
- [ ] Add financial health score
- [ ] Add spending pattern analysis
- [ ] Add insight suggestions
- [ ] Add anomaly detection for unusual expenses
- [ ] Add comparison views: month-over-month, year-over-year

### Export and backup
- [ ] Add PDF report generation
- [ ] Add annual summary export
- [ ] Add backup and restore flow
- [ ] Add cloud sync option or encrypted local backup

### Personalization and app polish
- [ ] Add onboarding flow
- [ ] Add custom accent theme support
- [ ] Add light/dark/custom theme presets
- [ ] Add profile switching for personal/business/family use
- [ ] Add empty states and polish for all screens

### Quality and architecture
- [ ] Split repository logic into feature services
- [ ] Split ViewModel into feature-specific view models
- [ ] Add validation and error handling for all screens
- [ ] Add tests for repository and business logic
- [ ] Add migration logic for Hive schema updates

## Ready for development board

### High priority
- [ ] Savings goals
- [ ] Alert system
- [ ] Bills and recurring reminders
- [ ] Debt tracker
- [ ] Budget enhancements

### Medium priority
- [ ] Advanced analytics and insights
- [ ] Category customization
- [ ] Multi-profile support
- [ ] Export and backup improvements

### Lower priority / stretch goals
- [ ] Gamification
- [ ] Cloud sync
- [ ] Full personalization system
- [ ] Financial health score maturity
