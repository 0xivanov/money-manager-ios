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

    func testInvestmentPriceTimestampFormattingUsesLatestPosition() throws {
        let earlier = "2026-07-15T10:00:00Z"
        let later = "2026-07-15T12:00:00Z"
        let positions = [
            investmentPosition(priceAsOf: earlier),
            investmentPosition(priceAsOf: later),
            investmentPosition(priceAsOf: nil),
        ]

        XCTAssertEqual(
            InvestmentPriceTimestampFormat.latestUpdate(in: positions),
            DateFormat.apiDateTime(later)
        )

        let now = try XCTUnwrap(DateFormat.apiDateTime("2026-07-15T12:10:00Z"))
        XCTAssertEqual(
            InvestmentPriceTimestampFormat.relativeElapsed(
                since: try XCTUnwrap(DateFormat.apiDateTime("2026-07-15T12:09:40Z")),
                now: now
            ),
            "just now"
        )
        XCTAssertEqual(
            InvestmentPriceTimestampFormat.relativeElapsed(
                since: try XCTUnwrap(DateFormat.apiDateTime("2026-07-15T12:08:00Z")),
                now: now
            ),
            "2 minutes ago"
        )
    }

    @MainActor
    func testAppPreferencesDefaultAndPersist() throws {
        let suiteName = "MoneyManagerTests.\(UUID().uuidString)"
        let preferences = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { preferences.removePersistentDomain(forName: suiteName) }

        let initialStore = MoneyManagerStore(preferences: preferences)
        XCTAssertTrue(initialStore.hidePortfolioBalances)
        XCTAssertEqual(initialStore.appAppearance, .system)

        initialStore.hidePortfolioBalances = false
        initialStore.appAppearance = .dark

        let restoredStore = MoneyManagerStore(preferences: preferences)
        XCTAssertFalse(restoredStore.hidePortfolioBalances)
        XCTAssertEqual(restoredStore.appAppearance, .dark)
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

    func testCategoryPresentationForDetailedFoodCategories() {
        XCTAssertEqual(categorySymbol("beauty"), "scissors")
        XCTAssertEqual(categorySymbol("groceries"), "cart.fill")
        XCTAssertEqual(categoryTitle("dining_out"), "Dining Out")
    }

    func testQwenCategoryAssessmentsKeepConfidenceAndRequestClarification() {
        let assessments = OnDeviceAIService.parseCategoryAssessments(
            #"{"assessments":[{"transaction_id":41,"category":"going out","confidence":0.92,"needs_clarification":false,"clarification_question":null},{"transaction_id":42,"category":"groceries","confidence":0.52,"needs_clarification":true,"clarification_question":"Was this a supermarket purchase?"}]}"#,
            transactionIDs: [41, 42, 43],
            allowedCategoriesByTransactionID: [
                41: Set(["groceries", "dining_out", "going_out", "other"]),
                42: Set(["groceries", "dining_out", "going_out", "other"]),
                43: Set(["salary", "other"]),
            ]
        )

        XCTAssertEqual(assessments[0].category, "going_out")
        XCTAssertFalse(assessments[0].needsClarification)
        XCTAssertNil(assessments[1].category)
        XCTAssertTrue(assessments[1].needsClarification)
        XCTAssertEqual(assessments[1].clarificationQuestion, "Was this a supermarket purchase?")
        XCTAssertEqual(assessments[2].transactionID, 43)
        XCTAssertTrue(assessments[2].needsClarification)
    }

    func testQwenParsesConfirmedFinancialActionProposals() throws {
        let now = try XCTUnwrap(DateFormat.apiDateTime("2026-07-18T12:00:00Z"))
        let schedule = OnDeviceAIService.parseFinancialActionResponse(
            #"{"action":"create_transaction_schedule","message":"Create monthly rent","schedule":{"type":"expense","name":"Rent","category":"housing","description":"Home rent","amount":"1200","frequency":"monthly","frequency_interval":1,"start_date":"2026-08-01","auto_post":true}}"#,
            expenseCategories: Set(["housing", "other"]),
            incomeCategories: Set(["salary", "other"]),
            currency: "EUR",
            now: now
        )
        XCTAssertEqual(
            schedule.proposal,
            .transactionSchedule(AITransactionScheduleDraft(
                type: "expense",
                name: "Rent",
                category: "housing",
                description: "Home rent",
                amount: "1200",
                currency: "EUR",
                frequency: "monthly",
                frequencyInterval: 1,
                startDate: "2026-08-01",
                autoPost: true
            ))
        )

        let investment = OnDeviceAIService.parseFinancialActionResponse(
            #"{"action":"create_investment_trade","message":"Record BTC buy","investment":{"symbol":"BTC","broker":"manual","side":"buy","amount":"100","fees":"1","occurred_at":"2026-07-18T10:00:00Z","notes":"AI entry"}}"#,
            expenseCategories: [],
            incomeCategories: [],
            currency: "EUR",
            now: now
        )
        XCTAssertEqual(
            investment.proposal,
            .investmentTrade(AIInvestmentTradeDraft(
                assetType: "crypto",
                symbol: "BTC",
                assetName: "Bitcoin",
                broker: "manual",
                side: "buy",
                amount: "100",
                fees: "1",
                currency: "EUR",
                occurredAt: "2026-07-18T10:00:00Z",
                notes: "AI entry"
            ))
        )
    }

    func testAIInsightPromptIncludesOnlyScheduledCashFlowFromSummaryMonth() {
        let summary = TransactionSummary(
            month: "2026-07",
            income: "3200.00",
            expense: "900.00",
            balance: "2300.00",
            currency: "EUR",
            transactionCount: 12
        )
        let scheduled = [
            TransactionScheduleOccurrence(
                id: 1,
                scheduleID: 10,
                scheduledFor: "2026-07-31",
                status: "planned",
                type: "income",
                name: "Salary",
                category: "salary",
                description: "",
                amount: "3000.00",
                currency: "EUR",
                autoPost: false,
                transactionID: nil
            ),
            TransactionScheduleOccurrence(
                id: 2,
                scheduleID: 11,
                scheduledFor: "2026-08-02",
                status: "planned",
                type: "expense",
                name: "Rent",
                category: "housing",
                description: "",
                amount: "1200.00",
                currency: "EUR",
                autoPost: true,
                transactionID: nil
            ),
            TransactionScheduleOccurrence(
                id: 3,
                scheduleID: 12,
                scheduledFor: "2026-07-10",
                status: "posted",
                type: "expense",
                name: "Already posted",
                category: "other",
                description: "",
                amount: "50.00",
                currency: "EUR",
                autoPost: true,
                transactionID: 99
            )
        ]

        let payment = Transaction(
            id: 77,
            type: "expense",
            category: "dining_out",
            description: "DINNER AT LOCAL RESTAURANT",
            amount: "52.40",
            currency: "EUR",
            occurredAt: "2026-07-16T20:15:00Z",
            source: "open_banking",
            status: "booked",
            excludedFromBudget: true,
            scheduleOccurrenceID: 99
        )
        let prompt = AIInsightPrompt.make(
            summary: summary,
            transactions: [payment],
            budgets: [],
            scheduledOccurrences: scheduled,
            portfolio: .empty
        )

        XCTAssertTrue(prompt.contains("COMPLETE_FINANCIAL_DATA_JSON"))
        XCTAssertTrue(prompt.contains("DINNER AT LOCAL RESTAURANT"))
        XCTAssertTrue(prompt.contains(#""excluded_from_budget":true"#))
        XCTAssertTrue(prompt.contains(#""schedule_occurrence_id":99"#))
        XCTAssertTrue(prompt.contains(#""source":"open_banking""#))
        XCTAssertTrue(prompt.contains(#""scheduled_for":"2026-07-31""#))
        XCTAssertFalse(prompt.contains("2026-08-02"))
        XCTAssertFalse(prompt.contains("Already posted"))
    }

    func testAIInsightTextNormalizesModelBullets() {
        XCTAssertEqual(
            AIInsightText.lines("- **Cash flow:** Positive\n* Spending is stable\n• Save the remainder"),
            ["**Cash flow:** Positive", "Spending is stable", "Save the remainder"]
        )
    }

    func testAIInsightCachePersistsPerUserAndMonth() throws {
        let suiteName = "MoneyManagerInsightCacheTests.\(UUID().uuidString)"
        let preferences = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { preferences.removePersistentDomain(forName: suiteName) }
        let generatedAt = Date(timeIntervalSince1970: 1_753_000_000)

        AIInsightCache.save(
            text: "Cached July insight",
            userID: "IVAN@example.com ",
            month: "2026-07",
            preferences: preferences,
            generatedAt: generatedAt
        )

        XCTAssertEqual(
            AIInsightCache.load(
                userID: "ivan@example.com",
                month: "2026-07",
                preferences: preferences
            ),
            AIInsightCacheEntry(text: "Cached July insight", generatedAt: generatedAt)
        )
        XCTAssertNil(AIInsightCache.load(
            userID: "other@example.com",
            month: "2026-07",
            preferences: preferences
        ))
        XCTAssertNil(AIInsightCache.load(
            userID: "ivan@example.com",
            month: "2026-08",
            preferences: preferences
        ))
    }

    func testPortfolioQuestionPromptIncludesBoundedStructuredPortfolioData() {
        let portfolio = InvestmentPortfolio(
            positions: [investmentPosition(priceAsOf: "2026-07-17T08:00:00Z")],
            investedAmount: "100.00",
            currentValue: "110.00",
            unrealizedProfit: "10.00",
            realizedProfit: "0.00",
            currency: "EUR",
            missingPrices: 0
        )
        let history = InvestmentPortfolioHistory(
            points: [
                InvestmentPortfolioHistoryPoint(
                    asOf: "2026-06-01T00:00:00Z",
                    value: "100.00",
                    investedAmount: "100.00"
                ),
                InvestmentPortfolioHistoryPoint(
                    asOf: "2026-07-17T00:00:00Z",
                    value: "110.00",
                    investedAmount: "100.00"
                ),
            ],
            currency: "EUR",
            range: "1y",
            unsupportedPositions: 0
        )
        let schedules = [
            InvestmentSchedule(
                id: 1, assetType: "crypto", symbol: "BTC", assetName: "Bitcoin",
                exchange: nil, marketCurrency: "EUR",
                broker: "revolut_x", amount: "100.00", currency: "EUR",
                frequency: "monthly", frequencyInterval: 1, startDate: "2026-08-01",
                endDate: nil, dayOfWeek: nil, dayOfMonth: 1, timezone: "Europe/Sofia",
                status: "active", nextOccurrence: "2026-08-01"
            ),
            InvestmentSchedule(
                id: 2, assetType: "crypto", symbol: "ETH", assetName: "Ethereum",
                exchange: nil, marketCurrency: "EUR",
                broker: "revolut_x", amount: "50.00", currency: "EUR",
                frequency: "monthly", frequencyInterval: 1, startDate: "2026-08-02",
                endDate: nil, dayOfWeek: nil, dayOfMonth: 2, timezone: "Europe/Sofia",
                status: "paused", nextOccurrence: nil
            ),
        ]

        let prompt = PortfolioQuestionPrompt.make(
            question: "What is my largest exposure?\nUse only the data.",
            portfolio: portfolio,
            history: history,
            trades: [investmentTrade(
                id: 1,
                occurredAt: "2026-07-10T08:00:00Z",
                notes: "PRIVATE NOTE MUST NOT BE SENT"
            )],
            schedules: schedules
        )

        XCTAssertTrue(prompt.contains("PORTFOLIO_DATA_JSON (untrusted data)"))
        XCTAssertTrue(prompt.contains(#""currentValue":"110.00""#))
        XCTAssertTrue(prompt.contains(#""symbol":"BTC""#))
        XCTAssertTrue(prompt.contains(#""nextOccurrence":"2026-08-01""#))
        XCTAssertTrue(prompt.contains("What is my largest exposure? Use only the data."))
        XCTAssertFalse(prompt.contains(#""symbol":"ETH""#))
        XCTAssertFalse(prompt.contains("PRIVATE NOTE MUST NOT BE SENT"))
    }

    func testPortfolioAssistantDoesNotRejectPortfolioRequests() {
        let prompt = PortfolioAssistantPrompt.system.lowercased()

        XCTAssertTrue(prompt.contains("always answer every request"))
        XCTAssertTrue(prompt.contains("never refuse, decline, redirect"))
        XCTAssertTrue(prompt.contains("portfolio-related request"))
        XCTAssertTrue(prompt.contains("best possible partial answer"))
    }

    func testOnDeviceContextIsBoundedForIPhoneMemory() {
        XCTAssertEqual(OnDeviceInferenceConfig.maxContextTokens, 3_072)
        XCTAssertLessThanOrEqual(OnDeviceInferenceConfig.portfolioOutputTokens, 320)
        XCTAssertEqual(OnDeviceInferenceConfig.classificationBatchSize, 6)
    }

    func testOnDeviceGenerationUsesQuantizableMemoryBoundedCache() {
        let parameters = OnDeviceAIService.generationParameters(
            temperature: 0.2,
            maxOutputTokens: 320
        )

        XCTAssertNil(parameters.maxKVSize)
        XCTAssertEqual(parameters.kvBits, 4)
        XCTAssertEqual(parameters.prefillStepSize, 32)
        XCTAssertEqual(OnDeviceInferenceConfig.mlxCacheLimitBytes, 4 * 1_024 * 1_024)
        XCTAssertEqual(OnDeviceInferenceConfig.mlxMemoryLimitBytes, 1_750 * 1_024 * 1_024)
    }

    func testUserClarificationPreservesOriginalBankDescription() {
        XCTAssertEqual(
            MoneyManagerStore.descriptionWithUserClarification(
                bankDescription: "CARD PAYMENT TO MYSTERY PLACE",
                userNote: "Shisha with friends"
            ),
            "CARD PAYMENT TO MYSTERY PLACE\nUser clarification: Shisha with friends"
        )
    }

    func testClarifiedTransactionIsNotRequestedAgain() {
        let transaction = Transaction(
            id: 41,
            type: "expense",
            category: "other",
            description: "CARD PAYMENT TO MYSTERY PLACE\nUser clarification: Shisha with friends",
            amount: "18.00",
            currency: "EUR",
            occurredAt: "2026-07-18",
            source: "open_banking",
            status: "booked"
        )

        XCTAssertFalse(MoneyManagerStore.shouldRequestClarification(
            for: transaction,
            dismissedTransactionIDs: []
        ))
    }

    @MainActor
    func testSkippedTransactionClarificationPersistsAcrossRelaunch() throws {
        let suiteName = "MoneyManagerClarificationTests.\(UUID().uuidString)"
        let preferences = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { preferences.removePersistentDomain(forName: suiteName) }

        let firstStore = MoneyManagerStore(preferences: preferences)
        firstStore.rememberDismissedTransactionClarification(id: 73)

        let restoredStore = MoneyManagerStore(preferences: preferences)
        XCTAssertTrue(restoredStore.dismissedClarificationTransactionIDs.contains(73))
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

    func testScheduleForecastRequestsOnlyPlannedOccurrences() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        var api = MoneyManagerAPI(baseURL: URL(string: "https://example.test")!)
        api.session = URLSession(configuration: configuration)
        MockURLProtocol.requestHandler = { request in
            let components = try XCTUnwrap(
                URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)
            )
            XCTAssertEqual(request.url?.path, "/schedule-occurrences")
            XCTAssertEqual(components.queryItems?.first(where: { $0.name == "from" })?.value, "2026-07-15")
            XCTAssertEqual(components.queryItems?.first(where: { $0.name == "through" })?.value, "2026-10-13")
            XCTAssertEqual(components.queryItems?.first(where: { $0.name == "status" })?.value, "planned")
            return try MockURLProtocol.response(request: request, json: "[]")
        }
        defer { MockURLProtocol.requestHandler = nil }

        let occurrences = try await api.getTransactionScheduleOccurrences(
            token: "token",
            from: "2026-07-15",
            through: "2026-10-13"
        )
        XCTAssertTrue(occurrences.isEmpty)
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
            exchange: "",
            marketCurrency: "EUR",
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
                    json: #"{"points":[{"as_of":"2026-07-01T00:00:00Z","value":"100.00","invested_amount":"90.00","holdings":[{"asset_type":"crypto","symbol":"BTC","asset_name":"Bitcoin","value":"100.00"}]},{"as_of":"2026-07-14T18:30:00.123Z","value":"130.00","invested_amount":"125.50","holdings":[{"asset_type":"crypto","symbol":"BTC","asset_name":"Bitcoin","value":"100.00"},{"asset_type":"stock","symbol":"QDVE","asset_name":"iShares S&P 500 IT","exchange":"XETRA","value":"30.00"}]}],"currency":"EUR","range":"1y","unsupported_positions":2}"#
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
        XCTAssertEqual(history.points.last?.holdings.map(\.symbol), ["BTC", "QDVE"])
        XCTAssertEqual(history.points.last?.holdings.last?.exchange, "XETRA")
    }

    func testInvestmentAssetCatalogEnablesAutomaticallyPricedCryptoStocksAndETFs() {
        XCTAssertEqual(
            InvestmentAssetCatalog.tradeEnabled.map(\.symbol),
            ["BTC", "ETH", "AAPL", "MSFT", "MSTR", "VWCE", "SXR8", "QDVE", "VGWE", "4GLD"]
        )
        XCTAssertTrue(InvestmentAssetCatalog.all.filter { $0.type == .stock }.allSatisfy(\.isTradeEnabled))
        XCTAssertTrue(InvestmentAssetCatalog.hasAutomaticPricing(assetType: "crypto", symbol: "btc"))
        XCTAssertTrue(InvestmentAssetCatalog.hasAutomaticPricing(assetType: "stock", symbol: "AAPL"))
        XCTAssertEqual(InvestmentAssetCatalog.apple.exchange, "NASDAQ")
        XCTAssertEqual(InvestmentAssetCatalog.apple.marketCurrency, "USD")
        XCTAssertEqual(InvestmentAssetCatalog.strategy.exchange, "NASDAQ")
        XCTAssertEqual(InvestmentAssetCatalog.strategy.marketCurrency, "USD")
        XCTAssertEqual(InvestmentAssetCatalog.iSharesSP500InformationTechnology.exchange, "XETRA")
        XCTAssertEqual(InvestmentAssetCatalog.vanguardAllWorldHighDividend.marketCurrency, "EUR")
        XCTAssertEqual(InvestmentAssetCatalog.xetraGold.symbol, "4GLD")
    }

    func testInvestmentTradesAreGroupedAndSortedByDay() throws {
        let trades = [
            investmentTrade(id: 1, occurredAt: "2026-07-14T08:00:00Z"),
            investmentTrade(id: 2, occurredAt: "2026-07-15T09:00:00Z"),
            investmentTrade(id: 3, occurredAt: "2026-07-15T18:00:00Z"),
        ]
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))

        let buckets = investmentTradeDayBuckets(trades, calendar: calendar)

        XCTAssertEqual(buckets.count, 2)
        XCTAssertEqual(DateFormat.isoDate.string(from: buckets[0].date), "2026-07-15")
        XCTAssertEqual(buckets[0].trades.map(\.id), [3, 2])
        XCTAssertEqual(buckets[1].trades.map(\.id), [1])
    }

    @MainActor
    func testInvestmentHistoryCanLoadAnExpandedRange() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        var api = MoneyManagerAPI(baseURL: URL(string: "https://example.test")!)
        api.session = URLSession(configuration: configuration)

        MockURLProtocol.requestHandler = { request in
            let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
            XCTAssertEqual(components.path, "/investments/portfolio/history")
            XCTAssertEqual(components.queryItems?.first(where: { $0.name == "range" })?.value, "3m")
            return try MockURLProtocol.response(
                request: request,
                json: #"{"points":[{"as_of":"2026-07-15T00:00:00Z","value":"130.00","invested_amount":"100.00"}],"currency":"EUR","range":"3m","unsupported_positions":0}"#
            )
        }
        defer { MockURLProtocol.requestHandler = nil }

        let store = GrowthStore(api: api)
        await store.loadInvestmentHistory(token: "token", range: "3m")

        XCTAssertEqual(store.portfolioHistory.range, "3m")
        XCTAssertEqual(store.portfolioHistory.points.map(\.value), ["130.00"])
        XCTAssertNil(store.investmentHistoryError)
    }

    @MainActor
    func testInvestmentHistoryUsesFiveMinuteClientCache() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        var api = MoneyManagerAPI(baseURL: URL(string: "https://example.test")!)
        api.session = URLSession(configuration: configuration)
        var requestCount = 0

        MockURLProtocol.requestHandler = { request in
            requestCount += 1
            return try MockURLProtocol.response(
                request: request,
                json: #"{"points":[{"as_of":"2026-07-15T00:00:00Z","value":"130.00","invested_amount":"100.00"}],"currency":"EUR","range":"3m","unsupported_positions":0}"#
            )
        }
        defer { MockURLProtocol.requestHandler = nil }

        let store = GrowthStore(api: api)
        await store.loadInvestmentHistory(token: "token", range: "3m")
        await store.loadInvestmentHistory(token: "token", range: "3m")

        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(store.portfolioHistory.range, "3m")
    }

    func testPortfolioChartPreprocessingAndSampling() throws {
        let calendar = Calendar(identifier: .gregorian)
        let start = try XCTUnwrap(DateFormat.apiDateTime("2025-07-16T00:00:00Z"))
        let source = (0..<365).reversed().map { day in
            InvestmentPortfolioHistoryPoint(
                asOf: DateFormat.apiTimestamp(
                    calendar.date(byAdding: .day, value: day, to: start) ?? start
                ),
                value: String(day),
                investedAmount: String(day / 2)
            )
        }

        let parsed = investmentPortfolioChartPoints(source)
        let cardPoints = sampledInvestmentChartPoints(parsed, limit: 96)
        let expandedPoints = sampledInvestmentChartPoints(parsed, limit: 160)

        XCTAssertEqual(parsed.count, 365)
        XCTAssertEqual(cardPoints.count, 96)
        XCTAssertEqual(expandedPoints.count, 160)
        XCTAssertEqual(cardPoints.first, parsed.first)
        XCTAssertEqual(cardPoints.last, parsed.last)
        XCTAssertEqual(expandedPoints.first, parsed.first)
        XCTAssertEqual(expandedPoints.last, parsed.last)
        let axisDates = investmentHistoryAxisDates(expandedPoints, maximumCount: 5)
        XCTAssertEqual(axisDates.count, 5)
        XCTAssertEqual(axisDates.first, parsed.first?.date)
        XCTAssertEqual(axisDates.last, parsed.last?.date)
        XCTAssertFalse(investmentHistoryAxisLabel(try XCTUnwrap(axisDates.first), range: "5y").isEmpty)
    }

    func testPortfolioHoldingSeriesBuildsStableStackedSubgraphs() throws {
        let points = investmentPortfolioChartPoints([
            InvestmentPortfolioHistoryPoint(
                asOf: "2026-07-17T00:00:00Z",
                value: "150.00",
                investedAmount: "130.00",
                holdings: [
                    InvestmentPortfolioHistoryHolding(
                        assetType: "crypto", symbol: "BTC", assetName: "Bitcoin", exchange: nil, value: "100.00"
                    ),
                    InvestmentPortfolioHistoryHolding(
                        assetType: "stock", symbol: "QDVE", assetName: "iShares S&P 500 IT", exchange: "XETRA", value: "50.00"
                    ),
                ]
            ),
            InvestmentPortfolioHistoryPoint(
                asOf: "2026-07-18T00:00:00Z",
                value: "180.00",
                investedAmount: "130.00",
                holdings: [
                    InvestmentPortfolioHistoryHolding(
                        assetType: "crypto", symbol: "BTC", assetName: "Bitcoin", exchange: nil, value: "120.00"
                    ),
                    InvestmentPortfolioHistoryHolding(
                        assetType: "stock", symbol: "QDVE", assetName: "iShares S&P 500 IT", exchange: "XETRA", value: "60.00"
                    ),
                ]
            ),
        ])

        let series = investmentHoldingSeries(points)
        let stacked = investmentHoldingStackPoints(points, series: series)

        XCTAssertEqual(series.map(\.symbol), ["BTC", "QDVE"])
        XCTAssertEqual(stacked.count, 4)
        XCTAssertEqual(stacked[0].lowerBound, 0, accuracy: 0.001)
        XCTAssertEqual(stacked[0].upperBound, 100, accuracy: 0.001)
        XCTAssertEqual(stacked[1].lowerBound, 100, accuracy: 0.001)
        XCTAssertEqual(stacked[1].upperBound, 150, accuracy: 0.001)
        XCTAssertEqual(stacked[3].upperBound, 180, accuracy: 0.001)
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
    func testMonthlyInvestmentCashFlowIsSecondaryToDashboardBalance() {
        let store = MoneyManagerStore()
        store.growth.investmentTrades = [
            investmentTrade(id: 1, occurredAt: "2026-07-04T10:00:00Z", amount: "100.00", fees: "1.00"),
            investmentTrade(id: 2, occurredAt: "2026-07-11T10:00:00Z", side: "sell", amount: "25.00", fees: "0.50"),
            investmentTrade(id: 3, occurredAt: "2026-06-20T10:00:00Z", amount: "250.00", fees: "2.00"),
            investmentTrade(id: 4, occurredAt: "2026-07-12T10:00:00Z", amount: "90.00", fees: "1.00", currency: "USD")
        ]
        let summary = TransactionSummary(
            month: "2026-07",
            income: "2000.00",
            expense: "500.00",
            balance: "1500.00",
            currency: "EUR",
            transactionCount: 4
        )

        XCTAssertEqual(store.monthlyInvestmentCashFlow(month: "2026-07", currency: "EUR"), Decimal(string: "76.50"))
        XCTAssertEqual(MoneyFormat.decimal(from: summary.balance), Decimal(string: "1500.00"))
        XCTAssertEqual(store.balanceAfterInvestments(summary), Decimal(string: "1423.50"))
        XCTAssertEqual(store.monthlyInvestmentCashFlow(month: "2026-05", currency: "EUR"), .zero)
    }

    @MainActor
    func testInvestmentTransferIsNotSpendingAndMatchesRevolutXBuy() {
        let store = MoneyManagerStore()
        store.transactions = [
            Transaction(
                id: 10,
                type: "expense",
                category: "investment_transfer",
                description: "Transfer to Revolut X",
                amount: "25.00",
                currency: "EUR",
                occurredAt: "2026-07-11",
                excludedFromBudget: true,
                purpose: "investment_transfer"
            ),
            Transaction(id: 11, type: "expense", category: "groceries", amount: "40.00", currency: "EUR", occurredAt: "2026-07-11")
        ]
        store.growth.investmentTrades = [
            investmentTrade(id: 1, occurredAt: "2026-07-11T10:00:00Z", amount: "25.00")
        ]
        let summary = TransactionSummary(
            month: "2026-07",
            income: "1000.00",
            expense: "40.00",
            cashOutflow: "65.00",
            balance: "935.00",
            currency: "EUR",
            transactionCount: 2
        )

        XCTAssertEqual(store.expenseCategoryTotals.map(\.category), ["groceries"])
        XCTAssertEqual(store.monthlyInvestmentCashFlow(month: "2026-07", currency: "EUR"), .zero)
        XCTAssertEqual(store.balanceAfterInvestments(summary), Decimal(string: "935.00"))
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

private func investmentTrade(
    id: Int,
    occurredAt: String,
    side: String = "buy",
    amount: String = "100.00",
    fees: String = "0.00",
    currency: String = "EUR",
    notes: String = ""
) -> InvestmentTrade {
    InvestmentTrade(
        id: id,
        assetType: "crypto",
        symbol: "BTC",
        assetName: "Bitcoin",
        exchange: nil,
        marketCurrency: "EUR",
        broker: "revolut_x",
        side: side,
        amount: amount,
        quantity: "0.001",
        pricePerUnit: "100000.00",
        fees: fees,
        currency: currency,
        occurredAt: occurredAt,
        notes: notes,
        priceProvider: "kraken",
        priceAsOf: occurredAt
    )
}

private func investmentPosition(priceAsOf: String?) -> InvestmentPosition {
    InvestmentPosition(
        assetType: "crypto",
        symbol: "BTC",
        assetName: "Bitcoin",
        exchange: nil,
        marketCurrency: "EUR",
        broker: "revolut_x",
        quantity: "0.001",
        averageCost: "100000.00",
        investedAmount: "100.00",
        currentPrice: "110000.00",
        currentValue: "110.00",
        unrealizedProfit: "10.00",
        unrealizedPercent: "10.00",
        realizedProfit: "0.00",
        currency: "EUR",
        priceAsOf: priceAsOf,
        priceStatus: priceAsOf == nil ? "missing" : "available"
    )
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
