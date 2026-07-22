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
                    Text("Your note is saved with the payment and Qwen uses it to choose a category.")
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
                    ProgressView("Re-evaluating")
                        .padding(18)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }
}

struct AIFinancialActionSection: View {
    @Bindable var store: MoneyManagerStore
    @State private var request = ""
    @State private var interpretation: AIFinancialActionInterpretation?
    @State private var isInterpreting = false
    @State private var isCreating = false
    @State private var errorMessage: String?

    var body: some View {
        Section {
            TextField(
                "For example: schedule €1,200 rent monthly from August 1",
                text: $request,
                axis: .vertical
            )
            .lineLimit(2...5)

            Button {
                Task { await interpretRequest() }
            } label: {
                HStack {
                    Label("Plan with Qwen", systemImage: "wand.and.stars")
                    Spacer()
                    if isInterpreting { ProgressView() }
                }
            }
            .disabled(
                request.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || isInterpreting
                    || !OnDeviceModelManager.shared.isModelInstalled
            )

            if let interpretation {
                Text(interpretation.message)
                    .font(.subheadline)

                if let proposal = interpretation.proposal {
                    proposalDetails(proposal)
                    Button {
                        Task { await confirm(proposal) }
                    } label: {
                        HStack {
                            Label("Confirm and create", systemImage: "checkmark.circle.fill")
                            Spacer()
                            if isCreating { ProgressView() }
                        }
                    }
                    .disabled(isCreating)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(AppColor.expense)
            }
        } header: {
            Text("AI actions")
        } footer: {
            Text("Qwen can propose recurring transactions and record BTC or ETH trades. Nothing is created until you review and confirm it.")
        }
    }

    @ViewBuilder
    private func proposalDetails(_ proposal: AIFinancialActionProposal) -> some View {
        switch proposal {
        case .transactionSchedule(let draft):
            VStack(alignment: .leading, spacing: 6) {
                Label("Recurring \(categoryTitle(draft.type))", systemImage: "calendar.badge.plus")
                Text("\(draft.name) · \(MoneyFormat.amount(MoneyFormat.decimal(from: draft.amount), currency: draft.currency))")
                Text("Every \(draft.frequencyInterval) \(draft.frequency), from \(draft.startDate)")
                Text(categoryTitle(draft.category))
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)
        case .investmentTrade(let draft):
            VStack(alignment: .leading, spacing: 6) {
                Label("Record investment", systemImage: "chart.line.uptrend.xyaxis")
                Text("\(draft.side.capitalized) \(MoneyFormat.amount(MoneyFormat.decimal(from: draft.amount), currency: draft.currency)) of \(draft.assetName)")
                Text("\(brokerNameForAI(draft.broker)) · \(DateFormat.dateTimeDisplay(draft.occurredAt))")
                if MoneyFormat.decimal(from: draft.fees) > .zero {
                    Text("Fees: \(MoneyFormat.amount(MoneyFormat.decimal(from: draft.fees), currency: draft.currency))")
                }
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @MainActor
    private func interpretRequest() async {
        guard let summary = store.summary else {
            errorMessage = "Load this month’s data first."
            return
        }
        isInterpreting = true
        errorMessage = nil
        interpretation = nil
        defer { isInterpreting = false }
        do {
            let context = AIInsightPrompt.make(
                summary: summary,
                transactions: store.transactions,
                budgets: store.growth.budgets,
                scheduledOccurrences: store.growth.scheduleOccurrences,
                portfolio: store.growth.portfolio
            )
            interpretation = try await OnDeviceAIService.shared.proposeFinancialAction(
                request: String(request.prefix(500)),
                financialContext: context,
                expenseCategories: store.expenseCategories.map(\.name),
                incomeCategories: store.incomeCategories.map(\.name),
                currency: summary.currency
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func confirm(_ proposal: AIFinancialActionProposal) async {
        guard let token = store.token else { return }
        isCreating = true
        errorMessage = nil
        defer { isCreating = false }

        let created: Bool
        switch proposal {
        case .transactionSchedule(let draft):
            guard let startDate = DateFormat.isoDate.date(from: draft.startDate) else {
                errorMessage = "The proposed start date is invalid."
                return
            }
            let weekday = Calendar.current.component(.weekday, from: startDate)
            let scheduleRequest = TransactionScheduleRequest(
                type: draft.type,
                name: draft.name,
                category: draft.category,
                description: draft.description,
                amount: draft.amount,
                currency: draft.currency,
                frequency: draft.frequency,
                frequencyInterval: draft.frequencyInterval,
                startDate: draft.startDate,
                endDate: nil,
                dayOfWeek: draft.frequency == "weekly" ? (weekday == 1 ? 7 : weekday - 1) : nil,
                dayOfMonth: draft.frequency == "monthly"
                    ? Calendar.current.component(.day, from: startDate)
                    : nil,
                timezone: TimeZone.current.identifier,
                autoPost: draft.autoPost
            )
            created = await store.growth.createTransactionSchedule(token: token, request: scheduleRequest)
        case .investmentTrade(let draft):
            let tradeRequest = InvestmentTradeRequest(
                assetType: draft.assetType,
                symbol: draft.symbol,
                assetName: draft.assetName,
                exchange: "",
                marketCurrency: "EUR",
                broker: draft.broker,
                side: draft.side,
                amount: draft.amount,
                fees: draft.fees,
                currency: draft.currency,
                occurredAt: draft.occurredAt,
                notes: draft.notes
            )
            created = await store.growth.createInvestmentTrade(token: token, request: tradeRequest)
        }

        if created {
            interpretation = AIFinancialActionInterpretation(
                message: "Created successfully.",
                proposal: nil
            )
            request = ""
        } else {
            errorMessage = store.growth.error ?? "The action could not be created."
        }
    }
}

private func brokerNameForAI(_ broker: String) -> String {
    switch broker {
    case "revolut_x": "Revolut X"
    default: "Manual"
    }
}
