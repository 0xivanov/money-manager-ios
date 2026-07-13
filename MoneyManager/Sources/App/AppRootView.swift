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
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            MoneyManagerTabBar(store: store)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
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
    }

    @ViewBuilder
    private var content: some View {
        switch store.selectedTab {
        case .dashboard:
            DashboardView(store: store)
        case .transactions:
            TransactionsView(store: store)
        case .investments:
            InvestmentView()
        case .profile:
            ProfileView(store: store)
        }
    }
}

private struct MoneyManagerTabBar: View {
    @Bindable var store: MoneyManagerStore

    var body: some View {
        HStack(spacing: 0) {
            tab(.dashboard)
            tab(.transactions)

            Button(action: store.openNewTransactionForm) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppColor.primaryText)
                    .frame(width: 52, height: 52)
                    .background(AppColor.filledButton)
                    .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            }
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Add transaction")

            tab(.investments)
            tab(.profile)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(AppColor.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
        .shadow(color: Color.black.opacity(0.10), radius: 18, y: 7)
    }

    private func tab(_ tab: AppTab) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) { store.selectedTab = tab }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 17, weight: .semibold))
                Text(tab.title.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(store.selectedTab == tab ? AppColor.financeGreen : AppColor.mutedText)
            .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(store.selectedTab == tab ? .isSelected : [])
    }
}
