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
    let status: String?
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
        status: String? = nil,
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
        self.status = status
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
        case status
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

enum OpenBankingLoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
}

enum OpenBankingCallbackState: Equatable {
    case idle
    case connected(connectionID: Int?)
    case cancelled
    case failed(String)
}

struct OpenBankingRegion: Identifiable, Hashable {
    let code: String

    var id: String { code }

    var name: String {
        Locale.current.localizedString(forRegionCode: code) ?? code
    }

    static let supported: [OpenBankingRegion] = [
        "AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR",
        "DE", "GR", "HU", "IS", "IE", "IT", "LV", "LI", "LT", "LU",
        "MT", "NL", "NO", "PL", "PT", "RO", "SK", "SI", "ES", "SE", "GB"
    ]
    .map(OpenBankingRegion.init(code:))
    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

    static var defaultCode: String {
        guard let region = Locale.current.region?.identifier.uppercased(),
              supported.contains(where: { $0.code == region })
        else { return "BG" }
        return region
    }
}

struct OpenBankingAuthMethod: Codable, Equatable, Hashable {
    let name: String
    let title: String?
    let psuType: String
    let approach: String
    let hiddenMethod: Bool

    enum CodingKeys: String, CodingKey {
        case name
        case title
        case psuType = "psu_type"
        case approach
        case hiddenMethod = "hidden_method"
    }
}

struct OpenBankingInstitution: Codable, Identifiable, Equatable, Hashable {
    let name: String
    let country: String
    let logo: String
    let psuTypes: [String]
    let authMethods: [OpenBankingAuthMethod]
    let maximumConsentValidity: Int
    let beta: Bool
    let bic: String?
    let requiredPSUHeaders: [String]?

    var id: String { "\(country):\(name)" }

    enum CodingKeys: String, CodingKey {
        case name
        case country
        case logo
        case psuTypes = "psu_types"
        case authMethods = "auth_methods"
        case maximumConsentValidity = "maximum_consent_validity"
        case beta
        case bic
        case requiredPSUHeaders = "required_psu_headers"
    }
}

struct OpenBankingAuthorizationRequest: Codable, Equatable {
    let institutionName: String
    let country: String
    let psuType: String
    let consentDays: Int
    let language: String

    enum CodingKeys: String, CodingKey {
        case institutionName = "institution_name"
        case country
        case psuType = "psu_type"
        case consentDays = "consent_days"
        case language
    }
}

struct OpenBankingAuthorization: Codable, Equatable {
    let authorizationURL: String
    let authorizationID: String
    let validUntil: String
    let expiresAt: String

    enum CodingKeys: String, CodingKey {
        case authorizationURL = "authorization_url"
        case authorizationID = "authorization_id"
        case validUntil = "valid_until"
        case expiresAt = "expires_at"
    }
}

struct OpenBankingConnection: Codable, Identifiable, Equatable {
    let id: Int
    let institutionName: String
    let country: String
    let psuType: String
    let status: String
    let validUntil: String
    let accountCount: Int
    let createdAt: String
    let updatedAt: String

    var needsAttention: Bool {
        let normalized = status.uppercased()
        return !["AUTHORIZED", "VALID", "READY"].contains(normalized)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case institutionName = "institution_name"
        case country
        case psuType = "psu_type"
        case status
        case validUntil = "valid_until"
        case accountCount = "account_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct OpenBankingAccount: Codable, Identifiable, Equatable {
    let id: Int
    let connectionID: Int
    let institutionName: String
    let country: String
    let name: String?
    let details: String?
    let cashAccountType: String
    let product: String?
    let currency: String
    let displayIdentifier: String?
    let identificationHash: String
    let canFetchData: Bool

    var displayName: String {
        let candidates = [details, product, name]
        return candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? "Bank account"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case connectionID = "connection_id"
        case institutionName = "institution_name"
        case country
        case name
        case details
        case cashAccountType = "cash_account_type"
        case product
        case currency
        case displayIdentifier = "display_identifier"
        case identificationHash = "identification_hash"
        case canFetchData = "can_fetch_data"
    }
}

struct OpenBankingMoneyAmount: Codable, Equatable {
    let currency: String
    let amount: String

    var decimal: Decimal { MoneyFormat.decimal(from: amount) }
}

struct OpenBankingBalance: Codable, Equatable {
    let name: String?
    let balanceAmount: OpenBankingMoneyAmount
    let balanceType: String?
    let lastChangeDateTime: String?
    let referenceDate: String?

    enum CodingKeys: String, CodingKey {
        case name
        case balanceAmount = "balance_amount"
        case balanceType = "balance_type"
        case lastChangeDateTime = "last_change_date_time"
        case referenceDate = "reference_date"
    }
}

struct OpenBankingBalanceResponse: Codable, Equatable {
    let balances: [OpenBankingBalance]

    var preferredBalance: OpenBankingBalance? {
        let preferredTypes = ["CLBD", "ITBD", "CLAV", "ITAV", "OPBD", "PRCD"]
        for type in preferredTypes {
            if let match = balances.first(where: { $0.balanceType?.uppercased() == type }) {
                return match
            }
        }
        return balances.first
    }
}

struct OpenBankingParty: Codable, Equatable {
    let name: String?
}

struct OpenBankingTransactionCode: Codable, Equatable {
    let code: String?
    let description: String?
    let subCode: String?

    enum CodingKeys: String, CodingKey {
        case code
        case description
        case subCode = "sub_code"
    }
}

struct OpenBankingTransaction: Codable, Identifiable, Equatable {
    let transactionID: String?
    let entryReference: String?
    let status: String?
    let bookingDate: String?
    let valueDate: String?
    let transactionDate: String?
    let creditDebitIndicator: String?
    let transactionAmount: OpenBankingMoneyAmount?
    let remittanceInformation: [String]?
    let creditor: OpenBankingParty?
    let debtor: OpenBankingParty?
    let bankTransactionCode: OpenBankingTransactionCode?
    let note: String?

    var id: String {
        transactionID ?? entryReference ?? "\(effectiveDate)|\(transactionAmount?.amount ?? "0")|\(title)"
    }

    var effectiveDate: String {
        bookingDate ?? transactionDate ?? valueDate ?? ""
    }

    var title: String {
        let isCredit = creditDebitIndicator?.uppercased() == "CRDT"
        let candidates = isCredit
            ? [debtor?.name, creditor?.name]
            : [creditor?.name, debtor?.name]
        if let party = candidates.compactMap({ $0?.trimmingCharacters(in: .whitespacesAndNewlines) }).first(where: { !$0.isEmpty }) {
            return party
        }
        if let remittance = remittanceInformation?.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            return remittance
        }
        if let description = bankTransactionCode?.description, !description.isEmpty {
            return description
        }
        if let note, !note.isEmpty { return note }
        return "Bank transaction"
    }

    var detail: String {
        remittanceInformation?.first(where: { $0 != title && !$0.isEmpty })
            ?? bankTransactionCode?.description
            ?? status
            ?? "Transaction"
    }

    var signedAmount: Decimal {
        let amount = transactionAmount?.decimal ?? .zero
        if amount < .zero { return amount }
        return creditDebitIndicator?.uppercased() == "DBIT" ? -amount : amount
    }

    enum CodingKeys: String, CodingKey {
        case transactionID = "transaction_id"
        case entryReference = "entry_reference"
        case status
        case bookingDate = "booking_date"
        case valueDate = "value_date"
        case transactionDate = "transaction_date"
        case creditDebitIndicator = "credit_debit_indicator"
        case transactionAmount = "transaction_amount"
        case remittanceInformation = "remittance_information"
        case creditor
        case debtor
        case bankTransactionCode = "bank_transaction_code"
        case note
    }
}

struct OpenBankingTransactionResponse: Codable, Equatable {
    let continuationKey: String?
    let transactions: [OpenBankingTransaction]

    enum CodingKeys: String, CodingKey {
        case continuationKey = "continuation_key"
        case transactions
    }
}

struct OpenBankingSyncResult: Codable, Equatable {
    let fetched: Int
    let imported: Int
    let updated: Int
    let unchanged: Int
    let ignored: Int
    let notifications: Int
}

struct OpenBankingAccountSnapshot: Equatable {
    let balances: OpenBankingBalanceResponse
    let transactions: OpenBankingTransactionResponse
    let loadedAt: Date
}
