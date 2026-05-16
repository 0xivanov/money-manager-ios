import SwiftUI

struct ProfileView: View {
    @Bindable var store: MoneyManagerStore
    private let apiBaseURL = "http://localhost:8080"

    var body: some View {
        NavigationStack {
            List {
                Section {
                    AccountRow(store: store)
                }

                Section("Connection") {
                    LabeledContent("API base URL", value: apiBaseURL)
                        .font(.subheadline.monospaced())
                    Label(isLoadingTitle, systemImage: store.isLoading ? "arrow.triangle.2.circlepath" : "checkmark.circle.fill")
                        .foregroundStyle(store.isLoading ? AppColor.mutedText : AppColor.income)
                }

                Section("Data") {
                    Button(action: store.openExportDialog) {
                        Label("Export transactions", systemImage: "square.and.arrow.down")
                    }
                    .disabled(store.isLoading)
                }

                Section("Developer") {
                    Button(action: store.openPhysicalPurchaseForm) {
                        Label("Simulate purchase signal", systemImage: "bolt.fill")
                    }
                }

                Section {
                    Button("Logout", role: .destructive, action: store.logout)
                }

                if let error = store.error, !error.isEmpty {
                    Section {
                        Text(error)
                            .foregroundStyle(AppColor.expense)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Profile")
        }
    }

    private var isLoadingTitle: String {
        store.isLoading ? "Syncing..." : "Connected"
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
