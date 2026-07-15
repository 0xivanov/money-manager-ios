import Charts
import SwiftUI

struct LegacyInvestmentPreview: View {
    private let points = [
        InvestmentPoint(month: "Feb", value: 11_900),
        InvestmentPoint(month: "Mar", value: 12_480),
        InvestmentPoint(month: "Apr", value: 12_120),
        InvestmentPoint(month: "May", value: 13_940),
        InvestmentPoint(month: "Jun", value: 14_720),
        InvestmentPoint(month: "Jul", value: 15_600),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    investmentHeader
                    portfolioCard
                    allocationCard
                    holdings
                    connectCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .appBackground()
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var investmentHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("WEALTH")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColor.mutedText)
                Text("Invest")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(AppColor.nearBlack)
            }
            Spacer()
            Label("PREVIEW", systemImage: "sparkles")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColor.stocks)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(AppColor.stocks.opacity(0.12))
                .clipShape(Capsule())
        }
    }

    private var portfolioCard: some View {
        AppCard(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PORTFOLIO VALUE")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppColor.mutedText)
                        Text("€15,600.80")
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppColor.nearBlack)
                    }
                    Spacer()
                    Text("+8.24%")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppColor.income)
                }

                Chart(points) { point in
                    AreaMark(
                        x: .value("Month", point.month),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColor.stocks.opacity(0.35), AppColor.stocks.opacity(0.03)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    LineMark(
                        x: .value("Month", point.month),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(AppColor.stocks)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                }
                .chartYAxis(.hidden)
                .chartXAxis(.hidden)
                .frame(height: 126)
                .accessibilityLabel("Preview portfolio chart rising from 11,900 euros to 15,600 euros")
            }
        }
    }

    private var allocationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Allocation")
                .font(.headline.weight(.bold))
                .foregroundStyle(AppColor.nearBlack)
            GeometryReader { proxy in
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(AppColor.stocks)
                        .frame(width: proxy.size.width * 0.68)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(AppColor.crypto)
                }
            }
            .frame(height: 10)
            HStack {
                allocationLabel(color: AppColor.stocks, title: "Stocks", value: "68%")
                Spacer()
                allocationLabel(color: AppColor.crypto, title: "Crypto", value: "32%")
            }
        }
    }

    private var holdings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Holdings")
                .font(.headline.weight(.bold))
                .foregroundStyle(AppColor.nearBlack)
            InvestmentAssetRow(symbol: "AAPL", name: "Apple", detail: "4.2 shares", value: "€812.40", change: "+2.41%", tint: AppColor.stocks)
            InvestmentAssetRow(symbol: "BTC", name: "Bitcoin", detail: "0.084 BTC", value: "€5,420.10", change: "+12.8%", tint: AppColor.crypto)
        }
    }

    private var connectCard: some View {
        AppCard(color: AppColor.invertedSurface, padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                Label("Connect your investments", systemImage: "link")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppColor.inverseText)
                Text("Broker and exchange integrations are planned. Your existing money tracking remains fully functional.")
                    .font(.subheadline)
                    .foregroundStyle(AppColor.inverseText.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    IntegrationPill(title: "STOCK BROKERS")
                    IntegrationPill(title: "CRYPTO")
                    Spacer()
                    Text("SOON")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColor.crypto)
                }
            }
        }
    }

    private func allocationLabel(color: Color, title: String, value: String) -> some View {
        HStack(spacing: 7) {
            Circle().fill(color).frame(width: 9, height: 9)
            Text(title).foregroundStyle(AppColor.mutedText)
            Text(value).fontWeight(.bold).foregroundStyle(AppColor.nearBlack)
        }
        .font(.caption)
    }
}

private struct InvestmentPoint: Identifiable {
    let month: String
    let value: Double
    var id: String { month }
}

private struct InvestmentAssetRow: View {
    let symbol: String
    let name: String
    let detail: String
    let value: String
    let change: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Text(String(symbol.prefix(1)))
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(tint)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.subheadline.weight(.bold)).foregroundStyle(AppColor.nearBlack)
                Text("\(symbol) · \(detail)").font(.caption).foregroundStyle(AppColor.mutedText)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(AppColor.nearBlack)
                Text(change).font(.caption.weight(.bold)).foregroundStyle(AppColor.income)
            }
        }
        .padding(14)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct IntegrationPill: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(AppColor.inverseText)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .overlay(Capsule().stroke(AppColor.inverseText.opacity(0.25), lineWidth: 1))
    }
}

struct DashboardView: View {
    @Bindable var store: MoneyManagerStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    MonthNavigator(
                        month: store.month,
                        canGoNext: store.canGoNextMonth,
                        previous: store.previousMonth,
                        next: store.nextMonth
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 8, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                    if let summary = store.summary {
                        BalanceCard(
                            summary: summary,
                            balance: store.balanceIncludingInvestments(summary)
                        )
                            .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                            .listRowBackground(Color.clear)
                    } else {
                        switch store.dashboardLoadState {
                        case .failed(let message):
                            DashboardFailureState(message: message, retry: store.retryDashboard)
                                .listRowBackground(Color.clear)
                        case .idle, .loading, .loaded:
                            DashboardLoadingState()
                                .listRowBackground(Color.clear)
                        }
                    }
                }

                if let summary = store.summary {
                    DashboardContent(store: store, summary: summary)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .refreshable { await refreshHome() }
            .appBackground()
            .navigationTitle("Overview")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: store.openNewTransactionForm) {
                        Label("Add transaction", systemImage: "plus")
                    }
                }
            }
            .task {
                guard let token = store.token else { return }
                async let planning: Void = store.growth.loadPlanning(token: token)
                async let investments: Void = store.growth.loadInvestments(token: token)
                _ = await (planning, investments)
            }
        }
    }

    private func refreshHome() async {
        guard let token = store.token else { return }
        async let transactions: Void = store.refresh()
        async let planning: Void = store.growth.loadPlanning(token: token, force: true)
        async let investments: Void = store.growth.loadInvestments(token: token, force: true)
        _ = await (transactions, planning, investments)
    }
}

private struct DashboardContent: View {
    @Bindable var store: MoneyManagerStore
    let summary: TransactionSummary

    var body: some View {
        if case .failed(let message) = store.dashboardLoadState {
            Section {
                ErrorBanner(message: message)
            }
        }

        Section {
            SummaryMetrics(
                summary: summary,
                investmentSpending: store.investmentSpending(currency: summary.currency)
            )
                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 20))
                .listRowBackground(Color.clear)
        }

        Section("Investments") {
            DashboardInvestmentCard(store: store)
                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 20))
                .listRowBackground(Color.clear)
        }

        Section {
            SpendingCard(store: store, currency: summary.currency)
                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 20))
                .listRowBackground(Color.clear)
        }

        Section("Plan") {
            NavigationLink {
                ScheduledMoneyView(store: store)
            } label: {
                PlanningLinkRow(
                    icon: "calendar.badge.clock",
                    title: "Scheduled money",
                    detail: "\(store.growth.transactionSchedules.count) active plans"
                )
            }
            NavigationLink {
                BudgetsView(store: store)
            } label: {
                PlanningLinkRow(
                    icon: "gauge.with.dots.needle.50percent",
                    title: "Budgets",
                    detail: budgetDetail
                )
            }
        }

        RecentTransactionsSection(store: store)
    }

    private var budgetDetail: String {
        guard !store.growth.budgets.isEmpty else { return "Set your first spending limit" }
        let approaching = store.growth.budgets.filter { $0.alertLevel != "safe" }.count
        return approaching == 0 ? "All budgets on track" : "\(approaching) need attention"
    }
}

private struct PlanningLinkRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(AppColor.financeGreen)
                .frame(width: 38, height: 38)
                .background(AppColor.softGreenSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(AppColor.mutedText)
            }
        }
    }
}

private struct DashboardLoadingState: View {
    var body: some View {
        AppCard(color: AppColor.surface, padding: 30) {
            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                Text("Loading your month")
                    .font(.headline)
                    .foregroundStyle(AppColor.nearBlack)
                Text("Fetching the latest balance and transactions.")
                    .font(.subheadline)
                    .foregroundStyle(AppColor.mutedText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
        }
    }
}

private struct DashboardFailureState: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        AppCard(color: AppColor.surface, padding: 26) {
            VStack(spacing: 12) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(AppColor.expense)
                Text("Couldn’t load this month")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppColor.nearBlack)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(AppColor.mutedText)
                    .multilineTextAlignment(.center)
                Button("Try again", action: retry)
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct BalanceCard: View {
    let summary: TransactionSummary
    let balance: Decimal

    var body: some View {
        AppCard(color: AppColor.softGreenSurface, padding: 24) {
            VStack(alignment: .leading, spacing: 10) {
                Label("Monthly balance", systemImage: "wallet.bifold.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.financeGreen)
                Text(MoneyFormat.amount(balance, currency: summary.currency))
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(AppColor.nearBlack)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text("Income minus expenses and investments for this month")
                    .font(.footnote)
                    .foregroundStyle(AppColor.mutedText)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

private struct SummaryMetrics: View {
    let summary: TransactionSummary
    let investmentSpending: Decimal
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            MetricTile(
                label: "Income",
                value: MoneyFormat.amount(MoneyFormat.decimal(from: summary.income), currency: summary.currency),
                tint: AppColor.income
            )
            MetricTile(
                label: "Expenses",
                value: MoneyFormat.amount(MoneyFormat.decimal(from: summary.expense), currency: summary.currency),
                tint: AppColor.expense
            )
            MetricTile(
                label: "Investments",
                value: MoneyFormat.amount(investmentSpending, currency: summary.currency),
                tint: AppColor.crypto
            )
        }
    }

    private var columns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible())]
        }
        return [GridItem(.adaptive(minimum: 100), spacing: 12)]
    }
}

private struct DashboardInvestmentCard: View {
    @Bindable var store: MoneyManagerStore

    var body: some View {
        Button {
            store.selectedTab = .investments
        } label: {
            AppCard(color: AppColor.invertedSurface, padding: 18) {
                if store.growth.isLoadingInvestments && hasNoInvestmentData {
                    HStack(spacing: 12) {
                        ProgressView().tint(AppColor.inverseText)
                        Text("Loading portfolio")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColor.inverseText)
                        Spacer()
                    }
                } else if hasNoInvestmentData {
                    HStack(spacing: 14) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(AppColor.crypto)
                            .frame(width: 44, height: 44)
                            .background(AppColor.crypto.opacity(0.14))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("No investments yet")
                                .font(.headline)
                                .foregroundStyle(AppColor.inverseText)
                            Text("Record a BTC or ETH purchase")
                                .font(.caption)
                                .foregroundStyle(AppColor.inverseText.opacity(0.66))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(AppColor.inverseText.opacity(0.55))
                    }
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("PORTFOLIO VALUE")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppColor.inverseText.opacity(0.62))
                                Text(portfolioValue)
                                    .font(.system(size: 26, weight: .bold, design: .rounded))
                                    .foregroundStyle(AppColor.inverseText)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(AppColor.inverseText.opacity(0.55))
                        }
                        HStack(spacing: 18) {
                            compactMetric("INVESTED", value: money(store.growth.portfolio.investedAmount))
                            compactMetric("UNREALIZED", value: unrealizedValue, color: unrealizedColor)
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens the Invest tab")
    }

    private var hasNoInvestmentData: Bool {
        store.growth.portfolio.positions.isEmpty && store.growth.investmentTrades.isEmpty
    }

    private var portfolioValue: String {
        guard let value = store.growth.portfolio.currentValue else { return "Partially priced" }
        return money(value)
    }

    private var unrealizedValue: String {
        guard let value = store.growth.portfolio.unrealizedProfit else { return "Unavailable" }
        return MoneyFormat.signed(
            MoneyFormat.decimal(from: value),
            currency: store.growth.portfolio.currency
        )
    }

    private var unrealizedColor: Color {
        guard let value = store.growth.portfolio.unrealizedProfit else {
            return AppColor.inverseText.opacity(0.62)
        }
        return MoneyFormat.decimal(from: value) >= 0 ? AppColor.income : AppColor.expense
    }

    private var accessibilityLabel: String {
        hasNoInvestmentData
            ? "Investments, no investments yet"
            : "Investments, portfolio value \(portfolioValue), unrealized \(unrealizedValue)"
    }

    private func money(_ value: String) -> String {
        MoneyFormat.amount(
            MoneyFormat.decimal(from: value),
            currency: store.growth.portfolio.currency
        )
    }

    private func compactMetric(_ label: String, value: String, color: Color = AppColor.inverseText) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(AppColor.inverseText.opacity(0.55))
            Text(value)
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SpendingCard: View {
    @Bindable var store: MoneyManagerStore
    let currency: String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        AppCard(padding: 22) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Spending by category")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppColor.nearBlack)
                    Spacer()
                    if store.selectedExpenseCategory != nil {
                        Button("Clear", action: store.clearSelectedExpenseCategory)
                            .font(.footnote.weight(.semibold))
                    }
                }

                if store.expenseCategoryTotals.isEmpty {
                    EmptyState(title: "No spending yet", message: "Add an expense to see category patterns.")
                } else {
                    VStack(spacing: 18) {
                        chart
                        legend
                    }
                }
            }
        }
    }

    private var chart: some View {
        DonutChart(
            totals: store.expenseCategoryTotals,
            selectedCategory: store.selectedExpenseCategory,
            onSelect: store.selectExpenseCategory
        )
        .frame(width: dynamicTypeSize.isAccessibilitySize ? 148 : 164, height: dynamicTypeSize.isAccessibilitySize ? 148 : 164)
        .frame(maxWidth: .infinity)
    }

    private var legend: some View {
        let totalAmount = store.expenseCategoryTotals.reduce(.zero) { $0 + $1.amount }
        return VStack(spacing: 4) {
            ForEach(store.expenseCategoryTotals) { total in
                CategoryLegendButton(
                    total: total,
                    totalAmount: totalAmount,
                    currency: currency,
                    isSelected: store.selectedExpenseCategory == total.category,
                    action: {
                        if store.selectedExpenseCategory == total.category {
                            store.clearSelectedExpenseCategory()
                        } else {
                            store.selectExpenseCategory(total.category)
                        }
                    }
                )
            }
        }
        .frame(maxWidth: .infinity)
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
                innerRadius: .ratio(0.64),
                angularInset: 1.5
            )
            .foregroundStyle(AppColor.category(total.category).opacity(dimmed ? 0.3 : 1))
            .cornerRadius(3)
        }
        .chartLegend(.hidden)
        .chartAngleSelection(value: $selectedAngle)
        .onChange(of: selectedAngle) { _, angle in
            guard let angle, let category = category(at: angle) else { return }
            onSelect(category)
        }
        .accessibilityHidden(true)
    }

    private func category(at angle: Double) -> String? {
        var runningTotal = 0.0
        for total in totals {
            runningTotal += NSDecimalNumber(decimal: total.amount).doubleValue
            if angle <= runningTotal { return total.category }
        }
        return totals.last?.category
    }
}

private struct CategoryLegendButton: View {
    let total: CategoryTotal
    let totalAmount: Decimal
    let currency: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let percent = totalAmount > .zero
            ? NSDecimalNumber(decimal: (total.amount / totalAmount) * 100).rounding(accordingToBehavior: nil).intValue
            : 0
        Button(action: action) {
            HStack(spacing: 10) {
                Circle()
                    .fill(AppColor.category(total.category))
                    .frame(width: 10, height: 10)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(categoryTitle(total.category))
                        .font(.subheadline.weight(isSelected ? .bold : .semibold))
                        .foregroundStyle(AppColor.nearBlack)
                    Text("\(percent)%")
                        .font(.caption)
                        .foregroundStyle(AppColor.mutedText)
                }
                Spacer()
                Text(MoneyFormat.amount(total.amount, currency: currency))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.nearBlack)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 8)
            .background(isSelected ? AppColor.softGreenSurface : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(categoryTitle(total.category)), \(percent) percent, \(MoneyFormat.amount(total.amount, currency: currency))")
        .accessibilityHint(isSelected ? "Double tap to clear this filter" : "Double tap to filter recent transactions")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct RecentTransactionsSection: View {
    @Bindable var store: MoneyManagerStore

    private var recentTransactions: [Transaction] {
        Array(store.dashboardDayBuckets.flatMap(\.transactions).prefix(5))
    }

    var body: some View {
        Section {
            if recentTransactions.isEmpty {
                EmptyState(
                    title: store.selectedExpenseCategory == nil ? "Nothing here yet" : "No matching expenses",
                    message: store.selectedExpenseCategory == nil
                        ? "New transactions will appear here for the selected month."
                        : "Try another category or clear the chart filter."
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(recentTransactions) { transaction in
                    TransactionListRow(transaction: transaction, store: store)
                }
            }

            Button(action: store.showAllTransactions) {
                Label("See all transactions", systemImage: "arrow.right")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        } header: {
            HStack {
                Text(store.selectedExpenseCategory == nil ? "Recent transactions" : "Recent: \(categoryTitle(store.selectedExpenseCategory ?? ""))")
                if store.selectedExpenseCategory != nil {
                    Spacer()
                    Button("Clear", action: store.clearSelectedExpenseCategory)
                        .font(.caption.weight(.semibold))
                        .textCase(nil)
                }
            }
        }
    }
}

struct EmptyState: View {
    let title: String
    let message: String

    var body: some View {
        AppCard(color: AppColor.surface, padding: 22) {
            VStack(spacing: 8) {
                CategoryBadge(category: "other")
                    .accessibilityHidden(true)
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppColor.nearBlack)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(AppColor.mutedText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
        }
    }
}
