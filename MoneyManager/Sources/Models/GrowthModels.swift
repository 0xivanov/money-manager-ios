import Foundation

struct TransactionSchedule: Codable, Identifiable, Equatable {
    let id: Int
    let type: String
    let name: String
    let category: String
    let description: String
    let amount: String
    let currency: String
    let frequency: String
    let frequencyInterval: Int
    let startDate: String
    let endDate: String?
    let dayOfWeek: Int?
    let dayOfMonth: Int?
    let timezone: String
    let autoPost: Bool
    let status: String
    let nextOccurrenceDate: String?

    enum CodingKeys: String, CodingKey {
        case id, type, name, category, description, amount, currency, frequency, timezone, status
        case frequencyInterval = "frequency_interval"
        case startDate = "start_date"
        case endDate = "end_date"
        case dayOfWeek = "day_of_week"
        case dayOfMonth = "day_of_month"
        case autoPost = "auto_post"
        case nextOccurrenceDate = "next_occurrence_date"
    }
}

struct TransactionScheduleRequest: Codable, Equatable {
    let type: String
    let name: String
    let category: String
    let description: String
    let amount: String
    let currency: String
    let frequency: String
    let frequencyInterval: Int
    let startDate: String
    let endDate: String?
    let dayOfWeek: Int?
    let dayOfMonth: Int?
    let timezone: String
    let autoPost: Bool

    enum CodingKeys: String, CodingKey {
        case type, name, category, description, amount, currency, frequency, timezone
        case frequencyInterval = "frequency_interval"
        case startDate = "start_date"
        case endDate = "end_date"
        case dayOfWeek = "day_of_week"
        case dayOfMonth = "day_of_month"
        case autoPost = "auto_post"
    }
}

struct TransactionScheduleOccurrence: Codable, Identifiable, Equatable {
    let id: Int
    let scheduleID: Int
    let scheduledFor: String
    let status: String
    let type: String
    let name: String
    let category: String
    let description: String
    let amount: String
    let currency: String
    let autoPost: Bool
    let transactionID: Int?

    enum CodingKeys: String, CodingKey {
        case id, status, type, name, category, description, amount, currency
        case scheduleID = "schedule_id"
        case scheduledFor = "scheduled_for"
        case autoPost = "auto_post"
        case transactionID = "transaction_id"
    }
}

struct Budget: Codable, Identifiable, Equatable {
    let id: Int
    let name: String
    let category: String?
    let amount: String
    let currency: String
    let period: String
    let warningThreshold: Int
    let status: String
    let periodStart: String
    let periodEnd: String
    let spentAmount: String
    let remainingAmount: String
    let progressPercent: String
    let alertLevel: String

    enum CodingKeys: String, CodingKey {
        case id, name, category, amount, currency, period, status
        case warningThreshold = "warning_threshold"
        case periodStart = "period_start"
        case periodEnd = "period_end"
        case spentAmount = "spent_amount"
        case remainingAmount = "remaining_amount"
        case progressPercent = "progress_percent"
        case alertLevel = "alert_level"
    }
}

struct BudgetRequest: Codable, Equatable {
    let name: String
    let category: String?
    let amount: String
    let currency: String
    let period: String
    let warningThreshold: Int

    enum CodingKeys: String, CodingKey {
        case name, category, amount, currency, period
        case warningThreshold = "warning_threshold"
    }
}

struct NotificationPreferences: Codable, Equatable {
    var bankSpending: Bool
    var budgetAlerts: Bool
    var scheduledMoney: Bool
    var investmentReminders: Bool
    var quietHoursStart: String?
    var quietHoursEnd: String?
    var timezone: String

    enum CodingKeys: String, CodingKey {
        case bankSpending = "bank_spending"
        case budgetAlerts = "budget_alerts"
        case scheduledMoney = "scheduled_money"
        case investmentReminders = "investment_reminders"
        case quietHoursStart = "quiet_hours_start"
        case quietHoursEnd = "quiet_hours_end"
        case timezone
    }

    static let defaults = NotificationPreferences(
        bankSpending: true,
        budgetAlerts: true,
        scheduledMoney: true,
        investmentReminders: true,
        quietHoursStart: nil,
        quietHoursEnd: nil,
        timezone: TimeZone.current.identifier
    )
}

struct PushDevice: Codable, Identifiable, Equatable {
    let id: Int
    let platform: String
    let appID: String
    let environment: String
    let lastSeenAt: String

    enum CodingKeys: String, CodingKey {
        case id, platform, environment
        case appID = "app_id"
        case lastSeenAt = "last_seen_at"
    }
}

struct PushDeviceRequest: Codable, Equatable {
    let platform: String
    let deviceToken: String
    let appID: String
    let environment: String

    enum CodingKeys: String, CodingKey {
        case platform, environment
        case deviceToken = "device_token"
        case appID = "app_id"
    }
}

struct InvestmentTrade: Codable, Identifiable, Equatable {
    let id: Int
    let assetType: String
    let symbol: String
    let assetName: String
    let broker: String
    let side: String
    let amount: String
    let quantity: String
    let pricePerUnit: String
    let fees: String
    let currency: String
    let occurredAt: String
    let notes: String
    let priceProvider: String?
    let priceAsOf: String?

    enum CodingKeys: String, CodingKey {
        case id, symbol, broker, side, amount, quantity, fees, currency, notes
        case assetType = "asset_type"
        case assetName = "asset_name"
        case pricePerUnit = "price_per_unit"
        case occurredAt = "occurred_at"
        case priceProvider = "price_provider"
        case priceAsOf = "price_as_of"
    }
}

struct InvestmentTradeRequest: Codable, Equatable {
    let assetType: String
    let symbol: String
    let assetName: String
    let broker: String
    let side: String
    let amount: String
    let fees: String
    let currency: String
    let occurredAt: String
    let notes: String

    enum CodingKeys: String, CodingKey {
        case symbol, broker, side, amount, fees, currency, notes
        case assetType = "asset_type"
        case assetName = "asset_name"
        case occurredAt = "occurred_at"
    }
}

enum InvestmentAssetType: String, Codable, Hashable {
    case crypto
    case stock
}

struct InvestmentAssetDefinition: Identifiable, Equatable, Hashable {
    let type: InvestmentAssetType
    let symbol: String
    let name: String
    let isTradeEnabled: Bool

    var id: String { "\(type.rawValue):\(symbol)" }
}

enum InvestmentAssetCatalog {
    static let bitcoin = InvestmentAssetDefinition(
        type: .crypto,
        symbol: "BTC",
        name: "Bitcoin",
        isTradeEnabled: true
    )
    static let ethereum = InvestmentAssetDefinition(
        type: .crypto,
        symbol: "ETH",
        name: "Ethereum",
        isTradeEnabled: true
    )

    // Stock definitions stay in the catalog so adding a market-data provider
    // later does not require another editor or portfolio-model redesign.
    static let apple = InvestmentAssetDefinition(
        type: .stock,
        symbol: "AAPL",
        name: "Apple",
        isTradeEnabled: false
    )
    static let microsoft = InvestmentAssetDefinition(
        type: .stock,
        symbol: "MSFT",
        name: "Microsoft",
        isTradeEnabled: false
    )

    static let all = [bitcoin, ethereum, apple, microsoft]
    static let tradeEnabled = all.filter(\.isTradeEnabled)

    static func hasAutomaticPricing(assetType: String, symbol: String) -> Bool {
        tradeEnabled.contains {
            $0.type.rawValue == assetType && $0.symbol.caseInsensitiveCompare(symbol) == .orderedSame
        }
    }
}

struct InvestmentPosition: Codable, Identifiable, Equatable {
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
    let currency: String
    let priceAsOf: String?
    let priceStatus: String

    var id: String { "\(assetType):\(symbol):\(broker)" }

    enum CodingKeys: String, CodingKey {
        case symbol, broker, quantity, currency
        case assetType = "asset_type"
        case assetName = "asset_name"
        case averageCost = "average_cost"
        case investedAmount = "invested_amount"
        case currentPrice = "current_price"
        case currentValue = "current_value"
        case unrealizedProfit = "unrealized_profit"
        case unrealizedPercent = "unrealized_percent"
        case realizedProfit = "realized_profit"
        case priceAsOf = "price_as_of"
        case priceStatus = "price_status"
    }
}

struct InvestmentPortfolio: Codable, Equatable {
    let positions: [InvestmentPosition]
    let investedAmount: String
    let currentValue: String?
    let unrealizedProfit: String?
    let realizedProfit: String
    let currency: String
    let missingPrices: Int

    enum CodingKeys: String, CodingKey {
        case positions, currency
        case investedAmount = "invested_amount"
        case currentValue = "current_value"
        case unrealizedProfit = "unrealized_profit"
        case realizedProfit = "realized_profit"
        case missingPrices = "missing_prices"
    }

    static let empty = InvestmentPortfolio(
        positions: [], investedAmount: "0.00", currentValue: "0.00",
        unrealizedProfit: "0.00", realizedProfit: "0.00", currency: "EUR", missingPrices: 0
    )
}

struct InvestmentPortfolioHistoryPoint: Codable, Identifiable, Equatable {
    let asOf: String
    let value: String
    let investedAmount: String

    var id: String { asOf }
    var date: Date? { DateFormat.apiDateTime(asOf) }

    enum CodingKeys: String, CodingKey {
        case value
        case asOf = "as_of"
        case investedAmount = "invested_amount"
    }
}

struct InvestmentPortfolioChartPoint: Identifiable, Equatable {
    let date: Date
    let value: Double
    let investedAmount: Double

    var id: Date { date }
}

func investmentPortfolioChartPoints(
    _ points: [InvestmentPortfolioHistoryPoint]
) -> [InvestmentPortfolioChartPoint] {
    points.compactMap { point in
        guard let date = point.date else { return nil }
        return InvestmentPortfolioChartPoint(
            date: date,
            value: Double(truncating: MoneyFormat.decimal(from: point.value) as NSDecimalNumber),
            investedAmount: Double(truncating: MoneyFormat.decimal(from: point.investedAmount) as NSDecimalNumber)
        )
    }
    .sorted { $0.date < $1.date }
}

func sampledInvestmentChartPoints(
    _ points: [InvestmentPortfolioChartPoint],
    limit: Int
) -> [InvestmentPortfolioChartPoint] {
    guard limit >= 2, points.count > limit else { return points }

    let lastIndex = points.count - 1
    let step = Double(lastIndex) / Double(limit - 1)
    var result: [InvestmentPortfolioChartPoint] = []
    result.reserveCapacity(limit)
    var previousIndex = -1

    for sampleIndex in 0..<limit {
        let index = sampleIndex == limit - 1
            ? lastIndex
            : Int((Double(sampleIndex) * step).rounded())
        guard index != previousIndex else { continue }
        result.append(points[index])
        previousIndex = index
    }
    return result
}

func investmentHistoryAxisDates(
    _ points: [InvestmentPortfolioChartPoint],
    maximumCount: Int
) -> [Date] {
    guard maximumCount > 1, !points.isEmpty else { return points.first.map { [$0.date] } ?? [] }
    if points.count <= maximumCount { return points.map(\.date) }

    let lastIndex = points.count - 1
    let step = Double(lastIndex) / Double(maximumCount - 1)
    return (0..<maximumCount).map { tick in
        let index = tick == maximumCount - 1
            ? lastIndex
            : Int((Double(tick) * step).rounded())
        return points[index].date
    }
}

func investmentHistoryAxisLabel(_ date: Date, range: String) -> String {
    switch range.lowercased() {
    case "1m":
        date.formatted(.dateTime.day().month(.abbreviated))
    case "5y", "max":
        date.formatted(.dateTime.year())
    default:
        date.formatted(.dateTime.month(.abbreviated).year(.twoDigits))
    }
}

struct InvestmentPortfolioHistory: Codable, Equatable {
    let points: [InvestmentPortfolioHistoryPoint]
    let currency: String
    let range: String
    let unsupportedPositions: Int

    enum CodingKeys: String, CodingKey {
        case points, currency, range
        case unsupportedPositions = "unsupported_positions"
    }

    static let empty = InvestmentPortfolioHistory(
        points: [],
        currency: "EUR",
        range: "1y",
        unsupportedPositions: 0
    )
}

struct InvestmentPriceRequest: Codable, Equatable {
    let assetType: String
    let symbol: String
    let currency: String
    let price: String

    enum CodingKeys: String, CodingKey {
        case symbol, currency, price
        case assetType = "asset_type"
    }
}

struct InvestmentPrice: Codable, Equatable {
    let assetType: String
    let symbol: String
    let currency: String
    let price: String
    let provider: String
    let asOf: String

    enum CodingKeys: String, CodingKey {
        case symbol, currency, price, provider
        case assetType = "asset_type"
        case asOf = "as_of"
    }
}

struct InvestmentSchedule: Codable, Identifiable, Equatable {
    let id: Int
    let assetType: String
    let symbol: String
    let assetName: String
    let broker: String
    let amount: String
    let currency: String
    let frequency: String
    let frequencyInterval: Int
    let startDate: String
    let endDate: String?
    let dayOfWeek: Int?
    let dayOfMonth: Int?
    let timezone: String
    let status: String
    let nextOccurrence: String?

    enum CodingKeys: String, CodingKey {
        case id, symbol, broker, amount, currency, frequency, timezone, status
        case assetType = "asset_type"
        case assetName = "asset_name"
        case frequencyInterval = "frequency_interval"
        case startDate = "start_date"
        case endDate = "end_date"
        case dayOfWeek = "day_of_week"
        case dayOfMonth = "day_of_month"
        case nextOccurrence = "next_occurrence"
    }
}

struct InvestmentScheduleRequest: Codable, Equatable {
    let assetType: String
    let symbol: String
    let assetName: String
    let broker: String
    let amount: String
    let currency: String
    let frequency: String
    let frequencyInterval: Int
    let startDate: String
    let endDate: String?
    let dayOfWeek: Int?
    let dayOfMonth: Int?
    let timezone: String

    enum CodingKeys: String, CodingKey {
        case symbol, broker, amount, currency, frequency, timezone
        case assetType = "asset_type"
        case assetName = "asset_name"
        case frequencyInterval = "frequency_interval"
        case startDate = "start_date"
        case endDate = "end_date"
        case dayOfWeek = "day_of_week"
        case dayOfMonth = "day_of_month"
    }
}
