import SwiftUI

struct TransactionsView: View {
    @Bindable var store: MoneyManagerStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(DateFormat.monthDisplay(store.month))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColor.mutedText)
                        FilterRow(store: store)
                        ErrorBanner(message: store.error)
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                }

                if store.dayBuckets.isEmpty {
                    Section {
                        EmptyState(title: "No transactions", message: "Use the add button to start this month’s ledger.")
                            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                            .listRowBackground(Color.clear)
                    }
                } else {
                    ForEach(store.dayBuckets) { bucket in
                        NativeDaySection(bucket: bucket, store: store)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .refreshable { store.refresh() }
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

struct DayBucketCard: View {
    let bucket: DayBucket
    @Bindable var store: MoneyManagerStore

    var body: some View {
        AppCard(padding: 18) {
            VStack(spacing: 12) {
                HStack {
                    Text(DateFormat.dayHeader.string(from: bucket.date))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppColor.nearBlack)
                    Spacer()
                    Text(MoneyFormat.signed(bucket.balanceChange))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(amountColor(bucket.balanceChange))
                }

                VStack(spacing: 0) {
                    ForEach(Array(bucket.transactions.enumerated()), id: \.element.id) { index, transaction in
                        TransactionSummaryRow(transaction: transaction, store: store)
                        if index != bucket.transactions.count - 1 {
                            Divider().overlay(AppColor.divider)
                        }
                    }
                }
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
            DaySectionHeader(bucket: bucket)
        }
    }
}

struct DaySectionHeader: View {
    let bucket: DayBucket

    var body: some View {
        HStack {
            Text(DateFormat.dayHeader.string(from: bucket.date))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppColor.nearBlack)
            Spacer()
            Text(MoneyFormat.signed(bucket.balanceChange))
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
        .accessibilityHint("Opens the transaction editor")
        .accessibilityAction(named: "Delete") {
            store.deleteTransaction(transaction.id)
        }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    store.deleteTransaction(transaction.id)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .tint(AppColor.expense)
            }
    }
}

private struct TransactionSummaryRow: View {
    let transaction: Transaction
    @Bindable var store: MoneyManagerStore

    var body: some View {
        TransactionRowContent(transaction: transaction)
            .padding(.vertical, 8)
            .background(AppColor.surface)
            .contentShape(Rectangle())
            .onTapGesture {
                store.editTransaction(transaction)
            }
    }
}

private struct TransactionRowContent: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            CategoryBadge(category: transaction.category)

            VStack(alignment: .leading, spacing: 4) {
                Text(categoryTitle(transaction.category))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.nearBlack)
                Text(DateFormat.dateOnly(transaction.occurredAt))
                    .font(.caption)
                    .foregroundStyle(AppColor.mutedText)
            }

            Spacer(minLength: 8)

            Text(signedAmount)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(transaction.type == TransactionType.income.rawValue ? AppColor.income : AppColor.expense)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private var signedAmount: String {
        let amount = MoneyFormat.decimal(from: transaction.amount)
        let signedAmount = transaction.type == TransactionType.income.rawValue ? amount : -amount
        return MoneyFormat.signed(signedAmount, currency: transaction.currency)
    }
}
