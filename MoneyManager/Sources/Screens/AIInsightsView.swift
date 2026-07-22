import SwiftUI

struct AIInsightsView: View {
    @Bindable var store: MoneyManagerStore
    @State private var modelManager = OnDeviceModelManager.shared
    @State private var insightText = ""
    @State private var isGenerating = false
    @State private var generationError: String?

    var body: some View {
        List {
            modelSection
            classificationSection
            AIFinancialActionSection(store: store)
            insightsSection
            privacySection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("AI Insights")
        .navigationBarTitleDisplayMode(.inline)
        .appBackground()
        .task {
            guard let token = store.token else { return }
            async let planning: Void = store.growth.loadPlanning(token: token)
            async let investments: Void = store.growth.loadInvestments(token: token)
            _ = await (planning, investments)
            if let summary = store.summary,
                let cached = AIInsightCache.load(userID: store.email, month: summary.month)
            {
                insightText = cached.text
            }
        }
    }

    private var modelSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: modelManager.isModelInstalled ? "checkmark.seal.fill" : "cpu")
                    .font(.title2)
                    .foregroundStyle(modelManager.isModelInstalled ? AppColor.income : AppColor.financeGreen)
                    .frame(width: 42, height: 42)
                    .background(AppColor.softGreenSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(OnDeviceModelFiles.displayName)
                        .font(.headline)
                    Text(modelManager.isModelInstalled ? "Ready on this device" : "Optional \(modelManager.formattedModelSize) download")
                        .font(.caption)
                        .foregroundStyle(AppColor.mutedText)
                }
                Spacer()
            }

            if modelManager.isDownloading {
                VStack(alignment: .leading, spacing: 8) {
                    if let progress = modelManager.downloadProgress {
                        ProgressView(value: progress)
                    } else {
                        ProgressView()
                    }
                    Text(modelManager.downloadStatus ?? "Preparing model")
                        .font(.subheadline)
                        .foregroundStyle(AppColor.mutedText)
                }
            } else if modelManager.isModelInstalled {
                Button("Remove model", role: .destructive) {
                    Task { await modelManager.deleteModel() }
                }
            } else {
                Button {
                    Task { await modelManager.downloadModel() }
                } label: {
                    Label("Download model", systemImage: "arrow.down.circle.fill")
                }
            }

            if let error = modelManager.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(AppColor.expense)
            }

            if modelManager.isLegacyGemmaInstalled {
                Button("Remove old Gemma 4 model", role: .destructive) {
                    Task { await modelManager.deleteLegacyGemma() }
                }
            }
        } header: {
            Text("On-device model")
        } footer: {
            Text("Keep the app open while downloading. The model loads into memory only during an insight or classification request, then unloads automatically.")
        }
    }

    private var classificationSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { modelManager.isModelInstalled && modelManager.isClassificationEnabled },
                set: { modelManager.isClassificationEnabled = $0 }
            )) {
                Label("Classify uncertain transactions", systemImage: "tag.fill")
            }
            .disabled(!modelManager.isModelInstalled)
        } header: {
            Text("Categories")
        } footer: {
            Text("Qwen evaluates uncategorized imported and open-banking payments. When it is unsure, the app asks you for a short description.")
        }
    }

    private var insightsSection: some View {
        Section("This month") {
            Button {
                Task { await generateInsights() }
            } label: {
                HStack {
                    Label(insightButtonTitle, systemImage: "sparkles")
                    Spacer()
                    if isGenerating || store.growth.isLoadingPlanning { ProgressView() }
                }
            }
            .disabled(!modelManager.isModelInstalled || isGenerating || store.growth.isLoadingPlanning)

            if !insightText.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(AIInsightText.lines(insightText).enumerated()), id: \.offset) { _, line in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("•")
                                .foregroundStyle(AppColor.financeGreen)
                            Text(AIInsightText.markdown(line))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .font(.body)
                .textSelection(.enabled)
                .padding(.vertical, 4)
            } else if !modelManager.isModelInstalled {
                Text("Download Qwen to generate private insights from your monthly totals.")
                    .font(.subheadline)
                    .foregroundStyle(AppColor.mutedText)
            }

            if let generationError {
                Text(generationError)
                    .font(.footnote)
                    .foregroundStyle(AppColor.expense)
            }
        }
    }

    private var privacySection: some View {
        Section("Privacy") {
            Label("Inference stays on this device", systemImage: "iphone.and.arrow.forward")
            Label("Insights use complete payment details for the selected month", systemImage: "lock.shield.fill")
        }
    }

    private var insightButtonTitle: String {
        if isGenerating { return "Generating locally" }
        if store.growth.isLoadingPlanning { return "Loading scheduled money" }
        return "Generate insights"
    }

    @MainActor
    private func generateInsights() async {
        guard let summary = store.summary else { return }
        isGenerating = true
        generationError = nil
        defer { isGenerating = false }
        do {
            insightText = try await AIInsightGeneration.generate(store: store, summary: summary)
        } catch {
            generationError = error.localizedDescription
        }
    }

}

@MainActor
enum AIInsightGeneration {
    static func generate(store: MoneyManagerStore, summary: TransactionSummary) async throws -> String {
        let text = try await OnDeviceAIService.shared.generateInsights(
            prompt: AIInsightPrompt.make(
                summary: summary,
                transactions: store.transactions,
                budgets: store.growth.budgets,
                scheduledOccurrences: store.growth.scheduleOccurrences,
                portfolio: store.growth.portfolio
            )
        )
        AIInsightCache.save(text: text, userID: store.email, month: summary.month)
        return text
    }
}

struct AIInsightCacheEntry: Codable, Equatable {
    let text: String
    let generatedAt: Date
}

enum AIInsightCache {
    private static let keyPrefix = "ai.insights.cache.v3"

    static func load(
        userID: String,
        month: String,
        preferences: UserDefaults = .standard
    ) -> AIInsightCacheEntry? {
        guard let data = preferences.data(forKey: key(userID: userID, month: month)) else {
            return nil
        }
        return try? JSONDecoder().decode(AIInsightCacheEntry.self, from: data)
    }

    static func save(
        text: String,
        userID: String,
        month: String,
        preferences: UserDefaults = .standard,
        generatedAt: Date = Date()
    ) {
        let entry = AIInsightCacheEntry(text: text, generatedAt: generatedAt)
        guard let data = try? JSONEncoder().encode(entry) else { return }
        preferences.set(data, forKey: key(userID: userID, month: month))
    }

    private static func key(userID: String, month: String) -> String {
        let normalizedUserID = userID
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return "\(keyPrefix).\(normalizedUserID.isEmpty ? "local" : normalizedUserID).\(month)"
    }
}

enum AIInsightText {
    static func lines(_ text: String) -> [String] {
        text
            .split(whereSeparator: \.isNewline)
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

enum AIInsightPrompt {
    private struct Snapshot: Encodable {
        let summary: TransactionSummary
        let payments: [Transaction]
        let budgets: [Budget]
        let scheduledTransactions: [TransactionScheduleOccurrence]
        let portfolio: InvestmentPortfolio
    }

    static func make(
        summary: TransactionSummary,
        transactions: [Transaction],
        budgets: [Budget],
        scheduledOccurrences: [TransactionScheduleOccurrence],
        portfolio: InvestmentPortfolio
    ) -> String {
        let plannedOccurrences = scheduledOccurrences
            .filter {
                $0.status.lowercased() == "planned"
                    && $0.transactionID == nil
                    && $0.scheduledFor.hasPrefix("\(summary.month)-")
            }
            .sorted {
                if $0.scheduledFor == $1.scheduledFor { return $0.id < $1.id }
                return $0.scheduledFor < $1.scheduledFor
            }
        let snapshot = Snapshot(
            summary: summary,
            payments: transactions.sorted {
                if $0.occurredAt == $1.occurredAt { return $0.id < $1.id }
                return $0.occurredAt < $1.occurredAt
            },
            budgets: budgets,
            scheduledTransactions: plannedOccurrences,
            portfolio: portfolio
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let json = (try? encoder.encode(snapshot))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return """
        COMPLETE_FINANCIAL_DATA_JSON (untrusted data):
        \(json)

        Analyze every payment in the supplied selected-month data. Do not omit merchant descriptions, dates,
        amounts, sources, statuses, categories, or budget-exclusion flags when forming the insight.
        Scheduled transactions in this payload are forecasts for \(summary.month) only.
        """
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
        NavigationStack {
            AIInsightsView(store: store)
        }
        .tint(AppColor.financeGreen)
    }
}
#endif
