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
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["description"] as? String, "Weekly groceries")
        XCTAssertEqual(object["occurred_at"] as? String, "2026-07-11")
        XCTAssertEqual(object["excluded_from_budget"] as? Bool, false)
    }

    func testDecodesPlanningAndInvestmentContracts() throws {
        let schedule = try JSONDecoder().decode(TransactionSchedule.self, from: Data(#"{"id":1,"type":"expense","name":"Rent","category":"housing","description":"","amount":"1200.00","currency":"EUR","frequency":"monthly","frequency_interval":1,"start_date":"2026-08-01","day_of_month":1,"timezone":"Europe/Sofia","auto_post":true,"status":"active","next_occurrence_date":"2026-08-01"}"#.utf8))
        XCTAssertEqual(schedule.nextOccurrenceDate, "2026-08-01")
        XCTAssertTrue(schedule.autoPost)

        let budget = try JSONDecoder().decode(Budget.self, from: Data(#"{"id":2,"name":"Food","category":"food","amount":"500.00","currency":"EUR","period":"monthly","warning_threshold":80,"status":"active","period_start":"2026-07-01","period_end":"2026-07-31","spent_amount":"410.00","remaining_amount":"90.00","progress_percent":"82.0","alert_level":"approaching"}"#.utf8))
        XCTAssertEqual(budget.alertLevel, "approaching")
        XCTAssertEqual(budget.progressPercent, "82.0")

        let portfolio = try JSONDecoder().decode(InvestmentPortfolio.self, from: Data(#"{"positions":[],"invested_amount":"0.00","current_value":"0.00","unrealized_profit":"0.00","realized_profit":"0.00","currency":"EUR","missing_prices":0}"#.utf8))
        XCTAssertEqual(portfolio, .empty)
    }

    func testInvestmentAmountContractAndPortfolioHistory() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        var api = MoneyManagerAPI(baseURL: URL(string: "https://example.test")!)
        api.session = URLSession(configuration: configuration)

        let tradeRequest = InvestmentTradeRequest(
            assetType: "crypto",
            symbol: "BTC",
            assetName: "Bitcoin",
            broker: "revolut_x",
            side: "buy",
            amount: "125.50",
            fees: "1.25",
            currency: "EUR",
            occurredAt: "2026-07-14T18:30:00Z",
            notes: "Monthly buy"
        )
        let encodedTradeRequest = try JSONEncoder().encode(tradeRequest)
        let encodedObject = try XCTUnwrap(JSONSerialization.jsonObject(with: encodedTradeRequest) as? [String: Any])
        XCTAssertEqual(encodedObject["amount"] as? String, "125.50")
        XCTAssertEqual(encodedObject["occurred_at"] as? String, "2026-07-14T18:30:00Z")
        XCTAssertNil(encodedObject["quantity"])
        XCTAssertNil(encodedObject["price_per_unit"])

        MockURLProtocol.requestHandler = { request in
            switch request.url?.path {
            case "/investments/trades":
                XCTAssertEqual(request.httpMethod, "POST")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token")
                return try MockURLProtocol.response(
                    request: request,
                    json: #"{"id":7,"asset_type":"crypto","symbol":"BTC","asset_name":"Bitcoin","broker":"revolut_x","side":"buy","amount":"125.50","quantity":"0.00155","price_per_unit":"80967.74","fees":"1.25","currency":"EUR","occurred_at":"2026-07-14T18:30:00Z","notes":"Monthly buy","price_provider":"kraken","price_as_of":"2026-07-14T18:30:00Z"}"#
                )
            case "/investments/portfolio/history":
                let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
                XCTAssertEqual(components.queryItems?.first(where: { $0.name == "range" })?.value, "1y")
                return try MockURLProtocol.response(
                    request: request,
                    json: #"{"points":[{"as_of":"2026-07-01T00:00:00Z","value":"100.00","invested_amount":"90.00"},{"as_of":"2026-07-14T18:30:00.123Z","value":"130.00","invested_amount":"125.50"}],"currency":"EUR","range":"1y","unsupported_positions":2}"#
                )
            default:
                throw URLError(.badURL)
            }
        }
        defer { MockURLProtocol.requestHandler = nil }

        let trade = try await api.createInvestmentTrade(token: "token", request: tradeRequest)
        XCTAssertEqual(trade.amount, "125.50")
        XCTAssertEqual(trade.quantity, "0.00155")
        XCTAssertEqual(trade.priceProvider, "kraken")

        let history = try await api.getInvestmentPortfolioHistory(token: "token", range: "1y")
        XCTAssertEqual(history.points.count, 2)
        XCTAssertEqual(history.unsupportedPositions, 2)
        XCTAssertNotNil(history.points.last?.date)
    }

    func testInvestmentAssetCatalogOnlyEnablesBTCAndETH() {
        XCTAssertEqual(InvestmentAssetCatalog.tradeEnabled.map(\.symbol), ["BTC", "ETH"])
        XCTAssertTrue(InvestmentAssetCatalog.all.filter { $0.type == .stock }.allSatisfy { !$0.isTradeEnabled })
        XCTAssertTrue(InvestmentAssetCatalog.hasAutomaticPricing(assetType: "crypto", symbol: "btc"))
        XCTAssertFalse(InvestmentAssetCatalog.hasAutomaticPricing(assetType: "stock", symbol: "AAPL"))
    }

    @MainActor
    func testInvestmentLoadKeepsLedgerWhenLivePricingFails() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        var api = MoneyManagerAPI(baseURL: URL(string: "https://example.test")!)
        api.session = URLSession(configuration: configuration)

        MockURLProtocol.requestHandler = { request in
            switch request.url?.path {
            case "/investments/portfolio":
                return try MockURLProtocol.response(
                    request: request,
                    json: #"{"error":"Crypto pricing is temporarily unavailable"}"#,
                    statusCode: 503
                )
            case "/investments/trades":
                return try MockURLProtocol.response(
                    request: request,
                    json: #"[{"id":7,"asset_type":"crypto","symbol":"BTC","asset_name":"Bitcoin","broker":"revolut_x","side":"buy","amount":"125.50","quantity":"0.00155","price_per_unit":"80967.74","fees":"1.25","currency":"EUR","occurred_at":"2026-07-14T18:30:00Z","notes":"Monthly buy","price_provider":"kraken","price_as_of":"2026-07-14T18:30:00Z"}]"#
                )
            case "/investment-schedules":
                return try MockURLProtocol.response(request: request, json: "[]")
            case "/investments/portfolio/history":
                return try MockURLProtocol.response(
                    request: request,
                    json: #"{"points":[],"currency":"EUR","range":"1y","unsupported_positions":0}"#
                )
            default:
                throw URLError(.badURL)
            }
        }
        defer { MockURLProtocol.requestHandler = nil }

        let store = GrowthStore(api: api)
        await store.loadInvestments(token: "token")

        XCTAssertEqual(store.investmentTrades.map(\.id), [7])
        XCTAssertEqual(store.investmentSchedules, [])
        XCTAssertEqual(store.portfolio, .empty)
        XCTAssertEqual(store.portfolioHistory, .empty)
        XCTAssertEqual(store.error, "Crypto pricing is temporarily unavailable")
        XCTAssertNil(store.investmentHistoryError)
    }

    func testDecodesOpenBankingContractsAndProviderData() throws {
        let institutionJSON = """
        {
          "name":"Revolut","country":"BG","logo":"https://example.com/revolut.svg",
          "psu_types":["personal"],"auth_methods":[{"name":"redirect","title":"Mobile app","psu_type":"personal","approach":"REDIRECT","hidden_method":false}],
          "maximum_consent_validity":180,"beta":false,"bic":"REVOBGSF"
        }
        """.data(using: .utf8)!
        let institution = try JSONDecoder().decode(OpenBankingInstitution.self, from: institutionJSON)
        XCTAssertEqual(institution.id, "BG:Revolut")
        XCTAssertEqual(institution.maximumConsentValidity, 180)

        let connectionJSON = """
        {"id":4,"institution_name":"Revolut","country":"BG","psu_type":"personal","status":"AUTHORIZED","valid_until":"2026-10-11T00:00:00Z","account_count":2,"created_at":"2026-07-13T10:00:00Z","updated_at":"2026-07-13T10:00:00Z"}
        """.data(using: .utf8)!
        let connection = try JSONDecoder().decode(OpenBankingConnection.self, from: connectionJSON)
        XCTAssertFalse(connection.needsAttention)
        XCTAssertEqual(connection.accountCount, 2)

        let accountJSON = """
        {"id":8,"connection_id":4,"institution_name":"Revolut","country":"BG","name":"Ivan Ivanov","details":"Everyday","cash_account_type":"CACC","product":"Current","currency":"EUR","display_identifier":"•••• 0123","identification_hash":"hash","can_fetch_data":true}
        """.data(using: .utf8)!
        let account = try JSONDecoder().decode(OpenBankingAccount.self, from: accountJSON)
        XCTAssertEqual(account.displayName, "Everyday")
        XCTAssertTrue(account.canFetchData)

        let balancesJSON = """
        {"balances":[{"name":"Available","balance_amount":{"currency":"EUR","amount":"900.00"},"balance_type":"CLAV"},{"name":"Booked","balance_amount":{"currency":"EUR","amount":"880.25"},"balance_type":"CLBD"}]}
        """.data(using: .utf8)!
        let balances = try JSONDecoder().decode(OpenBankingBalanceResponse.self, from: balancesJSON)
        XCTAssertEqual(balances.preferredBalance?.balanceAmount.decimal, Decimal(string: "880.25"))

        let transactionsJSON = """
        {"continuation_key":"next","transactions":[{"transaction_id":"tx-1","status":"BOOK","booking_date":"2026-07-12","credit_debit_indicator":"DBIT","creditor":{"name":"Fresh Market"},"remittance_information":["Weekly groceries"],"transaction_amount":{"currency":"EUR","amount":"42.80"}}]}
        """.data(using: .utf8)!
        let transactions = try JSONDecoder().decode(OpenBankingTransactionResponse.self, from: transactionsJSON)
        let transaction = try XCTUnwrap(transactions.transactions.first)
        XCTAssertEqual(transaction.title, "Fresh Market")
        XCTAssertEqual(transaction.signedAmount, Decimal(string: "-42.80"))
        XCTAssertEqual(transaction.detail, "Weekly groceries")

        let syncJSON = Data(#"{"fetched":4,"imported":2,"updated":1,"unchanged":1,"ignored":0,"notifications":1}"#.utf8)
        let sync = try JSONDecoder().decode(OpenBankingSyncResult.self, from: syncJSON)
        XCTAssertEqual(sync.imported, 2)
        XCTAssertEqual(sync.notifications, 1)
    }

    @MainActor
    func testHandlesOpenBankingDeepLinkCallback() throws {
        let store = MoneyManagerStore()
        let url = try XCTUnwrap(URL(string: "moneymanager://open-banking?status=connected&connection_id=27"))
        store.handleOpenBankingCallback(url)

        XCTAssertEqual(store.openBankingCallbackState, .connected(connectionID: 27))
        XCTAssertEqual(store.selectedTab, .profile)
        XCTAssertNil(store.openBankingError)

        let failedURL = try XCTUnwrap(URL(string: "moneymanager://open-banking?status=failed&error=session_exchange_failed"))
        store.handleOpenBankingCallback(failedURL)
        XCTAssertEqual(store.openBankingCallbackState, .failed("Bank connection failed: session exchange failed."))
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
    func testPortfolioInvestmentSpendingAdjustsDashboardBalance() {
        let store = MoneyManagerStore()
        store.growth.portfolio = InvestmentPortfolio(
            positions: [],
            investedAmount: "250.00",
            currentValue: "271.89",
            unrealizedProfit: "21.89",
            realizedProfit: "0.00",
            currency: "EUR",
            missingPrices: 0
        )
        let summary = TransactionSummary(
            month: "2026-07",
            income: "2000.00",
            expense: "500.00",
            balance: "1500.00",
            currency: "EUR",
            transactionCount: 4
        )

        XCTAssertEqual(store.investmentSpending(currency: "EUR"), Decimal(string: "250.00"))
        XCTAssertEqual(store.balanceIncludingInvestments(summary), Decimal(string: "1250.00"))
        XCTAssertEqual(store.investmentSpending(currency: "USD"), .zero)
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

private final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let requestHandler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try requestHandler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    static func response(
        request: URLRequest,
        json: String,
        statusCode: Int = 200
    ) throws -> (HTTPURLResponse, Data) {
        let url = try XCTUnwrap(request.url)
        let response = try XCTUnwrap(HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        ))
        return (response, Data(json.utf8))
    }
}
