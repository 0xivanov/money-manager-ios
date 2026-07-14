import SwiftUI
import UniformTypeIdentifiers

struct ProfileView: View {
    @Bindable var store: MoneyManagerStore
    @State private var isDeleteAccountConfirmationPresented = false
    @State private var isImportPickerPresented = false

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    AccountRow(store: store)
                }

                Section("Connection") {
                    LabeledContent("Server") {
                        Text(store.apiBaseURL.host ?? store.apiBaseURL.absoluteString)
                            .font(.subheadline.monospaced())
                            .foregroundStyle(AppColor.mutedText)
                            .multilineTextAlignment(.trailing)
                    }
                    ConnectionStatusRow(status: store.connectionStatus)
                    Button {
                        Task { await store.checkHealth() }
                    } label: {
                        Label("Check connection", systemImage: "arrow.clockwise")
                    }
                    .disabled(store.connectionStatus == .checking)
                }

                Section {
                    NavigationLink {
                        OpenBankingView(store: store)
                    } label: {
                        BankConnectionProfileRow(store: store)
                    }
                    IntegrationRoadmapRow(icon: "chart.line.uptrend.xyaxis", title: "Stock brokers", detail: "Holdings and performance")
                    IntegrationRoadmapRow(icon: "bitcoinsign.circle.fill", title: "Crypto exchanges", detail: "Wallets and positions")
                } header: {
                    Text("Connections")
                } footer: {
                    Text("Bank connections are read-only. Broker and crypto integrations are planned for later.")
                }

                Section("Planning") {
                    NavigationLink {
                        ScheduledMoneyView(store: store)
                    } label: {
                        Label("Scheduled money", systemImage: "calendar.badge.clock")
                    }
                    NavigationLink {
                        BudgetsView(store: store)
                    } label: {
                        Label("Budgets", systemImage: "gauge.with.dots.needle.50percent")
                    }
                    NavigationLink {
                        NotificationPreferencesView(store: store)
                    } label: {
                        Label("Notifications", systemImage: "bell.badge")
                    }
                }

                Section("Data") {
                    Button {
                        isImportPickerPresented = true
                    } label: {
                        Label("Import Revolut CSV", systemImage: "square.and.arrow.down.on.square")
                    }
                    .disabled(store.isLoading || store.isImporting)
                    Button(action: store.openExportDialog) {
                        Label("Export transactions", systemImage: "square.and.arrow.down")
                    }
                    .disabled(store.isLoading)
                }

                #if DEBUG
                Section("Developer") {
                    Button(action: store.openPhysicalPurchaseForm) {
                        Label("Simulate purchase signal", systemImage: "bolt.fill")
                    }
                }
                #endif

                Section("App") {
                    LabeledContent("Version", value: appVersion)
                }

                Section {
                    Button("Log out", role: .destructive, action: store.logout)
                    Button("Delete account", role: .destructive) {
                        isDeleteAccountConfirmationPresented = true
                    }
                    .disabled(store.isDeletingAccount)
                } footer: {
                    Text("Deleting your account permanently removes your transactions and categories.")
                }

                if let error = store.error, !error.isEmpty {
                    Section {
                        ErrorBanner(message: error)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Profile")
            .refreshable { await store.checkHealth() }
            .task {
                if store.connectionStatus == .unknown {
                    await store.checkHealth()
                }
                if store.openBankingLoadState == .idle {
                    await store.loadOpenBanking()
                }
            }
            .alert("Delete your account?", isPresented: $isDeleteAccountConfirmationPresented) {
                Button("Delete account", role: .destructive, action: store.deleteAccount)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone. All transactions, categories, and account data will be permanently deleted.")
            }
            .alert("Revolut import", isPresented: Binding(
                get: { store.importResultMessage != nil },
                set: { if !$0 { store.importResultMessage = nil } }
            )) {
                Button("OK") { store.importResultMessage = nil }
            } message: {
                Text(store.importResultMessage ?? "")
            }
            .fileImporter(
                isPresented: $isImportPickerPresented,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                do {
                    guard let url = try result.get().first else { return }
                    let granted = url.startAccessingSecurityScopedResource()
                    defer { if granted { url.stopAccessingSecurityScopedResource() } }
                    store.importRevolutCSV(try Data(contentsOf: url))
                } catch {
                    store.error = error.localizedDescription
                }
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}

private struct BankConnectionProfileRow: View {
    let store: MoneyManagerStore

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "building.columns.fill")
                .foregroundStyle(AppColor.financeGreen)
                .frame(width: 34, height: 34)
                .background(AppColor.softGreenSurface)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("Bank accounts")
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(AppColor.mutedText)
            }
            Spacer()
            Text(status)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColor.financeGreen)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(AppColor.softGreenSurface)
                .clipShape(Capsule())
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Bank accounts, \(detail), \(status.lowercased())")
    }

    private var detail: String {
        if store.openBankingConnections.isEmpty {
            return "Balances and transactions"
        }
        let accountCount = store.openBankingAccounts.count
        return "\(store.openBankingConnections.count) connected · \(accountCount) \(accountCount == 1 ? "account" : "accounts")"
    }

    private var status: String {
        if store.openBankingLoadState == .loading { return "CHECKING" }
        if !store.openBankingConnections.isEmpty { return "LIVE" }
        return "READY"
    }
}

private struct IntegrationRoadmapRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(AppColor.financeGreen)
                .frame(width: 34, height: 34)
                .background(AppColor.softGreenSurface)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(AppColor.mutedText)
            }
            Spacer()
            Text("SOON")
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppColor.mutedText)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(AppColor.background)
                .clipShape(Capsule())
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(detail), coming later")
    }
}

private struct ConnectionStatusRow: View {
    let status: ConnectionStatus

    var body: some View {
        Label(title, systemImage: systemImage)
            .foregroundStyle(tint)
            .accessibilityLabel(accessibilityLabel)
    }

    private var title: String {
        switch status {
        case .unknown: "Not checked"
        case .checking: "Checking connection…"
        case .connected: "Connected"
        case .offline: "Unavailable"
        }
    }

    private var systemImage: String {
        switch status {
        case .unknown: "questionmark.circle"
        case .checking: "arrow.triangle.2.circlepath"
        case .connected: "checkmark.circle.fill"
        case .offline: "exclamationmark.triangle.fill"
        }
    }

    private var tint: Color {
        switch status {
        case .unknown, .checking: AppColor.mutedText
        case .connected: AppColor.income
        case .offline: AppColor.expense
        }
    }

    private var accessibilityLabel: String {
        if case .offline(let message) = status {
            return "Server unavailable. \(message)"
        }
        return title
    }
}

private struct AccountRow: View {
    let store: MoneyManagerStore

    var body: some View {
        LabeledContent {
            Text("Authenticated")
                .foregroundStyle(AppColor.income)
        } label: {
            Label(store.email.isEmpty ? "Money Manager account" : store.email, systemImage: "person.crop.circle.fill")
        }
    }
}
