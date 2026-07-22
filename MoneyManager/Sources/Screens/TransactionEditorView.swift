import SwiftUI

struct TransactionEditorView: View {
    @Bindable var store: MoneyManagerStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Transaction type", selection: $store.formType) {
                        Text("Expense").tag(TransactionType.expense.rawValue)
                        Text("Income").tag(TransactionType.income.rawValue)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: store.formType) { _, newValue in
                        store.updateFormType(newValue)
                    }
                }

                Section("Details") {
                    LabeledContent("Amount") {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(store.summary?.currency ?? "EUR")
                                .foregroundStyle(AppColor.financeGreen)
                            TextField("0.00", text: $store.formAmount)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }

                    TextField("Description (optional)", text: $store.formDescription, axis: .vertical)
                        .lineLimit(1...3)
                        .textInputAutocapitalization(.sentences)

                    if store.formPurpose == "investment_transfer" {
                        CategorySelectorLabel(store: store)
                    } else {
                        NavigationLink {
                            CategoryPickerView(store: store)
                        } label: {
                            CategorySelectorLabel(store: store)
                        }
                    }

                    DatePicker("Date", selection: $store.formOccurredAt, in: ...Date(), displayedComponents: .date)
                }

                if store.formType == TransactionType.expense.rawValue {
                    Section {
                        Toggle("Investment transfer", isOn: investmentTransferBinding)

                        if store.formPurpose == "investment_transfer" {
                            Picker("Revolut X plan", selection: $store.formInvestmentScheduleID) {
                                Text("Not linked").tag(Int?.none)
                                ForEach(store.revolutXInvestmentSchedules) { schedule in
                                    Text("\(schedule.symbol) · \(MoneyFormat.amount(MoneyFormat.decimal(from: schedule.amount), currency: schedule.currency))")
                                        .tag(Int?.some(schedule.id))
                                }
                            }
                        }
                    } footer: {
                        Text("Investment transfers reduce cash, but are excluded from spending totals and budgets. Linking a plan prevents the matching Revolut X buy from being counted twice.")
                    }
                }

                if let error = store.error, !error.isEmpty {
                    Section {
                        Text(error)
                            .foregroundStyle(AppColor.expense)
                    }
                }
            }
            .interactiveDismissDisabled(store.hasTransactionDraft)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        store.cancelTransactionEditor()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: store.saveTransaction)
                        .disabled(store.isLoading)
                }
            }
        }
    }

    @MainActor
    private var title: String {
        if store.editingID != nil { return "Edit transaction" }
        return store.formType == TransactionType.income.rawValue ? "Add income" : "Add expense"
    }

    private var investmentTransferBinding: Binding<Bool> {
        Binding(
            get: { store.formPurpose == "investment_transfer" },
            set: store.setInvestmentTransfer
        )
    }
}

private struct CategorySelectorLabel: View {
    let store: MoneyManagerStore

    var body: some View {
        HStack(spacing: 13) {
            CategoryBadge(category: store.formCategory)
            VStack(alignment: .leading, spacing: 3) {
                Text("Category")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColor.mutedText)
                Text(categoryTitle(store.formCategory))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppColor.nearBlack)
            }
            Spacer()
        }
    }
}

struct CategoryPickerView: View {
    @Bindable var store: MoneyManagerStore
    @Environment(\.dismiss) private var dismiss
    @State private var categoryPendingDeletion: Category?

    var body: some View {
        List {
                Section {
                    ForEach(store.formCategoryOptions) { category in
                        CategoryPickerRow(
                            category: category,
                            isSelected: store.formCategory == category.name,
                            onSelect: {
                                store.chooseFormCategory(category.name)
                                dismiss()
                            },
                            onDelete: { categoryPendingDeletion = category }
                        )
                    }
                }

                Section("New category") {
                    HStack {
                        TextField("New category", text: $store.newCategoryName)

                        Button(action: store.addCategory) {
                            Label("Add", systemImage: "plus")
                        }
                        .disabled(store.isLoading)
                    }
                }

                if let error = store.error, !error.isEmpty {
                    Section {
                        Text(error)
                            .foregroundStyle(AppColor.expense)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Choose category")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: store.clearTransientError)
        .alert("Delete category?", isPresented: deleteConfirmationPresented, presenting: categoryPendingDeletion) { category in
            Button("Delete", role: .destructive) {
                store.deleteCategory(category)
                categoryPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                categoryPendingDeletion = nil
            }
        } message: { category in
            Text("\(categoryTitle(category.name)) will be removed from your category list. Existing transactions will not be deleted.")
        }
    }

    private var deleteConfirmationPresented: Binding<Bool> {
        Binding(
            get: { categoryPendingDeletion != nil },
            set: { if !$0 { categoryPendingDeletion = nil } }
        )
    }
}

private struct CategoryPickerRow: View {
    let category: Category
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                CategoryBadge(category: category.name, size: 36)
                Text(categoryTitle(category.name))
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(AppColor.financeGreen)
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !category.isDefault, category.id != 0 {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
                .tint(AppColor.expense)
            }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct ExportTransactionsView: View {
    @Bindable var store: MoneyManagerStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("From", selection: $store.exportFrom, in: ...store.exportTo, displayedComponents: .date)
                    DatePicker("To", selection: $store.exportTo, in: store.exportFrom...Date(), displayedComponents: .date)
                } footer: {
                    Text("Choose a date range and share a CSV copy of your transactions.")
                }

                if let error = store.error, !error.isEmpty {
                    Section {
                        Text(error)
                            .foregroundStyle(AppColor.expense)
                    }
                }
            }
            .interactiveDismissDisabled(store.isLoading)
            .navigationTitle("Export transactions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        store.cancelExport()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Export", action: store.exportTransactions)
                        .disabled(store.isLoading)
                }
            }
        }
    }
}
