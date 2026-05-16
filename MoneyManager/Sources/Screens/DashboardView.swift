import Charts
import SwiftUI

struct DashboardView: View {
    @Bindable var store: MoneyManagerStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    BalanceCard(store: store)
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .listRowBackground(Color.clear)
                }

                Section {
                    SummaryMetricsRow(store: store)
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 20))
                        .listRowBackground(Color.clear)
                }

                Section {
                    SpendingCard(store: store)
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 20))
                        .listRowBackground(Color.clear)
                }

                RecentTransactionsSection(store: store)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .refreshable { store.refresh() }
            .appBackground()
            .navigationTitle("Money Manager")
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button(action: store.previousMonth) {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(store.isLoading)

                    Button(action: store.nextMonth) {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(store.isLoading || !store.canGoNextMonth)
                }

                ToolbarItem(placement: .principal) {
                    Text(DateFormat.monthDisplay(store.month))
                        .font(.headline)
                }

                ToolbarItem(placement: .primaryAction) {
                    Button(action: store.openNewTransactionForm) {
                        Label("Add transaction", systemImage: "plus")
                    }
                }
            }
        }
    }
}

private struct BalanceCard: View {
    let store: MoneyManagerStore

    var body: some View {
        AppCard(padding: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Monthly balance".uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppColor.mutedText)
                Text(MoneyFormat.amount(MoneyFormat.decimal(from: store.summary?.balance ?? "0.00")))
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(AppColor.nearBlack)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }
}

private struct SummaryMetricsRow: View {
    let store: MoneyManagerStore

    var body: some View {
        HStack(spacing: 12) {
            MetricTile(label: "Income", value: MoneyFormat.amount(MoneyFormat.decimal(from: store.summary?.income ?? "0.00")), tint: AppColor.income)
            MetricTile(label: "Expenses", value: MoneyFormat.amount(MoneyFormat.decimal(from: store.summary?.expense ?? "0.00")), tint: AppColor.expense)
            MetricTile(label: "Count", value: "\(store.summary?.transactionCount ?? 0)", tint: AppColor.nearBlack)
        }
    }
}

private struct SpendingCard: View {
    @Bindable var store: MoneyManagerStore

    var body: some View {
        AppCard(padding: 24) {
            VStack(alignment: .leading, spacing: 24) {
                Text("Spending by category")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppColor.nearBlack)

                if store.expenseCategoryTotals.isEmpty {
                    EmptyState(title: "No spending yet", message: "Add an expense to see category patterns.")
                } else {
                    let totalAmount = store.expenseCategoryTotals.reduce(.zero) { $0 + $1.amount }

                    HStack(alignment: .center, spacing: 18) {
                        DonutChart(
                            totals: store.expenseCategoryTotals,
                            selectedCategory: store.selectedExpenseCategory,
                            onSelect: store.selectExpenseCategory
                        )
                        .frame(width: 116, height: 116)

                        VStack(spacing: 13) {
                            ForEach(store.expenseCategoryTotals.prefix(3)) { total in
                                PercentLegendRow(
                                    total: total,
                                    totalAmount: totalAmount,
                                    isSelected: store.selectedExpenseCategory == total.category
                                )
                            }
                        }
                    }

                    VStack(spacing: 14) {
                        ForEach(store.expenseCategoryTotals.prefix(5)) { total in
                            AmountBreakdownRow(total: total, isSelected: store.selectedExpenseCategory == total.category)
                        }
                    }

                    if let selected = store.selectedExpenseCategory {
                        HStack {
                            Text("Filtering: \(categoryTitle(selected))")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(AppColor.mutedText)
                            Spacer()
                            Button("Clear") {
                                store.clearSelectedExpenseCategory()
                            }
                            .font(.footnote.weight(.bold))
                        }
                        .padding(.top, 2)
                    }
                }
            }
        }
    }
}

private struct DonutChart: View {
    let totals: [CategoryTotal]
    let selectedCategory: String?
    let onSelect: (String) -> Void
    @State private var selectedAngle: Double?

    var body: some View {
        Chart(totals) { total in
            let amount = NSDecimalNumber(decimal: total.amount).doubleValue
            let dimmed = selectedCategory != nil && selectedCategory != total.category
            SectorMark(
                angle: .value("Amount", amount),
                innerRadius: .ratio(0.62),
                angularInset: 1.5
            )
            .foregroundStyle(AppColor.category(total.category).opacity(dimmed ? 0.35 : 1))
            .cornerRadius(3)
        }
        .chartLegend(.hidden)
        .chartAngleSelection(value: $selectedAngle)
        .onChange(of: selectedAngle) { _, angle in
            guard let angle, let category = category(at: angle) else { return }
            onSelect(category)
        }
        .accessibilityLabel("Spending by category chart")
    }

    private func category(at angle: Double) -> String? {
        var runningTotal = 0.0
        for total in totals {
            runningTotal += NSDecimalNumber(decimal: total.amount).doubleValue
            if angle <= runningTotal {
                return total.category
            }
        }
        return totals.last?.category
    }
}

private struct PercentLegendRow: View {
    let total: CategoryTotal
    let totalAmount: Decimal
    let isSelected: Bool

    var body: some View {
        let percent = totalAmount > .zero ? NSDecimalNumber(decimal: (total.amount / totalAmount) * 100).rounding(accordingToBehavior: nil).intValue : 0
        HStack(spacing: 8) {
            Circle()
                .fill(AppColor.category(total.category))
                .frame(width: 10, height: 10)
            Text(categoryTitle(total.category))
                .font(.subheadline.weight(isSelected ? .bold : .semibold))
                .foregroundStyle(AppColor.nearBlack)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Spacer()
            Text("\(percent)%")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.mutedText)
                .lineLimit(1)
        }
    }
}

private struct AmountBreakdownRow: View {
    let total: CategoryTotal
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(AppColor.category(total.category))
                .frame(width: 9, height: 9)
            Text(categoryTitle(total.category))
                .font(.headline.weight(isSelected ? .bold : .regular))
                .foregroundStyle(isSelected ? AppColor.nearBlack : AppColor.mutedText)
            Spacer()
            Text(MoneyFormat.amount(total.amount))
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppColor.nearBlack)
        }
    }
}

private struct RecentTransactionsSection: View {
    let store: MoneyManagerStore

    var body: some View {
        if store.dayBuckets.isEmpty {
            Section {
                EmptyState(title: "Nothing here yet", message: "New transactions will appear here for the selected month.")
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 20))
                    .listRowBackground(Color.clear)
            } header: {
                Text(title)
            }
        } else {
            ForEach(store.dayBuckets.prefix(4)) { bucket in
                Section {
                    ForEach(bucket.transactions.prefix(3)) { transaction in
                        TransactionListRow(transaction: transaction, store: store)
                    }
                } header: {
                    DaySectionHeader(bucket: bucket)
                }
            }
        }
    }

    private var title: String {
        store.selectedExpenseCategory == nil ? "Recent transactions" : "Recent: \(categoryTitle(store.selectedExpenseCategory ?? ""))"
    }
}

struct EmptyState: View {
    let title: String
    let message: String

    var body: some View {
        AppCard(color: AppColor.surface, padding: 22) {
            VStack(spacing: 8) {
                CategoryBadge(category: "other")
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppColor.nearBlack)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(AppColor.mutedText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
