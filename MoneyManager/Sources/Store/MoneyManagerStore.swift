import Foundation
import Observation

@MainActor
@Observable
final class MoneyManagerStore {
    private enum ActionScope: Hashable {
        case transactionEditor
        case export
        case importCSV
    }

    private let api: MoneyManagerAPI
    private let tokenStore: TokenStore
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var refreshGeneration = 0
    @ObservationIgnored private var sessionGeneration = 0
    @ObservationIgnored private var openBankingReloadRequested = false
    @ObservationIgnored private var actionTasks: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored private var scopedActionIDs: [ActionScope: UUID] = [:]
    @ObservationIgnored private var activeRequestIDs: Set<UUID> = []

    var token: String?
    var email = ""
    var password = ""
    var selectedTab: AppTab = .dashboard
    var activeSheet: AppSheet?
    var isRegisterMode = false
    var isLoading = false
    var error: String?
    var dashboardLoadState: DashboardLoadState = .idle
    var connectionStatus: ConnectionStatus = .unknown
    var openBankingLoadState: OpenBankingLoadState = .idle
    var openBankingInstitutions: [OpenBankingInstitution] = []
    var openBankingConnections: [OpenBankingConnection] = []
    var openBankingAccounts: [OpenBankingAccount] = []
    var openBankingBalances: [Int: OpenBankingBalanceResponse] = [:]
    var openBankingBalanceLoadStates: [Int: OpenBankingLoadState] = [:]
    var openBankingAccountSnapshots: [Int: OpenBankingAccountSnapshot] = [:]
    var openBankingAccountLoadStates: [Int: OpenBankingLoadState] = [:]
    var openBankingCountry = OpenBankingRegion.defaultCode
    var openBankingCallbackState: OpenBankingCallbackState = .idle
    var openBankingError: String?
    var isLoadingOpenBankingInstitutions = false
    var isStartingOpenBankingAuthorization = false
    var isDeletingOpenBankingConnection = false
    var isDeletingAccount = false
    var month = DateFormat.currentMonthKey()
    var filterType: String?
    var filterCategory: String?
    var searchQuery = ""
    var summary: TransactionSummary?
    var transactions: [Transaction] = []
    var selectedExpenseCategory: String?
    var editingID: Int?
    var formType = TransactionType.expense.rawValue
    var formCategory = "food"
    var formDescription = ""
    var formAmount = ""
    var formOccurredAt = Date()
    var expenseCategories: [Category] = []
    var incomeCategories: [Category] = []
    var newCategoryName = ""
    var exportFrom = DateFormat.firstDayDate(of: DateFormat.currentMonthKey())
    var exportTo = Date()
    var exportShareItem: ExportShareItem?
    var importResultMessage: String?
    var isImporting = false

    init(api: MoneyManagerAPI = MoneyManagerAPI(), tokenStore: TokenStore = TokenStore()) {
        self.api = api
        self.tokenStore = tokenStore
        self.token = tokenStore.getToken()
    }

    var isAuthenticated: Bool {
        token != nil
    }

    var apiBaseURL: URL {
        api.baseURL
    }

    var canGoNextMonth: Bool {
        guard let current = DateFormat.monthKey.date(from: month), let now = DateFormat.monthKey.date(from: DateFormat.currentMonthKey()) else {
            return false
        }
        return current < now
    }

    var expenseCategoryTotals: [CategoryTotal] {
        transactions
            .filter { $0.type == TransactionType.expense.rawValue }
            .reduce(into: [String: Decimal]()) { totals, transaction in
                totals[transaction.category, default: .zero] += MoneyFormat.decimal(from: transaction.amount)
            }
            .map { CategoryTotal(category: $0.key, amount: $0.value) }
            .filter { $0.amount > .zero }
            .sorted { $0.amount > $1.amount }
    }

    var transactionDayBuckets: [DayBucket] {
        makeDayBuckets(from: filteredTransactions)
    }

    var dashboardDayBuckets: [DayBucket] {
        let dashboardTransactions: [Transaction]
        if let selectedExpenseCategory {
            dashboardTransactions = transactions.filter {
                $0.type == TransactionType.expense.rawValue && $0.category == selectedExpenseCategory
            }
        } else {
            dashboardTransactions = transactions
        }
        return makeDayBuckets(from: dashboardTransactions)
    }

    var availableFilterCategories: [String] {
        let loadedCategories = expenseCategories.map(\.name) + incomeCategories.map(\.name)
        let transactionCategories = transactions.map(\.category)
        return Array(Set(loadedCategories + transactionCategories)).sorted {
            categoryTitle($0).localizedCaseInsensitiveCompare(categoryTitle($1)) == .orderedAscending
        }
    }

    var hasActiveTransactionFilters: Bool {
        filterType != nil || filterCategory != nil || !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasTransactionDraft: Bool {
        editingID != nil || !formAmount.isEmpty || !formDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func makeDayBuckets(from source: [Transaction]) -> [DayBucket] {
        source
            .reduce(into: [Date: [Transaction]]()) { buckets, transaction in
                let date = DateFormat.isoDate.date(from: DateFormat.dateOnly(transaction.occurredAt)) ?? .distantPast
                buckets[date, default: []].append(transaction)
            }
            .map { date, transactions in
                let sorted = transactions.sorted { lhs, rhs in
                    if lhs.occurredAt == rhs.occurredAt {
                        return lhs.id > rhs.id
                    }
                    return lhs.occurredAt > rhs.occurredAt
                }
                let balance = sorted.reduce(Decimal.zero) { total, transaction in
                    let amount = MoneyFormat.decimal(from: transaction.amount)
                    return transaction.type == TransactionType.income.rawValue ? total + amount : total - amount
                }
                return DayBucket(date: date, balanceChange: balance, transactions: sorted)
            }
            .sorted { $0.date > $1.date }
    }

    var formCategoryOptions: [Category] {
        let categories = formType == TransactionType.income.rawValue ? incomeCategories : expenseCategories
        if formCategory.isEmpty || categories.contains(where: { $0.name == formCategory }) {
            return categories
        }
        return categories + [Category(id: 0, type: formType, name: formCategory, isDefault: false)]
    }

    private var filteredTransactions: [Transaction] {
        var result = transactions
        if let filterType {
            result = result.filter { $0.type == filterType }
        }
        if let filterCategory {
            result = result.filter { $0.category == filterCategory }
        }
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            let queryAmount = MoneyFormat.inputDecimal(from: query)
            result = result.filter { transaction in
                let amount = MoneyFormat.decimal(from: transaction.amount)
                return transaction.category.localizedCaseInsensitiveContains(query)
                    || transaction.description?.localizedCaseInsensitiveContains(query) == true
                    || transaction.amount.localizedCaseInsensitiveContains(query)
                    || (queryAmount != nil && queryAmount == amount)
                    || MoneyFormat.amount(amount, currency: transaction.currency).localizedCaseInsensitiveContains(query)
                    || DateFormat.dateOnly(transaction.occurredAt).localizedCaseInsensitiveContains(query)
            }
        }
        return result
    }

    func bootstrap() async {
        let generation = sessionGeneration
        await checkHealth()
        guard generation == sessionGeneration, let savedToken = token else { return }
        dashboardLoadState = .loading
        do {
            async let expenseResult = api.getCategories(token: savedToken, type: TransactionType.expense.rawValue)
            async let incomeResult = api.getCategories(token: savedToken, type: TransactionType.income.rawValue)
            let (expenses, income) = try await (expenseResult, incomeResult)
            try requireCurrentSession(token: savedToken, generation: generation)
            expenseCategories = expenses
            incomeCategories = income
            await refresh()
            try requireCurrentSession(token: savedToken, generation: generation)

            do {
                let user = try await api.getCurrentUser(token: savedToken)
                try requireCurrentSession(token: savedToken, generation: generation)
                email = user.email
            } catch APIError.unauthorized {
                guard isCurrentSession(token: savedToken, generation: generation) else { return }
                expireSession(message: APIError.unauthorized.localizedDescription)
            } catch is CancellationError {
                return
            } catch {
                // Core financial data remains usable if optional profile hydration fails.
            }
        } catch APIError.unauthorized {
            guard isCurrentSession(token: savedToken, generation: generation) else { return }
            expireSession(message: APIError.unauthorized.localizedDescription)
        } catch is CancellationError {
            return
        } catch {
            guard isCurrentSession(token: savedToken, generation: generation) else { return }
            dashboardLoadState = .failed(error.localizedDescription)
        }
    }

    func submitAuth() {
        startAction { generation in
            await self.runRequest(generation: generation) {
                let trimmedEmail = self.email.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedEmail.isEmpty, !self.password.isEmpty else {
                    throw ValidationError("Email and password are required")
                }
                let result = self.isRegisterMode
                    ? try await self.api.register(email: trimmedEmail, password: self.password)
                    : try await self.api.login(email: trimmedEmail, password: self.password)
                try self.requireCurrentGeneration(generation)
                self.tokenStore.saveToken(result.token)
                self.token = result.token
                self.email = result.user.email
                self.password = ""
                self.dashboardLoadState = .loading
                do {
                    try await self.loadCategories(token: result.token, generation: generation)
                } catch {
                    self.dashboardLoadState = .failed(error.localizedDescription)
                    throw error
                }
                await self.refresh()
            }
        }
    }

    func logout() {
        resetSession(clearEmail: true)
    }

    func deleteAccount() {
        guard let token else { return }
        let generation = sessionGeneration
        isDeletingAccount = true
        error = nil
        startAction(generation: generation) { generation in
            do {
                try await self.api.deleteAccount(token: token)
                try self.requireCurrentSession(token: token, generation: generation)
                self.resetSession(clearEmail: true)
            } catch APIError.unauthorized {
                guard self.isCurrentSession(token: token, generation: generation) else { return }
                self.expireSession(message: APIError.unauthorized.localizedDescription)
            } catch is CancellationError {
                return
            } catch {
                guard self.isCurrentSession(token: token, generation: generation) else { return }
                self.error = error.localizedDescription
            }
            if self.sessionGeneration == generation {
                self.isDeletingAccount = false
            }
        }
    }

    private func resetSession(clearEmail: Bool) {
        refreshTask?.cancel()
        refreshTask = nil
        refreshGeneration += 1
        sessionGeneration += 1
        openBankingReloadRequested = false
        let tasks = Array(actionTasks.values)
        actionTasks.removeAll()
        scopedActionIDs.removeAll()
        tasks.forEach { $0.cancel() }
        activeRequestIDs.removeAll()
        isLoading = false
        isDeletingAccount = false
        tokenStore.clearToken()
        token = nil
        if clearEmail { email = "" }
        password = ""
        error = nil
        isRegisterMode = false
        selectedTab = .dashboard
        activeSheet = nil
        month = DateFormat.currentMonthKey()
        summary = nil
        transactions = []
        selectedExpenseCategory = nil
        filterType = nil
        filterCategory = nil
        searchQuery = ""
        expenseCategories = []
        incomeCategories = []
        dashboardLoadState = .idle
        openBankingLoadState = .idle
        openBankingInstitutions = []
        openBankingConnections = []
        openBankingAccounts = []
        openBankingBalances = [:]
        openBankingBalanceLoadStates = [:]
        openBankingAccountSnapshots = [:]
        openBankingAccountLoadStates = [:]
        openBankingCallbackState = .idle
        openBankingError = nil
        isLoadingOpenBankingInstitutions = false
        isStartingOpenBankingAuthorization = false
        isDeletingOpenBankingConnection = false
        exportShareItem = nil
        clearForm()
    }

    func toggleAuthMode() {
        isRegisterMode.toggle()
        error = nil
    }

    func previousMonth() {
        moveMonth(by: -1)
    }

    func nextMonth() {
        guard canGoNextMonth else { return }
        moveMonth(by: 1)
    }

    func refresh() async {
        guard let token else { return }
        refreshTask?.cancel()
        refreshGeneration += 1
        let generation = refreshGeneration
        let requestedMonth = month
        if summary == nil {
            dashboardLoadState = .loading
        }

        let task = Task { [weak self] in
            guard let self else { return }
            await self.performRefresh(token: token, month: requestedMonth, generation: generation)
        }
        refreshTask = task
        await task.value
        if refreshGeneration == generation {
            refreshTask = nil
        }
    }

    func retryDashboard() {
        Task { await refresh() }
    }

    func checkHealth() async {
        connectionStatus = .checking
        do {
            try await api.healthCheck()
            connectionStatus = .connected
        } catch {
            connectionStatus = .offline(error.localizedDescription)
        }
    }

    func loadOpenBanking(force: Bool = false) async {
        guard let requestedToken = token else { return }
        if openBankingLoadState == .loading {
            if force { openBankingReloadRequested = true }
            return
        }
        let generation = sessionGeneration
        let hadLoadedData = !openBankingConnections.isEmpty || !openBankingAccounts.isEmpty
        openBankingLoadState = .loading
        openBankingError = nil
        defer {
            let shouldReload = openBankingReloadRequested
                && isCurrentSession(token: requestedToken, generation: generation)
            openBankingReloadRequested = false
            if shouldReload {
                Task { await loadOpenBanking(force: true) }
            }
        }
        do {
            async let connectionsResult = api.getOpenBankingConnections(token: requestedToken)
            async let accountsResult = api.getOpenBankingAccounts(token: requestedToken)
            let (connections, accounts) = try await (connectionsResult, accountsResult)
            try requireCurrentSession(token: requestedToken, generation: generation)
            openBankingConnections = connections
            openBankingAccounts = accounts
            let accountIDs = Set(accounts.map(\.id))
            openBankingBalances = openBankingBalances.filter { accountIDs.contains($0.key) }
            openBankingBalanceLoadStates = openBankingBalanceLoadStates.filter { accountIDs.contains($0.key) }
            openBankingAccountSnapshots = openBankingAccountSnapshots.filter { accountIDs.contains($0.key) }
            openBankingAccountLoadStates = openBankingAccountLoadStates.filter { accountIDs.contains($0.key) }
            openBankingLoadState = .loaded
        } catch APIError.unauthorized {
            guard isCurrentSession(token: requestedToken, generation: generation) else { return }
            expireSession(message: APIError.unauthorized.localizedDescription)
        } catch is CancellationError {
            guard isCurrentSession(token: requestedToken, generation: generation) else { return }
            openBankingLoadState = hadLoadedData ? .loaded : .idle
            return
        } catch {
            guard isCurrentSession(token: requestedToken, generation: generation) else { return }
            openBankingError = error.localizedDescription
            openBankingLoadState = .failed(error.localizedDescription)
        }
    }

    func loadOpenBankingInstitutions(country: String? = nil, force: Bool = false) async {
        guard let requestedToken = token else { return }
        let requestedCountry = (country ?? openBankingCountry).uppercased()
        if !force, requestedCountry == openBankingInstitutions.first?.country {
            return
        }
        let generation = sessionGeneration
        openBankingCountry = requestedCountry
        isLoadingOpenBankingInstitutions = true
        openBankingError = nil
        if force || requestedCountry != openBankingInstitutions.first?.country {
            openBankingInstitutions = []
        }
        defer { isLoadingOpenBankingInstitutions = false }
        do {
            let institutions = try await api.getOpenBankingInstitutions(
                token: requestedToken,
                country: requestedCountry
            )
            try requireCurrentSession(token: requestedToken, generation: generation)
            openBankingInstitutions = institutions.sorted { lhs, rhs in
                if lhs.beta != rhs.beta { return !lhs.beta }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        } catch APIError.unauthorized {
            guard isCurrentSession(token: requestedToken, generation: generation) else { return }
            expireSession(message: APIError.unauthorized.localizedDescription)
        } catch is CancellationError {
            return
        } catch {
            guard isCurrentSession(token: requestedToken, generation: generation) else { return }
            openBankingError = error.localizedDescription
        }
    }

    func startOpenBankingAuthorization(for institution: OpenBankingInstitution) async -> URL? {
        guard let requestedToken = token else { return nil }
        let generation = sessionGeneration
        isStartingOpenBankingAuthorization = true
        openBankingError = nil
        openBankingCallbackState = .idle
        defer { isStartingOpenBankingAuthorization = false }
        do {
            let languageCode = Locale.current.language.languageCode?.identifier ?? "en"
            let language = languageCode.count == 2 ? languageCode : "en"
            let authorization = try await api.startOpenBankingAuthorization(
                token: requestedToken,
                institution: institution,
                language: language
            )
            try requireCurrentSession(token: requestedToken, generation: generation)
            guard let url = URL(string: authorization.authorizationURL),
                  url.scheme?.lowercased() == "https",
                  url.host != nil
            else {
                throw ValidationError("The bank returned an invalid authorization link")
            }
            return url
        } catch APIError.unauthorized {
            guard isCurrentSession(token: requestedToken, generation: generation) else { return nil }
            expireSession(message: APIError.unauthorized.localizedDescription)
        } catch is CancellationError {
            return nil
        } catch {
            guard isCurrentSession(token: requestedToken, generation: generation) else { return nil }
            openBankingError = error.localizedDescription
        }
        return nil
    }

    func loadOpenBankingBalance(accountID: Int, force: Bool = false) async {
        guard let requestedToken = token else { return }
        if openBankingBalanceLoadStates[accountID] == .loading && !force { return }
        if openBankingBalances[accountID] != nil && !force { return }
        guard let account = openBankingAccounts.first(where: { $0.id == accountID }), account.canFetchData else {
            let message = "Live balance is not available for this account."
            openBankingBalanceLoadStates[accountID] = .failed(message)
            return
        }
        let generation = sessionGeneration
        openBankingBalanceLoadStates[accountID] = .loading
        do {
            let balances = try await api.getOpenBankingBalances(token: requestedToken, accountID: accountID)
            try requireCurrentSession(token: requestedToken, generation: generation)
            openBankingBalances[accountID] = balances
            openBankingBalanceLoadStates[accountID] = .loaded
        } catch APIError.unauthorized {
            guard isCurrentSession(token: requestedToken, generation: generation) else { return }
            expireSession(message: APIError.unauthorized.localizedDescription)
        } catch is CancellationError {
            return
        } catch {
            guard isCurrentSession(token: requestedToken, generation: generation) else { return }
            openBankingBalanceLoadStates[accountID] = .failed(error.localizedDescription)
        }
    }

    func loadOpenBankingAccountData(accountID: Int, force: Bool = false) async {
        guard let requestedToken = token else { return }
        if openBankingAccountLoadStates[accountID] == .loading && !force { return }
        if openBankingAccountSnapshots[accountID] != nil && !force { return }
        guard let account = openBankingAccounts.first(where: { $0.id == accountID }), account.canFetchData else {
            let message = "Live data is not available for this account."
            openBankingAccountLoadStates[accountID] = .failed(message)
            return
        }
        let generation = sessionGeneration
        openBankingAccountLoadStates[accountID] = .loading
        do {
            let now = Date()
            let start = Calendar.current.date(byAdding: .day, value: -89, to: now) ?? now
            async let balancesResult = api.getOpenBankingBalances(token: requestedToken, accountID: accountID)
            async let transactionsResult = api.getOpenBankingTransactions(
                token: requestedToken,
                accountID: accountID,
                dateFrom: DateFormat.isoDate.string(from: start),
                dateTo: DateFormat.isoDate.string(from: now)
            )
            let (balances, transactions) = try await (balancesResult, transactionsResult)
            try requireCurrentSession(token: requestedToken, generation: generation)
            openBankingAccountSnapshots[accountID] = OpenBankingAccountSnapshot(
                balances: balances,
                transactions: transactions,
                loadedAt: Date()
            )
            openBankingBalances[accountID] = balances
            openBankingBalanceLoadStates[accountID] = .loaded
            openBankingAccountLoadStates[accountID] = .loaded
        } catch APIError.unauthorized {
            guard isCurrentSession(token: requestedToken, generation: generation) else { return }
            expireSession(message: APIError.unauthorized.localizedDescription)
        } catch is CancellationError {
            return
        } catch {
            guard isCurrentSession(token: requestedToken, generation: generation) else { return }
            openBankingAccountLoadStates[accountID] = .failed(error.localizedDescription)
        }
    }

    func deleteOpenBankingConnection(_ connection: OpenBankingConnection) async {
        guard let requestedToken = token else { return }
        let generation = sessionGeneration
        isDeletingOpenBankingConnection = true
        openBankingError = nil
        defer { isDeletingOpenBankingConnection = false }
        do {
            try await api.deleteOpenBankingConnection(token: requestedToken, id: connection.id)
            try requireCurrentSession(token: requestedToken, generation: generation)
            let removedAccountIDs = openBankingAccounts
                .filter { $0.connectionID == connection.id }
                .map(\.id)
            openBankingConnections.removeAll { $0.id == connection.id }
            openBankingAccounts.removeAll { $0.connectionID == connection.id }
            for accountID in removedAccountIDs {
                openBankingBalances[accountID] = nil
                openBankingBalanceLoadStates[accountID] = nil
                openBankingAccountSnapshots[accountID] = nil
                openBankingAccountLoadStates[accountID] = nil
            }
        } catch APIError.unauthorized {
            guard isCurrentSession(token: requestedToken, generation: generation) else { return }
            expireSession(message: APIError.unauthorized.localizedDescription)
        } catch is CancellationError {
            return
        } catch {
            guard isCurrentSession(token: requestedToken, generation: generation) else { return }
            openBankingError = error.localizedDescription
        }
    }

    func handleOpenBankingCallback(_ url: URL) {
        guard url.scheme?.lowercased() == "moneymanager",
              url.host?.lowercased() == "open-banking",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return }
        let values = (components.queryItems ?? []).reduce(into: [String: String]()) { result, item in
            result[item.name] = item.value ?? ""
        }
        switch values["status"]?.lowercased() {
        case "connected":
            let connectionID = values["connection_id"].flatMap(Int.init)
            openBankingCallbackState = .connected(connectionID: connectionID)
            openBankingError = nil
            selectedTab = .profile
            Task { await loadOpenBanking(force: true) }
        case "cancelled":
            openBankingCallbackState = .cancelled
            openBankingError = "Bank connection was cancelled. No access was granted."
        case "failed":
            let reason = values["error"]?.replacingOccurrences(of: "_", with: " ") ?? "unknown error"
            let message = "Bank connection failed: \(reason)."
            openBankingCallbackState = .failed(message)
            openBankingError = message
        default:
            break
        }
    }

    func clearOpenBankingCallbackState() {
        openBankingCallbackState = .idle
    }

    func selectExpenseCategory(_ category: String) {
        selectedExpenseCategory = category
    }

    func clearSelectedExpenseCategory() {
        selectedExpenseCategory = nil
    }

    func updateFilterType(_ value: String?) {
        filterType = value
    }

    func updateFilterCategory(_ value: String?) {
        filterCategory = value
    }

    func resetTransactionFilters() {
        filterType = nil
        filterCategory = nil
        searchQuery = ""
    }

    func showAllTransactions() {
        resetTransactionFilters()
        if let selectedExpenseCategory {
            filterType = TransactionType.expense.rawValue
            filterCategory = selectedExpenseCategory
        }
        selectedTab = .transactions
    }

    func openNewTransactionForm() {
        error = nil
        clearForm()
        activeSheet = .transactionEditor
    }

    func openPhysicalPurchaseForm() {
        error = nil
        clearForm()
        formType = TransactionType.expense.rawValue
        formCategory = "shopping"
        activeSheet = .transactionEditor
    }

    func editTransaction(_ transaction: Transaction) {
        error = nil
        editingID = transaction.id
        formType = transaction.type
        formCategory = transaction.category
        formDescription = transaction.description ?? ""
        formAmount = transaction.amount
        formOccurredAt = DateFormat.apiDate(transaction.occurredAt) ?? Date()
        activeSheet = .transactionEditor
    }

    func updateFormType(_ type: String) {
        formType = type
        let categories = type == TransactionType.income.rawValue ? incomeCategories : expenseCategories
        formCategory = categories.first?.name ?? (type == TransactionType.income.rawValue ? "salary" : "food")
    }

    func chooseFormCategory(_ category: String) {
        formCategory = category
        newCategoryName = ""
        error = nil
    }

    func clearTransientError() {
        error = nil
    }

    func saveTransaction() {
        startAction(scope: .transactionEditor) { generation in
            await self.runRequest(generation: generation) {
                try self.validateTransactionForm()
                guard let token = self.token else { return }
                guard let amount = MoneyFormat.inputDecimal(from: self.formAmount) else {
                    throw ValidationError("Enter a valid amount")
                }
                let description = self.formDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                let request = TransactionRequest(
                    type: self.formType,
                    category: self.formCategory,
                    description: description.isEmpty ? nil : description,
                    amount: MoneyFormat.apiAmount(amount),
                    currency: self.summary?.currency ?? "EUR",
                    occurredAt: DateFormat.isoDate.string(from: self.formOccurredAt)
                )
                if let editingID = self.editingID {
                    _ = try await self.api.updateTransaction(token: token, id: editingID, transaction: request)
                } else {
                    _ = try await self.api.createTransaction(token: token, transaction: request)
                }
                try self.requireCurrentSession(token: token, generation: generation)
                self.activeSheet = nil
                self.clearForm()
                await self.refresh()
            }
        }
    }

    func cancelTransactionEditor() {
        cancelAction(scope: .transactionEditor)
        activeSheet = nil
        clearForm()
        error = nil
    }

    func deleteTransaction(_ id: Int) {
        startAction { generation in
            await self.runRequest(generation: generation) {
                guard let token = self.token else { return }
                try await self.api.deleteTransaction(token: token, id: id)
                try self.requireCurrentSession(token: token, generation: generation)
                await self.refresh()
            }
        }
    }

    func addCategory() {
        startAction(scope: .transactionEditor) { generation in
            await self.runRequest(generation: generation) {
                guard let token = self.token else { return }
                let name = self.newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else {
                    throw ValidationError("Category name is required")
                }
                let category = try await self.api.createCategory(token: token, type: self.formType, name: name)
                try self.requireCurrentSession(token: token, generation: generation)
                try await self.loadCategories(token: token, generation: generation)
                self.formCategory = category.name
                self.newCategoryName = ""
            }
        }
    }

    func deleteCategory(_ category: Category) {
        startAction(scope: .transactionEditor) { generation in
            await self.runRequest(generation: generation) {
                guard let token = self.token else { return }
                guard !category.isDefault, category.id != 0 else {
                    throw ValidationError("Default categories cannot be deleted")
                }
                try await self.api.deleteCategory(token: token, id: category.id)
                try self.requireCurrentSession(token: token, generation: generation)
                try await self.loadCategories(token: token, generation: generation)
                if self.formCategory == category.name {
                    self.formCategory = self.formCategoryOptions.first?.name ?? (self.formType == TransactionType.income.rawValue ? "salary" : "food")
                }
            }
        }
    }

    func openExportDialog() {
        exportFrom = DateFormat.firstDayDate(of: month)
        exportTo = min(DateFormat.lastDayDate(of: month), Date())
        error = nil
        activeSheet = .exportTransactions
    }

    func exportTransactions() {
        startAction(scope: .export) { generation in
            await self.runRequest(generation: generation) {
                guard let token = self.token else { return }
                let from = DateFormat.isoDate.string(from: self.exportFrom)
                let to = DateFormat.isoDate.string(from: self.exportTo)
                guard self.exportFrom <= self.exportTo else {
                    throw ValidationError("The start date must be on or before the end date")
                }
                let csv = try await self.api.exportTransactionsCSV(token: token, from: from, to: to)
                try self.requireCurrentSession(token: token, generation: generation)
                let url = try ExportFileWriter.writeCSV(csv, fileName: "money-manager-\(from)-to-\(to).csv")
                try self.requireCurrentSession(token: token, generation: generation)
                self.exportShareItem = ExportShareItem(url: url)
                self.activeSheet = nil
            }
        }
    }

    func cancelExport() {
        cancelAction(scope: .export)
        activeSheet = nil
        error = nil
    }

    func importRevolutCSV(_ data: Data) {
        startAction(scope: .importCSV) { generation in
            self.isImporting = true
            defer { self.isImporting = false }
            await self.runRequest(generation: generation) {
                guard let token = self.token else { return }
                let result = try await self.api.importRevolutCSV(token: token, data: data)
                try self.requireCurrentSession(token: token, generation: generation)
                self.importResultMessage = "Imported \(result.imported). Skipped \(result.skipped) duplicates and \(result.ignored) unsupported rows."
                await self.refresh()
            }
        }
    }

    func clearForm() {
        editingID = nil
        formType = TransactionType.expense.rawValue
        formCategory = "food"
        formDescription = ""
        formAmount = ""
        formOccurredAt = Date()
        newCategoryName = ""
    }

    private func moveMonth(by offset: Int) {
        guard let date = DateFormat.monthKey.date(from: month), let nextDate = Calendar.current.date(byAdding: .month, value: offset, to: date) else {
            return
        }
        month = DateFormat.monthKey.string(from: nextDate)
        selectedExpenseCategory = nil
        summary = nil
        transactions = []
        dashboardLoadState = .loading
        Task { await refresh() }
    }

    private func loadCategories(token requestedToken: String, generation: Int) async throws {
        async let expense = api.getCategories(token: requestedToken, type: TransactionType.expense.rawValue)
        async let income = api.getCategories(token: requestedToken, type: TransactionType.income.rawValue)
        let (newExpenseCategories, newIncomeCategories) = try await (expense, income)
        try requireCurrentSession(token: requestedToken, generation: generation)
        expenseCategories = newExpenseCategories
        incomeCategories = newIncomeCategories
        if formCategory.isEmpty {
            formCategory = expenseCategories.first?.name ?? "food"
        }
    }

    private func performRefresh(token requestedToken: String, month requestedMonth: String, generation: Int) async {
        do {
            async let summaryResult = api.getSummary(token: requestedToken, month: requestedMonth)
            async let transactionsResult = api.getTransactions(token: requestedToken, month: requestedMonth)
            let (newSummary, newTransactions) = try await (summaryResult, transactionsResult)
            try Task.checkCancellation()
            guard
                refreshGeneration == generation,
                token == requestedToken,
                month == requestedMonth
            else { return }
            summary = newSummary
            transactions = newTransactions
            dashboardLoadState = .loaded
            error = nil
        } catch is CancellationError {
            return
        } catch let urlError as URLError where urlError.code == .cancelled {
            return
        } catch APIError.unauthorized {
            guard refreshGeneration == generation else { return }
            expireSession(message: APIError.unauthorized.localizedDescription)
        } catch {
            guard
                refreshGeneration == generation,
                token == requestedToken,
                month == requestedMonth
            else { return }
            dashboardLoadState = .failed(error.localizedDescription)
        }
    }

    private func validateTransactionForm() throws {
        let trimmedAmount = formAmount.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let amount = MoneyFormat.inputDecimal(from: trimmedAmount), amount > .zero else {
            throw ValidationError("Enter an amount greater than 0")
        }
        guard !formCategory.isEmpty else {
            throw ValidationError("Choose a category")
        }
        guard formDescription.count <= 200 else {
            throw ValidationError("Description must be 200 characters or fewer")
        }
    }

    private func startAction(
        scope: ActionScope? = nil,
        generation: Int? = nil,
        _ operation: @escaping @MainActor (Int) async -> Void
    ) {
        if let scope {
            cancelAction(scope: scope)
        }
        let id = UUID()
        let requestedGeneration = generation ?? sessionGeneration
        if let scope {
            scopedActionIDs[scope] = id
        }
        actionTasks[id] = Task { [weak self] in
            guard let self else { return }
            await operation(requestedGeneration)
            self.actionTasks[id] = nil
            if let scope, self.scopedActionIDs[scope] == id {
                self.scopedActionIDs[scope] = nil
            }
        }
    }

    private func cancelAction(scope: ActionScope) {
        guard let id = scopedActionIDs.removeValue(forKey: scope) else { return }
        actionTasks.removeValue(forKey: id)?.cancel()
    }

    private func runRequest(
        generation: Int,
        _ operation: @escaping () async throws -> Void
    ) async {
        guard generation == sessionGeneration else { return }
        let requestID = UUID()
        activeRequestIDs.insert(requestID)
        isLoading = true
        error = nil
        defer {
            activeRequestIDs.remove(requestID)
            isLoading = !activeRequestIDs.isEmpty
        }
        do {
            try Task.checkCancellation()
            try await operation()
            try Task.checkCancellation()
        } catch is CancellationError {
            return
        } catch let urlError as URLError where urlError.code == .cancelled {
            return
        } catch APIError.unauthorized {
            guard generation == sessionGeneration else { return }
            expireSession(message: APIError.unauthorized.localizedDescription)
        } catch {
            guard generation == sessionGeneration else { return }
            self.error = error.localizedDescription
        }
    }

    private func isCurrentSession(token requestedToken: String, generation: Int) -> Bool {
        sessionGeneration == generation && token == requestedToken
    }

    private func requireCurrentSession(token requestedToken: String, generation: Int) throws {
        guard isCurrentSession(token: requestedToken, generation: generation) else {
            throw CancellationError()
        }
        try Task.checkCancellation()
    }

    private func requireCurrentGeneration(_ generation: Int) throws {
        guard sessionGeneration == generation else { throw CancellationError() }
        try Task.checkCancellation()
    }

    private func expireSession(message: String) {
        resetSession(clearEmail: false)
        error = message
    }
}

struct ExportShareItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL
}

private struct ValidationError: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? { message }
}

enum ExportFileWriter {
    static func writeCSV(_ csv: String, fileName: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
