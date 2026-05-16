# Money Manager iOS Initial Design Specification

Date: 16 May 2026
Project path: `money-manager-ios`
Xcode project: `money-manager-ios/MoneyManager.xcodeproj`
Primary scheme: `MoneyManager`
Bundle identifier: `org.moneymanager.ios`
Minimum iOS target: iOS 17.0

This document is written for AI agents and future maintainers. It captures the current iOS app architecture, UI decisions, API contracts, state model, and known implementation details after the native iOS refactor performed on 16 May 2026.

## Product Summary

Money Manager is a native SwiftUI iOS client for a personal finance backend. It lets an authenticated user:

- Register or log in.
- View a monthly dashboard with balance, income, expenses, transaction count, category spending, and recent transactions.
- Browse all transactions for the selected month.
- Add, edit, and delete income or expense transactions.
- Manage custom categories for income and expense transactions.
- Export a CSV of transactions for a selected date range.
- Simulate a physical purchase signal through a developer action.

The app talks to a backend at `http://localhost:8080` by default. Authentication uses a bearer token saved in `UserDefaults`.

## Design Direction

The iOS app should use native iOS components as much as possible. Prefer SwiftUI platform controls and behaviors over custom Android-like affordances.

Important current decisions:

- Use `TabView` for the main authenticated shell.
- Use one `NavigationStack` per top-level screen.
- Use native large navigation titles and toolbar actions instead of custom headers or floating action buttons.
- Use `List`, `Form`, `Section`, `DatePicker`, `Picker`, toolbar cancellation/confirmation actions, and swipe actions for standard iOS interactions.
- Use iOS 17 Swift Charts for the dashboard category donut chart.
- Keep custom visual components only where they express app-specific data, such as category badges, summary cards, metric tiles, and chart legends.

Avoid reintroducing:

- Custom floating add buttons over the tab bar.
- `TextField("YYYY-MM-DD")` date entry.
- Hidden navigation bars with hand-built large titles.
- Scroll-view card stacks for content that needs native list row behaviors such as swipe-to-delete.
- Gesture-only row interactions when native `Button`, `NavigationLink`, or `List` row behaviors fit.

## Source Layout

Key folders under `money-manager-ios/MoneyManager/Sources`:

- `App/`
  - `MoneyManagerApp.swift`: app entry point; creates root `MoneyManagerStore`.
  - `AppRootView.swift`: authentication switch, authenticated `TabView`, sheet presentation.
- `Models/`
  - `Models.swift`: API models, app tabs, app sheets, derived view models.
- `Store/`
  - `MoneyManagerStore.swift`: main `@Observable` state store and app actions.
- `Services/`
  - `MoneyManagerAPI.swift`: URLSession client and API error handling.
  - `TokenStore.swift`: token persistence wrapper around `UserDefaults`.
- `Screens/`
  - `AuthView.swift`: login/register screen.
  - `DashboardView.swift`: monthly dashboard and recent transaction rows.
  - `TransactionsView.swift`: full month transaction list.
  - `TransactionEditorView.swift`: transaction editor, category picker, export flow.
  - `ProfileView.swift`: account, connection, export, developer, logout.
- `Components/`
  - `SharedComponents.swift`: app cards, metric tiles, category badges, buttons, banners, headers.
- `DesignSystem/`
  - `AppTheme.swift`: colors, metrics, category titles/icons, background modifier.
- `Utilities/`
  - `Formatters.swift`: money/date formatting helpers.
  - `ShareSheet.swift`: UIKit `UIActivityViewController` bridge for sharing exports.

Tests:

- `money-manager-ios/MoneyManagerTests/MoneyManagerTests.swift`

## App Entry And Root State

`MoneyManagerApp` is `@MainActor` and owns the store:

- `@State private var store = MoneyManagerStore()`
- `WindowGroup { AppRootView(store: store) }`

`AppRootView` uses `@Bindable var store`. It switches between:

- `AuthView` when `store.isAuthenticated == false`
- `AuthenticatedAppView` when `store.isAuthenticated == true`

It calls `await store.bootstrap()` in `.task` so a previously saved token can load categories and dashboard data.

The root applies `.tint(AppColor.financeGreen)`.

## Authenticated Shell

`AuthenticatedAppView` is a native `TabView` bound to `store.selectedTab`.

Tabs:

- Dashboard: `DashboardView`
- Transactions: `TransactionsView`
- Profile: `ProfileView`

Each tab is tagged with `AppTab`.

Sheets:

- `store.activeSheet == .transactionEditor` presents `TransactionEditorView`
  - `.presentationDetents([.large])`
  - visible drag indicator
- `store.activeSheet == .categoryPicker` presents `CategoryPickerView`
  - `.presentationDetents([.medium, .large])`
  - visible drag indicator
- `store.activeSheet == .exportTransactions` presents `ExportTransactionsView`
  - `.presentationDetents([.medium])`
  - visible drag indicator

Export sharing:

- `store.exportShareItem` presents `ShareSheet(items: [item.url])`.
- `ShareSheet` wraps `UIActivityViewController`.

Important behavior:

- Do not put a floating plus button over the tab bar. Add transaction actions live in native toolbars on Dashboard and Transactions.

## Store Architecture

`MoneyManagerStore` is:

- `@MainActor`
- `@Observable`
- The single app-level state owner.

Injected dependencies:

- `MoneyManagerAPI`
- `TokenStore`

Default dependencies:

- `MoneyManagerAPI(baseURL: URL(string: "http://localhost:8080")!)`
- `TokenStore()`

Primary state:

- `token: String?`
- `email: String`
- `password: String`
- `selectedTab: AppTab`
- `activeSheet: AppSheet?`
- `isRegisterMode: Bool`
- `isLoading: Bool`
- `error: String?`
- `month: String`, formatted as `yyyy-MM`
- `filterType: String?`
- `filterCategory: String?`
- `summary: TransactionSummary?`
- `transactions: [Transaction]`
- `selectedExpenseCategory: String?`
- transaction form state:
  - `editingID: Int?`
  - `formType: String`
  - `formCategory: String`
  - `formAmount: String`
  - `formOccurredAt: Date`
- category state:
  - `expenseCategories: [Category]`
  - `incomeCategories: [Category]`
  - `newCategoryName: String`
- export state:
  - `exportFrom: Date`
  - `exportTo: Date`
  - `exportShareItem: ExportShareItem?`

Date form fields intentionally use `Date`, not strings. Convert to API strings only when creating requests.

## Derived Store Values

`isAuthenticated`:

- True when `token != nil`.

`canGoNextMonth`:

- Prevents navigating into future months.
- Compares `month` against `DateFormat.currentMonthKey()`.

`expenseCategoryTotals`:

- Filters `transactions` to expenses.
- Groups by category.
- Converts amount strings to `Decimal`.
- Drops zero totals.
- Sorts descending by amount.
- Used by Dashboard chart and category legend.

`dayBuckets`:

- Filters through `filteredTransactions`.
- Groups transactions by `occurredAt` date.
- Sorts transactions inside a day by `occurredAt` descending, then `id` descending for ties.
- Computes daily balance:
  - income adds amount
  - expense subtracts amount
- Sorts day buckets newest first.
- Used by Dashboard recent sections and Transactions full list.

`formCategoryOptions`:

- Uses income categories when `formType == "income"`, otherwise expense categories.
- Includes a temporary category when editing a transaction whose category is not in the currently loaded category list.

`filteredTransactions`:

- Applies `filterType`.
- Applies `filterCategory`.
- Applies `selectedExpenseCategory` from dashboard chart interaction.

Note: `filterCategory` currently has state support but no first-class UI in the current iOS screens.

## Store Action Flow

Bootstrap:

- If no token, no-op.
- Loads categories and refreshes dashboard.

Auth:

- `submitAuth()` validates email/password.
- Calls `/auth/register` or `/auth/login`.
- Saves token to `TokenStore`.
- Stores returned user email.
- Clears password.
- Loads categories and dashboard.

Logout:

- Clears token from `TokenStore`.
- Clears token/password.
- Resets selected tab to dashboard.
- Clears active sheet, summary, transactions, selected category, categories, and form.

Month navigation:

- `previousMonth()` and `nextMonth()` call `moveMonth(by:)`.
- Moving month clears selected expense category and refreshes.
- Next month is blocked by `canGoNextMonth`.

Refreshing:

- `refresh()` launches a `Task` and calls `refreshDashboard()`.
- `refreshDashboard()` fetches summary and transactions concurrently for current month.

Dashboard category filtering:

- `selectExpenseCategory(_:)` toggles selected category.
- `clearSelectedExpenseCategory()` clears it.

Transaction editor:

- `openNewTransactionForm()` clears form and opens editor.
- `openPhysicalPurchaseForm()` clears form, sets expense/shopping defaults, opens editor.
- `editTransaction(_:)` copies transaction fields into form state and opens editor.
- `updateFormType(_:)` switches type and resets category to first available category or fallback.
- `saveTransaction()` validates amount and category, then creates or updates.
- `deleteTransaction(_:)` calls API delete and refreshes dashboard.

Category picker:

- `chooseFormCategory(_:)` sets category, clears new-category field, returns to transaction editor sheet.
- `addCategory()` validates name, creates category, reloads category lists, selects the new category, returns to editor.
- `deleteCategory(_:)` refuses default categories and category id `0`, deletes custom category, reloads categories, and resets selected form category if needed.

Export:

- `openExportDialog()` sets export dates to first day of current month through today, clears errors, opens export sheet.
- `exportTransactions()` validates date ordering, calls CSV export, writes a temp file, sets `exportShareItem`, and closes export sheet.

Request wrapper:

- `runRequest(_:)` sets `isLoading = true`, clears `error`, executes async operation, handles unauthorized by clearing token, stores localized error, and resets `isLoading`.

Important agent note:

- `runRequest` is global to the store. A long-running action marks the entire app loading. Be careful adding concurrent UI actions that rely on independent loading states.

## API Client

`MoneyManagerAPI` is a lightweight URLSession client.

Default base URL:

- `http://localhost:8080`

Endpoints:

- `POST /auth/register`
  - body: `{"email": "...", "password": "..."}`
  - returns `AuthResult`
- `POST /auth/login`
  - body: `{"email": "...", "password": "..."}`
  - returns `AuthResult`
- `GET /transactions/summary?month=yyyy-MM`
  - bearer token required
  - returns `TransactionSummary`
- `GET /transactions?month=yyyy-MM&type=expense|income&category=name`
  - bearer token required
  - current app usually fetches all month transactions and filters locally
  - returns `[Transaction]`
- `POST /transactions`
  - bearer token required
  - body: `TransactionRequest`
  - returns `Transaction`
- `PUT /transactions/{id}`
  - bearer token required
  - body: `TransactionRequest`
  - returns `Transaction`
- `DELETE /transactions/{id}`
  - bearer token required
  - expects empty response
- `GET /transactions/export?from=yyyy-MM-dd&to=yyyy-MM-dd`
  - bearer token required
  - returns CSV text
- `GET /categories?type=expense|income`
  - bearer token required
  - returns `[Category]`
- `POST /categories`
  - bearer token required
  - body: `CategoryRequest`
  - returns `Category`
- `DELETE /categories/{id}`
  - bearer token required
  - expects empty response

Request details:

- Timeout: 10 seconds.
- `Accept: application/json`.
- `Content-Type: application/json` for encoded bodies.
- Bearer token header: `Authorization: Bearer <token>`.
- For non-2xx responses:
  - HTTP 401 maps to `APIError.unauthorized`.
  - Other errors try to parse JSON `{ "error": "..." }`.
  - Fallback is raw response text, then HTTP status message.

Known limitation:

- The API client creates a new `JSONDecoder` and `JSONEncoder` per request. This is fine for now.
- Request body date fields are already strings in `yyyy-MM-dd`; do not set custom date strategies unless models change.

## Models

`TransactionType`:

- `expense`
- `income`

`User`:

- `id`
- `email`

`AuthResult`:

- `token`
- `user`

`Transaction`:

- `id: Int`
- `type: String`
- `category: String`
- `amount: String`
- `currency: String`
- `occurredAt: String`, decoded from `occurred_at`

`TransactionRequest`:

- `type`
- `category`
- `amount`
- `currency`, default `"EUR"`
- `occurredAt`, encoded as `occurred_at`

`Category`:

- `id`
- `type`
- `name`
- `isDefault`, decoded from `is_default`

`CategoryRequest`:

- `type`
- `name`

`TransactionSummary`:

- `month`
- `income`
- `expense`
- `balance`
- `currency`
- `transactionCount`, decoded from `transaction_count`

Derived display models:

- `CategoryTotal`
  - `category`
  - `amount`
  - id is category
- `DayBucket`
  - `date`
  - `balanceChange`
  - `transactions`
  - id is date

Navigation/support enums:

- `AppTab`: `dashboard`, `transactions`, `profile`
- `AppSheet`: `transactionEditor`, `categoryPicker`, `exportTransactions`

## Formatting

`MoneyFormat`:

- Uses `NumberFormatter` with `.decimal`.
- Locale is `en_US_POSIX`.
- Minimum and maximum fraction digits are 2.
- `decimal(from:)` uses `Decimal(string:locale:)`, falling back to `.zero`.
- `amount(_:currency:)` prepends a symbol and formats two decimals.
- `signed(_:currency:)` prepends `+` or `-`.
- Supported symbols:
  - EUR: `€`
  - USD: `$`
  - GBP: `£`
  - fallback: uppercase currency code plus space.

`DateFormat`:

- `isoDate`: `yyyy-MM-dd`, Gregorian, `en_US_POSIX`
- `monthKey`: `yyyy-MM`, Gregorian, `en_US_POSIX`
- `displayMonth`: `MMMM yyyy`, Gregorian, `en_US_POSIX`
- `dayHeader`: `EEE, MMM d`, Gregorian, `en_US_POSIX`
- `dateOnly(_:)`: first 10 chars of backend date string
- `monthDisplay(_:)`: converts `yyyy-MM` to display month
- `todayString()`
- `currentMonthKey()`
- `firstDay(of:)`
- `firstDayDate(of:)`
- `apiDate(_:)`

Important: UI date inputs use `DatePicker` and `Date`. Convert with `DateFormat.isoDate.string(from:)` only at the API boundary.

## Screen Details

### AuthView

Purpose:

- Handles login and registration before a token exists.

Structure:

- `ScrollView`
- Branding text
- preview balance card
- email input
- password/secure input with visibility toggle
- error banner
- primary submit button
- secondary auth-mode toggle

State:

- `store.email`
- `store.password`
- `store.isRegisterMode`
- local `@State isPasswordVisible`

Native opportunities:

- Could eventually become a `Form`, but current landing-style auth screen is acceptable because it is a custom first-run surface and not a settings/editor list.

### DashboardView

Purpose:

- Main financial overview for the selected month.

Structure:

- `NavigationStack`
- `List` with `.insetGrouped`
- hidden scroll content background and app background
- sections:
  - balance
  - summary metrics
  - spending by category
  - recent transactions

Toolbar:

- Leading toolbar group:
  - previous month button
  - next month button
- Principal toolbar:
  - current month display
- Primary action:
  - add transaction

Recent transactions:

- Uses real `List` sections and reusable `TransactionListRow`.
- This is intentional so swipe-to-delete works on dashboard recent rows.
- Shows up to 4 day buckets.
- Each day shows up to 3 transactions.

Spending chart:

- Uses Swift Charts `Chart` and `SectorMark`.
- Bound to `selectedAngle` via `.chartAngleSelection`.
- Converts selected angle into a category by summing category amounts.
- Selecting a category filters `store.dayBuckets` through `selectedExpenseCategory`.

Agent warning:

- Do not put recent transactions back into `DayBucketCard` if swipe-to-delete is expected. `DayBucketCard` is a custom card and cannot provide native list row swipe behavior by itself.

### TransactionsView

Purpose:

- Full transaction browser for the selected month.

Structure:

- `NavigationStack`
- `List`
- top section with month label, filter row, error banner
- day sections with transaction rows
- empty state when no transactions

Toolbar:

- Primary action add transaction.

Filters:

- Horizontal filter pills:
  - All
  - Expense
  - Income
- These update `store.filterType`.

Rows:

- `TransactionListRow` is a reusable list row.
- Primary tap/button action: `store.editTransaction(transaction)`.
- Swipe action: destructive delete via `store.deleteTransaction(transaction.id)`.
- Accessibility delete action is provided.
- Uses `.buttonStyle(.plain)` to keep row visuals.

Agent warning:

- Swipe actions require the row to be inside a `List`.
- If a row is placed inside `ScrollView`, `VStack`, or custom cards, swipe gestures will not behave like native iOS list swipe.

### TransactionEditorView

Purpose:

- Add or edit a transaction.

Structure:

- `NavigationStack`
- `Form`
- segmented picker for transaction type
- details section:
  - amount `TextField` with decimal keyboard
  - category selector row
  - native `DatePicker`
- error section when needed

Toolbar:

- Cancellation action:
  - "Cancel"
  - clears form, closes sheet
- Confirmation action:
  - "Save"
  - disabled when `store.isLoading`

Title:

- "Edit transaction" when `editingID != nil`
- "Add income" when form type is income
- "Add expense" otherwise

Category selection:

- Category selector is a button row that sets `activeSheet = .categoryPicker`.

Important:

- Form date is `store.formOccurredAt: Date`.
- Do not reintroduce manual `YYYY-MM-DD` fields.

### CategoryPickerView

Purpose:

- Choose, create, and delete transaction categories.

Structure:

- `NavigationStack`
- `List` with `.insetGrouped`
- category section with rows
- new category section with `TextField` and add button
- error section when needed

Rows:

- Tapping a row calls `store.chooseFormCategory(category.name)`.
- Current category shows a checkmark.
- Custom categories can be deleted with trailing swipe action.
- Default categories and id `0` categories are not deletable.

### ExportTransactionsView

Purpose:

- Select date range and export CSV.

Structure:

- `NavigationStack`
- `Form`
- date range section:
  - native `DatePicker` for from
  - native `DatePicker` for to
- footer explaining CSV share
- error section when needed

Toolbar:

- Cancellation action:
  - closes sheet
- Confirmation action:
  - "Export"
  - disabled while loading

Flow:

- `store.exportTransactions()` fetches CSV and writes a temp file.
- `store.exportShareItem` triggers `ShareSheet`.

### ProfileView

Purpose:

- Account and app actions.

Structure:

- `NavigationStack`
- `.insetGrouped` `List`
- native sections:
  - account status
  - connection
  - data export
  - developer action
  - logout
  - error section

Actions:

- Export transactions opens export sheet.
- Simulate purchase signal opens transaction editor prefilled as expense/shopping.
- Logout is a destructive role button.

## Shared Components

`AppCard`:

- White or configured background.
- Rounded rectangle, border, padding.
- Used in dashboard cards and auth preview.

`MetricTile`:

- Used for income/expenses/count summary.

`CategoryBadge`:

- Circle background with SF Symbol based on category.

`FilterPill`:

- Custom button for transaction type filters.

`PrimaryButton` and `SecondaryButton`:

- Still exist for auth/profile legacy surfaces.
- Prefer native toolbar actions and standard `Button` roles in new form/list screens.

`ErrorBanner`:

- Text-only error display.
- Used in older custom surfaces and some list header contexts.

`ScreenHeader`:

- Still exists but should not be used for main native navigation headers.
- Prefer `.navigationTitle`.

## Theme

`AppColor` defines:

- `background`
- `surface`
- `softGreenSurface`
- `softGreenCard`
- `financeGreen`
- `nearBlack`
- `mutedText`
- `divider`
- `expense`
- `income`
- category colors

`AppMetric` defines:

- `cardRadius = 22`
- `controlRadius = 16`
- `sectionSpacing = 18`

`View.appBackground()`:

- Applies `AppColor.background.ignoresSafeArea()`.

Category helpers:

- `categoryTitle(_:)`: capitalizes first character only.
- `categorySymbol(_:)`: maps known category names to SF Symbols.
- `amountColor(_:)`: income green, expense red, zero muted.

## Persistence

`TokenStore`:

- Stores auth token in `UserDefaults`.
- Used by `MoneyManagerStore`.

Security note:

- This is acceptable for a local prototype but not ideal for production. Prefer Keychain for tokens in a production iOS app.

## Native iOS UX Rules For Future Agents

When adding or changing screens:

- Use `Form` for editors/settings.
- Use `List` for browsable collections that need selection, swipe actions, deletion, or sections.
- Use `DatePicker` for dates.
- Use `Picker` for finite options.
- Use toolbar placements:
  - `.cancellationAction`
  - `.confirmationAction`
  - `.primaryAction`
  - `.topBarLeading`
  - `.principal`
- Use `Button(role: .destructive)` for destructive actions.
- Use native `.swipeActions` only on views that are actual `List` rows.
- Use `.refreshable` for pull-to-refresh.
- Use `NavigationStack` and `.navigationTitle` for screen titles.
- Prefer `ShareSheet` or future native share APIs for exporting.

When not to use custom components:

- Do not build fake text fields from `HStack` + backgrounds unless there is no native equivalent.
- Do not build custom date strings.
- Do not hide navigation bars to emulate headers.
- Do not use floating action buttons over tab bars.
- Do not use custom scroll containers for row collections that need native editing gestures.

## Known Current Limitations

- Backend base URL is hardcoded in both `MoneyManagerAPI` and `ProfileView` as `http://localhost:8080`.
- Token storage uses `UserDefaults`, not Keychain.
- Global `isLoading` may disable or visually affect unrelated operations.
- No confirmation dialog before deleting a transaction or custom category.
- Transaction amount is still a string in UI and model because the backend sends amount as a string.
- Currency is always `"EUR"` for transaction requests by default.
- Profile connection status is inferred from `isLoading`, not an actual health check.
- Auth screen is still more custom than the rest of the app.
- There are no SwiftUI previews currently documented as required.
- There is no dedicated UI test coverage for swipe actions, sheets, or chart selection.

## Testing And Verification

Current test file:

- `money-manager-ios/MoneyManagerTests/MoneyManagerTests.swift`

Current tests cover:

- Decoding backend models.
- Building API request query strings and auth header.
- Money formatting and signed amounts.
- Derived category totals and day buckets.

Recent verification after native iOS refactor:

- `build_sim` succeeded for scheme `MoneyManager` on iPhone 17 Pro simulator.
- `test_sim` succeeded with 4 passed, 0 failed.

XcodeBuildMCP session used:

- Project: `/Users/ivanivanov/projects/money-manager/money-manager-ios/MoneyManager.xcodeproj`
- Scheme: `MoneyManager`
- Configuration: `Debug`
- Simulator: `iPhone 17 Pro`

Recommended future tests:

- Unit test date conversion between `Date` and API `yyyy-MM-dd`.
- Unit test `openExportDialog()` date defaults.
- UI test add/edit/delete transaction flows.
- UI test dashboard recent row swipe-to-delete.
- UI test Transactions tab swipe-to-delete.
- UI test category creation and custom category deletion.

## Safe Change Checklist For Future Agents

Before editing:

- Inspect current source files; this spec may be stale after later changes.
- Check whether a requested interaction needs native `List` or `Form`.
- Keep state in `MoneyManagerStore` unless there is a clear local-only reason.
- Keep `Date` in UI state for date controls.

During editing:

- Prefer small SwiftUI subviews over giant `body` blocks.
- Do not duplicate transaction row implementations; reuse `TransactionListRow` when possible.
- Keep deletion actions in `List` row context.
- Keep API request string conversion at the API boundary.
- Preserve backend coding keys such as `occurred_at`, `is_default`, and `transaction_count`.

After editing:

- Build the iOS simulator target.
- Run the test target.
- If UI gestures changed, manually verify in Simulator when possible.
- Update this spec if architecture, state shape, API contracts, or major UI patterns change.

## Glossary

Dashboard selected expense category:

- A category selected through the spending chart. It filters expense transactions shown in dashboard recent transactions and also affects derived `dayBuckets`.

Physical purchase signal:

- Developer/profile action that opens the transaction editor prefilled as an expense in the `shopping` category.

Day bucket:

- A grouped set of transactions for one calendar day, including the net balance change for that day.

Active sheet:

- The app-level modal enum `AppSheet?` in `MoneyManagerStore`.

Export share item:

- A temporary CSV file URL wrapped in `ExportShareItem` to drive SwiftUI sheet presentation.
