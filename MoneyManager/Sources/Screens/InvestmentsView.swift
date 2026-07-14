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
                        Text("Record buys and sells for BTC, ETH, or stocks. Prices can be entered manually until automatic market data is enabled.")
                            .font(.subheadline).foregroundStyle(AppColor.mutedText).multilineTextAlignment(.center)
                        SecondaryButton(title: "Record first trade", systemImage: "plus") { sheet = .trade }
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                ForEach(store.growth.portfolio.positions) { position in
                    Button { sheet = .price(position) } label: { InvestmentPositionRow(position: position) }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens manual price editor")
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
                    Text("Export all recorded buys, sells, prices, fees, brokers, and notes as CSV.")
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
                Text("\(trade.occurredAt) · \(trade.quantity) @ \(MoneyFormat.amount(MoneyFormat.decimal(from: trade.pricePerUnit), currency: trade.currency))")
                    .font(.caption).foregroundStyle(AppColor.mutedText)
            }
            Spacer()
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
    @State private var assetType = "crypto"
    @State private var symbol = "BTC"
    @State private var assetName = "Bitcoin"
    @State private var broker = "revolut_x"
    @State private var side = "buy"
    @State private var quantity = ""
    @State private var price = ""
    @State private var fees = "0"
    @State private var occurredAt = Date()
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Asset") {
                    Picker("Type", selection: $assetType) {
                        Text("Crypto").tag("crypto")
                        Text("Stock").tag("stock")
                    }.pickerStyle(.segmented)
                    if assetType == "crypto" {
                        Picker("Asset", selection: $symbol) {
                            Text("Bitcoin (BTC)").tag("BTC")
                            Text("Ethereum (ETH)").tag("ETH")
                        }
                    } else {
                        TextField("Ticker, for example AAPL", text: $symbol).textInputAutocapitalization(.characters)
                        TextField("Company name", text: $assetName)
                    }
                    Picker("Broker", selection: $broker) {
                        Text("Manual").tag("manual")
                        if assetType == "crypto" { Text("Revolut X").tag("revolut_x") }
                        if assetType == "stock" { Text("Trading 212").tag("trading212") }
                    }
                }
                Section("Trade") {
                    Picker("Side", selection: $side) { Text("Buy").tag("buy"); Text("Sell").tag("sell") }.pickerStyle(.segmented)
                    TextField("Quantity", text: $quantity).keyboardType(.decimalPad)
                    TextField("Price per unit in EUR", text: $price).keyboardType(.decimalPad)
                    TextField("Fees in EUR", text: $fees).keyboardType(.decimalPad)
                    DatePicker("Date", selection: $occurredAt, in: ...Date(), displayedComponents: .date)
                    TextField("Notes", text: $notes, axis: .vertical)
                }
                if let error = store.growth.error { Section { ErrorBanner(message: error) } }
            }
            .navigationTitle("Record trade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isPresented = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(quantity.isEmpty || price.isEmpty || symbol.isEmpty || store.growth.isSaving)
                }
            }
            .onChange(of: assetType) { _, value in
                if value == "crypto" { symbol = "BTC"; assetName = "Bitcoin"; broker = "revolut_x" }
                else { symbol = ""; assetName = ""; broker = "trading212" }
            }
            .onChange(of: symbol) { _, value in
                if assetType == "crypto" { assetName = value == "BTC" ? "Bitcoin" : "Ethereum" }
            }
        }
    }

    private func save() async {
        guard let token = store.token else { return }
        let request = InvestmentTradeRequest(
            assetType: assetType, symbol: symbol.uppercased(), assetName: assetName,
            broker: broker, side: side, quantity: normalizedNumericInput(quantity),
            pricePerUnit: normalizedNumericInput(price), fees: normalizedNumericInput(fees),
            currency: "EUR", occurredAt: DateFormat.isoDate.string(from: occurredAt), notes: notes
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
    @State private var assetType = "crypto"
    @State private var symbol = "BTC"
    @State private var assetName = "Bitcoin"
    @State private var broker = "revolut_x"
    @State private var amount = ""
    @State private var frequency = "monthly"
    @State private var interval = 1
    @State private var startDate = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Asset") {
                    Picker("Type", selection: $assetType) { Text("Crypto").tag("crypto"); Text("Stock").tag("stock") }.pickerStyle(.segmented)
                    if assetType == "crypto" {
                        Picker("Asset", selection: $symbol) { Text("Bitcoin (BTC)").tag("BTC"); Text("Ethereum (ETH)").tag("ETH") }
                    } else {
                        TextField("Ticker", text: $symbol).textInputAutocapitalization(.characters)
                        TextField("Company name", text: $assetName)
                    }
                    Picker("Broker", selection: $broker) {
                        Text("Manual").tag("manual")
                        if assetType == "crypto" { Text("Revolut X").tag("revolut_x") }
                        if assetType == "stock" { Text("Trading 212").tag("trading212") }
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
                    Button("Save") { Task { await save() } }.disabled(amount.isEmpty || symbol.isEmpty || store.growth.isSaving)
                }
            }
            .onChange(of: assetType) { _, value in
                if value == "crypto" { symbol = "BTC"; assetName = "Bitcoin"; broker = "revolut_x" }
                else { symbol = ""; assetName = ""; broker = "trading212" }
            }
            .onChange(of: symbol) { _, value in if assetType == "crypto" { assetName = value == "BTC" ? "Bitcoin" : "Ethereum" } }
        }
    }

    private func save() async {
        guard let token = store.token else { return }
        let weekday = Calendar.current.component(.weekday, from: startDate)
        let request = InvestmentScheduleRequest(
            assetType: assetType, symbol: symbol.uppercased(), assetName: assetName, broker: broker,
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
                Section { Text("The CSV includes the exact trade date, asset, broker, side, quantity, price, fees, currency, and notes.") }
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
        store.growth.investmentTrades = [
            InvestmentTrade(id: 2, assetType: "crypto", symbol: "BTC", assetName: "Bitcoin", broker: "revolut_x", side: "buy", quantity: "0.02", pricePerUnit: "62000", fees: "1.50", currency: "EUR", occurredAt: "2026-07-10", notes: "Monthly buy"),
            InvestmentTrade(id: 1, assetType: "stock", symbol: "AAPL", assetName: "Apple", broker: "trading212", side: "buy", quantity: "4.2", pricePerUnit: "176.10", fees: "0", currency: "EUR", occurredAt: "2026-06-15", notes: ""),
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
