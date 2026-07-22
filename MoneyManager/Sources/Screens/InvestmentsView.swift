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
                    PortfolioAIQuestionCard(store: store)
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
                    PrivacyValueText(
                        value: portfolioValue,
                        isHidden: store.hidePortfolioBalances
                    )
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColor.inverseText)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                HStack(spacing: 24) {
                    PortfolioMetric(
                        label: "INVESTED",
                        value: money(store.growth.portfolio.investedAmount),
                        color: AppColor.inverseText,
                        isHidden: store.hidePortfolioBalances
                    )
                    PortfolioMetric(
                        label: "UNREALIZED",
                        value: signedMoney(store.growth.portfolio.unrealizedProfit),
                        color: profitColor(store.growth.portfolio.unrealizedProfit),
                        isHidden: store.hidePortfolioBalances
                    )
                    PortfolioMetric(
                        label: "REALIZED",
                        value: signedMoney(store.growth.portfolio.realizedProfit),
                        color: profitColor(store.growth.portfolio.realizedProfit),
                        isHidden: store.hidePortfolioBalances
                    )
                }
                InvestmentPriceStatus(
                    positions: store.growth.portfolio.positions,
                    color: AppColor.inverseText.opacity(0.62)
                )
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
                        Text("Record crypto, stock, or ETF buys and sells. Market prices and quantities are calculated automatically.")
                            .font(.subheadline).foregroundStyle(AppColor.mutedText).multilineTextAlignment(.center)
                        SecondaryButton(title: "Record first trade", systemImage: "plus") { sheet = .trade }
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                ForEach(store.growth.portfolio.positions) { position in
                    if InvestmentAssetCatalog.hasAutomaticPricing(assetType: position.assetType, symbol: position.symbol) {
                        InvestmentPositionRow(
                            position: position,
                            hidePortfolioBalances: store.hidePortfolioBalances
                        )
                    } else {
                        Button { sheet = .price(position) } label: {
                            InvestmentPositionRow(
                                position: position,
                                hidePortfolioBalances: store.hidePortfolioBalances
                            )
                        }
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
            HStack {
                Text("Recent activity").font(.title3.weight(.bold)).foregroundStyle(AppColor.nearBlack)
                Spacer()
                if !store.growth.investmentTrades.isEmpty {
                    NavigationLink("See all") {
                        InvestmentTradesView(store: store)
                    }
                    .font(.subheadline.weight(.semibold))
                    .accessibilityHint("Shows all investment trades")
                }
            }
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

private struct PortfolioAIQuestionCard: View {
    @Bindable var store: MoneyManagerStore
    @State private var modelManager = OnDeviceModelManager.shared
    @State private var question = ""
    @State private var submittedQuestion = ""
    @State private var answer = ""
    @State private var isAnswering = false
    @State private var errorMessage: String?
    @FocusState private var isQuestionFocused: Bool

    private let suggestions = [
        "What is my largest exposure?",
        "Summarize my performance",
        "How concentrated is my portfolio?",
    ]

    var body: some View {
        AppCard(color: AppColor.softGreenSurface, padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                header

                if !modelManager.isModelInstalled {
                    setupState
                } else if store.growth.portfolio.positions.isEmpty {
                    Text("Record a holding before asking Qwen about your portfolio.")
                        .font(.subheadline)
                        .foregroundStyle(AppColor.mutedText)
                } else {
                    questionComposer
                    answerState
                }

                Label("Portfolio data and answers stay on this device", systemImage: "lock.shield.fill")
                    .font(.caption)
                    .foregroundStyle(AppColor.mutedText)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.headline)
                .foregroundStyle(AppColor.financeGreen)
                .frame(width: 38, height: 38)
                .background(AppColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("Ask about your portfolio")
                    .font(.headline)
                    .foregroundStyle(AppColor.nearBlack)
                Text("Powered by Qwen on this iPhone")
                    .font(.caption)
                    .foregroundStyle(AppColor.mutedText)
            }
        }
    }

    private var setupState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Download Qwen from Profile to ask questions about holdings, allocation, and performance.")
                .font(.subheadline)
                .foregroundStyle(AppColor.mutedText)
            Button {
                store.selectedTab = .profile
            } label: {
                Label("Open AI settings", systemImage: "person.crop.circle")
                    .font(.subheadline.weight(.semibold))
            }
        }
    }

    private var questionComposer: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button(suggestion) {
                            question = suggestion
                            Task { await submitQuestion() }
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColor.financeGreen)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppColor.surface)
                        .clipShape(Capsule())
                        .overlay { Capsule().stroke(AppColor.divider, lineWidth: 1) }
                        .buttonStyle(.plain)
                        .disabled(isAnswering)
                    }
                }
            }
            .scrollIndicators(.hidden)

            TextField("Ask about allocation, returns, or holdings", text: $question, axis: .vertical)
                .lineLimit(1...4)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.send)
                .focused($isQuestionFocused)
                .onSubmit { Task { await submitQuestion() } }
                .padding(12)
                .background(AppColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppColor.divider, lineWidth: 1)
                }

            Button {
                Task { await submitQuestion() }
            } label: {
                HStack(spacing: 8) {
                    if isAnswering { ProgressView().tint(AppColor.primaryText) }
                    Label(isAnswering ? "Thinking on device" : "Ask Qwen", systemImage: "arrow.up.circle.fill")
                        .font(.subheadline.weight(.bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .foregroundStyle(AppColor.primaryText)
                .background(AppColor.filledButton)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(trimmedQuestion.isEmpty || isAnswering)
            .opacity(trimmedQuestion.isEmpty || isAnswering ? 0.55 : 1)
        }
    }

    @ViewBuilder
    private var answerState: some View {
        if !answer.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(submittedQuestion)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColor.mutedText)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(answerLines.enumerated()), id: \.offset) { _, line in
                        Text(AIInsightText.markdown(line))
                            .font(.subheadline)
                            .foregroundStyle(AppColor.nearBlack)
                            .lineLimit(nil)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
                .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }

        if let errorMessage {
            Text(errorMessage)
                .font(.footnote)
                .foregroundStyle(AppColor.expense)
        }
    }

    private var trimmedQuestion: String {
        question.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var answerLines: [String] {
        answer
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    @MainActor
    private func submitQuestion() async {
        let submitted = String(trimmedQuestion.prefix(240))
        guard !submitted.isEmpty, !isAnswering else { return }
        isQuestionFocused = false
        isAnswering = true
        submittedQuestion = submitted
        errorMessage = nil
        defer { isAnswering = false }

        do {
            let prompt = PortfolioQuestionPrompt.make(
                question: submitted,
                portfolio: store.growth.portfolio,
                history: store.growth.portfolioHistory,
                trades: store.growth.investmentTrades,
                schedules: store.growth.investmentSchedules
            )
            answer = try await OnDeviceAIService.shared.answerPortfolioQuestion(prompt: prompt)
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

enum PortfolioQuestionPrompt {
    private struct Snapshot: Encodable {
        let currency: String
        let investedAmount: String
        let currentValue: String?
        let unrealizedProfit: String?
        let realizedProfit: String
        let missingPrices: Int
        let positions: [Position]
        let historyRange: String
        let history: [HistoryPoint]
        let recentTrades: [Trade]
        let activeSchedules: [Schedule]
    }

    private struct Position: Encodable {
        let assetType: String
        let symbol: String
        let assetName: String
        let broker: String
        let quantity: String
        let averageCost: String
        let investedAmount: String
        let currentPrice: String?
        let currentValue: String?
        let unrealizedProfit: String?
        let unrealizedPercent: String?
        let realizedProfit: String
        let priceAsOf: String?
        let priceStatus: String
    }

    private struct HistoryPoint: Encodable {
        let asOf: String
        let value: String
        let investedAmount: String
    }

    private struct Trade: Encodable {
        let symbol: String
        let side: String
        let amount: String
        let quantity: String
        let pricePerUnit: String
        let fees: String
        let currency: String
        let broker: String
        let occurredAt: String
    }

    private struct Schedule: Encodable {
        let symbol: String
        let amount: String
        let currency: String
        let broker: String
        let frequency: String
        let frequencyInterval: Int
        let nextOccurrence: String?
    }

    static func make(
        question: String,
        portfolio: InvestmentPortfolio,
        history: InvestmentPortfolioHistory,
        trades: [InvestmentTrade],
        schedules: [InvestmentSchedule]
    ) -> String {
        let snapshot = Snapshot(
            currency: limited(portfolio.currency, to: 8),
            investedAmount: portfolio.investedAmount,
            currentValue: portfolio.currentValue,
            unrealizedProfit: portfolio.unrealizedProfit,
            realizedProfit: portfolio.realizedProfit,
            missingPrices: portfolio.missingPrices,
            positions: Array(portfolio.positions.prefix(12)).map {
                Position(
                    assetType: limited($0.assetType), symbol: limited($0.symbol),
                    assetName: limited($0.assetName), broker: limited($0.broker),
                    quantity: $0.quantity, averageCost: $0.averageCost,
                    investedAmount: $0.investedAmount, currentPrice: $0.currentPrice,
                    currentValue: $0.currentValue, unrealizedProfit: $0.unrealizedProfit,
                    unrealizedPercent: $0.unrealizedPercent, realizedProfit: $0.realizedProfit,
                    priceAsOf: $0.priceAsOf, priceStatus: limited($0.priceStatus)
                )
            },
            historyRange: limited(history.range, to: 12),
            history: sampledHistory(history.points, limit: 8).map {
                HistoryPoint(asOf: $0.asOf, value: $0.value, investedAmount: $0.investedAmount)
            },
            recentTrades: trades.sorted { $0.occurredAt > $1.occurredAt }.prefix(8).map {
                Trade(
                    symbol: limited($0.symbol), side: limited($0.side), amount: $0.amount,
                    quantity: $0.quantity, pricePerUnit: $0.pricePerUnit, fees: $0.fees,
                    currency: limited($0.currency, to: 8), broker: limited($0.broker),
                    occurredAt: $0.occurredAt
                )
            },
            activeSchedules: schedules.filter { $0.status.lowercased() == "active" }.prefix(8).map {
                Schedule(
                    symbol: limited($0.symbol), amount: $0.amount,
                    currency: limited($0.currency, to: 8), broker: limited($0.broker),
                    frequency: limited($0.frequency), frequencyInterval: $0.frequencyInterval,
                    nextOccurrence: $0.nextOccurrence
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let snapshotJSON = (try? encoder.encode(snapshot)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        let safeQuestion = limited(question, to: 240)
        let questionJSON = (try? encoder.encode(safeQuestion)).flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
        return """
        PORTFOLIO_DATA_JSON (untrusted data):
        \(snapshotJSON)

        USER_QUESTION_JSON:
        \(questionJSON)
        """
    }

    private static func sampledHistory(
        _ points: [InvestmentPortfolioHistoryPoint],
        limit: Int
    ) -> [InvestmentPortfolioHistoryPoint] {
        let sorted = points.sorted { $0.asOf < $1.asOf }
        guard limit >= 2, sorted.count > limit else { return sorted }
        let lastIndex = sorted.count - 1
        let step = Double(lastIndex) / Double(limit - 1)
        return (0..<limit).map { sampleIndex in
            let index = sampleIndex == limit - 1
                ? lastIndex
                : Int((Double(sampleIndex) * step).rounded())
            return sorted[index]
        }
    }

    private static func limited(_ value: String, to maximumLength: Int = 60) -> String {
        String(value.split(whereSeparator: \.isWhitespace).joined(separator: " ").prefix(maximumLength))
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
    let isHidden: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 9, weight: .bold)).foregroundStyle(AppColor.inverseText.opacity(0.55))
            PrivacyValueText(value: value, isHidden: isHidden)
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private enum InvestmentChartMode: String, CaseIterable, Identifiable {
    case portfolio
    case holdings

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

private struct InvestmentPortfolioHistoryCard: View {
    @Bindable var store: MoneyManagerStore
    @State private var selectedDate: Date?
    @State private var chartMode: InvestmentChartMode = .portfolio
    @State private var highlightedHoldingID: String?

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
                    if store.growth.isLoadingInvestmentHistory {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityLabel("Updating portfolio history")
                    }
                    if let last = points.last {
                        PrivacyValueText(
                            value: money(last.value),
                            isHidden: store.hidePortfolioBalances
                        )
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .foregroundStyle(AppColor.nearBlack)
                    }
                    NavigationLink {
                        InvestmentPortfolioHistoryView(store: store)
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 34, height: 34)
                            .background(AppColor.background)
                            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppColor.financeGreen)
                    .accessibilityLabel("Expand portfolio history")
                }

                chartModePicker

                chartContent

                if !points.isEmpty && !store.hidePortfolioBalances {
                    if chartMode == .portfolio {
                        HStack(spacing: 16) {
                            chartLegend(color: AppColor.financeGreen, title: "Value")
                            chartLegend(color: AppColor.mutedText, title: "Invested", dashed: true)
                        }
                    } else {
                        InvestmentHoldingLegend(
                            series: holdingSeries,
                            highlightedHoldingID: $highlightedHoldingID
                        )
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

    private var chartModePicker: some View {
        Picker("Chart mode", selection: $chartMode) {
            ForEach(InvestmentChartMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: chartMode) {
            selectedDate = nil
            if chartMode == .portfolio {
                highlightedHoldingID = nil
            }
        }
        .disabled(holdingSeries.isEmpty)
    }

    @ViewBuilder
    private var chartContent: some View {
        if store.hidePortfolioBalances && !points.isEmpty {
            PortfolioPrivacyPlaceholder(height: 180)
        } else if store.growth.isLoadingInvestmentHistory && points.isEmpty {
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
                Text("Your chart will appear after the first investment trade.")
                    .font(.caption)
                    .foregroundStyle(AppColor.mutedText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 180)
            .accessibilityElement(children: .combine)
        } else {
            InvestmentHistoryChart(
                points: chartPoints,
                range: store.growth.portfolioHistory.range,
                currency: store.growth.portfolioHistory.currency,
                mode: chartMode,
                height: 190,
                axisMaximumCount: 4,
                showsEndPoint: true,
                selectedDate: $selectedDate,
                highlightedHoldingID: $highlightedHoldingID
            )
        }
    }

    private var points: [InvestmentPortfolioChartPoint] {
        store.growth.portfolioHistoryChartPoints
    }

    private var chartPoints: [InvestmentPortfolioChartPoint] {
        sampledInvestmentChartPoints(points, limit: 96)
    }

    private var holdingSeries: [InvestmentHoldingChartValue] {
        investmentHoldingSeries(chartPoints)
    }

    private var rangeTitle: String {
        switch store.growth.portfolioHistory.range {
        case "1m": "Last month"
        case "3m": "Last 3 months"
        case "1y": "Last year"
        case "2y": "Last 2 years"
        case "5y": "Last 5 years"
        case "max": "All time"
        default: store.growth.portfolioHistory.range.uppercased()
        }
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

    private func money(_ value: Double) -> String {
        MoneyFormat.amount(Decimal(value), currency: store.growth.portfolioHistory.currency)
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

private func nearestInvestmentChartPoint(
    to selectedDate: Date?,
    in points: [InvestmentPortfolioChartPoint]
) -> InvestmentPortfolioChartPoint? {
    guard let selectedDate else { return nil }
    return points.min {
        abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
    }
}

private struct InvestmentChartSelectionTooltip: View {
    let date: Date
    let value: String
    let investedAmount: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(date.formatted(.dateTime.day().month(.abbreviated).year()))
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppColor.nearBlack)

            valueRow(color: AppColor.financeGreen, label: "Value", value: value)
            valueRow(color: AppColor.mutedText, label: "Invested", value: investedAmount)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppColor.divider, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.12), radius: 8, y: 3)
        .allowsHitTesting(false)
    }

    private func valueRow(color: Color, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .foregroundStyle(AppColor.mutedText)
            Spacer(minLength: 8)
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(AppColor.nearBlack)
        }
        .font(.caption2.monospacedDigit())
        .frame(minWidth: 145)
    }
}

private let investmentHoldingPalette: [Color] = [
    Color(red: 0.12, green: 0.82, blue: 0.51),
    Color(red: 0.20, green: 0.55, blue: 0.96),
    Color(red: 0.98, green: 0.58, blue: 0.10),
    Color(red: 0.65, green: 0.39, blue: 0.93),
    Color(red: 0.92, green: 0.27, blue: 0.42),
    Color(red: 0.12, green: 0.72, blue: 0.75),
    Color(red: 0.78, green: 0.64, blue: 0.12),
    Color(red: 0.52, green: 0.58, blue: 0.68)
]

private func investmentHoldingColor(
    for holdingID: String,
    in series: [InvestmentHoldingChartValue]
) -> Color {
    guard let index = series.firstIndex(where: { $0.id == holdingID }) else {
        return AppColor.mutedText
    }
    return investmentHoldingPalette[index % investmentHoldingPalette.count]
}

private struct InvestmentHoldingLegend: View {
    let series: [InvestmentHoldingChartValue]
    @Binding var highlightedHoldingID: String?

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(series) { holding in
                    let isHighlighted = highlightedHoldingID == nil || highlightedHoldingID == holding.id
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            highlightedHoldingID = highlightedHoldingID == holding.id ? nil : holding.id
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(investmentHoldingColor(for: holding.id, in: series))
                                .frame(width: 8, height: 8)
                            Text(holding.symbol)
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(isHighlighted ? AppColor.nearBlack : AppColor.mutedText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(isHighlighted ? AppColor.background : AppColor.surface)
                        .clipShape(Capsule())
                        .overlay {
                            Capsule().stroke(AppColor.divider, lineWidth: 1)
                        }
                        .opacity(isHighlighted ? 1 : 0.58)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Highlight \(holding.assetName)")
                    .accessibilityAddTraits(highlightedHoldingID == holding.id ? .isSelected : [])
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

private struct InvestmentHistoryChart: View {
    let points: [InvestmentPortfolioChartPoint]
    let range: String
    let currency: String
    let mode: InvestmentChartMode
    let height: CGFloat
    let axisMaximumCount: Int
    let showsEndPoint: Bool
    @Binding var selectedDate: Date?
    @Binding var highlightedHoldingID: String?

    var body: some View {
        Group {
            if mode == .holdings && !series.isEmpty {
                holdingsChart
            } else {
                portfolioChart
            }
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(mode == .holdings ? "Portfolio holdings history" : "Portfolio value history")
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Tap or drag across the chart to inspect a date")
    }

    private var portfolioChart: some View {
        Chart {
            ForEach(points) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Portfolio value", point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppColor.financeGreen.opacity(0.28), AppColor.financeGreen.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Portfolio value", point.value),
                    series: .value("Series", "Portfolio value")
                )
                .foregroundStyle(AppColor.financeGreen)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Invested amount", point.investedAmount),
                    series: .value("Series", "Invested amount")
                )
                .foregroundStyle(AppColor.mutedText)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))

                if showsEndPoint, point.id == points.last?.id, selectedPoint == nil {
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Portfolio value", point.value)
                    )
                    .foregroundStyle(AppColor.financeGreen)
                    .symbolSize(24)
                }
            }

            if let selectedPoint {
                RuleMark(x: .value("Selected date", selectedPoint.date))
                    .foregroundStyle(AppColor.nearBlack.opacity(0.42))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

                PointMark(
                    x: .value("Selected date", selectedPoint.date),
                    y: .value("Selected invested amount", selectedPoint.investedAmount)
                )
                .foregroundStyle(AppColor.mutedText)
                .symbolSize(38)

                PointMark(
                    x: .value("Selected date", selectedPoint.date),
                    y: .value("Selected portfolio value", selectedPoint.value)
                )
                .foregroundStyle(AppColor.financeGreen)
                .symbolSize(52)
                .annotation(
                    position: .top,
                    spacing: 8,
                    overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))
                ) {
                    InvestmentChartSelectionTooltip(
                        date: selectedPoint.date,
                        value: money(selectedPoint.value),
                        investedAmount: money(selectedPoint.investedAmount)
                    )
                }
            }
        }
        .chartLegend(.hidden)
        .investmentHistoryAxes(points: points, range: range, maximumCount: axisMaximumCount)
        .chartXSelection(value: $selectedDate)
    }

    private var holdingsChart: some View {
        Chart {
            ForEach(stackPoints) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    yStart: .value("Stack start", point.lowerBound),
                    yEnd: .value("Stack end", point.upperBound),
                    series: .value("Holding", point.holdingID)
                )
                .foregroundStyle(investmentHoldingColor(for: point.holdingID, in: series))
                .opacity(holdingOpacity(point.holdingID, selected: 0.72, dimmed: 0.10))

                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Holding boundary", point.upperBound),
                    series: .value("Holding", point.holdingID)
                )
                .foregroundStyle(investmentHoldingColor(for: point.holdingID, in: series))
                .lineStyle(StrokeStyle(lineWidth: highlightedHoldingID == point.holdingID ? 2.5 : 1.1))
                .opacity(holdingOpacity(point.holdingID, selected: 1, dimmed: 0.16))
            }

            if let selectedPoint {
                RuleMark(x: .value("Selected date", selectedPoint.date))
                    .foregroundStyle(AppColor.nearBlack.opacity(0.48))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

                PointMark(
                    x: .value("Selected date", selectedPoint.date),
                    y: .value("Selected total", selectedPoint.value)
                )
                .foregroundStyle(selectedMarkerColor)
                .symbolSize(52)
                .annotation(
                    position: .top,
                    spacing: 8,
                    overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))
                ) {
                    InvestmentHoldingsSelectionTooltip(
                        point: selectedPoint,
                        series: series,
                        highlightedHoldingID: highlightedHoldingID,
                        currency: currency,
                        maximumRows: height < 250 ? 3 : 8
                    )
                }
            }
        }
        .chartLegend(.hidden)
        .investmentHistoryAxes(points: points, range: range, maximumCount: axisMaximumCount)
        .chartXSelection(value: $selectedDate)
    }

    private var series: [InvestmentHoldingChartValue] {
        investmentHoldingSeries(points)
    }

    private var stackPoints: [InvestmentHoldingStackPoint] {
        investmentHoldingStackPoints(points, series: series)
    }

    private var selectedPoint: InvestmentPortfolioChartPoint? {
        nearestInvestmentChartPoint(to: selectedDate, in: points)
    }

    private var selectedMarkerColor: Color {
        guard let highlightedHoldingID else { return AppColor.nearBlack }
        return investmentHoldingColor(for: highlightedHoldingID, in: series)
    }

    private var accessibilityValue: String {
        if let selectedPoint {
            if mode == .holdings {
                let values = selectedPoint.holdings
                    .filter { $0.value > 0 }
                    .sorted { $0.value > $1.value }
                    .map { "\($0.symbol) \(money($0.value))" }
                    .joined(separator: ", ")
                return "\(selectedPoint.date.formatted(date: .abbreviated, time: .omitted)), \(values), total \(money(selectedPoint.value))."
            }
            return "\(selectedPoint.date.formatted(date: .abbreviated, time: .omitted)), value \(money(selectedPoint.value)), invested \(money(selectedPoint.investedAmount))."
        }
        guard let first = points.first, let last = points.last else { return "No history available" }
        return "From \(money(first.value)) to \(money(last.value))."
    }

    private func holdingOpacity(_ holdingID: String, selected: Double, dimmed: Double) -> Double {
        guard let highlightedHoldingID else { return selected }
        return highlightedHoldingID == holdingID ? selected : dimmed
    }

    private func money(_ value: Double) -> String {
        MoneyFormat.amount(Decimal(value), currency: currency)
    }
}

private extension View {
    func investmentHistoryAxes(
        points: [InvestmentPortfolioChartPoint],
        range: String,
        maximumCount: Int
    ) -> some View {
        chartXAxis {
            AxisMarks(values: investmentHistoryAxisDates(points, maximumCount: maximumCount)) { value in
                AxisGridLine().foregroundStyle(AppColor.divider)
                AxisValueLabel(collisionResolution: .disabled) {
                    if let date = value.as(Date.self) {
                        Text(investmentHistoryAxisLabel(date, range: range))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppColor.mutedText)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: maximumCount)) {
                AxisGridLine().foregroundStyle(AppColor.divider)
                AxisValueLabel()
            }
        }
        .chartXScale(range: .plotDimension(startPadding: 0, endPadding: 0))
    }
}

private struct InvestmentHoldingsSelectionTooltip: View {
    let point: InvestmentPortfolioChartPoint
    let series: [InvestmentHoldingChartValue]
    let highlightedHoldingID: String?
    let currency: String
    let maximumRows: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(point.date.formatted(.dateTime.day().month(.abbreviated).year()))
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppColor.nearBlack)

            ForEach(Array(visibleHoldings.prefix(maximumRows))) { holding in
                HStack(spacing: 6) {
                    Circle()
                        .fill(investmentHoldingColor(for: holding.id, in: series))
                        .frame(width: 6, height: 6)
                    Text(holding.symbol)
                        .foregroundStyle(AppColor.mutedText)
                    Spacer(minLength: 8)
                    Text(money(holding.value))
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColor.nearBlack)
                }
            }

            if visibleHoldings.count > maximumRows {
                Text("+\(visibleHoldings.count - maximumRows) more holdings")
                    .foregroundStyle(AppColor.mutedText)
            }

            Divider()
            HStack {
                Text("Total").foregroundStyle(AppColor.mutedText)
                Spacer(minLength: 8)
                Text(money(point.value))
                    .fontWeight(.bold)
                    .foregroundStyle(AppColor.nearBlack)
            }
        }
        .font(.caption2.monospacedDigit())
        .frame(minWidth: 160, maxWidth: 220)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppColor.divider, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.12), radius: 8, y: 3)
        .allowsHitTesting(false)
    }

    private var visibleHoldings: [InvestmentHoldingChartValue] {
        let valuesByID = Dictionary(uniqueKeysWithValues: point.holdings.map { ($0.id, $0) })
        let ordered = series.compactMap { valuesByID[$0.id] }.filter { $0.value > 0 }
        guard let highlightedHoldingID,
              let index = ordered.firstIndex(where: { $0.id == highlightedHoldingID })
        else { return ordered }
        var highlightedFirst = ordered
        let highlighted = highlightedFirst.remove(at: index)
        highlightedFirst.insert(highlighted, at: 0)
        return highlightedFirst
    }

    private func money(_ value: Double) -> String {
        MoneyFormat.amount(Decimal(value), currency: currency)
    }
}

private enum InvestmentHistoryRange: String, CaseIterable, Identifiable {
    case month = "1m"
    case quarter = "3m"
    case year = "1y"
    case twoYears = "2y"
    case fiveYears = "5y"
    case maximum = "max"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .month: "1M"
        case .quarter: "3M"
        case .year: "1Y"
        case .twoYears: "2Y"
        case .fiveYears: "5Y"
        case .maximum: "MAX"
        }
    }

    var accessibilityTitle: String {
        switch self {
        case .month: "One month"
        case .quarter: "Three months"
        case .year: "One year"
        case .twoYears: "Two years"
        case .fiveYears: "Five years"
        case .maximum: "All available history"
        }
    }
}

private struct InvestmentPortfolioHistoryView: View {
    @Bindable var store: MoneyManagerStore
    @State private var selectedRange: InvestmentHistoryRange
    @State private var selectedDate: Date?
    @State private var chartMode: InvestmentChartMode = .portfolio
    @State private var highlightedHoldingID: String?

    init(store: MoneyManagerStore) {
        self.store = store
        _selectedRange = State(
            initialValue: InvestmentHistoryRange(rawValue: store.growth.portfolioHistory.range) ?? .year
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                rangePicker

                InvestmentPriceStatus(positions: store.growth.portfolio.positions)

                historySummary

                AppCard(padding: 18) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Portfolio value")
                                .font(.headline)
                                .foregroundStyle(AppColor.nearBlack)
                            Spacer()
                            if store.growth.isLoadingInvestmentHistory {
                                ProgressView()
                                    .controlSize(.small)
                                    .accessibilityLabel("Updating portfolio history")
                            }
                            if let last = points.last {
                                PrivacyValueText(
                                    value: money(last.value),
                                    isHidden: store.hidePortfolioBalances
                                )
                                    .font(.headline.monospacedDigit())
                                    .foregroundStyle(AppColor.nearBlack)
                            }
                        }

                        chartModePicker

                        chartContent

                        if !points.isEmpty && !store.hidePortfolioBalances {
                            if chartMode == .portfolio {
                                HStack(spacing: 18) {
                                    chartLegend(color: AppColor.financeGreen, title: "Value")
                                    chartLegend(color: AppColor.mutedText, title: "Invested", dashed: true)
                                }
                            } else {
                                InvestmentHoldingLegend(
                                    series: holdingSeries,
                                    highlightedHoldingID: $highlightedHoldingID
                                )
                            }
                        }
                    }
                }

                if store.growth.portfolioHistory.unsupportedPositions > 0 {
                    Label(unsupportedPositionsMessage, systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(AppColor.mutedText)
                        .padding(.horizontal, 4)
                }
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .appBackground()
        .navigationTitle("Portfolio history")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: selectedRange) {
            guard
                store.growth.portfolioHistory.range != selectedRange.rawValue,
                let token = store.token
            else { return }
            await store.growth.loadInvestmentHistory(token: token, range: selectedRange.rawValue)
        }
        .refreshable {
            guard let token = store.token else { return }
            await store.growth.loadInvestmentHistory(token: token, range: selectedRange.rawValue, force: true)
        }
    }

    private var rangePicker: some View {
        HStack(spacing: 4) {
            ForEach(InvestmentHistoryRange.allCases) { range in
                Button {
                    selectedDate = nil
                    selectedRange = range
                } label: {
                    Text(range.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(selectedRange == range ? AppColor.primaryText : AppColor.mutedText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(selectedRange == range ? AppColor.filledButton : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(range.accessibilityTitle)
                .accessibilityAddTraits(selectedRange == range ? .isSelected : [])
            }
        }
        .padding(4)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppColor.divider, lineWidth: 1)
        }
    }

    private var chartModePicker: some View {
        Picker("Chart mode", selection: $chartMode) {
            ForEach(InvestmentChartMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: chartMode) {
            selectedDate = nil
            if chartMode == .portfolio {
                highlightedHoldingID = nil
            }
        }
        .disabled(holdingSeries.isEmpty)
    }

    private var historySummary: some View {
        HStack(spacing: 10) {
            historyMetric(
                title: "VALUE",
                value: points.last.map { money($0.value) } ?? "—",
                isHidden: store.hidePortfolioBalances
            )
            historyMetric(
                title: "INVESTED",
                value: points.last.map { money($0.investedAmount) } ?? "—",
                isHidden: store.hidePortfolioBalances
            )
            historyMetric(
                title: "RETURN",
                value: returnValue,
                color: returnColor,
                isHidden: store.hidePortfolioBalances
            )
        }
    }

    private func historyMetric(
        title: String,
        value: String,
        color: Color = AppColor.nearBlack,
        isHidden: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppColor.mutedText)
            PrivacyValueText(value: value, isHidden: isHidden)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppColor.divider, lineWidth: 1)
        }
    }

    @ViewBuilder
    private var chartContent: some View {
        if store.hidePortfolioBalances && !points.isEmpty {
            PortfolioPrivacyPlaceholder(height: 320)
        } else if store.growth.isLoadingInvestmentHistory && points.isEmpty {
            VStack(spacing: 10) {
                ProgressView()
                Text("Loading history")
                    .font(.caption)
                    .foregroundStyle(AppColor.mutedText)
            }
            .frame(maxWidth: .infinity, minHeight: 320)
        } else if let error = store.growth.investmentHistoryError, points.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "chart.line.downtrend.xyaxis")
                    .font(.title2)
                    .foregroundStyle(AppColor.mutedText)
                Text("Portfolio history is unavailable")
                    .font(.subheadline.weight(.semibold))
                Text(error)
                    .font(.caption)
                    .foregroundStyle(AppColor.mutedText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 320)
        } else if points.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.title2)
                    .foregroundStyle(AppColor.financeGreen)
                Text("No portfolio history yet")
                    .font(.subheadline.weight(.semibold))
                Text("Your chart will appear after the first investment trade.")
                    .font(.caption)
                    .foregroundStyle(AppColor.mutedText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 320)
        } else {
            InvestmentHistoryChart(
                points: chartPoints,
                range: displayedRange.rawValue,
                currency: store.growth.portfolioHistory.currency,
                mode: chartMode,
                height: 340,
                axisMaximumCount: 5,
                showsEndPoint: false,
                selectedDate: $selectedDate,
                highlightedHoldingID: $highlightedHoldingID
            )
        }
    }

    private var points: [InvestmentPortfolioChartPoint] {
        store.growth.portfolioHistoryChartPoints
    }

    private var chartPoints: [InvestmentPortfolioChartPoint] {
        sampledInvestmentChartPoints(points, limit: 160)
    }

    private var holdingSeries: [InvestmentHoldingChartValue] {
        investmentHoldingSeries(chartPoints)
    }

    private var displayedRange: InvestmentHistoryRange {
        InvestmentHistoryRange(rawValue: store.growth.portfolioHistory.range) ?? selectedRange
    }

    private var returnAmount: Decimal? {
        guard let last = points.last else { return nil }
        return Decimal(last.value) - Decimal(last.investedAmount)
    }

    private var returnValue: String {
        guard let returnAmount else { return "—" }
        return MoneyFormat.signed(returnAmount, currency: store.growth.portfolioHistory.currency)
    }

    private var returnColor: Color {
        guard let returnAmount else { return AppColor.mutedText }
        return amountColor(returnAmount)
    }

    private var unsupportedPositionsMessage: String {
        let count = store.growth.portfolioHistory.unsupportedPositions
        return count == 1 ? "1 stock position is excluded" : "\(count) stock positions are excluded"
    }

    private func money(_ value: String) -> String {
        MoneyFormat.amount(
            MoneyFormat.decimal(from: value),
            currency: store.growth.portfolioHistory.currency
        )
    }

    private func money(_ value: Double) -> String {
        MoneyFormat.amount(Decimal(value), currency: store.growth.portfolioHistory.currency)
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

struct InvestmentTradeDayBucket: Identifiable, Equatable {
    let date: Date
    let trades: [InvestmentTrade]

    var id: Date { date }
}

func investmentTradeDayBuckets(
    _ trades: [InvestmentTrade],
    calendar: Calendar = .current
) -> [InvestmentTradeDayBucket] {
    let datedTrades = trades.compactMap { trade -> (Date, InvestmentTrade)? in
        guard let date = DateFormat.apiDateTime(trade.occurredAt) else { return nil }
        return (calendar.startOfDay(for: date), trade)
    }
    return Dictionary(grouping: datedTrades, by: \.0)
        .map { day, entries in
            InvestmentTradeDayBucket(
                date: day,
                trades: entries.map(\.1).sorted {
                    (DateFormat.apiDateTime($0.occurredAt) ?? .distantPast)
                        > (DateFormat.apiDateTime($1.occurredAt) ?? .distantPast)
                }
            )
        }
        .sorted { $0.date > $1.date }
}

private struct InvestmentTradesView: View {
    @Bindable var store: MoneyManagerStore
    @State private var searchQuery = ""
    @State private var side: String?

    var body: some View {
        List {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        tradeFilter(title: "All", value: nil)
                        tradeFilter(title: "Buys", value: "buy")
                        tradeFilter(title: "Sells", value: "sell")
                    }
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 8, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            if filteredTrades.isEmpty {
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: searchQuery.isEmpty ? "chart.line.uptrend.xyaxis" : "magnifyingglass")
                            .font(.title2)
                            .foregroundStyle(AppColor.financeGreen)
                        Text(searchQuery.isEmpty && side == nil ? "No investment activity yet" : "No matching trades")
                            .font(.headline)
                            .foregroundStyle(AppColor.nearBlack)
                        Text(searchQuery.isEmpty && side == nil
                            ? "Your recorded trades will appear here."
                            : "Try changing your search or trade filter.")
                            .font(.subheadline)
                            .foregroundStyle(AppColor.mutedText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 36)
                    .listRowBackground(Color.clear)
                }
            } else {
                ForEach(dayBuckets) { bucket in
                    Section {
                        ForEach(bucket.trades) { trade in
                            InvestmentTradeRow(store: store, trade: trade)
                                .listRowBackground(AppColor.surface)
                        }
                    } header: {
                        HStack {
                            Text(DateFormat.dayHeader.string(from: bucket.date))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(AppColor.nearBlack)
                            Spacer()
                            Text("\(bucket.trades.count) \(bucket.trades.count == 1 ? "trade" : "trades")")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppColor.mutedText)
                        }
                        .textCase(nil)
                        .padding(.top, 4)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationTitle("Investment activity")
        .navigationBarTitleDisplayMode(.large)
        .searchable(
            text: $searchQuery,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Asset, broker, amount, or notes"
        )
        .refreshable {
            guard let token = store.token else { return }
            await store.growth.loadInvestments(token: token, force: true)
        }
    }

    private var filteredTrades: [InvestmentTrade] {
        store.growth.investmentTrades.filter { trade in
            let matchesSide = side == nil || trade.side == side
            let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !query.isEmpty else { return matchesSide }
            let searchableText = [
                trade.symbol,
                trade.assetName,
                brokerName(trade.broker),
                trade.side,
                trade.amount,
                trade.quantity,
                trade.notes,
                DateFormat.dateTimeDisplay(trade.occurredAt),
            ].joined(separator: " ").lowercased()
            return matchesSide && searchableText.contains(query)
        }
    }

    private var dayBuckets: [InvestmentTradeDayBucket] {
        investmentTradeDayBuckets(filteredTrades)
    }

    private func tradeFilter(title: String, value: String?) -> some View {
        Button {
            side = value
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(side == value ? AppColor.primaryText : AppColor.nearBlack)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(side == value ? AppColor.filledButton : AppColor.surface)
                .clipShape(Capsule())
                .overlay {
                    if side != value {
                        Capsule().stroke(AppColor.divider, lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

private struct InvestmentAssetIcon: View {
    let symbol: String
    let assetType: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(backgroundColor)

            switch symbol.uppercased() {
            case "BTC":
                Image(systemName: "bitcoinsign")
                    .font(.system(size: 25, weight: .bold))
                    .rotationEffect(.degrees(8))
                    .foregroundStyle(.white)
            case "ETH":
                EthereumMark()
                    .fill(.white)
                    .frame(width: 23, height: 29)
            default:
                Text(String(symbol.prefix(1)))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 46, height: 46)
        .accessibilityHidden(true)
    }

    private var backgroundColor: Color {
        switch symbol.uppercased() {
        case "BTC": Color(red: 247 / 255, green: 147 / 255, blue: 26 / 255)
        case "ETH": Color(red: 98 / 255, green: 126 / 255, blue: 234 / 255)
        default: assetType == "crypto" ? AppColor.crypto : AppColor.stocks
        }
    }
}

private struct EthereumMark: Shape {
    func path(in rect: CGRect) -> Path {
        let centerX = rect.midX
        var path = Path()

        path.move(to: CGPoint(x: centerX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.43))
        path.addLine(to: CGPoint(x: centerX, y: rect.minY + rect.height * 0.59))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.43))
        path.closeSubpath()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.53))
        path.addLine(to: CGPoint(x: centerX, y: rect.minY + rect.height * 0.69))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.53))
        path.addLine(to: CGPoint(x: centerX, y: rect.maxY))
        path.closeSubpath()

        return path
    }
}

private struct InvestmentPositionRow: View {
    let position: InvestmentPosition
    let hidePortfolioBalances: Bool

    var body: some View {
        HStack(spacing: 13) {
            InvestmentAssetIcon(symbol: position.symbol, assetType: position.assetType)
            VStack(alignment: .leading, spacing: 3) {
                Text(position.assetName).font(.headline).foregroundStyle(AppColor.nearBlack)
                PrivacyValueText(
                    value: positionDetail,
                    isHidden: hidePortfolioBalances,
                    hiddenAccessibilityLabel: "\(position.symbol), \(brokerName(position.broker)), quantity hidden"
                )
                    .font(.caption).foregroundStyle(AppColor.mutedText)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                PrivacyValueText(
                    value: position.currentValue.map {
                        MoneyFormat.amount(MoneyFormat.decimal(from: $0), currency: position.currency)
                    } ?? "Set price",
                    isHidden: hidePortfolioBalances
                )
                    .font(.subheadline.weight(.bold)).foregroundStyle(position.currentValue == nil ? AppColor.crypto : AppColor.nearBlack)
                PrivacyValueText(
                    value: "Avg \(MoneyFormat.amount(MoneyFormat.decimal(from: position.averageCost), currency: position.currency))",
                    isHidden: hidePortfolioBalances,
                    hiddenAccessibilityLabel: "Average cost hidden"
                )
                    .font(.caption2).foregroundStyle(AppColor.mutedText)
            }
        }
        .padding(15)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppMetric.cardRadius, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: AppMetric.cardRadius, style: .continuous).stroke(AppColor.divider, lineWidth: 1) }
    }

    private var positionDetail: String {
        let listing = position.exchange.map { " · \($0)" } ?? ""
        return "\(position.symbol)\(listing) · \(brokerName(position.broker)) · \(position.quantity)"
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
                        if selectedAsset.type == .crypto {
                            Text("Revolut X").tag("revolut_x")
                        } else {
                            Text("Trading 212").tag("trading212")
                        }
                    }
                    if selectedAsset.type == .stock {
                        LabeledContent("Listing", value: "\(selectedAsset.exchange) · \(selectedAsset.marketCurrency)")
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
                    Text("The backend looks up the market price at this time, converts it to EUR when needed, and calculates the quantity.")
                }
                if let error = store.growth.error { Section { ErrorBanner(message: error) } }
            }
            .navigationTitle("Record trade")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: selectedAsset) { _, asset in
                broker = asset.type == .crypto ? "revolut_x" : "trading212"
            }
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
            exchange: selectedAsset.exchange,
            marketCurrency: selectedAsset.marketCurrency,
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
                        if selectedAsset.type == .crypto {
                            Text("Revolut X").tag("revolut_x")
                        } else {
                            Text("Trading 212").tag("trading212")
                        }
                    }
                    if selectedAsset.type == .stock {
                        LabeledContent("Listing", value: "\(selectedAsset.exchange) · \(selectedAsset.marketCurrency)")
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
            .onChange(of: selectedAsset) { _, asset in
                broker = asset.type == .crypto ? "revolut_x" : "trading212"
            }
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
            exchange: selectedAsset.exchange,
            marketCurrency: selectedAsset.marketCurrency,
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
                    assetType: "crypto", symbol: "BTC", assetName: "Bitcoin", exchange: nil, marketCurrency: "EUR", broker: "revolut_x",
                    quantity: "0.084", averageCost: "54000.00", investedAmount: "4536.00",
                    currentPrice: "64525.00", currentValue: "5420.10", unrealizedProfit: "884.10",
                    unrealizedPercent: "19.49", realizedProfit: "0.00", currency: "EUR",
                    priceAsOf: "2026-07-13T20:00:00Z", priceStatus: "available"
                ),
                InvestmentPosition(
                    assetType: "crypto", symbol: "ETH", assetName: "Ethereum", exchange: nil, marketCurrency: "EUR", broker: "revolut_x",
                    quantity: "1.25", averageCost: "2100.00", investedAmount: "2625.00",
                    currentPrice: "2400.00", currentValue: "3000.00", unrealizedProfit: "375.00",
                    unrealizedPercent: "14.29", realizedProfit: "0.00", currency: "EUR",
                    priceAsOf: "2026-07-13T20:00:00Z", priceStatus: "available"
                ),
                InvestmentPosition(
                    assetType: "stock", symbol: "AAPL", assetName: "Apple", exchange: "NASDAQ", marketCurrency: "USD", broker: "trading212",
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
                previewHistoryPoint(asOf: "2026-02-01T00:00:00Z", value: "1200.00", invested: "1200.00", btc: "800.00", eth: "400.00"),
                previewHistoryPoint(asOf: "2026-03-01T00:00:00Z", value: "1960.00", invested: "1800.00", btc: "1300.00", eth: "660.00"),
                previewHistoryPoint(asOf: "2026-04-01T00:00:00Z", value: "2650.00", invested: "2500.00", btc: "1750.00", eth: "900.00"),
                previewHistoryPoint(asOf: "2026-05-01T00:00:00Z", value: "3120.00", invested: "3100.00", btc: "2050.00", eth: "1070.00"),
                previewHistoryPoint(asOf: "2026-06-01T00:00:00Z", value: "4010.00", invested: "3900.00", btc: "2700.00", eth: "1310.00"),
                previewHistoryPoint(asOf: "2026-07-13T20:00:00Z", value: "5420.10", invested: "4536.00", btc: "3900.10", eth: "1520.00"),
            ],
            currency: "EUR",
            range: "1y",
            unsupportedPositions: 1
        )
        store.growth.investmentTrades = [
            InvestmentTrade(id: 2, assetType: "crypto", symbol: "BTC", assetName: "Bitcoin", exchange: nil, marketCurrency: "EUR", broker: "revolut_x", side: "buy", amount: "1240.00", quantity: "0.02", pricePerUnit: "62000", fees: "1.50", currency: "EUR", occurredAt: "2026-07-10T08:30:00Z", notes: "Monthly buy", priceProvider: "kraken", priceAsOf: "2026-07-10T08:30:00Z"),
            InvestmentTrade(id: 1, assetType: "stock", symbol: "AAPL", assetName: "Apple", exchange: "NASDAQ", marketCurrency: "USD", broker: "trading212", side: "buy", amount: "739.62", quantity: "4.2", pricePerUnit: "176.10", fees: "0", currency: "EUR", occurredAt: "2026-06-15T10:15:00Z", notes: "", priceProvider: "twelve_data", priceAsOf: "2026-06-15T10:15:00Z"),
        ]
        store.growth.investmentSchedules = [
            InvestmentSchedule(id: 1, assetType: "crypto", symbol: "BTC", assetName: "Bitcoin", exchange: nil, marketCurrency: "EUR", broker: "revolut_x", amount: "100.00", currency: "EUR", frequency: "monthly", frequencyInterval: 1, startDate: "2026-07-15", endDate: nil, dayOfWeek: nil, dayOfMonth: 15, timezone: "Europe/Sofia", status: "active", nextOccurrence: "2026-07-15")
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

private func previewHistoryPoint(
    asOf: String,
    value: String,
    invested: String,
    btc: String,
    eth: String
) -> InvestmentPortfolioHistoryPoint {
    InvestmentPortfolioHistoryPoint(
        asOf: asOf,
        value: value,
        investedAmount: invested,
        holdings: [
            InvestmentPortfolioHistoryHolding(
                assetType: "crypto", symbol: "BTC", assetName: "Bitcoin", exchange: nil, value: btc
            ),
            InvestmentPortfolioHistoryHolding(
                assetType: "crypto", symbol: "ETH", assetName: "Ethereum", exchange: nil, value: eth
            ),
        ]
    )
}
#endif
