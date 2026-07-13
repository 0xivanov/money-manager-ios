import XCTest
@testable import MoneyManager

final class MoneyManagerTests: XCTestCase {
    func testDecodesBackendModels() throws {
        let transactionJSON = """
        {"id":7,"type":"expense","category":"food","description":"Lunch with Maya","amount":"12.50","currency":"EUR","occurred_at":"2026-05-15"}
        """.data(using: .utf8)!
        let transaction = try JSONDecoder().decode(Transaction.self, from: transactionJSON)
        XCTAssertEqual(transaction.id, 7)
        XCTAssertEqual(transaction.category, "food")
        XCTAssertEqual(transaction.description, "Lunch with Maya")
        XCTAssertEqual(transaction.occurredAt, "2026-05-15")

        let summaryJSON = """
        {"month":"2026-05","income":"2000.00","expense":"412.35","balance":"1587.65","currency":"EUR","transaction_count":3}
        """.data(using: .utf8)!
        let summary = try JSONDecoder().decode(TransactionSummary.self, from: summaryJSON)
        XCTAssertEqual(summary.transactionCount, 3)
        XCTAssertEqual(summary.balance, "1587.65")

        let categoryJSON = """
        {"id":2,"type":"expense","name":"transport","is_default":true}
        """.data(using: .utf8)!
        let category = try JSONDecoder().decode(Category.self, from: categoryJSON)
        XCTAssertTrue(category.isDefault)
    }

    func testAPIRequestBuildsExpectedQueries() throws {
        let api = MoneyManagerAPI(baseURL: URL(string: "http://localhost:8080")!)
        let request = try api.makeRequest(
            path: "/transactions",
            token: "abc",
            queryItems: [
                URLQueryItem(name: "month", value: "2026-05"),
                URLQueryItem(name: "type", value: "expense"),
                URLQueryItem(name: "category", value: "food")
            ]
        )

        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer abc")
        XCTAssertEqual(request.url?.scheme, "http")
        XCTAssertEqual(request.url?.host, "localhost")
        XCTAssertEqual(request.url?.path, "/transactions")
        XCTAssertTrue(request.url?.query?.contains("month=2026-05") == true)
        XCTAssertTrue(request.url?.query?.contains("type=expense") == true)
        XCTAssertTrue(request.url?.query?.contains("category=food") == true)
    }

    func testMoneyFormattingAndSignedAmounts() {
        let locale = Locale(identifier: "en_US")
        XCTAssertEqual(MoneyFormat.amount(Decimal(string: "12.5")!, locale: locale), "€12.50")
        XCTAssertEqual(MoneyFormat.signed(Decimal(string: "18")!, locale: locale), "+€18.00")
        XCTAssertEqual(MoneyFormat.signed(Decimal(string: "-4.2")!, locale: locale), "-€4.20")
        XCTAssertEqual(MoneyFormat.inputDecimal(from: "12,50", locale: Locale(identifier: "bg_BG")), Decimal(string: "12.5"))
        XCTAssertEqual(MoneyFormat.apiAmount(Decimal(string: "12.50")!), "12.5")
        XCTAssertNil(MoneyFormat.inputDecimal(from: "1.999", locale: locale))
        XCTAssertNil(MoneyFormat.inputDecimal(from: "1,999", locale: Locale(identifier: "bg_BG")))
        XCTAssertNil(MoneyFormat.inputDecimal(from: "1.2.3", locale: locale))
    }

    func testTransactionRequestEncodesDescription() throws {
        let request = TransactionRequest(
            type: "expense",
            category: "food",
            description: "Weekly groceries",
            amount: "42.10",
            occurredAt: "2026-07-11"
        )
        let data = try JSONEncoder().encode(request)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: String])
        XCTAssertEqual(object["description"], "Weekly groceries")
        XCTAssertEqual(object["occurred_at"], "2026-07-11")
    }

    @MainActor
    func testDerivedCategoryTotalsAndDayBuckets() {
        let store = MoneyManagerStore()
        store.transactions = [
            Transaction(id: 1, type: "expense", category: "food", amount: "12.50", currency: "EUR", occurredAt: "2026-05-15"),
            Transaction(id: 2, type: "expense", category: "food", amount: "7.50", currency: "EUR", occurredAt: "2026-05-15"),
            Transaction(id: 3, type: "income", category: "salary", amount: "100.00", currency: "EUR", occurredAt: "2026-05-15"),
            Transaction(id: 4, type: "expense", category: "transport", amount: "5.00", currency: "EUR", occurredAt: "2026-05-14")
        ]

        XCTAssertEqual(store.expenseCategoryTotals.first?.category, "food")
        XCTAssertEqual(store.expenseCategoryTotals.first?.amount, Decimal(string: "20.00"))
        XCTAssertEqual(store.transactionDayBuckets.count, 2)
        XCTAssertEqual(store.transactionDayBuckets.first?.balanceChange, Decimal(string: "80.00"))
    }

    @MainActor
    func testTransactionSearchAndCategoryFilters() {
        let store = MoneyManagerStore()
        store.transactions = [
            Transaction(id: 1, type: "expense", category: "food", description: "Weekly groceries", amount: "42.00", currency: "EUR", occurredAt: "2026-07-11"),
            Transaction(id: 2, type: "expense", category: "travel", description: "Train ticket", amount: "18.00", currency: "EUR", occurredAt: "2026-07-10"),
            Transaction(id: 3, type: "income", category: "salary", description: "July salary", amount: "3000.00", currency: "EUR", occurredAt: "2026-07-01")
        ]

        store.searchQuery = "train"
        XCTAssertEqual(store.transactionDayBuckets.flatMap(\.transactions).map(\.id), [2])

        store.searchQuery = ""
        store.updateFilterType("expense")
        store.updateFilterCategory("food")
        XCTAssertEqual(store.transactionDayBuckets.flatMap(\.transactions).map(\.id), [1])

        store.resetTransactionFilters()
        XCTAssertEqual(store.transactionDayBuckets.flatMap(\.transactions).count, 3)
    }

    @MainActor
    func testExportDefaultsToSelectedMonthEnd() {
        let store = MoneyManagerStore()
        store.month = "2026-05"
        store.openExportDialog()

        XCTAssertEqual(DateFormat.isoDate.string(from: store.exportFrom), "2026-05-01")
        XCTAssertEqual(DateFormat.isoDate.string(from: store.exportTo), "2026-05-31")
    }
}
