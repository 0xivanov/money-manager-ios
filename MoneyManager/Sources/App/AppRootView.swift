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
        .onOpenURL { url in
            store.handleOpenBankingCallback(url)
        }
    }
}

private struct AuthenticatedAppView: View {
    @Bindable var store: MoneyManagerStore

    var body: some View {
        ZStack(alignment: .bottom) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    Color.clear
                        .frame(height: 82)
                        .accessibilityHidden(true)
                }

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

    private let shape = RoundedRectangle(cornerRadius: 23, style: .continuous)

    @ViewBuilder
    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 12) {
                tabBarContent
                    .glassEffect(
                        .clear.tint(Color.primary.opacity(0.06)),
                        in: shape
                    )
                    .overlay {
                        shape.stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.42),
                                    Color.white.opacity(0.08),
                                    Color.black.opacity(0.14)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                    }
            }
            .shadow(color: Color.black.opacity(0.10), radius: 18, y: 8)
        } else {
            tabBarContent
                .background(.ultraThinMaterial, in: shape)
                .overlay {
                    shape.stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.42),
                                Color.white.opacity(0.08),
                                Color.black.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
                }
                .shadow(color: Color.black.opacity(0.12), radius: 24, y: 10)
        }
    }

    private var tabBarContent: some View {
        HStack(spacing: 0) {
            tab(.dashboard)
            tab(.transactions)

            addTransactionButton

            tab(.investments)
            tab(.profile)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
    }

    @ViewBuilder
    private var addTransactionButton: some View {
        if #available(iOS 26.0, *) {
            Button(action: store.openNewTransactionForm) {
                addTransactionLabel
            }
            .buttonStyle(.plain)
            .glassEffect(
                .regular.tint(AppColor.filledButton).interactive(),
                in: RoundedRectangle(cornerRadius: 17, style: .continuous)
            )
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Add transaction")
        } else {
            Button(action: store.openNewTransactionForm) {
                addTransactionLabel
                    .background(.thinMaterial)
                    .background(AppColor.filledButton.opacity(0.88))
                    .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .stroke(Color.white.opacity(0.24), lineWidth: 0.8)
                    }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Add transaction")
        }
    }

    private var addTransactionLabel: some View {
        Image(systemName: "plus")
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(AppColor.primaryText)
            .frame(width: 52, height: 52)
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
