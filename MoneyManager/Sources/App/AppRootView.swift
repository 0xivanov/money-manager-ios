import SwiftUI

struct AppRootView: View {
    @Bindable var store: MoneyManagerStore

    var body: some View {
        Group {
            switch store.authenticationState {
            case .authenticated:
                AuthenticatedAppView(store: store)
            case .signedOut:
                AuthView(store: store)
            case .restoring:
                SessionRestorationView()
            case .restorationFailed(let message):
                SessionRestorationFailureView(
                    message: message,
                    retry: store.retrySessionRestoration
                )
            }
        }
        .tint(AppColor.financeGreen)
        .preferredColorScheme(store.appAppearance.colorScheme)
        .task {
            LegacyLocalModelCleanup.removeDownloadedModels()
            await store.bootstrap()
            if store.isAuthenticated,
               PushConfiguration.isEnabled,
               let eventType = PushEventStore.pending {
                store.handlePushEvent(eventType)
                PushEventStore.pending = nil
            }
        }
        .task(id: store.isAuthenticated) {
            guard PushConfiguration.isEnabled else { return }
            guard store.isAuthenticated else { return }
            guard let token = store.token, let deviceToken = PushDeviceTokenStore.current else { return }
            await store.growth.registerPushDevice(token: token, deviceToken: deviceToken)
        }
        .onOpenURL { url in
            store.handleOpenBankingCallback(url)
        }
        .onReceive(NotificationCenter.default.publisher(for: .pushDeviceTokenReceived)) { notification in
            guard PushConfiguration.isEnabled else { return }
            guard store.isAuthenticated else { return }
            guard let token = store.token, let deviceToken = notification.object as? String else { return }
            Task { await store.growth.registerPushDevice(token: token, deviceToken: deviceToken) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .pushRegistrationFailed)) { notification in
            guard PushConfiguration.isEnabled else { return }
            if let message = notification.object as? String {
                store.growth.error = message
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .pushNotificationOpened)) { notification in
            guard PushConfiguration.isEnabled else { return }
            guard let eventType = notification.object as? String else { return }
            store.handlePushEvent(eventType)
            PushEventStore.pending = nil
        }
    }
}

private struct SessionRestorationView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(AppColor.financeGreen)
            Text("Opening Money Manager")
                .font(.headline)
                .foregroundStyle(AppColor.primaryText)
            Text("Restoring your secure session…")
                .font(.subheadline)
                .foregroundStyle(AppColor.mutedText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appBackground()
    }
}

private struct SessionRestorationFailureView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(AppColor.expense)
            Text("Couldn’t connect")
                .font(.title2.weight(.bold))
                .foregroundStyle(AppColor.primaryText)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppColor.mutedText)
                .multilineTextAlignment(.center)
            Button("Try again", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appBackground()
    }
}

private extension AppAppearance {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

private struct AuthenticatedAppView: View {
    @Bindable var store: MoneyManagerStore

    var body: some View {
        TabView(selection: $store.selectedTab) {
            DashboardView(store: store)
                .tabItem {
                    Label(AppTab.dashboard.title, systemImage: AppTab.dashboard.systemImage)
                }
                .tag(AppTab.dashboard)

            TransactionsView(store: store)
                .tabItem {
                    Label(AppTab.transactions.title, systemImage: AppTab.transactions.systemImage)
                }
                .tag(AppTab.transactions)

            InvestmentView(store: store)
                .tabItem {
                    Label(AppTab.investments.title, systemImage: AppTab.investments.systemImage)
                }
                .tag(AppTab.investments)

            ProfileView(store: store)
                .tabItem {
                    Label(AppTab.profile.title, systemImage: AppTab.profile.systemImage)
                }
                .tag(AppTab.profile)
        }
        .background(AppColor.background)
        .sheet(item: $store.activeSheet) { sheet in
            switch sheet {
            case .transactionEditor:
                TransactionEditorView(store: store)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            case .exportTransactions:
                ExportTransactionsView(store: store)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(item: $store.exportShareItem) { item in
            ShareSheet(items: [item.url])
        }
        .sheet(item: $store.activeTransactionClarification) { clarification in
            TransactionClarificationView(store: store, clarification: clarification)
                .id(clarification.id)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}
