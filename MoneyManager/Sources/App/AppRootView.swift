import SwiftUI

struct AppRootView: View {
    @Bindable var store: MoneyManagerStore

    var body: some View {
        Group {
            if store.isAuthenticated {
                AuthenticatedAppView(store: store)
            } else {
                AuthView(store: store)
            }
        }
        .tint(AppColor.financeGreen)
        .preferredColorScheme(store.appAppearance.colorScheme)
        .task {
            await store.bootstrap()
            if PushConfiguration.isEnabled, let eventType = PushEventStore.pending {
                store.handlePushEvent(eventType)
                PushEventStore.pending = nil
            }
        }
        .task(id: store.token) {
            guard PushConfiguration.isEnabled else { return }
            guard let token = store.token, let deviceToken = PushDeviceTokenStore.current else { return }
            await store.growth.registerPushDevice(token: token, deviceToken: deviceToken)
        }
        .onOpenURL { url in
            store.handleOpenBankingCallback(url)
        }
        .onReceive(NotificationCenter.default.publisher(for: .pushDeviceTokenReceived)) { notification in
            guard PushConfiguration.isEnabled else { return }
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
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
            Task { await OnDeviceAIService.shared.unload() }
        }
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
