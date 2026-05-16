import Foundation
import Observation

@MainActor
@Observable
final class MoneyManagerStore {
    private let api: MoneyManagerAPI
    private let tokenStore: TokenStore

    var token: String?
    var email = ""
    var password = ""
    var selectedTab: AppTab = .dashboard
    var activeSheet: AppSheet?
    var isRegisterMode = false
    var isLoading = false
    var error: String?
    var month = DateFormat.currentMonthKey()
    var filterType: String?
    var filterCategory: String?
    var summary: TransactionSummary?
    var transactions: [Transaction] = []
    var selectedExpenseCategory: String?
    var editingID: Int?
    var formType = TransactionType.expense.rawValue
    var formCategory = "food"
    var formAmount = ""
    var formOccurredAt = Date()
    var expenseCategories: [Category] = []
    var incomeCategories: [Category] = []
    var newCategoryName = ""
    var exportFrom = DateFormat.firstDayDate(of: DateFormat.currentMonthKey())
    var exportTo = Date()
    var exportShareItem: ExportShareItem?

    init(api: MoneyManagerAPI = MoneyManagerAPI(), tokenStore: TokenStore = TokenStore()) {
        self.api = api
        self.tokenStore = tokenStore
        self.token = tokenStore.getToken()
    }

    var isAuthenticated: Bool {
        token != nil
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

    var dayBuckets: [DayBucket] {
        filteredTransactions
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
        if let selectedExpenseCategory {
            result = result.filter { $0.type == TransactionType.expense.rawValue && $0.category == selectedExpenseCategory }
        }
        return result
    }

    func bootstrap() async {
        guard token != nil else { return }
        await runRequest {
            try await self.loadCategories()
            try await self.refreshDashboard()
        }
    }

    func submitAuth() {
        Task {
            await runRequest {
                let trimmedEmail = self.email.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedEmail.isEmpty, !self.password.isEmpty else {
                    throw ValidationError("Email and password are required")
                }
                let result = self.isRegisterMode
                    ? try await self.api.register(email: trimmedEmail, password: self.password)
                    : try await self.api.login(email: trimmedEmail, password: self.password)
                self.tokenStore.saveToken(result.token)
                self.token = result.token
                self.email = result.user.email
                self.password = ""
                try await self.loadCategories()
                try await self.refreshDashboard()
            }
        }
    }

    func logout() {
        tokenStore.clearToken()
        token = nil
        password = ""
        selectedTab = .dashboard
        activeSheet = nil
        summary = nil
        transactions = []
        selectedExpenseCategory = nil
        expenseCategories = []
        incomeCategories = []
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

    func refresh() {
        Task {
            await runRequest {
                try await self.refreshDashboard()
            }
        }
    }

    func selectExpenseCategory(_ category: String) {
        selectedExpenseCategory = selectedExpenseCategory == category ? nil : category
    }

    func clearSelectedExpenseCategory() {
        selectedExpenseCategory = nil
    }

    func updateFilterType(_ value: String?) {
        filterType = value
        filterCategory = nil
    }

    func openNewTransactionForm() {
        clearForm()
        activeSheet = .transactionEditor
    }

    func openPhysicalPurchaseForm() {
        clearForm()
        formType = TransactionType.expense.rawValue
        formCategory = "shopping"
        activeSheet = .transactionEditor
    }

    func editTransaction(_ transaction: Transaction) {
        editingID = transaction.id
        formType = transaction.type
        formCategory = transaction.category
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
        activeSheet = .transactionEditor
    }

    func saveTransaction() {
        Task {
            await runRequest {
                try self.validateTransactionForm()
                guard let token = self.token else { return }
                let request = TransactionRequest(
                    type: self.formType,
                    category: self.formCategory,
                    amount: self.formAmount.trimmingCharacters(in: .whitespacesAndNewlines),
                    occurredAt: DateFormat.isoDate.string(from: self.formOccurredAt)
                )
                if let editingID = self.editingID {
                    _ = try await self.api.updateTransaction(token: token, id: editingID, transaction: request)
                } else {
                    _ = try await self.api.createTransaction(token: token, transaction: request)
                }
                self.activeSheet = nil
                self.clearForm()
                try await self.refreshDashboard()
            }
        }
    }

    func deleteTransaction(_ id: Int) {
        Task {
            await runRequest {
                guard let token = self.token else { return }
                try await self.api.deleteTransaction(token: token, id: id)
                try await self.refreshDashboard()
            }
        }
    }

    func addCategory() {
        Task {
            await runRequest {
                guard let token = self.token else { return }
                let name = self.newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else {
                    throw ValidationError("Category name is required")
                }
                let category = try await self.api.createCategory(token: token, type: self.formType, name: name)
                try await self.loadCategories()
                self.formCategory = category.name
                self.newCategoryName = ""
                self.activeSheet = .transactionEditor
            }
        }
    }

    func deleteCategory(_ category: Category) {
        Task {
            await runRequest {
                guard let token = self.token else { return }
                guard !category.isDefault, category.id != 0 else {
                    throw ValidationError("Default categories cannot be deleted")
                }
                try await self.api.deleteCategory(token: token, id: category.id)
                try await self.loadCategories()
                if self.formCategory == category.name {
                    self.formCategory = self.formCategoryOptions.first?.name ?? (self.formType == TransactionType.income.rawValue ? "salary" : "food")
                }
            }
        }
    }

    func openExportDialog() {
        exportFrom = DateFormat.firstDayDate(of: month)
        exportTo = Date()
        error = nil
        activeSheet = .exportTransactions
    }

    func exportTransactions() {
        Task {
            await runRequest {
                guard let token = self.token else { return }
                let from = DateFormat.isoDate.string(from: self.exportFrom)
                let to = DateFormat.isoDate.string(from: self.exportTo)
                guard self.exportFrom <= self.exportTo else {
                    throw ValidationError("From date must be before or equal to to date")
                }
                let csv = try await self.api.exportTransactionsCSV(token: token, from: from, to: to)
                let url = try ExportFileWriter.writeCSV(csv, fileName: "money-manager-\(from)-to-\(to).csv")
                self.exportShareItem = ExportShareItem(url: url)
                self.activeSheet = nil
            }
        }
    }

    func clearForm() {
        editingID = nil
        formType = TransactionType.expense.rawValue
        formCategory = "food"
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
        refresh()
    }

    private func loadCategories() async throws {
        guard let token else { return }
        async let expense = api.getCategories(token: token, type: TransactionType.expense.rawValue)
        async let income = api.getCategories(token: token, type: TransactionType.income.rawValue)
        expenseCategories = try await expense
        incomeCategories = try await income
        if formCategory.isEmpty {
            formCategory = expenseCategories.first?.name ?? "food"
        }
    }

    private func refreshDashboard() async throws {
        guard let token else { return }
        async let summaryResult = api.getSummary(token: token, month: month)
        async let transactionsResult = api.getTransactions(token: token, month: month)
        summary = try await summaryResult
        transactions = try await transactionsResult
        error = nil
    }

    private func validateTransactionForm() throws {
        let trimmedAmount = formAmount.trimmingCharacters(in: .whitespacesAndNewlines)
        let amount = MoneyFormat.decimal(from: trimmedAmount)
        guard amount > .zero else {
            throw ValidationError("Enter an amount greater than 0")
        }
        guard !formCategory.isEmpty else {
            throw ValidationError("Choose a category")
        }
    }

    private func runRequest(_ operation: @escaping () async throws -> Void) async {
        isLoading = true
        error = nil
        do {
            try await operation()
        } catch APIError.unauthorized {
            tokenStore.clearToken()
            token = nil
            error = APIError.unauthorized.localizedDescription
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
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
