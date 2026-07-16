import Foundation

extension MoneyManagerStore {
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
                let result =
                    self.isRegisterMode
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
        if let token {
            Task { await growth.unregisterPushDevice(token: token) }
        }
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
        categoryClassificationTask?.cancel()
        categoryClassificationTask = nil
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
        growth.reset()
        clearForm()
    }

    func toggleAuthMode() {
        isRegisterMode.toggle()
        error = nil
    }

    func handlePushEvent(_ eventType: String) {
        switch eventType {
        case "bank_spending", "scheduled_transaction_posted", "scheduled_transaction_due":
            selectedTab = .transactions
        case "investment_reminder":
            selectedTab = .investments
        case "budget_alert":
            selectedTab = .dashboard
        default:
            break
        }
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

    func isCurrentSession(token requestedToken: String, generation: Int) -> Bool {
        sessionGeneration == generation && token == requestedToken
    }

    func requireCurrentSession(token requestedToken: String, generation: Int) throws {
        guard isCurrentSession(token: requestedToken, generation: generation) else {
            throw CancellationError()
        }
        try Task.checkCancellation()
    }

    func requireCurrentGeneration(_ generation: Int) throws {
        guard sessionGeneration == generation else { throw CancellationError() }
        try Task.checkCancellation()
    }

    func expireSession(message: String) {
        resetSession(clearEmail: false)
        error = message
    }
}
