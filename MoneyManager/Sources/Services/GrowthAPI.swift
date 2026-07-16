import Foundation

extension MoneyManagerAPI {
    func getTransactionSchedules(token: String) async throws -> [TransactionSchedule] {
        try await request(path: "/schedules", token: token)
    }

    func createTransactionSchedule(token: String, request body: TransactionScheduleRequest) async throws -> TransactionSchedule {
        try await request(path: "/schedules", method: "POST", token: token, body: body)
    }

    func pauseTransactionSchedule(token: String, id: Int) async throws -> TransactionSchedule {
        try await request(path: "/schedules/\(id)/pause", method: "POST", token: token, body: Optional<String>.none)
    }

    func resumeTransactionSchedule(token: String, id: Int) async throws -> TransactionSchedule {
        try await request(path: "/schedules/\(id)/resume", method: "POST", token: token, body: Optional<String>.none)
    }

    func deleteTransactionSchedule(token: String, id: Int) async throws {
        let _: EmptyResponse = try await request(path: "/schedules/\(id)", method: "DELETE", token: token)
    }

    func getTransactionScheduleOccurrences(
        token: String,
        from: String,
        through: String,
        status: String = "planned"
    ) async throws -> [TransactionScheduleOccurrence] {
        try await request(path: "/schedule-occurrences", token: token, queryItems: [
            URLQueryItem(name: "from", value: from),
            URLQueryItem(name: "through", value: through),
            URLQueryItem(name: "status", value: status),
        ])
    }

    func getBudgets(token: String) async throws -> [Budget] {
        try await request(path: "/budgets", token: token)
    }

    func createBudget(token: String, request body: BudgetRequest) async throws -> Budget {
        try await request(path: "/budgets", method: "POST", token: token, body: body)
    }

    func deleteBudget(token: String, id: Int) async throws {
        let _: EmptyResponse = try await request(path: "/budgets/\(id)", method: "DELETE", token: token)
    }

    func getNotificationPreferences(token: String) async throws -> NotificationPreferences {
        try await request(path: "/notification-preferences", token: token)
    }

    func updateNotificationPreferences(token: String, preferences: NotificationPreferences) async throws -> NotificationPreferences {
        try await request(path: "/notification-preferences", method: "PUT", token: token, body: preferences)
    }

    func registerPushDevice(token: String, request body: PushDeviceRequest) async throws -> PushDevice {
        try await request(path: "/push-devices", method: "POST", token: token, body: body)
    }

    func deletePushDevice(token: String, id: Int) async throws {
        let _: EmptyResponse = try await request(path: "/push-devices/\(id)", method: "DELETE", token: token)
    }

    func getInvestmentPortfolio(token: String) async throws -> InvestmentPortfolio {
        try await request(path: "/investments/portfolio", token: token, timeoutInterval: 30)
    }

    func getInvestmentPortfolioHistory(token: String, range: String = "1y") async throws -> InvestmentPortfolioHistory {
        try await request(
            path: "/investments/portfolio/history",
            token: token,
            queryItems: [URLQueryItem(name: "range", value: range)],
            timeoutInterval: 30
        )
    }

    func getInvestmentTrades(token: String) async throws -> [InvestmentTrade] {
        try await request(path: "/investments/trades", token: token)
    }

    func createInvestmentTrade(token: String, request body: InvestmentTradeRequest) async throws -> InvestmentTrade {
        try await request(
            path: "/investments/trades",
            method: "POST",
            token: token,
            body: body,
            timeoutInterval: 30
        )
    }

    func deleteInvestmentTrade(token: String, id: Int) async throws {
        let _: EmptyResponse = try await request(path: "/investments/trades/\(id)", method: "DELETE", token: token)
    }

    func setManualInvestmentPrice(token: String, request body: InvestmentPriceRequest) async throws -> InvestmentPrice {
        try await request(path: "/investments/prices", method: "PUT", token: token, body: body)
    }

    func getInvestmentSchedules(token: String) async throws -> [InvestmentSchedule] {
        try await request(path: "/investment-schedules", token: token)
    }

    func createInvestmentSchedule(token: String, request body: InvestmentScheduleRequest) async throws -> InvestmentSchedule {
        try await request(path: "/investment-schedules", method: "POST", token: token, body: body)
    }

    func pauseInvestmentSchedule(token: String, id: Int) async throws -> InvestmentSchedule {
        try await request(path: "/investment-schedules/\(id)/pause", method: "POST", token: token, body: Optional<String>.none)
    }

    func resumeInvestmentSchedule(token: String, id: Int) async throws -> InvestmentSchedule {
        try await request(path: "/investment-schedules/\(id)/resume", method: "POST", token: token, body: Optional<String>.none)
    }

    func deleteInvestmentSchedule(token: String, id: Int) async throws {
        let _: EmptyResponse = try await request(path: "/investment-schedules/\(id)", method: "DELETE", token: token)
    }

    func exportInvestmentCSV(token: String, from: String, through: String) async throws -> String {
        let request = try makeRequest(path: "/investments/export", token: token, queryItems: [
            URLQueryItem(name: "from", value: from),
            URLQueryItem(name: "through", value: through),
        ])
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return String(data: data, encoding: .utf8) ?? ""
    }
}
