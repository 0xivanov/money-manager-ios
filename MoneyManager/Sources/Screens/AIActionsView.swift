import SwiftUI

struct TransactionClarification: Identifiable, Equatable {
    let transaction: Transaction
    let question: String

    var id: Int { transaction.id }
}

struct TransactionClarificationView: View {
    @Bindable var store: MoneyManagerStore
    let clarification: TransactionClarification
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Amount") {
                        Text(MoneyFormat.amount(
                            MoneyFormat.decimal(from: clarification.transaction.amount),
                            currency: clarification.transaction.currency
                        ))
                        .monospacedDigit()
                    }
                    LabeledContent("Date", value: DateFormat.dateTimeDisplay(clarification.transaction.occurredAt))
                    if let description = clarification.transaction.description, !description.isEmpty {
                        LabeledContent("Bank description") {
                            Text(description)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                } header: {
                    Text("Uncertain payment")
                }

                Section {
                    Text(clarification.question)
                        .font(.subheadline.weight(.semibold))
                    TextField("Short description, for example dinner with friends", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                        .textInputAutocapitalization(.sentences)
                } footer: {
                    Text("Your note is saved with the payment and checked against the app’s category rules.")
                }

                if let error = store.error {
                    Section { ErrorBanner(message: error) }
                }
            }
            .navigationTitle("Describe payment")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip", action: store.skipTransactionClarification)
                        .disabled(store.isSavingTransactionClarification)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await store.submitTransactionClarification(note) }
                    }
                    .disabled(
                        note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || store.isSavingTransactionClarification
                    )
                }
            }
            .overlay {
                if store.isSavingTransactionClarification {
                    ProgressView("Checking category")
                        .padding(18)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }
}
