import SwiftUI

#if DEBUG
    struct OpenBankingPreviewHost: View {
        @State private var store: MoneyManagerStore

        init(isEmpty: Bool) {
            let store = MoneyManagerStore()
            store.openBankingLoadState = .loaded
            store.openBankingCountry = "BG"
            store.openBankingInstitutions = [
                OpenBankingInstitution(
                    name: "Revolut",
                    country: "BG",
                    logo: "",
                    psuTypes: ["personal"],
                    authMethods: [OpenBankingAuthMethod(name: "redirect", title: "Mobile app", psuType: "personal", approach: "REDIRECT", hiddenMethod: false)],
                    maximumConsentValidity: 180,
                    beta: false,
                    bic: "REVOBGSF",
                    requiredPSUHeaders: nil
                ),
                OpenBankingInstitution(
                    name: "UniCredit Bulbank",
                    country: "BG",
                    logo: "",
                    psuTypes: ["personal"],
                    authMethods: [],
                    maximumConsentValidity: 90,
                    beta: false,
                    bic: "UNCRBGSF",
                    requiredPSUHeaders: nil
                ),
                OpenBankingInstitution(
                    name: "DSK Bank",
                    country: "BG",
                    logo: "",
                    psuTypes: ["personal"],
                    authMethods: [],
                    maximumConsentValidity: 90,
                    beta: false,
                    bic: "STSABGSF",
                    requiredPSUHeaders: nil
                ),
            ]

            if !isEmpty {
                let connection = OpenBankingConnection(
                    id: 1,
                    institutionName: "Revolut",
                    country: "BG",
                    psuType: "personal",
                    status: "AUTHORIZED",
                    validUntil: "2026-10-11T00:00:00Z",
                    accountCount: 2,
                    createdAt: "2026-07-13T10:00:00Z",
                    updatedAt: "2026-07-13T10:00:00Z"
                )
                let everyday = OpenBankingAccount(
                    id: 1,
                    connectionID: 1,
                    institutionName: "Revolut",
                    country: "BG",
                    name: "Alex Morgan",
                    details: "Everyday",
                    cashAccountType: "CACC",
                    product: "Current account",
                    currency: "EUR",
                    displayIdentifier: "•••• 0123",
                    identificationHash: "preview-everyday",
                    canFetchData: true
                )
                let savings = OpenBankingAccount(
                    id: 2,
                    connectionID: 1,
                    institutionName: "Revolut",
                    country: "BG",
                    name: "Alex Morgan",
                    details: "Savings",
                    cashAccountType: "SVGS",
                    product: "Savings account",
                    currency: "EUR",
                    displayIdentifier: "•••• 9876",
                    identificationHash: "preview-savings",
                    canFetchData: true
                )
                let everydayBalances = OpenBankingBalanceResponse(balances: [
                    OpenBankingBalance(
                        name: "Booked balance",
                        balanceAmount: OpenBankingMoneyAmount(currency: "EUR", amount: "4280.12"),
                        balanceType: "CLBD",
                        lastChangeDateTime: "2026-07-13T10:00:00Z",
                        referenceDate: "2026-07-13"
                    )
                ])
                let savingsBalances = OpenBankingBalanceResponse(balances: [
                    OpenBankingBalance(
                        name: "Booked balance",
                        balanceAmount: OpenBankingMoneyAmount(currency: "EUR", amount: "12640.00"),
                        balanceType: "CLBD",
                        lastChangeDateTime: "2026-07-13T10:00:00Z",
                        referenceDate: "2026-07-13"
                    )
                ])
                let previewTransactions = OpenBankingTransactionResponse(
                    continuationKey: nil,
                    transactions: [
                        OpenBankingTransaction(
                            transactionID: "preview-1",
                            entryReference: nil,
                            status: "BOOK",
                            bookingDate: "2026-07-13",
                            valueDate: "2026-07-13",
                            transactionDate: "2026-07-13",
                            creditDebitIndicator: "DBIT",
                            transactionAmount: OpenBankingMoneyAmount(currency: "EUR", amount: "42.80"),
                            remittanceInformation: ["Weekly groceries"],
                            creditor: OpenBankingParty(name: "Fresh Market"),
                            debtor: nil,
                            bankTransactionCode: nil,
                            note: nil
                        ),
                        OpenBankingTransaction(
                            transactionID: "preview-2",
                            entryReference: nil,
                            status: "BOOK",
                            bookingDate: "2026-07-10",
                            valueDate: "2026-07-10",
                            transactionDate: "2026-07-10",
                            creditDebitIndicator: "CRDT",
                            transactionAmount: OpenBankingMoneyAmount(currency: "EUR", amount: "3200.00"),
                            remittanceInformation: ["July salary"],
                            creditor: nil,
                            debtor: OpenBankingParty(name: "Salary"),
                            bankTransactionCode: nil,
                            note: nil
                        ),
                        OpenBankingTransaction(
                            transactionID: "preview-3",
                            entryReference: nil,
                            status: "BOOK",
                            bookingDate: "2026-07-09",
                            valueDate: "2026-07-09",
                            transactionDate: "2026-07-09",
                            creditDebitIndicator: "DBIT",
                            transactionAmount: OpenBankingMoneyAmount(currency: "EUR", amount: "18.45"),
                            remittanceInformation: ["Health"],
                            creditor: OpenBankingParty(name: "Central Pharmacy"),
                            debtor: nil,
                            bankTransactionCode: nil,
                            note: nil
                        ),
                    ]
                )
                store.openBankingConnections = [connection]
                store.openBankingAccounts = [everyday, savings]
                store.openBankingBalances = [1: everydayBalances, 2: savingsBalances]
                store.openBankingBalanceLoadStates = [1: .loaded, 2: .loaded]
                store.openBankingAccountSnapshots = [
                    1: OpenBankingAccountSnapshot(
                        balances: everydayBalances,
                        transactions: previewTransactions,
                        loadedAt: Date()
                    )
                ]
                store.openBankingAccountLoadStates = [1: .loaded]
            }

            _store = State(initialValue: store)
        }

        var body: some View {
            NavigationStack {
                OpenBankingView(store: store)
            }
            .tint(AppColor.financeGreen)
            .onOpenURL { store.handleOpenBankingCallback($0) }
        }
    }
#endif
