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
        .task {
            await store.bootstrap()
        }
    }
}

private struct AuthenticatedAppView: View {
    @Bindable var store: MoneyManagerStore

    var body: some View {
        TabView(selection: $store.selectedTab) {
            DashboardView(store: store)
                .tabItem { Label(AppTab.dashboard.title, systemImage: AppTab.dashboard.systemImage) }
                .tag(AppTab.dashboard)

            TransactionsView(store: store)
                .tabItem { Label(AppTab.transactions.title, systemImage: AppTab.transactions.systemImage) }
                .tag(AppTab.transactions)

            ProfileView(store: store)
                .tabItem { Label(AppTab.profile.title, systemImage: AppTab.profile.systemImage) }
                .tag(AppTab.profile)
        }
        .background(AppColor.background)
        .sheet(item: $store.activeSheet) { sheet in
            switch sheet {
            case .transactionEditor:
                TransactionEditorView(store: store)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            case .categoryPicker:
                CategoryPickerView(store: store)
                    .presentationDetents([.medium, .large])
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
    }
}
