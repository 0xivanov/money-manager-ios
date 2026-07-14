import SwiftUI

struct TransactionsView: View {
    @Bindable var store: MoneyManagerStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    MonthNavigator(
                        month: store.month,
                        canGoNext: store.canGoNextMonth,
                        isLoading: store.dashboardLoadState == .loading,
                        previous: store.previousMonth,
                        next: store.nextMonth
                    )
                    .listRowBackground(Color.clear)
                }

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        FilterRow(store: store)
                        CategoryFilterRow(store: store)
                        ErrorBanner(message: store.error)
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 8, trailing: 20))
                }

                if case .failed(let message) = store.dashboardLoadState, store.summary != nil {
                    Section {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .foregroundStyle(AppColor.expense)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Showing saved results")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppColor.nearBlack)
                                Text(message)
                                    .font(.footnote)
                                    .foregroundStyle(AppColor.mutedText)
                            }
                            Spacer()
                            Button("Retry", action: store.retryDashboard)
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(.vertical, 4)
                    }
                }

                if store.dashboardLoadState == .loading, store.summary == nil {
                    Section {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Loading transactions…")
                                .foregroundStyle(AppColor.mutedText)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                } else if case .failed(let message) = store.dashboardLoadState, store.summary == nil {
                    Section {
                        AppCard(color: AppColor.surface, padding: 24) {
                            VStack(spacing: 12) {
                                Image(systemName: "wifi.exclamationmark")
                                    .font(.system(size: 30, weight: .semibold))
                                    .foregroundStyle(AppColor.expense)
                                Text("Couldn’t load transactions")
                                    .font(.headline)
                                    .foregroundStyle(AppColor.nearBlack)
                                Text(message)
                                    .font(.subheadline)
                                    .foregroundStyle(AppColor.mutedText)
                                    .multilineTextAlignment(.center)
                                Button("Try again", action: store.retryDashboard)
                                    .buttonStyle(.borderedProminent)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                        .listRowBackground(Color.clear)
                    }
                } else if store.transactionDayBuckets.isEmpty {
                    Section {
                        EmptyState(
                            title: store.hasActiveTransactionFilters ? "No matches" : "No transactions",
                            message: store.hasActiveTransactionFilters
                                ? "Try changing or resetting your filters."
                                : "Use the add button to start this month’s ledger."
                        )
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                        .listRowBackground(Color.clear)
                    }
                } else {
                    ForEach(store.transactionDayBuckets) { bucket in
                        NativeDaySection(bucket: bucket, store: store)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .refreshable { await store.refresh() }
            .searchable(
                text: $store.searchQuery,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Description, category, amount, or date"
            )
            .appBackground()
            .navigationTitle("Transactions")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: store.openNewTransactionForm) {
                        Label("Add transaction", systemImage: "plus")
                    }
                }
            }
        }
    }
}

private struct FilterRow: View {
    @Bindable var store: MoneyManagerStore

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterPill(title: "All", isSelected: store.filterType == nil) {
                    store.updateFilterType(nil)
                }
                FilterPill(title: "Expense", isSelected: store.filterType == TransactionType.expense.rawValue) {
                    store.updateFilterType(TransactionType.expense.rawValue)
                }
                FilterPill(title: "Income", isSelected: store.filterType == TransactionType.income.rawValue) {
                    store.updateFilterType(TransactionType.income.rawValue)
                }
            }
        }
    }
}

private struct CategoryFilterRow: View {
    @Bindable var store: MoneyManagerStore

    var body: some View {
        HStack(spacing: 12) {
            Menu {
                Button("All categories") { store.updateFilterCategory(nil) }
                Divider()
                ForEach(store.availableFilterCategories, id: \.self) { category in
                    Button {
                        store.updateFilterCategory(category)
                    } label: {
                        if store.filterCategory == category {
                            Label(categoryTitle(category), systemImage: "checkmark")
                        } else {
                            Text(categoryTitle(category))
                        }
                    }
                }
            } label: {
                Label(
                    store.filterCategory.map(categoryTitle) ?? "All categories",
                    systemImage: "line.3.horizontal.decrease.circle"
                )
                .font(.subheadline.weight(.semibold))
            }

            Spacer()

            if store.hasActiveTransactionFilters {
                Button("Reset", action: store.resetTransactionFilters)
                    .font(.subheadline.weight(.semibold))
            }
        }
    }
}

private struct NativeDaySection: View {
    let bucket: DayBucket
    @Bindable var store: MoneyManagerStore

    var body: some View {
        Section {
            ForEach(bucket.transactions) { transaction in
                TransactionListRow(transaction: transaction, store: store)
                    .listRowBackground(AppColor.surface)
            }
        } header: {
            DaySectionHeader(bucket: bucket, currency: store.summary?.currency ?? "EUR")
        }
    }
}

struct DaySectionHeader: View {
    let bucket: DayBucket
    var currency = "EUR"

    var body: some View {
        HStack {
            Text(DateFormat.dayHeader.string(from: bucket.date))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppColor.nearBlack)
            Spacer()
            Text(MoneyFormat.signed(bucket.balanceChange, currency: currency))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(amountColor(bucket.balanceChange))
        }
        .textCase(nil)
        .padding(.top, 4)
    }
}

struct TransactionListRow: View {
    let transaction: Transaction
    @Bindable var store: MoneyManagerStore

    var body: some View {
        Button {
            store.editTransaction(transaction)
        } label: {
            TransactionRowContent(transaction: transaction)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens the transaction editor")
        .accessibilityAction(named: "Delete") {
            store.deleteTransaction(transaction.id)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                store.deleteTransaction(transaction.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(AppColor.expense)
        }
    }

    private var accessibilityLabel: String {
        let description = transaction.description?.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = description.flatMap { $0.isEmpty ? nil : $0 } ?? categoryTitle(transaction.category)
        return "\(title), \(categoryTitle(transaction.category)), \(signedAmount), \(DateFormat.dateOnly(transaction.occurredAt))"
    }

    private var signedAmount: String {
        let amount = MoneyFormat.decimal(from: transaction.amount)
        let value = transaction.type == TransactionType.income.rawValue ? amount : -amount
        return MoneyFormat.signed(value, currency: transaction.currency)
    }
}

private struct TransactionRowContent: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            CategoryBadge(category: transaction.category)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.nearBlack)
                    .lineLimit(2)
                Text(metadata)
                    .font(.caption)
                    .foregroundStyle(AppColor.mutedText)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(signedAmount)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(transaction.type == TransactionType.income.rawValue ? AppColor.income : AppColor.expense)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private var title: String {
        let description = transaction.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return description.isEmpty ? categoryTitle(transaction.category) : description
    }

    private var metadata: String {
        let hasDescription = transaction.description?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        return hasDescription
            ? "\(categoryTitle(transaction.category)) · \(DateFormat.dateOnly(transaction.occurredAt))"
            : DateFormat.dateOnly(transaction.occurredAt)
    }

    private var signedAmount: String {
        let amount = MoneyFormat.decimal(from: transaction.amount)
        let signedAmount = transaction.type == TransactionType.income.rawValue ? amount : -amount
        return MoneyFormat.signed(signedAmount, currency: transaction.currency)
    }
}
