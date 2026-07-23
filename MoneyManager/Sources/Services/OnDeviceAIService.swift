import Foundation
import FoundationModels

enum FinancialInsightSeverity: String, Codable, Equatable, CaseIterable {
    case informational
    case moderate
    case high

    var title: String {
        switch self {
        case .informational: "On track"
        case .moderate: "Worth reviewing"
        case .high: "Needs attention"
        }
    }
}

enum FinancialInsightKind: String, Codable, Equatable {
    case cashFlow
    case spending
    case budget
    case scheduledMoney
    case portfolio
    case dataQuality
}

struct FinancialInsight: Codable, Equatable, Identifiable {
    let id: String
    let kind: FinancialInsightKind
    let title: String
    let explanation: String
    let severity: FinancialInsightSeverity
    let suggestedAction: String?
    let supportingMetric: String
}

struct FinancialAnalytics: Codable, Equatable {
    let month: String
    let currency: String
    let monthlyIncome: Decimal
    let monthlySpending: Decimal
    let monthlyBalance: Decimal
    let savingsRate: Decimal?
    let findings: [FinancialInsight]
}

enum FinancialReportSource: String, Codable, Equatable {
    case appleFoundationModel
    case deterministic

    var label: String {
        switch self {
        case .appleFoundationModel: "Explained by Apple Intelligence"
        case .deterministic: "Calculated on this device"
        }
    }
}

struct MonthlyFinancialReport: Codable, Equatable {
    let summary: String
    let positiveChanges: [FinancialInsight]
    let spendingRisks: [FinancialInsight]
    let portfolioRisks: [FinancialInsight]
    let nextMonthPriorities: [String]
    let source: FinancialReportSource

    var allFindings: [FinancialInsight] {
        positiveChanges + spendingRisks + portfolioRisks
    }
}

enum FinancialAnalyticsEngine {
    static func analyze(
        summary: TransactionSummary,
        transactions: [Transaction],
        budgets: [Budget],
        scheduledOccurrences: [TransactionScheduleOccurrence],
        portfolio: InvestmentPortfolio
    ) -> FinancialAnalytics {
        let income = MoneyFormat.decimal(from: summary.income)
        let spending = MoneyFormat.decimal(from: summary.expense)
        let balance = income - spending
        let savingsRate = income > .zero ? balance / income : nil
        let currency = summary.currency
        var findings: [FinancialInsight] = []

        findings.append(cashFlowFinding(
            income: income,
            spending: spending,
            balance: balance,
            savingsRate: savingsRate,
            currency: currency
        ))

        let selectedExpenses = transactions.filter {
            $0.type == TransactionType.expense.rawValue
                && $0.occurredAt.hasPrefix(summary.month)
        }
        if let categoryFinding = largestCategoryFinding(
            transactions: selectedExpenses,
            totalSpending: spending,
            currency: currency
        ) {
            findings.append(categoryFinding)
        }
        if let unusualFinding = unusualTransactionFinding(
            transactions: selectedExpenses,
            currency: currency
        ) {
            findings.append(unusualFinding)
        }

        findings.append(contentsOf: budgetFindings(budgets, currency: currency))
        if let scheduledFinding = scheduledMoneyFinding(
            summary: summary,
            occurrences: scheduledOccurrences,
            currentBalance: MoneyFormat.decimal(from: summary.balance)
        ) {
            findings.append(scheduledFinding)
        }
        findings.append(contentsOf: portfolioFindings(portfolio))

        return FinancialAnalytics(
            month: summary.month,
            currency: currency,
            monthlyIncome: income,
            monthlySpending: spending,
            monthlyBalance: balance,
            savingsRate: savingsRate,
            findings: Array(findings.prefix(10))
        )
    }

    private static func cashFlowFinding(
        income: Decimal,
        spending: Decimal,
        balance: Decimal,
        savingsRate: Decimal?,
        currency: String
    ) -> FinancialInsight {
        if let savingsRate, balance >= .zero {
            let percent = percentage(savingsRate)
            return FinancialInsight(
                id: "cash-flow",
                kind: .cashFlow,
                title: savingsRate >= Decimal(string: "0.20")! ? "Healthy monthly buffer" : "Positive monthly balance",
                explanation: "Income exceeds spending by \(money(balance, currency: currency)).",
                severity: .informational,
                suggestedAction: savingsRate >= Decimal(string: "0.20")!
                    ? "Decide how much of the remaining balance should go to savings or upcoming goals."
                    : "Review flexible spending to create a larger buffer.",
                supportingMetric: "Savings rate \(percent)"
            )
        }

        let shortfall = abs(balance)
        return FinancialInsight(
            id: "cash-flow",
            kind: .cashFlow,
            title: income == .zero ? "No income recorded" : "Spending exceeds income",
            explanation: income == .zero
                ? "No income is recorded for this month, while spending is \(money(spending, currency: currency))."
                : "Spending is \(money(shortfall, currency: currency)) above recorded income.",
            severity: .high,
            suggestedAction: "Check the largest spending categories and set a realistic limit for the rest of the month.",
            supportingMetric: "Spending balance \(money(balance, currency: currency))"
        )
    }

    private static func largestCategoryFinding(
        transactions: [Transaction],
        totalSpending: Decimal,
        currency: String
    ) -> FinancialInsight? {
        guard totalSpending > .zero else { return nil }
        let totals = Dictionary(grouping: transactions, by: { $0.category }).mapValues { rows in
            rows.reduce(Decimal.zero) { $0 + MoneyFormat.decimal(from: $1.amount) }
        }
        guard let largest = totals.max(by: { $0.value < $1.value }), largest.value > .zero else {
            return nil
        }
        let share = largest.value / totalSpending
        return FinancialInsight(
            id: "largest-category-\(largest.key)",
            kind: .spending,
            title: "\(categoryTitle(largest.key)) is the largest category",
            explanation: "You spent \(money(largest.value, currency: currency)) in this category this month.",
            severity: share >= Decimal(string: "0.40")! ? .moderate : .informational,
            suggestedAction: share >= Decimal(string: "0.40")!
                ? "Review the transactions in \(categoryTitle(largest.key)) before changing other categories."
                : nil,
            supportingMetric: "\(percentage(share)) of monthly spending"
        )
    }

    private static func unusualTransactionFinding(
        transactions: [Transaction],
        currency: String
    ) -> FinancialInsight? {
        let minimumLargeAmount = Decimal(100)
        let ratioThreshold = Decimal(string: "2.5")!
        let eligible = transactions.filter { $0.scheduleOccurrenceID == nil }
        let candidates = Dictionary(grouping: eligible, by: { $0.category }).compactMap { category, rows -> (Transaction, Decimal, Decimal)? in
            guard rows.count >= 3 else { return nil }
            let amounts = rows
                .map { MoneyFormat.decimal(from: $0.amount) }
                .filter { $0 > .zero }
                .sorted()
            guard amounts.count >= 3, let largest = amounts.last else { return nil }
            let middle = amounts.count / 2
            let median = amounts.count.isMultiple(of: 2)
                ? (amounts[middle - 1] + amounts[middle]) / 2
                : amounts[middle]
            guard largest >= minimumLargeAmount,
                median > .zero,
                largest >= median * ratioThreshold,
                let transaction = rows.max(by: {
                    MoneyFormat.decimal(from: $0.amount) < MoneyFormat.decimal(from: $1.amount)
                })
            else { return nil }
            return (transaction, largest, median)
        }
        guard let (transaction, largest, median) = candidates.max(by: {
            $0.1 / $0.2 < $1.1 / $1.2
        }) else { return nil }
        let description = transaction.description?.trimmingCharacters(in: .whitespacesAndNewlines)
        let category = categoryTitle(transaction.category)
        return FinancialInsight(
            id: "unusual-transaction-\(transaction.id)",
            kind: .spending,
            title: "One payment is unusually large",
            explanation: "The \(money(largest, currency: currency)) payment\(description.map { " to \($0)" } ?? "") is at least 2.5 times the typical \(category) payment this month.",
            severity: .moderate,
            suggestedAction: "Confirm that this payment is expected and categorised correctly.",
            supportingMetric: "Typical \(category) payment \(money(median, currency: currency))"
        )
    }

    private static func budgetFindings(_ budgets: [Budget], currency: String) -> [FinancialInsight] {
        budgets.compactMap { budget in
            let progress = MoneyFormat.decimal(from: budget.progressPercent)
            let threshold = Decimal(budget.warningThreshold)
            guard progress >= threshold else { return nil }
            let remaining = MoneyFormat.decimal(from: budget.remainingAmount)
            let isExceeded = progress >= Decimal(100)
            return FinancialInsight(
                id: "budget-\(budget.id)",
                kind: .budget,
                title: isExceeded ? "\(budget.name) budget exceeded" : "\(budget.name) is approaching its limit",
                explanation: isExceeded
                    ? "Spending has passed the \(money(MoneyFormat.decimal(from: budget.amount), currency: budget.currency)) limit."
                    : "\(money(max(remaining, .zero), currency: budget.currency)) remains in this budget period.",
                severity: isExceeded ? .high : .moderate,
                suggestedAction: "Review recent \(budget.category.map(categoryTitle) ?? "budgeted") spending and adjust the remaining plan.",
                supportingMetric: "\(decimalPercent(progress)) used"
            )
        }
        .sorted { severityRank($0.severity) > severityRank($1.severity) }
        .prefix(3)
        .map { $0 }
    }

    private static func scheduledMoneyFinding(
        summary: TransactionSummary,
        occurrences: [TransactionScheduleOccurrence],
        currentBalance: Decimal
    ) -> FinancialInsight? {
        let planned = occurrences.filter {
            $0.status.lowercased() == "planned"
                && $0.transactionID == nil
                && $0.scheduledFor.hasPrefix("\(summary.month)-")
        }
        guard !planned.isEmpty else { return nil }
        let income = planned.filter { $0.type == "income" }.reduce(Decimal.zero) {
            $0 + MoneyFormat.decimal(from: $1.amount)
        }
        let expenses = planned.filter { $0.type == "expense" }.reduce(Decimal.zero) {
            $0 + MoneyFormat.decimal(from: $1.amount)
        }
        let projected = currentBalance + income - expenses
        return FinancialInsight(
            id: "scheduled-money",
            kind: .scheduledMoney,
            title: projected >= .zero ? "Scheduled money stays covered" : "Scheduled money creates a shortfall",
            explanation: "Remaining scheduled income is \(money(income, currency: summary.currency)) and scheduled spending is \(money(expenses, currency: summary.currency)).",
            severity: projected >= .zero ? .informational : .high,
            suggestedAction: projected < .zero ? "Move or reduce a planned expense before it is due." : nil,
            supportingMetric: "Projected balance \(money(projected, currency: summary.currency))"
        )
    }

    private static func portfolioFindings(_ portfolio: InvestmentPortfolio) -> [FinancialInsight] {
        var findings: [FinancialInsight] = []
        let valuedPositions = portfolio.positions.compactMap { position -> (InvestmentPosition, Decimal)? in
            guard let raw = position.currentValue else { return nil }
            let value = MoneyFormat.decimal(from: raw)
            return value > .zero ? (position, value) : nil
        }
        let total = valuedPositions.reduce(Decimal.zero) { $0 + $1.1 }
        if total > .zero {
            let valuesBySymbol = Dictionary(grouping: valuedPositions, by: { $0.0.symbol }).mapValues { rows in
                rows.reduce(Decimal.zero) { $0 + $1.1 }
            }
            if let largest = valuesBySymbol.max(by: { $0.value < $1.value }) {
                let weight = largest.value / total
                if weight >= Decimal(string: "0.25")! {
                    findings.append(FinancialInsight(
                        id: "portfolio-concentration-\(largest.key)",
                        kind: .portfolio,
                        title: "Portfolio is concentrated in \(largest.key)",
                        explanation: "A single holding represents a substantial share of the valued portfolio.",
                        severity: weight >= Decimal(string: "0.50")! ? .high : .moderate,
                        suggestedAction: "Compare this exposure with your own position-size limit and time horizon.",
                        supportingMetric: "\(percentage(weight)) of portfolio value"
                    ))
                }
            }
        }
        if portfolio.missingPrices > 0 {
            findings.append(FinancialInsight(
                id: "portfolio-missing-prices",
                kind: .dataQuality,
                title: "Portfolio analysis is incomplete",
                explanation: "Some holdings do not have a current price, so allocation and performance totals may be understated.",
                severity: .moderate,
                suggestedAction: "Refresh prices before making allocation decisions.",
                supportingMetric: "\(portfolio.missingPrices) missing price\(portfolio.missingPrices == 1 ? "" : "s")"
            ))
        }
        return findings
    }

    private static func money(_ value: Decimal, currency: String) -> String {
        MoneyFormat.amount(value, currency: currency)
    }

    private static func percentage(_ ratio: Decimal) -> String {
        decimalPercent(ratio * 100)
    }

    private static func decimalPercent(_ value: Decimal) -> String {
        let number = NSDecimalNumber(decimal: value).doubleValue
        return String(format: "%.0f%%", number)
    }

    private static func severityRank(_ severity: FinancialInsightSeverity) -> Int {
        switch severity {
        case .informational: 0
        case .moderate: 1
        case .high: 2
        }
    }
}

enum TemplateFinancialReportProvider {
    static func report(from analytics: FinancialAnalytics) -> MonthlyFinancialReport {
        let positives = analytics.findings.filter { $0.severity == .informational }
        let spending = analytics.findings.filter {
            $0.severity != .informational && $0.kind != .portfolio && $0.kind != .dataQuality
        }
        let portfolio = analytics.findings.filter { $0.kind == .portfolio || $0.kind == .dataQuality }
        let priorities = analytics.findings
            .sorted { severityRank($0.severity) > severityRank($1.severity) }
            .compactMap(\.suggestedAction)
            .reduce(into: [String]()) { result, item in
                if !result.contains(item) { result.append(item) }
            }
            .prefix(3)
        let summary: String
        if let savingsRate = analytics.savingsRate {
            let rate = NSDecimalNumber(decimal: savingsRate * 100).doubleValue
            summary = analytics.monthlyBalance >= .zero
                ? String(format: "You kept %.0f%% of recorded income this month. The findings below are calculated from your transactions, budgets, scheduled money, and portfolio.", rate)
                : "Recorded spending is above income this month. Start with the highest-severity finding below."
        } else {
            summary = "There is not enough recorded income to calculate a savings rate. The remaining findings are still based on your current data."
        }
        return MonthlyFinancialReport(
            summary: summary,
            positiveChanges: positives,
            spendingRisks: spending,
            portfolioRisks: portfolio,
            nextMonthPriorities: Array(priorities),
            source: .deterministic
        )
    }

    private static func severityRank(_ severity: FinancialInsightSeverity) -> Int {
        switch severity {
        case .informational: 0
        case .moderate: 1
        case .high: 2
        }
    }
}

enum AppleFinancialModelStatus: Equatable {
    case available
    case requiresIOS26
    case deviceNotEligible
    case appleIntelligenceDisabled
    case modelPreparing

    var detail: String {
        switch self {
        case .available: "Apple Intelligence can refine the wording of calculated insights."
        case .requiresIOS26: "Calculated insights work now. Apple Intelligence explanations require iOS 26."
        case .deviceNotEligible: "This device uses calculated insights without a language model."
        case .appleIntelligenceDisabled: "Calculated insights work now. Enable Apple Intelligence to refine their wording."
        case .modelPreparing: "Calculated insights work now. Apple’s on-device model is still preparing."
        }
    }
}

@available(iOS 26.0, *)
@Generable(description: "A concise explanation of financial findings already calculated by the app")
private struct AppleFinancialNarrative {
    @Guide(description: "Two short sentences. Use only supplied metrics and do not introduce new numbers.")
    let summary: String
}

actor FinancialIntelligenceService {
    static let shared = FinancialIntelligenceService()

    nonisolated static var modelStatus: AppleFinancialModelStatus {
        guard #available(iOS 26.0, *) else { return .requiresIOS26 }
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(.deviceNotEligible):
            return .deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled):
            return .appleIntelligenceDisabled
        case .unavailable(.modelNotReady):
            return .modelPreparing
        case .unavailable:
            return .modelPreparing
        }
    }

    func generateReport(analytics: FinancialAnalytics) async -> MonthlyFinancialReport {
        let fallback = TemplateFinancialReportProvider.report(from: analytics)
        guard #available(iOS 26.0, *), Self.modelStatus == .available else { return fallback }
        do {
            let data = try JSONEncoder().encode(analytics)
            guard let json = String(data: data, encoding: .utf8) else { return fallback }
            let session = LanguageModelSession {
                """
                You explain personal-finance findings calculated and validated by the application.
                Never calculate new metrics, invent transactions, alter numbers, or recommend a specific security.
                Describe investments as risks and trade-offs, never guarantees. Be calm, direct, and practical.
                """
            }
            let response = try await session.respond(
                to: "Write a short monthly overview using only this validated analytics JSON: \(json)",
                generating: AppleFinancialNarrative.self
            )
            let summary = response.content.summary.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !summary.isEmpty else { return fallback }
            return MonthlyFinancialReport(
                summary: summary,
                positiveChanges: fallback.positiveChanges,
                spendingRisks: fallback.spendingRisks,
                portfolioRisks: fallback.portfolioRisks,
                nextMonthPriorities: fallback.nextMonthPriorities,
                source: .appleFoundationModel
            )
        } catch {
            return fallback
        }
    }

    func answerPortfolioQuestion(
        question: String,
        portfolio: InvestmentPortfolio
    ) async -> String {
        let facts = PortfolioAnalyticsEngine.answer(question: question, portfolio: portfolio)
        guard #available(iOS 26.0, *), Self.modelStatus == .available else { return facts }
        do {
            let session = LanguageModelSession {
                """
                Explain only the supplied validated portfolio facts. Do not recalculate them, add live prices,
                recommend buying or selling, or predict returns. Answer in at most 100 words.
                """
            }
            let response = try await session.respond(
                to: "Question: \(question)\nValidated answer: \(facts)"
            )
            let answer = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return answer.isEmpty ? facts : answer
        } catch {
            return facts
        }
    }
}

enum PortfolioAnalyticsEngine {
    static func answer(question: String, portfolio: InvestmentPortfolio) -> String {
        guard !portfolio.positions.isEmpty else { return "Record a holding before analysing your portfolio." }
        let currency = portfolio.currency
        let valued = portfolio.positions.compactMap { position -> (InvestmentPosition, Decimal)? in
            guard let raw = position.currentValue else { return nil }
            let value = MoneyFormat.decimal(from: raw)
            return value > .zero ? (position, value) : nil
        }
        let total = valued.reduce(Decimal.zero) { $0 + $1.1 }
        let lower = question.lowercased()

        if lower.contains("largest") || lower.contains("exposure") || lower.contains("concentrat") {
            let valuesBySymbol = Dictionary(grouping: valued, by: {
                $0.0.symbol.uppercased()
            }).mapValues { rows in
                (
                    name: rows.first?.0.assetName ?? rows.first?.0.symbol ?? "Holding",
                    value: rows.reduce(Decimal.zero) { $0 + $1.1 }
                )
            }
            guard total > .zero, let largest = valuesBySymbol.max(by: { $0.value.value < $1.value.value }) else {
                return "Current prices are missing, so the largest exposure cannot be calculated reliably."
            }
            let weight = NSDecimalNumber(decimal: largest.value.value / total * 100).doubleValue
            return String(
                format: "%@ (%@) is the largest exposure at %.0f%% of the portfolio, worth %@ across all accounts. An exposure above 25%% is flagged as a concentration heuristic, not a universal limit.",
                largest.value.name,
                largest.key,
                weight,
                MoneyFormat.amount(largest.value.value, currency: currency)
            )
        }

        if lower.contains("performance") || lower.contains("return") || lower.contains("profit") {
            guard let currentRaw = portfolio.currentValue,
                let profitRaw = portfolio.unrealizedProfit
            else {
                return "Performance cannot be calculated completely because one or more current prices are missing."
            }
            let current = MoneyFormat.decimal(from: currentRaw)
            let invested = MoneyFormat.decimal(from: portfolio.investedAmount)
            let unrealized = MoneyFormat.decimal(from: profitRaw)
            let percent = invested > .zero
                ? NSDecimalNumber(decimal: unrealized / invested * 100).doubleValue
                : 0
            return String(
                format: "Current value is %@ against %@ invested. Unrealised profit is %@ (%.1f%%), and realised profit is %@.",
                MoneyFormat.amount(current, currency: currency),
                MoneyFormat.amount(invested, currency: currency),
                MoneyFormat.amount(unrealized, currency: currency),
                percent,
                MoneyFormat.amount(MoneyFormat.decimal(from: portfolio.realizedProfit), currency: currency)
            )
        }

        let holdings = portfolio.positions.count
        let valueText = portfolio.currentValue.map {
            MoneyFormat.amount(MoneyFormat.decimal(from: $0), currency: currency)
        } ?? "incomplete because prices are missing"
        return "The portfolio has \(holdings) position\(holdings == 1 ? "" : "s") with a current value of \(valueText). \(portfolio.missingPrices) price\(portfolio.missingPrices == 1 ? " is" : "s are") missing. Ask about concentration, largest exposure, or performance for a calculated breakdown."
    }
}

struct TransactionCategoryAssessment: Equatable {
    let transactionID: Int
    let category: String?
    let confidence: Double
    let needsClarification: Bool
    let clarificationQuestion: String?
}

enum DeterministicTransactionClassifier {
    static let maxBatchSize = 24

    private static let expenseRules: [(aliases: [String], keywords: [String])] = [
        (["groceries", "grocery"], ["supermarket", "grocery", "lidl", "kaufland", "billa", "fantastico", "tesco"]),
        (["dining_out", "food", "restaurants"], ["restaurant", "cafe", "coffee", "foodpanda", "glovo", "uber eats", "lunch", "dinner"]),
        (["going_out", "entertainment"], ["cinema", "concert", "nightclub", "club", "shisha", "theatre"]),
        (["transport"], ["taxi", "uber", "metro", "rail", "parking", "fuel", "shell", "omv", "bus ticket"]),
        (["housing", "rent"], ["rent", "mortgage", "electricity", "water bill", "heating", "utility"]),
        (["subscriptions"], ["netflix", "spotify", "subscription", "adobe", "apple.com/bill", "google storage"]),
        (["health", "healthcare"], ["pharmacy", "doctor", "dental", "hospital", "clinic"]),
        (["shopping"], [
            "amazon", "ikea", "zara", "h&m", "clothing",
            "electronics", "computer", "computer parts", "laptop", "desktop",
            "ssd", "hard drive", "monitor", "keyboard", "graphics card", "gpu",
        ]),
    ]
    private static let incomeRules: [(aliases: [String], keywords: [String])] = [
        (["salary"], ["salary", "payroll", "wage"]),
        (["freelance", "business"], ["invoice", "freelance", "client payment"]),
        (["interest"], ["interest payment", "bank interest"]),
    ]

    static func classify(
        _ transactions: [Transaction],
        allowedCategoriesByType: [String: [String]]
    ) -> [TransactionCategoryAssessment] {
        transactions.map { transaction in
            let text = normalizedSearchText(transaction.description ?? "")
            let allowed = allowedCategoriesByType[transaction.type] ?? []
            let rules = transaction.type == TransactionType.income.rawValue ? incomeRules : expenseRules
            for rule in rules where searchTerms(for: rule).contains(where: {
                containsPhrase($0, in: text)
            }) {
                if let category = matchingCategory(aliases: rule.aliases, allowed: allowed) {
                    return TransactionCategoryAssessment(
                        transactionID: transaction.id,
                        category: category,
                        confidence: 0.93,
                        needsClarification: false,
                        clarificationQuestion: nil
                    )
                }
            }
            return TransactionCategoryAssessment(
                transactionID: transaction.id,
                category: nil,
                confidence: 0,
                needsClarification: true,
                clarificationQuestion: "What was this payment for?"
            )
        }
    }

    private static func matchingCategory(aliases: [String], allowed: [String]) -> String? {
        let normalizedAliases = Set(aliases.map(normalize))
        return allowed.first { normalizedAliases.contains(normalize($0)) }
    }

    private static func searchTerms(
        for rule: (aliases: [String], keywords: [String])
    ) -> [String] {
        rule.keywords + rule.aliases.map { $0.replacingOccurrences(of: "_", with: " ") }
    }

    private static func containsPhrase(_ phrase: String, in normalizedText: String) -> Bool {
        let normalizedPhrase = normalizedSearchText(phrase)
        guard !normalizedPhrase.isEmpty else { return false }
        return " \(normalizedText) ".contains(" \(normalizedPhrase) ")
    }

    private static func normalizedSearchText(_ value: String) -> String {
        value.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )
        .lowercased()
        .components(separatedBy: CharacterSet.alphanumerics.inverted)
        .filter { !$0.isEmpty }
        .joined(separator: " ")
    }

    private static func normalize(_ value: String) -> String {
        value.lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
    }
}

enum LegacyLocalModelCleanup {
    static func removeDownloadedModels(fileManager: FileManager = .default) {
        guard let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first,
            let applicationSupport = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first
        else { return }

        removeDownloadedModels(
            cachesDirectory: caches,
            applicationSupportDirectory: applicationSupport,
            fileManager: fileManager
        )
    }

    static func removeDownloadedModels(
        cachesDirectory caches: URL,
        applicationSupportDirectory applicationSupport: URL,
        fileManager: FileManager = .default
    ) {
        let exactDirectories = [
            caches
                .appendingPathComponent("huggingface", isDirectory: true)
                .appendingPathComponent("hub", isDirectory: true)
                .appendingPathComponent("models--mlx-community--Qwen3-1.7B-4bit", isDirectory: true),
            applicationSupport.appendingPathComponent("Gemma", isDirectory: true),
            caches.appendingPathComponent("Gemma", isDirectory: true),
        ]
        for directory in exactDirectories where fileManager.fileExists(atPath: directory.path) {
            try? fileManager.removeItem(at: directory)
        }
    }
}
