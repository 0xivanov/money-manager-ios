import SwiftUI

struct OpenBankingView: View {
    @Bindable var store: MoneyManagerStore
    @State private var isConnectFlowPresented = false
    @State private var connectionPendingDeletion: OpenBankingConnection?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let error = store.openBankingError, !error.isEmpty {
                    OpenBankingRecoveryCard(
                        title: "Connection needs attention",
                        detail: error,
                        actionTitle: store.openBankingConnections.isEmpty ? "Choose a bank" : "Try again"
                    ) {
                        if store.openBankingConnections.isEmpty {
                            isConnectFlowPresented = true
                        } else {
                            Task { await store.loadOpenBanking(force: true) }
                        }
                    }
                }

                content
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
        }
        .background(AppColor.background)
        .navigationTitle("Bank connections")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if !store.openBankingConnections.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isConnectFlowPresented = true
                    } label: {
                        Label("Connect another bank", systemImage: "plus")
                    }
                }
            }
        }
        .task {
            if store.openBankingLoadState == .idle {
                await store.loadOpenBanking()
            }
        }
        .refreshable {
            await store.loadOpenBanking(force: true)
        }
        .sheet(isPresented: $isConnectFlowPresented) {
            NavigationStack {
                OpenBankingBankPickerView(store: store)
            }
        }
        .onChange(of: store.openBankingCallbackState) { _, state in
            guard state != .idle else { return }
            isConnectFlowPresented = false
            store.clearOpenBankingCallbackState()
        }
        .confirmationDialog(
            "Disconnect this bank?",
            isPresented: Binding(
                get: { connectionPendingDeletion != nil },
                set: { if !$0 { connectionPendingDeletion = nil } }
            ),
            presenting: connectionPendingDeletion
        ) { connection in
            Button("Disconnect \(connection.institutionName)", role: .destructive) {
                Task { await store.deleteOpenBankingConnection(connection) }
                connectionPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                connectionPendingDeletion = nil
            }
        } message: { connection in
            Text("Money Manager will revoke access and remove its saved connection to \(connection.institutionName). Imported transaction history is not affected.")
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.openBankingLoadState == .loading && store.openBankingConnections.isEmpty {
            OpenBankingLoadingCard(title: "Loading bank connections")
        } else if store.openBankingConnections.isEmpty {
            OpenBankingEmptyState {
                isConnectFlowPresented = true
            }
        } else {
            connectedContent
        }
    }

    private var connectedContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            OpenBankingSectionLabel("CONNECTED")

            ForEach(store.openBankingConnections) { connection in
                OpenBankingConnectionCard(connection: connection) {
                    connectionPendingDeletion = connection
                }
            }

            OpenBankingSectionLabel("ACCOUNTS")

            if store.openBankingAccounts.isEmpty {
                AppCard {
                    Text("No accounts were returned")
                        .font(.headline)
                        .foregroundStyle(AppColor.nearBlack)
                    Text("This can happen when a restricted production application has not linked the selected account in Enable Banking.")
                        .font(.subheadline)
                        .foregroundStyle(AppColor.mutedText)
                        .padding(.top, 6)
                }
            } else {
                ForEach(store.openBankingAccounts) { account in
                    if account.canFetchData {
                        NavigationLink {
                            OpenBankingAccountDetailView(store: store, account: account)
                        } label: {
                            OpenBankingAccountCard(
                                account: account,
                                balance: store.openBankingBalances[account.id]?.preferredBalance,
                                state: store.openBankingBalanceLoadStates[account.id] ?? .idle
                            )
                        }
                        .buttonStyle(.plain)
                        .task {
                            await store.loadOpenBankingBalance(accountID: account.id)
                        }
                    } else {
                        OpenBankingAccountCard(account: account, balance: nil, state: .failed("Live data unavailable"))
                    }
                }
            }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(AppColor.financeGreen)
                Text("Read-only access. Money Manager cannot move money or make payments.")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppColor.nearBlack)
            }
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.softGreenSurface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}

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
            )
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
                name: "Ivan Ivanov",
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
                name: "Ivan Ivanov",
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
                    )
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

private struct OpenBankingEmptyState: View {
    let connect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            OpenBankingSectionLabel("ACCOUNTS")
            Text("Your money, automatically")
                .font(.title2.weight(.bold))
                .foregroundStyle(AppColor.inverseText)
            Text("Connect read-only accounts to see balances and activity without sharing bank credentials with Money Manager.")
                .font(.body)
                .foregroundStyle(AppColor.inverseText.opacity(0.78))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.invertedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

        VStack(alignment: .leading, spacing: 7) {
            Label("Private by design", systemImage: "lock.fill")
                .font(.headline)
                .foregroundStyle(AppColor.nearBlack)
            Text("Access is read-only, consent can be revoked at any time, and bank passwords never reach Money Manager.")
                .font(.subheadline)
                .foregroundStyle(AppColor.mutedText)
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.softGreenSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

        PrimaryButton(title: "Connect a bank", systemImage: "building.columns.fill", action: connect)
            .padding(.top, 8)
    }
}

private struct OpenBankingConnectionCard: View {
    let connection: OpenBankingConnection
    let disconnect: () -> Void

    var body: some View {
        HStack(spacing: 13) {
            OpenBankingInstitutionMark(name: connection.institutionName, logo: nil, size: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(connection.institutionName)
                    .font(.headline)
                    .foregroundStyle(AppColor.nearBlack)
                Text("\(connection.accountCount) \(connection.accountCount == 1 ? "account" : "accounts") · valid until \(OpenBankingDate.short(connection.validUntil))")
                    .font(.caption)
                    .foregroundStyle(AppColor.mutedText)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 7) {
                Text(connection.needsAttention ? "ACTION" : "LIVE")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(connection.needsAttention ? AppColor.expense : AppColor.financeGreen)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(connection.needsAttention ? AppColor.expense.opacity(0.12) : AppColor.softGreenSurface)
                    .clipShape(Capsule())

                Menu {
                    Button(role: .destructive, action: disconnect) {
                        Label("Disconnect", systemImage: "link.badge.minus")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 32, height: 24)
                }
                .accessibilityLabel("Manage \(connection.institutionName) connection")
            }
        }
        .padding(16)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .stroke(connection.needsAttention ? AppColor.expense.opacity(0.4) : AppColor.divider, lineWidth: 1)
        }
    }
}

private struct OpenBankingAccountCard: View {
    let account: OpenBankingAccount
    let balance: OpenBankingBalance?
    let state: OpenBankingLoadState

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Text(account.displayName.uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color(red: 0.45, green: 0.89, blue: 0.66))
                    .lineLimit(1)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColor.inverseText)
                    .frame(width: 32, height: 32)
                    .background(AppColor.financeGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 5) {
                balanceValue
                Text(account.displayIdentifier ?? account.institutionName)
                    .font(.caption)
                    .foregroundStyle(AppColor.inverseText.opacity(0.72))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.invertedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var balanceValue: some View {
        if let balance {
            Text(MoneyFormat.amount(balance.balanceAmount.decimal, currency: balance.balanceAmount.currency))
                .font(.title2.weight(.bold).monospacedDigit())
                .foregroundStyle(AppColor.inverseText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        } else if state == .loading {
            ProgressView()
                .tint(AppColor.inverseText)
                .accessibilityLabel("Loading balance")
        } else {
            Text(state.failureMessage ?? "View live balance")
                .font(.headline)
                .foregroundStyle(AppColor.inverseText)
                .lineLimit(2)
        }
    }
}

private struct OpenBankingBankPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var store: MoneyManagerStore
    @State private var searchText = ""
    @State private var selectedCountry: String

    init(store: MoneyManagerStore) {
        self.store = store
        _selectedCountry = State(initialValue: store.openBankingCountry)
    }

    var body: some View {
        Group {
            if store.isLoadingOpenBankingInstitutions && store.openBankingInstitutions.isEmpty {
                OpenBankingLoadingCard(title: "Finding available banks")
                    .padding(16)
            } else if let error = store.openBankingError, store.openBankingInstitutions.isEmpty {
                OpenBankingRecoveryCard(title: "Banks could not be loaded", detail: error, actionTitle: "Try again") {
                    Task { await store.loadOpenBankingInstitutions(country: selectedCountry, force: true) }
                }
                .padding(16)
            } else if filteredInstitutions.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredInstitutions) { institution in
                            NavigationLink {
                                OpenBankingConsentView(store: store, institution: institution)
                            } label: {
                                OpenBankingInstitutionRow(institution: institution)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .background(AppColor.background)
            }
        }
        .navigationTitle("Choose your bank")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search banks")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close", action: dismiss.callAsFunction)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Country", selection: $selectedCountry) {
                        ForEach(OpenBankingRegion.supported) { region in
                            Text(region.name).tag(region.code)
                        }
                    }
                } label: {
                    Label(selectedCountry, systemImage: "globe.europe.africa.fill")
                }
                .accessibilityLabel("Country, \(regionName)")
            }
        }
        .task {
            await store.loadOpenBankingInstitutions(country: selectedCountry)
        }
        .onChange(of: selectedCountry) { _, country in
            searchText = ""
            Task { await store.loadOpenBankingInstitutions(country: country, force: true) }
        }
    }

    private var filteredInstitutions: [OpenBankingInstitution] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return store.openBankingInstitutions }
        return store.openBankingInstitutions.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.bic?.localizedCaseInsensitiveContains(query) == true
        }
    }

    private var regionName: String {
        OpenBankingRegion.supported.first(where: { $0.code == selectedCountry })?.name ?? selectedCountry
    }
}

private struct OpenBankingInstitutionRow: View {
    let institution: OpenBankingInstitution

    var body: some View {
        HStack(spacing: 13) {
            OpenBankingInstitutionMark(name: institution.name, logo: institution.logo, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(institution.name)
                    .font(.headline)
                    .foregroundStyle(AppColor.nearBlack)
                Text(institution.beta ? "Personal banking · beta" : "Personal banking")
                    .font(.caption)
                    .foregroundStyle(AppColor.mutedText)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColor.financeGreen)
        }
        .padding(16)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppColor.divider, lineWidth: 1)
        }
    }
}

private struct OpenBankingConsentView: View {
    @Environment(\.openURL) private var openURL
    @Bindable var store: MoneyManagerStore
    let institution: OpenBankingInstitution
    @State private var isWaitingForBank = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(institution.name)
                        .font(.title2.weight(.bold))
                    Text("Connect your personal accounts for a complete view of your money.")
                        .font(.body)
                        .foregroundStyle(AppColor.inverseText.opacity(0.78))
                }
                .foregroundStyle(AppColor.inverseText)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColor.invertedSurface)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                OpenBankingSectionLabel("READ-ONLY PERMISSIONS")
                OpenBankingPermissionCard(
                    icon: "banknote.fill",
                    title: "View balances",
                    detail: "Current and available balances"
                )
                OpenBankingPermissionCard(
                    icon: "list.bullet.rectangle.portrait",
                    title: "Read transaction history",
                    detail: "Merchant, amount, date, and status"
                )

                Label("Money Manager cannot move money or make payments.", systemImage: "lock.shield.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColor.nearBlack)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColor.softGreenSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                if let error = store.openBankingError {
                    ErrorBanner(message: error)
                }

                PrimaryButton(
                    title: isWaitingForBank ? "Waiting for your bank" : "Continue to \(institution.name)",
                    systemImage: isWaitingForBank ? nil : "arrow.up.right.square.fill",
                    isLoading: store.isStartingOpenBankingAuthorization
                ) {
                    Task {
                        if let url = await store.startOpenBankingAuthorization(for: institution) {
                            isWaitingForBank = true
                            openURL(url)
                        }
                    }
                }
                .disabled(isWaitingForBank || store.isStartingOpenBankingAuthorization)

                if isWaitingForBank {
                    Text("Finish securely in your bank, then Money Manager will reopen automatically.")
                        .font(.footnote)
                        .foregroundStyle(AppColor.mutedText)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(16)
        }
        .background(AppColor.background)
        .navigationTitle("Review access")
        .navigationBarTitleDisplayMode(.large)
    }
}

private struct OpenBankingPermissionCard: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(AppColor.financeGreen)
                .frame(width: 42, height: 42)
                .background(AppColor.softGreenSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppColor.nearBlack)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(AppColor.mutedText)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct OpenBankingAccountDetailView: View {
    @Bindable var store: MoneyManagerStore
    let account: OpenBankingAccount

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                OpenBankingAccountCard(
                    account: account,
                    balance: store.openBankingAccountSnapshots[account.id]?.balances.preferredBalance
                        ?? store.openBankingBalances[account.id]?.preferredBalance,
                    state: store.openBankingAccountLoadStates[account.id]
                        ?? store.openBankingBalanceLoadStates[account.id]
                        ?? .idle
                )

                OpenBankingSectionLabel("RECENT ACTIVITY")

                accountActivity

                SecondaryButton(title: "Refresh", systemImage: "arrow.clockwise") {
                    Task { await store.loadOpenBankingAccountData(accountID: account.id, force: true) }
                }
                .disabled(store.openBankingAccountLoadStates[account.id] == .loading)
            }
            .padding(16)
        }
        .background(AppColor.background)
        .navigationTitle(account.displayName)
        .navigationBarTitleDisplayMode(.large)
        .task {
            await store.loadOpenBankingAccountData(accountID: account.id)
        }
        .refreshable {
            await store.loadOpenBankingAccountData(accountID: account.id, force: true)
        }
    }

    @ViewBuilder
    private var accountActivity: some View {
        if let snapshot = store.openBankingAccountSnapshots[account.id] {
            if snapshot.transactions.transactions.isEmpty {
                ContentUnavailableView(
                    "No recent transactions",
                    systemImage: "tray",
                    description: Text("The bank returned no booked transactions for the last 90 days.")
                )
                .frame(maxWidth: .infinity)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(snapshot.transactions.transactions.prefix(50))) { transaction in
                        OpenBankingTransactionRow(transaction: transaction, fallbackCurrency: account.currency)
                    }
                }
                Text("Updated \(snapshot.loadedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(AppColor.mutedText)
            }
        } else {
            switch store.openBankingAccountLoadStates[account.id] ?? .idle {
            case .loading:
                OpenBankingLoadingCard(title: "Loading live account data")
            case .failed(let message):
                OpenBankingRecoveryCard(title: "Account data is unavailable", detail: message, actionTitle: "Try again") {
                    Task { await store.loadOpenBankingAccountData(accountID: account.id, force: true) }
                }
            case .idle, .loaded:
                OpenBankingLoadingCard(title: "Preparing account")
            }
        }
    }
}

private struct OpenBankingTransactionRow: View {
    let transaction: OpenBankingTransaction
    let fallbackCurrency: String

    var body: some View {
        HStack(spacing: 12) {
            Text(String(transaction.title.prefix(1)).uppercased())
                .font(.subheadline.weight(.bold))
                .foregroundStyle(amountColor(transaction.signedAmount))
                .frame(width: 42, height: 42)
                .background(amountColor(transaction.signedAmount).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.nearBlack)
                    .lineLimit(1)
                Text("\(transaction.detail) · \(OpenBankingDate.transaction(transaction.effectiveDate))")
                    .font(.caption)
                    .foregroundStyle(AppColor.mutedText)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(MoneyFormat.signed(
                transaction.signedAmount,
                currency: transaction.transactionAmount?.currency ?? fallbackCurrency
            ))
            .font(.subheadline.weight(.bold).monospacedDigit())
            .foregroundStyle(amountColor(transaction.signedAmount))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
        }
        .padding(14)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct OpenBankingInstitutionMark: View {
    let name: String
    let logo: String?
    let size: CGFloat

    var body: some View {
        Group {
            if let logo,
               let url = URL(string: logo),
               url.scheme?.lowercased() == "https" {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    fallback
                }
                .padding(7)
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .background(AppColor.background)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
        .accessibilityHidden(true)
    }

    private var fallback: some View {
        Text(String(name.prefix(1)).uppercased())
            .font(.system(size: size * 0.35, weight: .bold))
            .foregroundStyle(AppColor.nearBlack)
    }
}

private struct OpenBankingSectionLabel: View {
    private let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(AppColor.financeGreen)
            .tracking(0.8)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct OpenBankingLoadingCard: View {
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(AppColor.financeGreen)
            Text(title)
                .font(.headline)
                .foregroundStyle(AppColor.nearBlack)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct OpenBankingRecoveryCard: View {
    let title: String
    let detail: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            Label(title, systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(AppColor.expense)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(AppColor.nearBlack)
            Button(actionTitle, action: action)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppColor.expense)
                .padding(.top, 2)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.expense.opacity(0.11))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private enum OpenBankingDate {
    static func short(_ value: String) -> String {
        guard let date = parse(value) else { return String(value.prefix(10)) }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    static func transaction(_ value: String) -> String {
        guard let date = DateFormat.isoDate.date(from: String(value.prefix(10))) else { return String(value.prefix(10)) }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    private static func parse(_ value: String) -> Date? {
        let precise = ISO8601DateFormatter()
        precise.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = precise.date(from: value) { return date }
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        return standard.date(from: value)
    }
}

private extension OpenBankingLoadState {
    var failureMessage: String? {
        if case .failed(let message) = self { return message }
        return nil
    }
}
