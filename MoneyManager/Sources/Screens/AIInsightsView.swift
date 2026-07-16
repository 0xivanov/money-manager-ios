import SwiftUI

struct AIInsightsView: View {
    @Bindable var store: MoneyManagerStore
    @State private var modelManager = GemmaModelManager.shared
    @State private var insightText = ""
    @State private var isGenerating = false
    @State private var generationError: String?

    var body: some View {
        List {
            modelSection
            classificationSection
            insightsSection
            privacySection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("AI Insights")
        .navigationBarTitleDisplayMode(.inline)
        .appBackground()
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
                    Text(GemmaModelFiles.displayName)
                        .font(.headline)
                    Text(modelManager.isModelInstalled ? "Ready on this device" : "Optional \(modelManager.formattedModelSize) download")
                        .font(.caption)
                        .foregroundStyle(AppColor.mutedText)
                }
                Spacer()
            }

            if modelManager.isDownloading {
                HStack(spacing: 10) {
                    ProgressView()
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
        } header: {
            Text("On-device model")
        } footer: {
            Text("Keep the app open while downloading. The model is verified before use and can be removed at any time.")
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
            Text("Fast rules and the small Core ML classifier run first. Gemma is only used when they are unsure, and only high-confidence matches replace Other.")
        }
    }

    private var insightsSection: some View {
        Section("This month") {
            Button {
                Task { await generateInsights() }
            } label: {
                HStack {
                    Label(isGenerating ? "Generating locally" : "Generate insights", systemImage: "sparkles")
                    Spacer()
                    if isGenerating { ProgressView() }
                }
            }
            .disabled(!modelManager.isModelInstalled || isGenerating)

            if !insightText.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(insightLines.enumerated()), id: \.offset) { _, line in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("•")
                                .foregroundStyle(AppColor.financeGreen)
                            Text(markdownLine(line))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .font(.body)
                .textSelection(.enabled)
                .padding(.vertical, 4)
            } else if !modelManager.isModelInstalled {
                Text("Download Gemma to generate private insights from your monthly totals.")
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
            Label("Insights use aggregates, not merchant descriptions", systemImage: "lock.shield.fill")
        }
    }

    private var insightLines: [String] {
        insightText
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

    private func markdownLine(_ line: String) -> AttributedString {
        (try? AttributedString(markdown: line)) ?? AttributedString(line)
    }

    @MainActor
    private func generateInsights() async {
        guard let summary = store.summary else { return }
        isGenerating = true
        generationError = nil
        defer { isGenerating = false }
        do {
            insightText = try await GemmaOnDeviceService.shared.generateInsights(
                prompt: insightPrompt(summary: summary)
            )
        } catch {
            generationError = error.localizedDescription
        }
    }

    private func insightPrompt(summary: TransactionSummary) -> String {
        let expenseTransactions = store.transactions.filter { $0.type == TransactionType.expense.rawValue }
        let grouped = Dictionary(grouping: expenseTransactions, by: { $0.category })
        let categoryLines = grouped.map { category, transactions in
            let total = transactions.reduce(Decimal.zero) {
                $0 + MoneyFormat.decimal(from: $1.amount)
            }
            return (category, total, transactions.count)
        }
        .sorted { $0.1 > $1.1 }
        .prefix(8)
        .map { "- \($0.0): \($0.1) \(summary.currency) across \($0.2) transactions" }
        .joined(separator: "\n")

        let budgetLines = store.growth.budgets.prefix(8).map {
            "- \($0.name): spent \($0.spentAmount) of \($0.amount) \($0.currency), status \($0.alertLevel)"
        }.joined(separator: "\n")

        let portfolio = store.growth.portfolio
        return """
        Month: \(summary.month)
        Income: \(summary.income) \(summary.currency)
        Expenses: \(summary.expense) \(summary.currency)
        Balance: \(summary.balance) \(summary.currency)
        Transaction count: \(summary.transactionCount)

        Expense categories:
        \(categoryLines.isEmpty ? "- No expense data" : categoryLines)

        Budgets:
        \(budgetLines.isEmpty ? "- No budgets" : budgetLines)

        Portfolio: invested \(portfolio.investedAmount) \(portfolio.currency), current value \(portfolio.currentValue ?? "unavailable"), unrealized profit \(portfolio.unrealizedProfit ?? "unavailable").
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
