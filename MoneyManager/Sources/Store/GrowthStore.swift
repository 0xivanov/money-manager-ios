import Foundation
import Observation

@MainActor
@Observable
final class GrowthStore {
    private struct InvestmentHistoryCacheEntry {
        let history: InvestmentPortfolioHistory
        let cachedAt: Date
    }

    private static let investmentHistoryCacheTTL: TimeInterval = 5 * 60

    private let api: MoneyManagerAPI
    @ObservationIgnored private var investmentLoadTask: Task<Void, Never>?
    @ObservationIgnored private var investmentLoadID: UUID?
    @ObservationIgnored private var investmentHistoryLoadID: UUID?
    @ObservationIgnored private var investmentHistoryCache: [String: InvestmentHistoryCacheEntry] = [:]

    var transactionSchedules: [TransactionSchedule] = []
    var scheduleOccurrences: [TransactionScheduleOccurrence] = []
    var budgets: [Budget] = []
    var notificationPreferences = NotificationPreferences.defaults
    var portfolio = InvestmentPortfolio.empty
    var portfolioHistory = InvestmentPortfolioHistory.empty {
        didSet {
            portfolioHistoryChartPoints = investmentPortfolioChartPoints(portfolioHistory.points)
        }
    }
    private(set) var portfolioHistoryChartPoints: [InvestmentPortfolioChartPoint] = []
    var investmentTrades: [InvestmentTrade] = []
    var investmentSchedules: [InvestmentSchedule] = []
    var isLoadingPlanning = false
    var isLoadingInvestments = false
    var isLoadingInvestmentHistory = false
    var isSaving = false
    var error: String?
    var investmentHistoryError: String?
    var shareItem: ExportShareItem?

    init(api: MoneyManagerAPI) {
        self.api = api
    }

    func reset() {
        investmentLoadTask?.cancel()
        investmentLoadTask = nil
        investmentLoadID = nil
        investmentHistoryLoadID = nil
        investmentHistoryCache = [:]
        transactionSchedules = []
        scheduleOccurrences = []
        budgets = []
        notificationPreferences = .defaults
        portfolio = .empty
        portfolioHistory = .empty
        investmentTrades = []
        investmentSchedules = []
        isLoadingPlanning = false
        isLoadingInvestments = false
        isLoadingInvestmentHistory = false
        isSaving = false
        error = nil
        investmentHistoryError = nil
        shareItem = nil
    }

    func loadPlanning(token: String, force: Bool = false) async {
        if isLoadingPlanning || (!force && !transactionSchedules.isEmpty && !budgets.isEmpty) { return }
        isLoadingPlanning = true
        error = nil
        defer { isLoadingPlanning = false }
        do {
            let calendar = Calendar(identifier: .gregorian)
            let today = calendar.startOfDay(for: Date())
            let through = calendar.date(byAdding: .day, value: 90, to: today) ?? today
            async let schedulesResult = api.getTransactionSchedules(token: token)
            async let occurrencesResult = api.getTransactionScheduleOccurrences(
                token: token,
                from: DateFormat.isoDate.string(from: today),
                through: DateFormat.isoDate.string(from: through)
            )
            async let budgetsResult = api.getBudgets(token: token)
            async let preferencesResult = api.getNotificationPreferences(token: token)
            let (schedules, occurrences, loadedBudgets, preferences) = try await (
                schedulesResult, occurrencesResult, budgetsResult, preferencesResult
            )
            transactionSchedules = schedules
            scheduleOccurrences = occurrences
            budgets = loadedBudgets
            notificationPreferences = preferences
        } catch {
            self.error = error.localizedDescription
        }
    }

    func createTransactionSchedule(token: String, request: TransactionScheduleRequest) async -> Bool {
        await performSave {
            _ = try await api.createTransactionSchedule(token: token, request: request)
            await loadPlanning(token: token, force: true)
        }
    }

    func toggleTransactionSchedule(token: String, schedule: TransactionSchedule) async {
        _ = await performSave {
            if schedule.status == "paused" {
                _ = try await api.resumeTransactionSchedule(token: token, id: schedule.id)
            } else {
                _ = try await api.pauseTransactionSchedule(token: token, id: schedule.id)
            }
            await loadPlanning(token: token, force: true)
        }
    }

    func deleteTransactionSchedule(token: String, id: Int) async {
        _ = await performSave {
            try await api.deleteTransactionSchedule(token: token, id: id)
            await loadPlanning(token: token, force: true)
        }
    }

    func createBudget(token: String, request: BudgetRequest) async -> Bool {
        await performSave {
            _ = try await api.createBudget(token: token, request: request)
            await loadPlanning(token: token, force: true)
        }
    }

    func deleteBudget(token: String, id: Int) async {
        _ = await performSave {
            try await api.deleteBudget(token: token, id: id)
            await loadPlanning(token: token, force: true)
        }
    }

    func saveNotificationPreferences(token: String, preferences: NotificationPreferences) async -> Bool {
        await performSave {
            notificationPreferences = try await api.updateNotificationPreferences(token: token, preferences: preferences)
        }
    }

    func registerPushDevice(token: String, deviceToken: String) async {
        let environment: String
        #if DEBUG
        environment = "sandbox"
        #else
        environment = "production"
        #endif
        let request = PushDeviceRequest(
            platform: "ios",
            deviceToken: deviceToken,
            appID: Bundle.main.bundleIdentifier ?? "org.moneymanager.ios",
            environment: environment
        )
        _ = await performSave {
            let device = try await api.registerPushDevice(token: token, request: request)
            PushDeviceRegistrationStore.deviceID = device.id
        }
    }

    func unregisterPushDevice(token: String) async {
        guard let deviceID = PushDeviceRegistrationStore.deviceID else { return }
        do {
            try await api.deletePushDevice(token: token, id: deviceID)
            PushDeviceRegistrationStore.deviceID = nil
        } catch APIError.unauthorized {
            PushDeviceRegistrationStore.deviceID = nil
        } catch {
            // Keep the ID for a later successful registration or logout attempt.
        }
    }

    func loadInvestments(token: String, force: Bool = false) async {
        if let investmentLoadTask {
            await investmentLoadTask.value
            return
        }
        if !force && (
            !portfolio.positions.isEmpty || !investmentTrades.isEmpty || !portfolioHistory.points.isEmpty
        ) { return }
        if force {
            investmentHistoryCache = [:]
        }

        let loadID = UUID()
        let task = Task { [weak self] in
            guard let self else { return }
            await self.performInvestmentLoad(token: token)
        }
        investmentLoadID = loadID
        investmentLoadTask = task
        await task.value
        if investmentLoadID == loadID {
            investmentLoadTask = nil
            investmentLoadID = nil
        }
    }

    private func performInvestmentLoad(token: String) async {
        isLoadingInvestments = true
        isLoadingInvestmentHistory = true
        error = nil
        investmentHistoryError = nil
        defer {
            isLoadingInvestments = false
            isLoadingInvestmentHistory = false
        }

        async let portfolioResult = api.getInvestmentPortfolio(token: token)
        async let tradesResult = api.getInvestmentTrades(token: token)
        async let schedulesResult = api.getInvestmentSchedules(token: token)
        async let historyResult = api.getInvestmentPortfolioHistory(token: token, range: "1y")

        var loadErrors: [String] = []
        do {
            let loadedPortfolio = try await portfolioResult
            try Task.checkCancellation()
            portfolio = loadedPortfolio
        } catch {
            if !isCancellation(error) { loadErrors.append(error.localizedDescription) }
        }
        do {
            let loadedTrades = try await tradesResult
            try Task.checkCancellation()
            investmentTrades = loadedTrades
        } catch {
            if !isCancellation(error) { loadErrors.append(error.localizedDescription) }
        }
        do {
            let loadedSchedules = try await schedulesResult
            try Task.checkCancellation()
            investmentSchedules = loadedSchedules
        } catch {
            if !isCancellation(error) { loadErrors.append(error.localizedDescription) }
        }

        do {
            let loadedHistory = try await historyResult
            try Task.checkCancellation()
            storeInvestmentHistory(loadedHistory)
        } catch {
            if !isCancellation(error) { investmentHistoryError = error.localizedDescription }
        }
        self.error = loadErrors.first
    }

    func createInvestmentTrade(token: String, request: InvestmentTradeRequest) async -> Bool {
        await performSave {
            _ = try await api.createInvestmentTrade(token: token, request: request)
            investmentHistoryCache = [:]
            await loadInvestments(token: token, force: true)
        }
    }

    func loadInvestmentHistory(token: String, range: String, force: Bool = false) async {
        if !force,
           let cached = investmentHistoryCache[range],
           Date().timeIntervalSince(cached.cachedAt) < Self.investmentHistoryCacheTTL {
            portfolioHistory = cached.history
            investmentHistoryError = nil
            return
        }

        let loadID = UUID()
        investmentHistoryLoadID = loadID
        isLoadingInvestmentHistory = true
        investmentHistoryError = nil
        defer {
            if investmentHistoryLoadID == loadID {
                investmentHistoryLoadID = nil
                isLoadingInvestmentHistory = false
            }
        }
        do {
            let loadedHistory = try await api.getInvestmentPortfolioHistory(token: token, range: range)
            try Task.checkCancellation()
            guard investmentHistoryLoadID == loadID else { return }
            storeInvestmentHistory(loadedHistory)
        } catch {
            if investmentHistoryLoadID == loadID && !isCancellation(error) {
                investmentHistoryError = error.localizedDescription
            }
        }
    }

    private func storeInvestmentHistory(_ history: InvestmentPortfolioHistory) {
        portfolioHistory = history
        investmentHistoryCache[history.range] = InvestmentHistoryCacheEntry(
            history: history,
            cachedAt: Date()
        )
    }

    private func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        return (error as? URLError)?.code == .cancelled
    }

    func deleteInvestmentTrade(token: String, id: Int) async {
        _ = await performSave {
            try await api.deleteInvestmentTrade(token: token, id: id)
            investmentHistoryCache = [:]
            await loadInvestments(token: token, force: true)
        }
    }

    func setManualPrice(token: String, position: InvestmentPosition, price: String) async -> Bool {
        await performSave {
            _ = try await api.setManualInvestmentPrice(token: token, request: InvestmentPriceRequest(
                assetType: position.assetType,
                symbol: position.symbol,
                currency: position.currency,
                price: price
            ))
            investmentHistoryCache = [:]
            await loadInvestments(token: token, force: true)
        }
    }

    func createInvestmentSchedule(token: String, request: InvestmentScheduleRequest) async -> Bool {
        await performSave {
            _ = try await api.createInvestmentSchedule(token: token, request: request)
            await loadInvestments(token: token, force: true)
        }
    }

    func toggleInvestmentSchedule(token: String, schedule: InvestmentSchedule) async {
        _ = await performSave {
            if schedule.status == "paused" {
                _ = try await api.resumeInvestmentSchedule(token: token, id: schedule.id)
            } else {
                _ = try await api.pauseInvestmentSchedule(token: token, id: schedule.id)
            }
            await loadInvestments(token: token, force: true)
        }
    }

    func deleteInvestmentSchedule(token: String, id: Int) async {
        _ = await performSave {
            try await api.deleteInvestmentSchedule(token: token, id: id)
            await loadInvestments(token: token, force: true)
        }
    }

    func exportInvestments(token: String, from: Date, through: Date) async {
        _ = await performSave {
            let fromText = DateFormat.isoDate.string(from: from)
            let throughText = DateFormat.isoDate.string(from: through)
            let csv = try await api.exportInvestmentCSV(token: token, from: fromText, through: throughText)
            let url = try ExportFileWriter.writeCSV(csv, fileName: "money-manager-investments-\(fromText)-to-\(throughText).csv")
            shareItem = ExportShareItem(url: url)
        }
    }

    private func performSave(_ operation: () async throws -> Void) async -> Bool {
        guard !isSaving else { return false }
        isSaving = true
        error = nil
        defer { isSaving = false }
        do {
            try await operation()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
