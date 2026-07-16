import CoreML
import Foundation
import NaturalLanguage

struct TransactionCategoryPrediction: Equatable {
    enum Source: String, Equatable {
        case correction
        case rule
        case model
        case gemma
    }

    let category: String
    let confidence: Double
    let source: Source
}

final class OnDeviceTransactionClassifier {
    static let shared = OnDeviceTransactionClassifier()

    private static let modelName = "TransactionCategoryClassifier"
    private static let correctionPreferenceKey = "classification.transactionCategoryCorrections"
    private static let minimumModelConfidence = 0.80
    private static let minimumModelMargin = 0.15

    private let model: NLModel?
    private let preferences: UserDefaults

    init(
        bundle: Bundle = .main,
        preferences: UserDefaults = .standard,
        loadBundledModel: Bool = true
    ) {
        self.preferences = preferences
        guard loadBundledModel,
            let url = bundle.url(forResource: Self.modelName, withExtension: "mlmodelc"),
            let coreMLModel = try? MLModel(contentsOf: url),
            let naturalLanguageModel = try? NLModel(mlModel: coreMLModel)
        else {
            model = nil
            return
        }
        model = naturalLanguageModel
    }

    var isModelAvailable: Bool { model != nil }

    func predict(description: String, transactionType: String) -> TransactionCategoryPrediction? {
        let type = transactionType.lowercased()
        let allowedCategories = Self.allowedCategories(for: type)
        guard !allowedCategories.isEmpty else { return nil }

        let merchantKey = Self.merchantKey(description)
        guard !merchantKey.isEmpty else { return nil }

        if let correctedCategory = corrections()[Self.correctionKey(type: type, merchantKey: merchantKey)],
            allowedCategories.contains(correctedCategory)
        {
            return TransactionCategoryPrediction(
                category: correctedCategory,
                confidence: 1,
                source: .correction
            )
        }

        if let ruleCategory = Self.ruleCategory(for: description, transactionType: type),
            allowedCategories.contains(ruleCategory)
        {
            return TransactionCategoryPrediction(category: ruleCategory, confidence: 0.99, source: .rule)
        }

        guard let model else { return nil }
        let input = "\(type) \(Self.normalized(description))"
        let hypotheses = model.predictedLabelHypotheses(for: input, maximumCount: 5)
            .filter { allowedCategories.contains($0.key) && $0.key != "other" }
            .sorted { $0.value > $1.value }
        guard let best = hypotheses.first else { return nil }
        let runnerUpConfidence = hypotheses.dropFirst().first?.value ?? 0
        guard best.value >= Self.minimumModelConfidence,
            best.value - runnerUpConfidence >= Self.minimumModelMargin
        else { return nil }
        return TransactionCategoryPrediction(category: best.key, confidence: best.value, source: .model)
    }

    func rememberCorrection(description: String, transactionType: String, category: String) {
        let type = transactionType.lowercased()
        let normalizedCategory = category.lowercased()
        guard Self.allowedCategories(for: type).contains(normalizedCategory) else { return }
        let merchantKey = Self.merchantKey(description)
        guard !merchantKey.isEmpty else { return }
        var stored = corrections()
        stored[Self.correctionKey(type: type, merchantKey: merchantKey)] = normalizedCategory
        guard let encoded = try? JSONEncoder().encode(stored) else { return }
        preferences.set(encoded, forKey: Self.correctionPreferenceKey)
    }

    private func corrections() -> [String: String] {
        guard let data = preferences.data(forKey: Self.correctionPreferenceKey),
            let stored = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return stored
    }

    private static func correctionKey(type: String, merchantKey: String) -> String {
        "\(type)|\(merchantKey)"
    }

    private static func allowedCategories(for type: String) -> Set<String> {
        switch type {
        case TransactionType.expense.rawValue:
            ["groceries", "dining_out", "going_out", "transport", "housing", "utilities", "health", "entertainment", "shopping", "travel", "education", "beauty", "other"]
        case TransactionType.income.rawValue:
            ["salary", "freelance", "gift", "investment", "refund", "other"]
        default:
            []
        }
    }

    private static func ruleCategory(for description: String, transactionType: String) -> String? {
        let text = normalized(description)
        let rules = transactionType == TransactionType.income.rawValue ? incomeRules : expenseRules
        return rules.first { rule in rule.keywords.contains { text.contains($0) } }?.category
    }

    private static func normalized(_ value: String) -> String {
        let folded = value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
        let characters = folded.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(String(scalar)) : " "
        }
        return String(characters)
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .joined(separator: " ")
    }

    private static func merchantKey(_ value: String) -> String {
        let ignored = Set([
            "card", "payment", "to", "from", "revolut", "transaction", "purchase", "transfer",
            "visa", "mastercard", "debit", "credit", "completed", "the", "at", "online"
        ])
        let tokens = normalized(value)
            .split(separator: " ")
            .map(String.init)
            .filter { token in
                !ignored.contains(token) && !token.allSatisfy { $0.isNumber }
            }
        return tokens.prefix(8).joined(separator: " ")
    }

    private struct Rule {
        let category: String
        let keywords: [String]
    }

    private static let expenseRules: [Rule] = [
        Rule(category: "going_out", keywords: [
            "shisha", "hookah", "nightclub", "night club", "cocktail", "lounge",
            "club entry", "club ticket"
        ]),
        Rule(category: "groceries", keywords: [
            "lidl", "kaufland", "billa", "fantastico", "t market", "supermarket", "grocery",
        ]),
        Rule(category: "dining_out", keywords: [
            "restaurant", "cafe", "coffee", "bakery", "glovo", "wolt", "mcdonald", "kfc",
            "happy bar"
        ]),
        Rule(category: "transport", keywords: [
            "uber", "bolt", "taxi", "metro", "bus ticket", "tram", "railway", "train ticket",
            "parking", "petrol", "gas station", "shell", "omv", "bdz"
        ]),
        Rule(category: "housing", keywords: ["rent payment", "monthly rent", "landlord", "mortgage"]),
        Rule(category: "utilities", keywords: [
            "electricity", "electric bill", "water bill", "heating", "utility", "internet bill",
            "broadband", "mobile bill", "phone bill", "telecom", "vivacom", "yettel",
            "a1 bulgaria", "toplofikacia", "electrohold"
        ]),
        Rule(category: "health", keywords: [
            "pharmacy", "apteka", "sopharmacy", "hospital", "clinic", "doctor", "dentist",
            "dental", "medical"
        ]),
        Rule(category: "entertainment", keywords: [
            "netflix", "spotify", "cinema", "movie theatre", "movie theater", "concert", "steam games",
            "playstation", "xbox", "youtube premium", "hbo max", "disney plus"
        ]),
        Rule(category: "travel", keywords: [
            "airbnb", "booking com", "hotel", "hostel", "airline", "flight", "ryanair", "wizz air", "easyjet"
        ]),
        Rule(category: "education", keywords: [
            "university", "school fee", "tuition", "online course", "udemy", "coursera", "textbook"
        ]),
        Rule(category: "beauty", keywords: [
            "barber", "barbershop", "hair salon", "hairdresser", "haircut", "beauty salon",
            "nail salon", "nails", "manicure", "pedicure", "cosmetics", "makeup", "skin care",
            "skincare", "eyebrow", "brow studio", "lash studio", "waxing", "sephora", "douglas parfumerie"
        ]),
        Rule(category: "shopping", keywords: [
            "amazon", "ebay", "etsy", "shopping mall", "retail", "clothing", "fashion", "zara", "ikea",
            "dm drogerie", "emag", "technopolis", "technomarket", "decathlon"
        ])
    ]

    private static let incomeRules: [Rule] = [
        Rule(category: "salary", keywords: ["salary", "payroll", "monthly wage", "wages"]),
        Rule(category: "freelance", keywords: ["freelance", "contractor payment", "client invoice", "consulting fee"]),
        Rule(category: "gift", keywords: ["gift"]),
        Rule(category: "investment", keywords: ["dividend", "interest payment", "investment return", "bond coupon"]),
        Rule(category: "refund", keywords: ["refund", "reversal", "cashback", "chargeback", "reimbursement"])
    ]
}

struct RevolutCSVAnnotation: Equatable {
    let data: Data
    let classified: Int
    let uncertain: Int
}

enum RevolutCSVCategoryAnnotator {
    static let categoryHeader = "Money Manager Category"

    static func annotate(
        _ data: Data,
        classifier: OnDeviceTransactionClassifier = .shared
    ) throws -> RevolutCSVAnnotation {
        guard var rows = parse(data), let header = rows.first, rows.count > 1 else {
            throw ValidationError("The selected file is not a valid CSV")
        }
        let normalizedHeaders = header.map(normalizeHeader)
        guard let descriptionIndex = normalizedHeaders.firstIndex(of: "description"),
            let amountIndex = normalizedHeaders.firstIndex(of: "amount")
        else {
            throw ValidationError("CSV is missing the Revolut description or amount column")
        }

        let categoryIndex: Int
        if let existingIndex = normalizedHeaders.firstIndex(of: normalizeHeader(categoryHeader)) {
            categoryIndex = existingIndex
        } else {
            rows[0].append(categoryHeader)
            categoryIndex = rows[0].count - 1
        }

        var classified = 0
        var uncertain = 0
        for index in rows.indices.dropFirst() {
            while rows[index].count <= categoryIndex { rows[index].append("") }
            guard descriptionIndex < rows[index].count, amountIndex < rows[index].count else { continue }
            let description = rows[index][descriptionIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let amount = rows[index][amountIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !description.isEmpty, !amount.isEmpty else { continue }
            let transactionType = amount.hasPrefix("-")
                ? TransactionType.expense.rawValue
                : TransactionType.income.rawValue
            if let prediction = classifier.predict(description: description, transactionType: transactionType) {
                rows[index][categoryIndex] = prediction.category
                classified += 1
            } else {
                rows[index][categoryIndex] = ""
                uncertain += 1
            }
        }

        return RevolutCSVAnnotation(data: serialize(rows), classified: classified, uncertain: uncertain)
    }

    private static func normalizeHeader(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(whereSeparator: \Character.isWhitespace)
            .joined(separator: " ")
    }

    private static func parse(_ data: Data) -> [[String]]? {
        guard var text = String(data: data, encoding: .utf8) else { return nil }
        if text.hasPrefix("\u{feff}") { text.removeFirst() }

        let scalars = Array(text.unicodeScalars)
        let quote = UnicodeScalar(34)!
        let comma = UnicodeScalar(44)!
        let carriageReturn = UnicodeScalar(13)!
        let lineFeed = UnicodeScalar(10)!
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var index = 0

        while index < scalars.count {
            let scalar = scalars[index]
            if scalar == quote {
                if inQuotes, index + 1 < scalars.count, scalars[index + 1] == quote {
                    field.unicodeScalars.append(quote)
                    index += 1
                } else {
                    inQuotes.toggle()
                }
            } else if !inQuotes, scalar == comma {
                row.append(field)
                field = ""
            } else if !inQuotes, scalar == carriageReturn || scalar == lineFeed {
                row.append(field)
                if row.contains(where: { !$0.isEmpty }) { rows.append(row) }
                row = []
                field = ""
                if scalar == carriageReturn, index + 1 < scalars.count, scalars[index + 1] == lineFeed {
                    index += 1
                }
            } else {
                field.unicodeScalars.append(scalar)
            }
            index += 1
        }
        guard !inQuotes else { return nil }
        row.append(field)
        if row.contains(where: { !$0.isEmpty }) { rows.append(row) }
        return rows
    }

    private static func serialize(_ rows: [[String]]) -> Data {
        let csv = rows.map { row in
            row.map(escape).joined(separator: ",")
        }.joined(separator: "\r\n") + "\r\n"
        return Data(csv.utf8)
    }

    private static func escape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\r") || value.contains("\n") else {
            return value
        }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
