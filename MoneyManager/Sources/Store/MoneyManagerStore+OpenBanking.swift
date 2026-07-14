import Foundation

extension MoneyManagerStore {
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
            let shouldReload =
                openBankingReloadRequested
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
            let syncResult = try await api.syncOpenBankingAccount(
                token: requestedToken,
                accountID: accountID
            )
            try requireCurrentSession(token: requestedToken, generation: generation)
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
            if syncResult.imported > 0 || syncResult.updated > 0 {
                await refresh()
            }
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
            let removedAccountIDs =
                openBankingAccounts
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

}
