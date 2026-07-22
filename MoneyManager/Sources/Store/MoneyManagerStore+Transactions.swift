import Foundation

extension MoneyManagerStore {
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
        formExcludedFromBudget = transaction.excludedFromBudget ?? false
        formPurpose = transaction.purpose ?? "spending"
        formInvestmentScheduleID = transaction.investmentScheduleID
        activeSheet = .transactionEditor
    }

    func updateFormType(_ type: String) {
        if type == TransactionType.income.rawValue {
            setInvestmentTransfer(false)
        }
        formType = type
        let categories = type == TransactionType.income.rawValue ? incomeCategories : expenseCategories
        formCategory = categories.first?.name ?? (type == TransactionType.income.rawValue ? "salary" : "groceries")
    }

    func setInvestmentTransfer(_ enabled: Bool) {
        formPurpose = enabled ? "investment_transfer" : "spending"
        formInvestmentScheduleID = enabled ? suggestedInvestmentScheduleID : nil
        formExcludedFromBudget = enabled
        if enabled {
            formType = TransactionType.expense.rawValue
            formCategory = "investment_transfer"
        } else if formCategory == "investment_transfer" {
            formCategory = expenseCategories.first(where: { $0.name != "investment_transfer" })?.name ?? "groceries"
        }
    }

    var revolutXInvestmentSchedules: [InvestmentSchedule] {
        growth.investmentSchedules.filter {
            $0.broker.caseInsensitiveCompare("revolut_x") == .orderedSame && $0.status == "active"
        }
    }

    private var suggestedInvestmentScheduleID: Int? {
        let amount = MoneyFormat.inputDecimal(from: formAmount)
        return revolutXInvestmentSchedules.first {
            amount != nil && MoneyFormat.decimal(from: $0.amount) == amount
        }?.id ?? revolutXInvestmentSchedules.first?.id
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
                    occurredAt: DateFormat.isoDate.string(from: self.formOccurredAt),
                    excludedFromBudget: self.formExcludedFromBudget,
                    purpose: self.formPurpose,
                    investmentScheduleID: self.formInvestmentScheduleID
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
                    self.formCategory = self.formCategoryOptions.first?.name ?? (self.formType == TransactionType.income.rawValue ? "salary" : "groceries")
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
                self.importResultMessage = "Imported \(result.imported). Skipped \(result.skipped) duplicates and \(result.ignored) unsupported rows. Recognised merchants are categorized on this device; uncertain payments remain in Other for review."
                await self.refresh()
            }
        }
    }

    func scheduleOnDeviceClassification(
        for sourceTransactions: [Transaction],
        token requestedToken: String,
        generation: Int,
        month requestedMonth: String
    ) {
        categoryClassificationTask?.cancel()
        let candidates = Array(sourceTransactions.filter { transaction in
            Self.shouldRequestClarification(
                for: transaction,
                dismissedTransactionIDs: dismissedClarificationTransactionIDs
            )
        }.prefix(DeterministicTransactionClassifier.maxBatchSize))
        guard !candidates.isEmpty else {
            categoryClassificationTask = nil
            return
        }

        categoryClassificationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let assessments = DeterministicTransactionClassifier.classify(
                    candidates,
                    allowedCategoriesByType: [
                        TransactionType.expense.rawValue: self.expenseCategories.map(\.name),
                        TransactionType.income.rawValue: self.incomeCategories.map(\.name),
                    ]
                )
                try self.requireCurrentSession(token: requestedToken, generation: generation)
                let transactionsByID = Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, $0) })
                for assessment in assessments {
                    try Task.checkCancellation()
                    guard let transaction = transactionsByID[assessment.transactionID] else { continue }
                    guard let category = assessment.category else { continue }
                    let request = TransactionRequest(
                        type: transaction.type,
                        category: category,
                        description: transaction.description,
                        amount: transaction.amount,
                        currency: transaction.currency,
                        occurredAt: DateFormat.dateOnly(transaction.occurredAt),
                        excludedFromBudget: transaction.excludedFromBudget ?? false,
                        purpose: transaction.purpose ?? "spending",
                        investmentScheduleID: transaction.investmentScheduleID
                    )
                    let updated = try await self.api.updateTransaction(
                        token: requestedToken,
                        id: transaction.id,
                        transaction: request
                    )
                    try self.requireCurrentSession(token: requestedToken, generation: generation)
                    guard self.month == requestedMonth,
                        let index = self.transactions.firstIndex(where: { $0.id == updated.id }),
                        self.transactions[index].category.caseInsensitiveCompare("other") == .orderedSame
                    else { continue }
                    self.transactions[index] = updated
                }
            } catch APIError.unauthorized {
                guard self.isCurrentSession(token: requestedToken, generation: generation) else { return }
                self.expireSession(message: APIError.unauthorized.localizedDescription)
                return
            } catch is CancellationError {
                return
            } catch let urlError as URLError where urlError.code == .cancelled {
                return
            } catch {
                // Classification is best effort. Failed rows remain Other until the next refresh.
            }
            if self.isCurrentSession(token: requestedToken, generation: generation) {
                self.categoryClassificationTask = nil
            }
        }
    }

    func submitTransactionClarification(_ note: String) async {
        guard let clarification = activeTransactionClarification,
            let token,
            !isSavingTransactionClarification
        else { return }
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNote.isEmpty else { return }
        isSavingTransactionClarification = true
        error = nil
        defer { isSavingTransactionClarification = false }

        let transaction = clarification.transaction
        let description = Self.descriptionWithUserClarification(
            bankDescription: transaction.description,
            userNote: trimmedNote
        )
        let enriched = Transaction(
            id: transaction.id,
            type: transaction.type,
            category: transaction.category,
            description: description,
            amount: transaction.amount,
            currency: transaction.currency,
            occurredAt: transaction.occurredAt,
            source: transaction.source,
            status: transaction.status,
            excludedFromBudget: transaction.excludedFromBudget,
            scheduleOccurrenceID: transaction.scheduleOccurrenceID,
            purpose: transaction.purpose,
            investmentScheduleID: transaction.investmentScheduleID
        )

        do {
            let assessment = DeterministicTransactionClassifier.classify(
                [enriched],
                allowedCategoriesByType: [
                    TransactionType.expense.rawValue: expenseCategories.map(\.name),
                    TransactionType.income.rawValue: incomeCategories.map(\.name),
                ]
            ).first
            let request = TransactionRequest(
                type: enriched.type,
                category: assessment?.category ?? "other",
                description: description,
                amount: enriched.amount,
                currency: enriched.currency,
                occurredAt: DateFormat.dateOnly(enriched.occurredAt),
                excludedFromBudget: enriched.excludedFromBudget ?? false,
                purpose: enriched.purpose ?? "spending",
                investmentScheduleID: enriched.investmentScheduleID
            )
            let updated = try await api.updateTransaction(
                token: token,
                id: enriched.id,
                transaction: request
            )
            if let index = transactions.firstIndex(where: { $0.id == updated.id }) {
                transactions[index] = updated
            }
            rememberDismissedTransactionClarification(id: enriched.id)
            advanceTransactionClarificationQueue()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func skipTransactionClarification() {
        if let id = activeTransactionClarification?.id {
            rememberDismissedTransactionClarification(id: id)
        }
        advanceTransactionClarificationQueue()
    }

    var uncategorizedReviewCount: Int {
        transactions.filter {
            Self.shouldRequestClarification(
                for: $0,
                dismissedTransactionIDs: dismissedClarificationTransactionIDs
            )
        }.count
    }

    func beginUncategorizedReview() {
        activeTransactionClarification = nil
        queuedTransactionClarifications = []
        transactions.filter {
            Self.shouldRequestClarification(
                for: $0,
                dismissedTransactionIDs: dismissedClarificationTransactionIDs
            )
        }
        .prefix(DeterministicTransactionClassifier.maxBatchSize)
        .forEach {
            enqueueTransactionClarification(
                transaction: $0,
                question: "What was this payment for?"
            )
        }
    }

    nonisolated static func shouldRequestClarification(
        for transaction: Transaction,
        dismissedTransactionIDs: Set<Int>
    ) -> Bool {
        guard transaction.category.caseInsensitiveCompare("other") == .orderedSame,
            transaction.source == "import" || transaction.source == "open_banking",
            !transaction.isInvestmentRelated,
            !dismissedTransactionIDs.contains(transaction.id)
        else { return false }

        return transaction.description?.range(
            of: "User clarification:",
            options: [.caseInsensitive, .diacriticInsensitive]
        ) == nil
    }

    nonisolated static func descriptionWithUserClarification(
        bankDescription: String?,
        userNote: String
    ) -> String {
        let original = bankDescription?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let note = String(userNote.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120))
        return original.isEmpty
            ? "User clarification: \(note)"
            : "\(original)\nUser clarification: \(note)"
    }

    private func enqueueTransactionClarification(
        transaction: Transaction,
        question: String?
    ) {
        let clarification = TransactionClarification(
            transaction: transaction,
            question: question ?? "What was this payment for?"
        )
        guard activeTransactionClarification?.id != clarification.id,
            !queuedTransactionClarifications.contains(where: { $0.id == clarification.id }),
            !dismissedClarificationTransactionIDs.contains(clarification.id)
        else { return }
        if activeTransactionClarification == nil {
            activeTransactionClarification = clarification
        } else {
            queuedTransactionClarifications.append(clarification)
        }
    }

    private func advanceTransactionClarificationQueue() {
        activeTransactionClarification = queuedTransactionClarifications.isEmpty
            ? nil
            : queuedTransactionClarifications.removeFirst()
    }

    func clearForm() {
        editingID = nil
        formType = TransactionType.expense.rawValue
        formCategory = "groceries"
        formDescription = ""
        formAmount = ""
        formOccurredAt = Date()
        formExcludedFromBudget = false
        formPurpose = "spending"
        formInvestmentScheduleID = nil
        newCategoryName = ""
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
}
