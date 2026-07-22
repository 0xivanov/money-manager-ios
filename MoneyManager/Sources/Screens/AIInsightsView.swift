import SwiftUI

struct AIInsightsView: View {
    @Bindable var store: MoneyManagerStore
    @State private var report: MonthlyFinancialReport?
    @State private var generatedAt: Date?
    @State private var isGenerating = false

    var body: some View {
        List {
            intelligenceSection
            reportSections
            methodologySection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Financial Insights")
        .navigationBarTitleDisplayMode(.inline)
        .appBackground()
        .task {
            guard let token = store.token else { return }
            async let planning: Void = store.growth.loadPlanning(token: token)
            async let investments: Void = store.growth.loadInvestments(token: token)
            _ = await (planning, investments)
            loadCachedReport()
        }
    }

    private var intelligenceSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: modelStatus == .available ? "apple.intelligence" : "function")
                    .font(.title2)
                    .foregroundStyle(AppColor.financeGreen)
                    .frame(width: 42, height: 42)
                    .background(AppColor.softGreenSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("On-device financial analysis")
                        .font(.headline)
                    Text(modelStatus.detail)
                        .font(.caption)
                        .foregroundStyle(AppColor.mutedText)
                }
            }

            Button {
                Task { await generateReport() }
            } label: {
                HStack {
                    Label(report == nil ? "Analyse this month" : "Refresh analysis", systemImage: "sparkles")
                    Spacer()
                    if isGenerating { ProgressView() }
                }
            }
            .disabled(isGenerating || store.growth.isLoadingPlanning || store.summary == nil)
        } header: {
            Text("How it works")
        } footer: {
            Text("The app calculates every amount and risk rule itself. Apple Intelligence only refines the summary when it is available.")
        }
    }

    @ViewBuilder
    private var reportSections: some View {
        if let report {
            Section("Overview") {
                Text(report.summary)
                    .font(.body)
                    .textSelection(.enabled)
                LabeledContent("Source", value: report.source.label)
                    .font(.caption)
                    .foregroundStyle(AppColor.mutedText)
                if let generatedAt {
                    LabeledContent("Updated", value: generatedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(AppColor.mutedText)
                }
            }

            findingSection("On track", findings: report.positiveChanges)
            findingSection("Spending and cash flow", findings: report.spendingRisks)
            findingSection("Portfolio", findings: report.portfolioRisks)

            if !report.nextMonthPriorities.isEmpty {
                Section("Next actions") {
                    ForEach(Array(report.nextMonthPriorities.enumerated()), id: \.offset) { index, priority in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.caption.bold())
                                .foregroundStyle(AppColor.financeGreen)
                                .frame(width: 24, height: 24)
                                .background(AppColor.softGreenSurface)
                                .clipShape(Circle())
                            Text(priority)
                                .font(.subheadline)
                        }
                    }
                }
            }
        } else if !isGenerating {
            Section {
                ContentUnavailableView(
                    "No analysis yet",
                    systemImage: "chart.bar.doc.horizontal",
                    description: Text("Analyse this month to review cash flow, budgets, unusual spending, scheduled money, and portfolio concentration.")
                )
            }
        }
    }

    private func findingSection(_ title: String, findings: [FinancialInsight]) -> some View {
        Section(title) {
            if findings.isEmpty {
                Text("No findings in this area.")
                    .font(.subheadline)
                    .foregroundStyle(AppColor.mutedText)
            } else {
                ForEach(findings) { finding in
                    FinancialInsightRow(finding: finding)
                }
            }
        }
    }

    private var methodologySection: some View {
        Section("Privacy and limits") {
            Label("Transaction and portfolio data stays on this device", systemImage: "lock.shield.fill")
            Label("All calculations use explicit, testable rules", systemImage: "checkmark.seal.fill")
            Text("Concentration and unusual-payment thresholds are heuristics, not financial advice. Market prices can be delayed or missing.")
                .font(.footnote)
                .foregroundStyle(AppColor.mutedText)
        }
    }

    private var modelStatus: AppleFinancialModelStatus {
        FinancialIntelligenceService.modelStatus
    }

    @MainActor
    private func generateReport() async {
        guard let summary = store.summary, !isGenerating else { return }
        isGenerating = true
        defer { isGenerating = false }
        let analytics = FinancialAnalyticsEngine.analyze(
            summary: summary,
            transactions: store.transactions,
            budgets: store.growth.budgets,
            scheduledOccurrences: store.growth.scheduleOccurrences,
            portfolio: store.growth.portfolio
        )
        let generated = await FinancialIntelligenceService.shared.generateReport(analytics: analytics)
        let timestamp = Date()
        report = generated
        generatedAt = timestamp
        AIInsightCache.save(
            report: generated,
            userID: store.email,
            month: summary.month,
            generatedAt: timestamp
        )
    }

    private func loadCachedReport() {
        guard let summary = store.summary,
            let cached = AIInsightCache.load(userID: store.email, month: summary.month)
        else { return }
        report = cached.report
        generatedAt = cached.generatedAt
    }
}

struct FinancialInsightRow: View {
    let finding: FinancialInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label(finding.title, systemImage: severityIcon)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(finding.severity.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(severityColor)
            }
            Text(finding.explanation)
                .font(.subheadline)
            Text(finding.supportingMetric)
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(AppColor.financeGreen)
            if let action = finding.suggestedAction {
                Text(action)
                    .font(.caption)
                    .foregroundStyle(AppColor.mutedText)
            }
        }
        .padding(.vertical, 4)
    }

    private var severityIcon: String {
        switch finding.severity {
        case .informational: "checkmark.circle.fill"
        case .moderate: "exclamationmark.circle.fill"
        case .high: "exclamationmark.triangle.fill"
        }
    }

    private var severityColor: Color {
        switch finding.severity {
        case .informational: AppColor.income
        case .moderate: .orange
        case .high: AppColor.expense
        }
    }
}

struct AIInsightCacheEntry: Codable, Equatable {
    let report: MonthlyFinancialReport
    let generatedAt: Date
}

enum AIInsightCache {
    private static let keyPrefix = "ai.insights.cache.v4"

    static func load(
        userID: String,
        month: String,
        preferences: UserDefaults = .standard
    ) -> AIInsightCacheEntry? {
        guard let data = preferences.data(forKey: key(userID: userID, month: month)) else { return nil }
        return try? JSONDecoder().decode(AIInsightCacheEntry.self, from: data)
    }

    static func save(
        report: MonthlyFinancialReport,
        userID: String,
        month: String,
        preferences: UserDefaults = .standard,
        generatedAt: Date = Date()
    ) {
        let entry = AIInsightCacheEntry(report: report, generatedAt: generatedAt)
        guard let data = try? JSONEncoder().encode(entry) else { return }
        preferences.set(data, forKey: key(userID: userID, month: month))
    }

    private static func key(userID: String, month: String) -> String {
        let normalizedUserID = userID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(keyPrefix).\(normalizedUserID.isEmpty ? "local" : normalizedUserID).\(month)"
    }
}

enum AIInsightText {
    static func lines(_ text: String) -> [String] {
        text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { line in
                for prefix in ["- ", "* ", "• "] where line.hasPrefix(prefix) {
                    return String(line.dropFirst(prefix.count))
                }
                return line
            }
    }

    static func markdown(_ line: String) -> AttributedString {
        (try? AttributedString(markdown: line)) ?? AttributedString(line)
    }
}

#if DEBUG
struct AIInsightsPreviewHost: View {
    @State private var store: MoneyManagerStore

    init() {
        let previewStore = MoneyManagerStore()
        previewStore.summary = TransactionSummary(
            month: "2026-07",
            income: "3200.00",
            expense: "1248.40",
            balance: "1951.60",
            currency: "EUR",
            transactionCount: 23
        )
        previewStore.transactions = [
            Transaction(id: 1, type: "expense", category: "groceries", amount: "312.40", currency: "EUR", occurredAt: "2026-07-15"),
            Transaction(id: 2, type: "expense", category: "dining_out", amount: "164.00", currency: "EUR", occurredAt: "2026-07-13"),
            Transaction(id: 3, type: "expense", category: "housing", amount: "650.00", currency: "EUR", occurredAt: "2026-07-01"),
            Transaction(id: 4, type: "expense", category: "transport", amount: "122.00", currency: "EUR", occurredAt: "2026-07-10")
        ]
        _store = State(initialValue: previewStore)
    }

    var body: some View {
        NavigationStack { AIInsightsView(store: store) }
            .tint(AppColor.financeGreen)
    }
}
#endif
