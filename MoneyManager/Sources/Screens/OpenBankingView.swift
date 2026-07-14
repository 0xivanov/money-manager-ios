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
