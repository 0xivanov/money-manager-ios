import SwiftUI

struct OpenBankingBankPickerView: View {
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
