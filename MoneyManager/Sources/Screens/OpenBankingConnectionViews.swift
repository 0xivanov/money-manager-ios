import SwiftUI

struct OpenBankingEmptyState: View {
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

struct OpenBankingConnectionCard: View {
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

struct OpenBankingAccountCard: View {
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
