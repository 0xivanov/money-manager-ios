import Foundation

enum TransactionType: String, Codable, CaseIterable, Identifiable {
    case expense
    case income

    var id: String { rawValue }
}

struct User: Codable, Equatable {
    let id: Int
    let email: String
}

struct AuthResult: Codable, Equatable {
    let token: String
    let user: User
}

struct Transaction: Codable, Identifiable, Equatable {
    let id: Int
    let type: String
    let category: String
    let description: String?
    let amount: String
    let currency: String
    let occurredAt: String
    let source: String?
    let excludedFromBudget: Bool?
    let scheduleOccurrenceID: Int?

    init(
        id: Int,
        type: String,
        category: String,
        description: String? = nil,
        amount: String,
        currency: String,
        occurredAt: String,
        source: String? = nil,
        excludedFromBudget: Bool? = nil,
        scheduleOccurrenceID: Int? = nil
    ) {
        self.id = id
        self.type = type
        self.category = category
        self.description = description
        self.amount = amount
        self.currency = currency
        self.occurredAt = occurredAt
        self.source = source
        self.excludedFromBudget = excludedFromBudget
        self.scheduleOccurrenceID = scheduleOccurrenceID
    }

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case category
        case description
        case amount
        case currency
        case occurredAt = "occurred_at"
        case source
        case excludedFromBudget = "excluded_from_budget"
        case scheduleOccurrenceID = "schedule_occurrence_id"
    }
}

struct TransactionRequest: Codable, Equatable {
    let type: String
    let category: String
    let description: String?
    let amount: String
    let currency: String
    let occurredAt: String
    let excludedFromBudget: Bool

    init(
        type: String,
        category: String,
        description: String? = nil,
        amount: String,
        currency: String = "EUR",
        occurredAt: String,
        excludedFromBudget: Bool = false
    ) {
        self.type = type
        self.category = category
        self.description = description
        self.amount = amount
        self.currency = currency
        self.occurredAt = occurredAt
        self.excludedFromBudget = excludedFromBudget
    }

    enum CodingKeys: String, CodingKey {
        case type
        case category
        case description
        case amount
        case currency
        case occurredAt = "occurred_at"
        case excludedFromBudget = "excluded_from_budget"
    }
}

struct Category: Codable, Identifiable, Equatable {
    let id: Int
    let type: String
    let name: String
    let isDefault: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case name
        case isDefault = "is_default"
    }
}

struct CategoryRequest: Codable, Equatable {
    let type: String
    let name: String
}

struct TransactionSummary: Codable, Equatable {
    let month: String
    let income: String
    let expense: String
    let cashOutflow: String?
    let balance: String
    let currency: String
    let transactionCount: Int

    init(
        month: String,
        income: String,
        expense: String,
        cashOutflow: String? = nil,
        balance: String,
        currency: String,
        transactionCount: Int
    ) {
        self.month = month
        self.income = income
        self.expense = expense
        self.cashOutflow = cashOutflow
        self.balance = balance
        self.currency = currency
        self.transactionCount = transactionCount
    }

    enum CodingKeys: String, CodingKey {
        case month
        case income
        case expense
        case cashOutflow = "cash_outflow"
        case balance
        case currency
        case transactionCount = "transaction_count"
    }
}

struct CategoryTotal: Identifiable, Equatable {
    let category: String
    let amount: Decimal

    var id: String { category }
}

struct DayBucket: Identifiable, Equatable {
    let date: Date
    let balanceChange: Decimal
    let transactions: [Transaction]

    var id: Date { date }
}

enum AppTab: String, CaseIterable, Identifiable {
    case dashboard
    case transactions
    case investments
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Home"
        case .transactions: "Activity"
        case .investments: "Invest"
        case .profile: "Profile"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: "house.fill"
        case .transactions: "receipt.fill"
        case .investments: "chart.line.uptrend.xyaxis"
        case .profile: "person.crop.circle.fill"
        }
    }
}

enum AppSheet: Identifiable, Equatable {
    case transactionEditor
    case exportTransactions

    var id: String {
        switch self {
        case .transactionEditor: "transactionEditor"
        case .exportTransactions: "exportTransactions"
        }
    }
}

enum DashboardLoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
}

struct ImportResult: Codable, Equatable {
    let imported: Int
    let skipped: Int
    let ignored: Int
}

enum ConnectionStatus: Equatable {
    case unknown
    case checking
    case connected
    case offline(String)
}
