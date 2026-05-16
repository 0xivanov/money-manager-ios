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
    let amount: String
    let currency: String
    let occurredAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case category
        case amount
        case currency
        case occurredAt = "occurred_at"
    }
}

struct TransactionRequest: Codable, Equatable {
    let type: String
    let category: String
    let amount: String
    let currency: String
    let occurredAt: String

    init(type: String, category: String, amount: String, currency: String = "EUR", occurredAt: String) {
        self.type = type
        self.category = category
        self.amount = amount
        self.currency = currency
        self.occurredAt = occurredAt
    }

    enum CodingKeys: String, CodingKey {
        case type
        case category
        case amount
        case currency
        case occurredAt = "occurred_at"
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
    let balance: String
    let currency: String
    let transactionCount: Int

    enum CodingKeys: String, CodingKey {
        case month
        case income
        case expense
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
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .transactions: "Transactions"
        case .profile: "Profile"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: "house.fill"
        case .transactions: "receipt.fill"
        case .profile: "person.crop.circle.fill"
        }
    }
}

enum AppSheet: Identifiable, Equatable {
    case transactionEditor
    case categoryPicker
    case exportTransactions

    var id: String {
        switch self {
        case .transactionEditor: "transactionEditor"
        case .categoryPicker: "categoryPicker"
        case .exportTransactions: "exportTransactions"
        }
    }
}
