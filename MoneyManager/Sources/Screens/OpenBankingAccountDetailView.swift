import SwiftUI

struct OpenBankingAccountDetailView: View {
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

                SecondaryButton(title: "Sync activity", systemImage: "arrow.triangle.2.circlepath") {
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

            Text(
                MoneyFormat.signed(
                    transaction.signedAmount,
                    currency: transaction.transactionAmount?.currency ?? fallbackCurrency
                )
            )
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
