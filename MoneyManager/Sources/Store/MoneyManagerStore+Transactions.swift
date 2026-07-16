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
        activeSheet = .transactionEditor
    }

    func updateFormType(_ type: String) {
        formType = type
        let categories = type == TransactionType.income.rawValue ? incomeCategories : expenseCategories
        formCategory = categories.first?.name ?? (type == TransactionType.income.rawValue ? "salary" : "groceries")
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
                    let original = self.transactions.first { $0.id == editingID }
                    _ = try await self.api.updateTransaction(token: token, id: editingID, transaction: request)
                    if let original,
                        original.category.caseInsensitiveCompare(request.category) != .orderedSame,
                        original.source == "import" || original.source == "open_banking"
                    {
                        OnDeviceTransactionClassifier.shared.rememberCorrection(
                            description: request.description ?? original.description ?? "",
                            transactionType: request.type,
                            category: request.category
                        )
                    }
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
                let annotation = try RevolutCSVCategoryAnnotator.annotate(data)
                let result = try await self.api.importRevolutCSV(token: token, data: annotation.data)
                try self.requireCurrentSession(token: token, generation: generation)
                let classificationMessage = annotation.classified > 0
                    ? " Categorized \(annotation.classified) on this device."
                    : ""
                self.importResultMessage = "Imported \(result.imported). Skipped \(result.skipped) duplicates and \(result.ignored) unsupported rows.\(classificationMessage)"
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
        let classifier = OnDeviceTransactionClassifier.shared
        let candidates = sourceTransactions.compactMap { transaction -> Transaction? in
            guard transaction.category.caseInsensitiveCompare("other") == .orderedSame,
                transaction.source == "import" || transaction.source == "open_banking",
                transaction.description?.isEmpty == false
            else { return nil }
            return transaction
        }
        guard !candidates.isEmpty else {
            categoryClassificationTask = nil
            return
        }

        categoryClassificationTask = Task { [weak self] in
            guard let self else { return }
            for transaction in candidates {
                do {
                    try Task.checkCancellation()
                    try self.requireCurrentSession(token: requestedToken, generation: generation)
                    guard let description = transaction.description else { continue }
                    let prediction: TransactionCategoryPrediction?
                    if let localPrediction = classifier.predict(
                        description: description,
                        transactionType: transaction.type
                    ) {
                        prediction = localPrediction
                    } else if GemmaModelManager.shared.isModelInstalled,
                        GemmaModelManager.shared.isClassificationEnabled
                    {
                        let categories = transaction.type == TransactionType.income.rawValue
                            ? self.incomeCategories.map(\.name)
                            : self.expenseCategories.map(\.name)
                        prediction = try await GemmaOnDeviceService.shared.classify(
                            description: description,
                            transactionType: transaction.type,
                            allowedCategories: categories
                        )
                    } else {
                        prediction = nil
                    }
                    guard let prediction, prediction.category != "other" else { continue }
                    let request = TransactionRequest(
                        type: transaction.type,
                        category: prediction.category,
                        description: transaction.description,
                        amount: transaction.amount,
                        currency: transaction.currency,
                        occurredAt: DateFormat.dateOnly(transaction.occurredAt),
                        excludedFromBudget: transaction.excludedFromBudget ?? false
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
                } catch APIError.unauthorized {
                    guard self.isCurrentSession(token: requestedToken, generation: generation) else { return }
                    self.expireSession(message: APIError.unauthorized.localizedDescription)
                    return
                } catch is CancellationError {
                    return
                } catch let urlError as URLError where urlError.code == .cancelled {
                    return
                } catch {
                    // Classification is best effort. Uncertain or rejected rows remain Other.
                    continue
                }
            }
            if self.isCurrentSession(token: requestedToken, generation: generation) {
                self.categoryClassificationTask = nil
            }
        }
    }

    func clearForm() {
        editingID = nil
        formType = TransactionType.expense.rawValue
        formCategory = "groceries"
        formDescription = ""
        formAmount = ""
        formOccurredAt = Date()
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
