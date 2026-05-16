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
                            Text("EUR")
                                .foregroundStyle(AppColor.financeGreen)
                            TextField("0.00", text: $store.formAmount)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }

                    CategorySelectorCard(store: store)

                    DatePicker("Date", selection: $store.formOccurredAt, displayedComponents: .date)
                }

                if let error = store.error, !error.isEmpty {
                    Section {
                        Text(error)
                            .foregroundStyle(AppColor.expense)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        store.activeSheet = nil
                        store.clearForm()
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
}

private struct CategorySelectorCard: View {
    @Bindable var store: MoneyManagerStore

    var body: some View {
        Button {
            store.activeSheet = .categoryPicker
        } label: {
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
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

struct CategoryPickerView: View {
    @Bindable var store: MoneyManagerStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.formCategoryOptions) { category in
                        CategoryPickerRow(category: category, isSelected: store.formCategory == category.name, store: store)
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
        }
    }
}

private struct CategoryPickerRow: View {
    let category: Category
    let isSelected: Bool
    @Bindable var store: MoneyManagerStore

    var body: some View {
        Button {
            store.chooseFormCategory(category.name)
        } label: {
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
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if !category.isDefault, category.id != 0 {
                Button(role: .destructive) {
                    store.deleteCategory(category)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .tint(AppColor.expense)
            }
        }
    }
}

private struct ExportField: View {
    let title: String
    @Binding var date: Date

    var body: some View {
        DatePicker(title, selection: $date, displayedComponents: .date)
    }
}

struct ExportTransactionsView: View {
    @Bindable var store: MoneyManagerStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ExportField(title: "From", date: $store.exportFrom)
                    ExportField(title: "To", date: $store.exportTo)
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
            .navigationTitle("Export transactions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        store.activeSheet = nil
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
