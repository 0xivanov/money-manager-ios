import Foundation

extension MoneyManagerStore {
    var canGoNextMonth: Bool {
        // Month keys use the sortable yyyy-MM format, so comparing the keys
        // avoids timezone and day-boundary differences between Date values.
        month < DateFormat.currentMonthKey()
    }

    var expenseCategoryTotals: [CategoryTotal] {
        transactions
            .filter {
                $0.type == TransactionType.expense.rawValue
                    && !$0.isInvestmentRelated
            }
            .reduce(into: [String: Decimal]()) { totals, transaction in
                totals[transaction.category, default: .zero] += MoneyFormat.decimal(from: transaction.amount)
            }
            .map { CategoryTotal(category: $0.key, amount: $0.value) }
            .filter { $0.amount > .zero }
            .sorted { $0.amount > $1.amount }
    }

    func monthlyInvestmentCashFlow(month: String, currency: String) -> Decimal {
        var matchedTransferIDs = Set<Int>()
        return growth.investmentTrades
            .filter {
                $0.currency.caseInsensitiveCompare(currency) == .orderedSame
                    && String($0.occurredAt.prefix(7)) == month
            }
            .reduce(.zero) { total, trade in
                let amount = MoneyFormat.decimal(from: trade.amount)
                let fees = MoneyFormat.decimal(from: trade.fees)

                switch trade.side.lowercased() {
                case "buy":
                    if let transfer = matchingInvestmentTransfer(
                        for: trade,
                        excluding: matchedTransferIDs
                    ) {
                        matchedTransferIDs.insert(transfer.id)
                        return total
                    }
                    return total + amount + fees
                case "sell":
                    return total - amount + fees
                default:
                    return total
                }
            }
    }

    private func matchingInvestmentTransfer(
        for trade: InvestmentTrade,
        excluding matchedIDs: Set<Int>
    ) -> Transaction? {
        guard trade.broker.caseInsensitiveCompare("revolut_x") == .orderedSame,
            let tradeDate = DateFormat.apiDate(trade.occurredAt)
        else { return nil }

        let tradeAmount = MoneyFormat.decimal(from: trade.amount)
        let tradeWithFees = tradeAmount + MoneyFormat.decimal(from: trade.fees)
        return transactions.first { transaction in
            guard !matchedIDs.contains(transaction.id),
                transaction.type == TransactionType.expense.rawValue,
                transaction.isInvestmentRelated,
                transaction.currency.caseInsensitiveCompare(trade.currency) == .orderedSame,
                let transferDate = DateFormat.apiDate(transaction.occurredAt),
                abs(transferDate.timeIntervalSince(tradeDate)) <= 3 * 24 * 60 * 60
            else { return false }

            let transferAmount = MoneyFormat.decimal(from: transaction.amount)
            guard transferAmount == tradeAmount || transferAmount == tradeWithFees else { return false }
            guard let scheduleID = transaction.investmentScheduleID else { return true }
            guard let schedule = growth.investmentSchedules.first(where: { $0.id == scheduleID }) else { return false }
            return schedule.broker.caseInsensitiveCompare(trade.broker) == .orderedSame
                && schedule.symbol.caseInsensitiveCompare(trade.symbol) == .orderedSame
        }
    }

    func balanceAfterInvestments(_ summary: TransactionSummary) -> Decimal {
        MoneyFormat.decimal(from: summary.balance)
            - monthlyInvestmentCashFlow(month: summary.month, currency: summary.currency)
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
        editingID != nil
            || formPurpose != "spending"
            || !formAmount.isEmpty
            || !formDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

    private func moveMonth(by offset: Int) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = DateFormat.monthKey.timeZone
        guard let date = DateFormat.monthKey.date(from: month), let nextDate = calendar.date(byAdding: .month, value: offset, to: date) else {
            return
        }
        month = DateFormat.monthKey.string(from: nextDate)
        selectedExpenseCategory = nil
        summary = nil
        transactions = []
        dashboardLoadState = .loading
        Task { await refresh() }
    }

    func loadCategories(token requestedToken: String, generation: Int) async throws {
        async let expense = api.getCategories(token: requestedToken, type: TransactionType.expense.rawValue)
        async let income = api.getCategories(token: requestedToken, type: TransactionType.income.rawValue)
        let (newExpenseCategories, newIncomeCategories) = try await (expense, income)
        try requireCurrentSession(token: requestedToken, generation: generation)
        expenseCategories = newExpenseCategories
        incomeCategories = newIncomeCategories
        if formCategory.isEmpty {
            formCategory = expenseCategories.first?.name ?? "groceries"
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
            scheduleOnDeviceClassification(
                for: newTransactions,
                token: requestedToken,
                generation: sessionGeneration,
                month: requestedMonth
            )
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

}
