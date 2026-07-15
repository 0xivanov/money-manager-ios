import Charts
import SwiftUI

struct InvestmentView: View {
    @Bindable var store: MoneyManagerStore
    @State private var sheet: InvestmentSheet?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    header
                    portfolioCard
                    InvestmentPortfolioHistoryCard(store: store)
                    if let error = store.growth.error { ErrorBanner(message: error) }
                    positionsSection
                    plansSection
                    recentTradesSection
                    auditSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .appBackground()
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await load(true) }
            .task { await load(false) }
            .sheet(item: $sheet) { item in
                switch item {
                case .trade:
                    InvestmentTradeEditor(store: store, isPresented: sheetBinding)
                case .schedule:
                    InvestmentScheduleEditor(store: store, isPresented: sheetBinding)
                case .price(let position):
                    InvestmentPriceEditor(store: store, position: position, isPresented: sheetBinding)
                case .export:
                    InvestmentExportView(store: store, isPresented: sheetBinding)
                }
            }
            .sheet(item: $store.growth.shareItem) { item in
                ShareSheet(items: [item.url])
            }
        }
    }

    private var sheetBinding: Binding<Bool> {
        Binding(get: { sheet != nil }, set: { if !$0 { sheet = nil } })
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("WEALTH").font(.caption.weight(.bold)).foregroundStyle(AppColor.mutedText)
                Text("Invest").font(.system(size: 32, weight: .bold)).foregroundStyle(AppColor.nearBlack)
            }
            Spacer()
            Button { sheet = .trade } label: {
                Image(systemName: "plus").font(.headline.weight(.bold)).frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppColor.primaryText)
            .background(AppColor.filledButton)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .accessibilityLabel("Record investment trade")
        }
    }

    private var portfolioCard: some View {
        AppCard(color: AppColor.invertedSurface, padding: 20) {
            VStack(alignment: .leading, spacing: 18) {
                Text("PORTFOLIO VALUE")
                    .font(.caption.weight(.bold)).foregroundStyle(AppColor.inverseText.opacity(0.62))
                if store.growth.isLoadingInvestments && store.growth.investmentTrades.isEmpty {
                    ProgressView().tint(AppColor.inverseText)
                } else {
                    Text(portfolioValue)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColor.inverseText)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                HStack(spacing: 24) {
                    PortfolioMetric(label: "INVESTED", value: money(store.growth.portfolio.investedAmount), color: AppColor.inverseText)
                    PortfolioMetric(label: "UNREALIZED", value: signedMoney(store.growth.portfolio.unrealizedProfit), color: profitColor(store.growth.portfolio.unrealizedProfit))
                    PortfolioMetric(label: "REALIZED", value: signedMoney(store.growth.portfolio.realizedProfit), color: profitColor(store.growth.portfolio.realizedProfit))
                }
                if store.growth.portfolio.missingPrices > 0 {
                    Label("\(store.growth.portfolio.missingPrices) position prices need updating", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(AppColor.crypto)
                }
            }
        }
    }

    @ViewBuilder
    private var positionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Holdings").font(.title3.weight(.bold)).foregroundStyle(AppColor.nearBlack)
                Spacer()
                Text("AVERAGE COST").font(.caption2.weight(.bold)).foregroundStyle(AppColor.mutedText)
            }
            if store.growth.portfolio.positions.isEmpty && !store.growth.isLoadingInvestments {
                AppCard(padding: 24) {
                    VStack(spacing: 10) {
                        Image(systemName: "chart.line.uptrend.xyaxis").font(.largeTitle).foregroundStyle(AppColor.financeGreen)
                        Text("Build your portfolio ledger").font(.headline)
                        Text("Record BTC or ETH buys and sells. The execution price and crypto quantity are calculated automatically.")
                            .font(.subheadline).foregroundStyle(AppColor.mutedText).multilineTextAlignment(.center)
                        SecondaryButton(title: "Record first trade", systemImage: "plus") { sheet = .trade }
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                ForEach(store.growth.portfolio.positions) { position in
                    if InvestmentAssetCatalog.hasAutomaticPricing(assetType: position.assetType, symbol: position.symbol) {
                        InvestmentPositionRow(position: position)
                    } else {
                        Button { sheet = .price(position) } label: { InvestmentPositionRow(position: position) }
                            .buttonStyle(.plain)
                            .accessibilityHint("Opens manual price editor for this unsupported asset")
                    }
                }
            }
        }
    }

    private var plansSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Investment plans").font(.title3.weight(.bold)).foregroundStyle(AppColor.nearBlack)
                Spacer()
                Button("Add plan") { sheet = .schedule }.font(.subheadline.weight(.semibold))
            }
            if store.growth.investmentSchedules.isEmpty {
                AppCard(padding: 16) {
                    Label("Schedule a daily, weekly, or monthly investment reminder", systemImage: "calendar.badge.clock")
                        .font(.subheadline).foregroundStyle(AppColor.mutedText)
                }
            } else {
                ForEach(store.growth.investmentSchedules) { schedule in
                    InvestmentScheduleRow(store: store, schedule: schedule)
                }
            }
        }
    }

    private var recentTradesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent activity").font(.title3.weight(.bold)).foregroundStyle(AppColor.nearBlack)
            if store.growth.investmentTrades.isEmpty {
                Text("No investment activity yet.").font(.subheadline).foregroundStyle(AppColor.mutedText)
            } else {
                ForEach(store.growth.investmentTrades.prefix(8)) { trade in
                    InvestmentTradeRow(store: store, trade: trade)
                }
            }
        }
    }

    private var auditSection: some View {
        AppCard(color: AppColor.softGreenSurface, padding: 16) {
            HStack(spacing: 12) {
                Image(systemName: "doc.text.magnifyingglass").font(.title2).foregroundStyle(AppColor.financeGreen)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Audit-ready history").font(.headline).foregroundStyle(AppColor.nearBlack)
                    Text("Export amounts, calculated quantities and prices, fees, brokers, and notes as CSV.")
                        .font(.caption).foregroundStyle(AppColor.mutedText)
                }
                Spacer()
                Button("Export") { sheet = .export }.font(.subheadline.weight(.bold))
            }
        }
    }

    private var portfolioValue: String {
        guard let value = store.growth.portfolio.currentValue else { return "Price update needed" }
        return money(value)
    }

    private func money(_ value: String) -> String {
        MoneyFormat.amount(MoneyFormat.decimal(from: value), currency: store.growth.portfolio.currency)
    }

    private func signedMoney(_ value: String?) -> String {
        guard let value else { return "—" }
        return MoneyFormat.signed(MoneyFormat.decimal(from: value), currency: store.growth.portfolio.currency)
    }

    private func profitColor(_ value: String?) -> Color {
        guard let value else { return AppColor.inverseText.opacity(0.62) }
        return MoneyFormat.decimal(from: value) >= 0 ? AppColor.income : AppColor.expense
    }

    private func load(_ force: Bool) async {
        guard let token = store.token else { return }
        await store.growth.loadInvestments(token: token, force: force)
    }
}

private enum InvestmentSheet: Identifiable {
    case trade
    case schedule
    case price(InvestmentPosition)
    case export

    var id: String {
        switch self {
        case .trade: "trade"
        case .schedule: "schedule"
        case .price(let position): "price:\(position.id)"
        case .export: "export"
        }
    }
}

private struct PortfolioMetric: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 9, weight: .bold)).foregroundStyle(AppColor.inverseText.opacity(0.55))
            Text(value).font(.caption.weight(.bold).monospacedDigit()).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct InvestmentPortfolioHistoryCard: View {
    @Bindable var store: MoneyManagerStore

    var body: some View {
        AppCard(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Portfolio history")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppColor.nearBlack)
                        Text(rangeTitle)
                            .font(.caption)
                            .foregroundStyle(AppColor.mutedText)
                    }
                    Spacer()
                    if let last = points.last {
                        Text(money(last.value))
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .foregroundStyle(AppColor.nearBlack)
                    }
                }

                chartContent

                if !points.isEmpty {
                    HStack(spacing: 16) {
                        chartLegend(color: AppColor.financeGreen, title: "Value")
                        chartLegend(color: AppColor.mutedText, title: "Invested", dashed: true)
                    }
                }

                if store.growth.portfolioHistory.unsupportedPositions > 0 {
                    Label(
                        unsupportedPositionsMessage,
                        systemImage: "info.circle"
                    )
                    .font(.caption)
                    .foregroundStyle(AppColor.mutedText)
                }
            }
        }
    }

    @ViewBuilder
    private var chartContent: some View {
        if store.growth.isLoadingInvestmentHistory && points.isEmpty {
            VStack(spacing: 10) {
                ProgressView()
                Text("Building your portfolio history")
                    .font(.caption)
                    .foregroundStyle(AppColor.mutedText)
            }
            .frame(maxWidth: .infinity, minHeight: 180)
            .accessibilityElement(children: .combine)
        } else if let error = store.growth.investmentHistoryError, points.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "chart.line.downtrend.xyaxis")
                    .font(.title2)
                    .foregroundStyle(AppColor.mutedText)
                Text("Portfolio history is unavailable")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.nearBlack)
                Text(error)
                    .font(.caption)
                    .foregroundStyle(AppColor.mutedText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 180)
            .accessibilityElement(children: .combine)
        } else if points.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.title2)
                    .foregroundStyle(AppColor.financeGreen)
                Text("No portfolio history yet")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.nearBlack)
                Text("Your chart will appear after the first BTC or ETH trade.")
                    .font(.caption)
                    .foregroundStyle(AppColor.mutedText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 180)
            .accessibilityElement(children: .combine)
        } else {
            Chart(points) { point in
                AreaMark(
                    x: .value("Date", point.date ?? .distantPast),
                    y: .value("Portfolio value", double(point.value))
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppColor.financeGreen.opacity(0.28), AppColor.financeGreen.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Date", point.date ?? .distantPast),
                    y: .value("Portfolio value", double(point.value)),
                    series: .value("Series", "Portfolio value")
                )
                .foregroundStyle(AppColor.financeGreen)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                LineMark(
                    x: .value("Date", point.date ?? .distantPast),
                    y: .value("Invested amount", double(point.investedAmount)),
                    series: .value("Series", "Invested amount")
                )
                .foregroundStyle(AppColor.mutedText)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))

                PointMark(
                    x: .value("Date", point.date ?? .distantPast),
                    y: .value("Portfolio value", double(point.value))
                )
                .foregroundStyle(AppColor.financeGreen)
                .symbolSize(14)
            }
            .chartLegend(.hidden)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) {
                    AxisGridLine().foregroundStyle(AppColor.divider)
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) {
                    AxisGridLine().foregroundStyle(AppColor.divider)
                    AxisValueLabel()
                }
            }
            .chartXScale(range: .plotDimension(startPadding: 10, endPadding: 10))
            .frame(height: 190)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Portfolio value for the last year")
            .accessibilityValue(chartAccessibilityValue)
        }
    }

    private var points: [InvestmentPortfolioHistoryPoint] {
        store.growth.portfolioHistory.points
            .filter { $0.date != nil }
            .sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
    }

    private var rangeTitle: String {
        switch store.growth.portfolioHistory.range {
        case "1m": "Last month"
        case "3m": "Last 3 months"
        case "1y": "Last year"
        case "all": "All time"
        default: store.growth.portfolioHistory.range.uppercased()
        }
    }

    private var chartAccessibilityValue: String {
        guard let first = points.first, let last = points.last else { return "No history available" }
        return "From \(money(first.value)) to \(money(last.value)). Invested amount \(money(last.investedAmount))."
    }

    private var unsupportedPositionsMessage: String {
        let count = store.growth.portfolioHistory.unsupportedPositions
        return count == 1
            ? "1 stock position is excluded"
            : "\(count) stock positions are excluded"
    }

    private func money(_ value: String) -> String {
        MoneyFormat.amount(
            MoneyFormat.decimal(from: value),
            currency: store.growth.portfolioHistory.currency
        )
    }

    private func double(_ value: String) -> Double {
        NSDecimalNumber(decimal: MoneyFormat.decimal(from: value)).doubleValue
    }

    private func chartLegend(color: Color, title: String, dashed: Bool = false) -> some View {
        HStack(spacing: 6) {
            Capsule()
                .stroke(color, style: StrokeStyle(lineWidth: 2, dash: dashed ? [4, 3] : []))
                .frame(width: 20, height: 2)
            Text(title)
                .font(.caption)
                .foregroundStyle(AppColor.mutedText)
        }
    }
}

private struct InvestmentPositionRow: View {
    let position: InvestmentPosition

    var body: some View {
        HStack(spacing: 13) {
            Text(String(position.symbol.prefix(1)))
                .font(.headline.weight(.bold)).foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(position.assetType == "crypto" ? AppColor.crypto : AppColor.stocks)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(position.assetName).font(.headline).foregroundStyle(AppColor.nearBlack)
                Text("\(position.symbol) · \(brokerName(position.broker)) · \(position.quantity)")
                    .font(.caption).foregroundStyle(AppColor.mutedText)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(position.currentValue.map { MoneyFormat.amount(MoneyFormat.decimal(from: $0), currency: position.currency) } ?? "Set price")
                    .font(.subheadline.weight(.bold)).foregroundStyle(position.currentValue == nil ? AppColor.crypto : AppColor.nearBlack)
                Text("Avg \(MoneyFormat.amount(MoneyFormat.decimal(from: position.averageCost), currency: position.currency))")
                    .font(.caption2).foregroundStyle(AppColor.mutedText)
            }
        }
        .padding(15)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppMetric.cardRadius, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: AppMetric.cardRadius, style: .continuous).stroke(AppColor.divider, lineWidth: 1) }
    }
}

private struct InvestmentTradeRow: View {
    @Bindable var store: MoneyManagerStore
    let trade: InvestmentTrade

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: trade.side == "buy" ? "arrow.down.left" : "arrow.up.right")
                .foregroundStyle(trade.side == "buy" ? AppColor.income : AppColor.expense)
                .frame(width: 38, height: 38)
                .background((trade.side == "buy" ? AppColor.income : AppColor.expense).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text("\(categoryTitle(trade.side)) \(trade.symbol)").font(.subheadline.weight(.semibold))
                Text("\(trade.quantity) \(trade.symbol) @ \(MoneyFormat.amount(MoneyFormat.decimal(from: trade.pricePerUnit), currency: trade.currency))")
                    .font(.caption)
                    .foregroundStyle(AppColor.mutedText)
                    .lineLimit(1)
                Text(priceTimestamp)
                    .font(.caption2)
                    .foregroundStyle(AppColor.mutedText)
            }
            Spacer()
            Text(MoneyFormat.amount(MoneyFormat.decimal(from: trade.amount), currency: trade.currency))
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(AppColor.nearBlack)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Menu {
                Button("Delete trade", role: .destructive) {
                    guard let token = store.token else { return }
                    Task { await store.growth.deleteInvestmentTrade(token: token, id: trade.id) }
                }
            } label: {
                Image(systemName: "ellipsis").frame(width: 36, height: 36).contentShape(Rectangle())
            }
        }
        .padding(.vertical, 5)
    }

    private var priceTimestamp: String {
        let provider = trade.priceProvider.map { " · \(categoryTitle($0))" } ?? ""
        return "\(DateFormat.dateTimeDisplay(trade.occurredAt))\(provider)"
    }
}

private struct InvestmentScheduleRow: View {
    @Bindable var store: MoneyManagerStore
    let schedule: InvestmentSchedule

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .foregroundStyle(AppColor.financeGreen).frame(width: 40, height: 40)
                .background(AppColor.softGreenSurface).clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text("\(schedule.symbol) · \(MoneyFormat.amount(MoneyFormat.decimal(from: schedule.amount), currency: schedule.currency))")
                    .font(.subheadline.weight(.bold))
                Text("\(categoryTitle(schedule.frequency)) · next \(schedule.nextOccurrence ?? "not scheduled")")
                    .font(.caption).foregroundStyle(AppColor.mutedText)
            }
            Spacer()
            Menu {
                Button(schedule.status == "paused" ? "Resume" : "Pause") {
                    guard let token = store.token else { return }
                    Task { await store.growth.toggleInvestmentSchedule(token: token, schedule: schedule) }
                }
                Button("Archive", role: .destructive) {
                    guard let token = store.token else { return }
                    Task { await store.growth.deleteInvestmentSchedule(token: token, id: schedule.id) }
                }
            } label: { Image(systemName: "ellipsis").frame(width: 36, height: 36) }
        }
        .padding(14).background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppMetric.cardRadius, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: AppMetric.cardRadius, style: .continuous).stroke(AppColor.divider, lineWidth: 1) }
        .opacity(schedule.status == "paused" ? 0.62 : 1)
    }
}

private struct InvestmentTradeEditor: View {
    @Bindable var store: MoneyManagerStore
    @Binding var isPresented: Bool
    @State private var selectedAsset = InvestmentAssetCatalog.bitcoin
    @State private var broker = "revolut_x"
    @State private var side = "buy"
    @State private var amount = ""
    @State private var fees = "0"
    @State private var occurredAt = Date()
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Asset") {
                    Picker("Asset", selection: $selectedAsset) {
                        ForEach(InvestmentAssetCatalog.tradeEnabled) { asset in
                            Text("\(asset.name) (\(asset.symbol))").tag(asset)
                        }
                    }
                    Picker("Broker", selection: $broker) {
                        Text("Manual").tag("manual")
                        Text("Revolut X").tag("revolut_x")
                    }
                }
                Section {
                    Picker("Side", selection: $side) { Text("Buy").tag("buy"); Text("Sell").tag("sell") }.pickerStyle(.segmented)
                    TextField("Amount in EUR", text: $amount).keyboardType(.decimalPad)
                    TextField("Fees in EUR", text: $fees).keyboardType(.decimalPad)
                    DatePicker(
                        "Executed at",
                        selection: $occurredAt,
                        in: ...Date(),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    TextField("Notes", text: $notes, axis: .vertical)
                } header: {
                    Text("Trade")
                } footer: {
                    Text("The backend looks up the market price at this time and calculates the BTC or ETH quantity.")
                }
                if let error = store.growth.error { Section { ErrorBanner(message: error) } }
            }
            .navigationTitle("Record trade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isPresented = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(!canSave || store.growth.isSaving)
                }
            }
        }
    }

    private var parsedAmount: Decimal? {
        MoneyFormat.inputDecimal(from: amount)
    }

    private var parsedFees: Decimal? {
        fees.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? .zero
            : MoneyFormat.inputDecimal(from: fees)
    }

    private var canSave: Bool {
        guard let parsedAmount, let parsedFees else { return false }
        return parsedAmount > .zero && parsedFees >= .zero
    }

    private func save() async {
        guard
            let token = store.token,
            let parsedAmount,
            let parsedFees,
            parsedAmount > .zero,
            parsedFees >= .zero
        else { return }
        let request = InvestmentTradeRequest(
            assetType: selectedAsset.type.rawValue,
            symbol: selectedAsset.symbol,
            assetName: selectedAsset.name,
            broker: broker,
            side: side,
            amount: MoneyFormat.apiAmount(parsedAmount),
            fees: MoneyFormat.apiAmount(parsedFees),
            currency: "EUR",
            occurredAt: DateFormat.apiTimestamp(occurredAt),
            notes: notes
        )
        if await store.growth.createInvestmentTrade(token: token, request: request) { isPresented = false }
    }
}

private struct InvestmentPriceEditor: View {
    @Bindable var store: MoneyManagerStore
    let position: InvestmentPosition
    @Binding var isPresented: Bool
    @State private var price = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("\(position.assetName) price") {
                    TextField("Current price in EUR", text: $price).keyboardType(.decimalPad)
                    if let current = position.currentPrice {
                        LabeledContent("Last price", value: MoneyFormat.amount(MoneyFormat.decimal(from: current), currency: position.currency))
                    }
                }
                Section { Text("Manual prices are clearly marked and can be replaced later by a reviewed market-data integration.") }
                if let error = store.growth.error { Section { ErrorBanner(message: error) } }
            }
            .navigationTitle("Update \(position.symbol)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isPresented = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }.disabled(price.isEmpty || store.growth.isSaving)
                }
            }
        }
    }

    private func save() async {
        guard let token = store.token else { return }
        if await store.growth.setManualPrice(token: token, position: position, price: normalizedNumericInput(price)) { isPresented = false }
    }
}

private struct InvestmentScheduleEditor: View {
    @Bindable var store: MoneyManagerStore
    @Binding var isPresented: Bool
    @State private var selectedAsset = InvestmentAssetCatalog.bitcoin
    @State private var broker = "revolut_x"
    @State private var amount = ""
    @State private var frequency = "monthly"
    @State private var interval = 1
    @State private var startDate = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Asset") {
                    Picker("Asset", selection: $selectedAsset) {
                        ForEach(InvestmentAssetCatalog.tradeEnabled) { asset in
                            Text("\(asset.name) (\(asset.symbol))").tag(asset)
                        }
                    }
                    Picker("Broker", selection: $broker) {
                        Text("Manual").tag("manual")
                        Text("Revolut X").tag("revolut_x")
                    }
                }
                Section("Plan") {
                    TextField("Amount in EUR", text: $amount).keyboardType(.decimalPad)
                    Picker("Repeats", selection: $frequency) { Text("Daily").tag("daily"); Text("Weekly").tag("weekly"); Text("Monthly").tag("monthly") }
                    Stepper("Every \(interval) \(frequency)", value: $interval, in: 1...365)
                    DatePicker("Starts", selection: $startDate, in: Calendar.current.startOfDay(for: Date())..., displayedComponents: .date)
                }
                Section { Text("Plans create reminders. They never place orders or claim that an investment happened.") }
                if let error = store.growth.error { Section { ErrorBanner(message: error) } }
            }
            .navigationTitle("Investment plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isPresented = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }.disabled(amount.isEmpty || store.growth.isSaving)
                }
            }
        }
    }

    private func save() async {
        guard let token = store.token else { return }
        let weekday = Calendar.current.component(.weekday, from: startDate)
        let request = InvestmentScheduleRequest(
            assetType: selectedAsset.type.rawValue,
            symbol: selectedAsset.symbol,
            assetName: selectedAsset.name,
            broker: broker,
            amount: normalizedNumericInput(amount), currency: "EUR", frequency: frequency,
            frequencyInterval: interval, startDate: DateFormat.isoDate.string(from: startDate), endDate: nil,
            dayOfWeek: frequency == "weekly" ? (weekday == 1 ? 7 : weekday - 1) : nil,
            dayOfMonth: frequency == "monthly" ? Calendar.current.component(.day, from: startDate) : nil,
            timezone: TimeZone.current.identifier
        )
        if await store.growth.createInvestmentSchedule(token: token, request: request) { isPresented = false }
    }
}

private struct InvestmentExportView: View {
    @Bindable var store: MoneyManagerStore
    @Binding var isPresented: Bool
    @State private var from = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
    @State private var through = Date()

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("From", selection: $from, in: ...through, displayedComponents: .date)
                DatePicker("Through", selection: $through, in: from...Date(), displayedComponents: .date)
                Section { Text("The CSV includes the exact execution time, asset, broker, side, entered amount, calculated quantity and price, fees, provider, currency, and notes.") }
                if let error = store.growth.error { Section { ErrorBanner(message: error) } }
            }
            .navigationTitle("Audit export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isPresented = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Export") { Task { await export() } }.disabled(store.growth.isSaving)
                }
            }
        }
    }

    private func export() async {
        guard let token = store.token else { return }
        await store.growth.exportInvestments(token: token, from: from, through: through)
        if store.growth.shareItem != nil { isPresented = false }
    }
}

private func brokerName(_ broker: String) -> String {
    switch broker {
    case "revolut_x": "Revolut X"
    case "trading212": "Trading 212"
    default: "Manual"
    }
}

#if DEBUG
enum GrowthPreviewKind {
    case investments
    case planning
}

@MainActor
struct GrowthPreviewHost: View {
    @State private var store: MoneyManagerStore
    let kind: GrowthPreviewKind

    init(kind: GrowthPreviewKind) {
        self.kind = kind
        let store = MoneyManagerStore()
        store.token = "preview"
        store.email = "ivan@example.com"
        store.growth.portfolio = InvestmentPortfolio(
            positions: [
                InvestmentPosition(
                    assetType: "crypto", symbol: "BTC", assetName: "Bitcoin", broker: "revolut_x",
                    quantity: "0.084", averageCost: "54000.00", investedAmount: "4536.00",
                    currentPrice: "64525.00", currentValue: "5420.10", unrealizedProfit: "884.10",
                    unrealizedPercent: "19.49", realizedProfit: "0.00", currency: "EUR",
                    priceAsOf: "2026-07-13T20:00:00Z", priceStatus: "available"
                ),
                InvestmentPosition(
                    assetType: "stock", symbol: "AAPL", assetName: "Apple", broker: "trading212",
                    quantity: "4.2", averageCost: "176.10", investedAmount: "739.62",
                    currentPrice: nil, currentValue: nil, unrealizedProfit: nil,
                    unrealizedPercent: nil, realizedProfit: "42.00", currency: "EUR",
                    priceAsOf: nil, priceStatus: "missing"
                ),
            ],
            investedAmount: "5275.62", currentValue: nil, unrealizedProfit: nil,
            realizedProfit: "42.00", currency: "EUR", missingPrices: 1
        )
        store.growth.portfolioHistory = InvestmentPortfolioHistory(
            points: [
                InvestmentPortfolioHistoryPoint(asOf: "2026-02-01T00:00:00Z", value: "1200.00", investedAmount: "1200.00"),
                InvestmentPortfolioHistoryPoint(asOf: "2026-03-01T00:00:00Z", value: "1960.00", investedAmount: "1800.00"),
                InvestmentPortfolioHistoryPoint(asOf: "2026-04-01T00:00:00Z", value: "2650.00", investedAmount: "2500.00"),
                InvestmentPortfolioHistoryPoint(asOf: "2026-05-01T00:00:00Z", value: "3120.00", investedAmount: "3100.00"),
                InvestmentPortfolioHistoryPoint(asOf: "2026-06-01T00:00:00Z", value: "4010.00", investedAmount: "3900.00"),
                InvestmentPortfolioHistoryPoint(asOf: "2026-07-13T20:00:00Z", value: "5420.10", investedAmount: "4536.00"),
            ],
            currency: "EUR",
            range: "1y",
            unsupportedPositions: 1
        )
        store.growth.investmentTrades = [
            InvestmentTrade(id: 2, assetType: "crypto", symbol: "BTC", assetName: "Bitcoin", broker: "revolut_x", side: "buy", amount: "1240.00", quantity: "0.02", pricePerUnit: "62000", fees: "1.50", currency: "EUR", occurredAt: "2026-07-10T08:30:00Z", notes: "Monthly buy", priceProvider: "kraken", priceAsOf: "2026-07-10T08:30:00Z"),
            InvestmentTrade(id: 1, assetType: "stock", symbol: "AAPL", assetName: "Apple", broker: "trading212", side: "buy", amount: "739.62", quantity: "4.2", pricePerUnit: "176.10", fees: "0", currency: "EUR", occurredAt: "2026-06-15T10:15:00Z", notes: "", priceProvider: nil, priceAsOf: nil),
        ]
        store.growth.investmentSchedules = [
            InvestmentSchedule(id: 1, assetType: "crypto", symbol: "BTC", assetName: "Bitcoin", broker: "revolut_x", amount: "100.00", currency: "EUR", frequency: "monthly", frequencyInterval: 1, startDate: "2026-07-15", endDate: nil, dayOfWeek: nil, dayOfMonth: 15, timezone: "Europe/Sofia", status: "active", nextOccurrence: "2026-07-15")
        ]
        store.growth.transactionSchedules = [
            TransactionSchedule(id: 1, type: "expense", name: "Rent", category: "housing", description: "", amount: "1250.00", currency: "EUR", frequency: "monthly", frequencyInterval: 1, startDate: "2026-08-01", endDate: nil, dayOfWeek: nil, dayOfMonth: 1, timezone: "Europe/Sofia", autoPost: true, status: "active", nextOccurrenceDate: "2026-08-01"),
            TransactionSchedule(id: 2, type: "income", name: "Salary", category: "salary", description: "", amount: "4200.00", currency: "EUR", frequency: "monthly", frequencyInterval: 1, startDate: "2026-07-31", endDate: nil, dayOfWeek: nil, dayOfMonth: 31, timezone: "Europe/Sofia", autoPost: true, status: "active", nextOccurrenceDate: "2026-07-31"),
        ]
        store.growth.budgets = [
            Budget(id: 1, name: "Monthly spending", category: nil, amount: "2200.00", currency: "EUR", period: "monthly", warningThreshold: 80, status: "active", periodStart: "2026-07-01", periodEnd: "2026-07-31", spentAmount: "1485.20", remainingAmount: "714.80", progressPercent: "67.5", alertLevel: "safe")
        ]
        _store = State(initialValue: store)
    }

    var body: some View {
        if kind == .investments {
            InvestmentView(store: store)
        } else {
            NavigationStack { ScheduledMoneyView(store: store) }
        }
    }
}
#endif
