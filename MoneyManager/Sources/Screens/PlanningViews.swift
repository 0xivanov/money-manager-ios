import SwiftUI
import UserNotifications
import UIKit

struct ScheduledMoneyView: View {
    @Bindable var store: MoneyManagerStore
    @State private var isEditorPresented = false

    private var growth: GrowthStore { store.growth }

    var body: some View {
        List {
            if let error = growth.error {
                Section { ErrorBanner(message: error) }
            }

            Section {
                if growth.transactionSchedules.isEmpty && !growth.isLoadingPlanning {
                    ContentUnavailableView(
                        "No scheduled money",
                        systemImage: "calendar.badge.plus",
                        description: Text("Plan recurring income and expenses by day, week, or month.")
                    )
                } else {
                    ForEach(growth.transactionSchedules) { schedule in
                        ScheduleRow(schedule: schedule)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    guard let token = store.token else { return }
                                    Task { await growth.deleteTransactionSchedule(token: token, id: schedule.id) }
                                } label: {
                                    Label("Archive", systemImage: "archivebox")
                                }
                                Button {
                                    guard let token = store.token else { return }
                                    Task { await growth.toggleTransactionSchedule(token: token, schedule: schedule) }
                                } label: {
                                    Label(schedule.status == "paused" ? "Resume" : "Pause", systemImage: schedule.status == "paused" ? "play.fill" : "pause.fill")
                                }
                                .tint(AppColor.financeGreen)
                            }
                    }
                }
            } header: {
                Text("Plans")
            } footer: {
                Text("Automatic posting creates a transaction on its scheduled date. Turn it off when you only want a forecast.")
            }

            if !growth.scheduleOccurrences.isEmpty {
                Section("Next 90 days") {
                    ForEach(growth.scheduleOccurrences.prefix(12)) { occurrence in
                        HStack(spacing: 12) {
                            Image(systemName: occurrence.type == "income" ? "arrow.down.left" : "arrow.up.right")
                                .foregroundStyle(occurrence.type == "income" ? AppColor.income : AppColor.expense)
                                .frame(width: 34, height: 34)
                                .background((occurrence.type == "income" ? AppColor.income : AppColor.expense).opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(occurrence.name).font(.subheadline.weight(.semibold))
                                Text("\(occurrence.scheduledFor) · \(categoryTitle(occurrence.category))")
                                    .font(.caption).foregroundStyle(AppColor.mutedText)
                            }
                            Spacer()
                            Text(MoneyFormat.amount(MoneyFormat.decimal(from: occurrence.amount), currency: occurrence.currency))
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Scheduled money")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { isEditorPresented = true } label: { Label("New schedule", systemImage: "plus") }
            }
        }
        .overlay {
            if growth.isLoadingPlanning && growth.transactionSchedules.isEmpty { ProgressView() }
        }
        .refreshable { await load(force: true) }
        .task { await load(force: false) }
        .sheet(isPresented: $isEditorPresented) {
            ScheduleEditorView(store: store, isPresented: $isEditorPresented)
        }
    }

    private func load(force: Bool) async {
        guard let token = store.token else { return }
        await growth.loadPlanning(token: token, force: force)
    }
}

private struct ScheduleRow: View {
    let schedule: TransactionSchedule

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: schedule.type == "income" ? "arrow.down.left.circle.fill" : "arrow.up.right.circle.fill")
                .font(.title2)
                .foregroundStyle(schedule.type == "income" ? AppColor.income : AppColor.expense)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(schedule.name).font(.headline)
                    if schedule.status == "paused" {
                        Text("PAUSED").font(.caption2.weight(.bold)).foregroundStyle(AppColor.mutedText)
                    }
                }
                Text(scheduleDescription(schedule))
                    .font(.caption).foregroundStyle(AppColor.mutedText)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(MoneyFormat.amount(MoneyFormat.decimal(from: schedule.amount), currency: schedule.currency))
                    .font(.subheadline.weight(.bold).monospacedDigit())
                if let next = schedule.nextOccurrenceDate {
                    Text(next).font(.caption2).foregroundStyle(AppColor.mutedText)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

private struct ScheduleEditorView: View {
    @Bindable var store: MoneyManagerStore
    @Binding var isPresented: Bool
    @State private var type = "expense"
    @State private var name = ""
    @State private var category = "food"
    @State private var description = ""
    @State private var amount = ""
    @State private var frequency = "monthly"
    @State private var interval = 1
    @State private var startDate = Date()
    @State private var autoPost = true

    private var categories: [Category] {
        type == "income" ? store.incomeCategories : store.expenseCategories
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Money") {
                    Picker("Type", selection: $type) {
                        Text("Expense").tag("expense")
                        Text("Income").tag("income")
                    }
                    .pickerStyle(.segmented)
                    TextField("Name, for example Rent", text: $name)
                    Picker("Category", selection: $category) {
                        ForEach(categories) { Text(categoryTitle($0.name)).tag($0.name) }
                    }
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    TextField("Optional note", text: $description, axis: .vertical)
                }
                Section("Timing") {
                    Picker("Repeats", selection: $frequency) {
                        Text("Daily").tag("daily")
                        Text("Weekly").tag("weekly")
                        Text("Monthly").tag("monthly")
                    }
                    Stepper("Every \(interval) \(frequencyUnit)", value: $interval, in: 1...365)
                    DatePicker("Starts", selection: $startDate, in: Calendar.current.startOfDay(for: Date())..., displayedComponents: .date)
                    Toggle("Create transaction automatically", isOn: $autoPost)
                }
                if let error = store.growth.error { Section { ErrorBanner(message: error) } }
            }
            .navigationTitle("New schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isPresented = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(store.growth.isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || amount.isEmpty || categories.isEmpty)
                }
            }
            .onChange(of: type) { _, newValue in
                let options = newValue == "income" ? store.incomeCategories : store.expenseCategories
                category = options.first?.name ?? ""
            }
            .onAppear {
                category = categories.first?.name ?? category
            }
        }
    }

    private var frequencyUnit: String {
        switch frequency {
        case "daily": interval == 1 ? "day" : "days"
        case "weekly": interval == 1 ? "week" : "weeks"
        default: interval == 1 ? "month" : "months"
        }
    }

    private func save() async {
        guard let token = store.token else { return }
        let day = Calendar.current.component(.weekday, from: startDate)
        let isoWeekday = day == 1 ? 7 : day - 1
        let request = TransactionScheduleRequest(
            type: type,
            name: name,
            category: category,
            description: description,
            amount: normalizedNumericInput(amount),
            currency: "EUR",
            frequency: frequency,
            frequencyInterval: interval,
            startDate: DateFormat.isoDate.string(from: startDate),
            endDate: nil,
            dayOfWeek: frequency == "weekly" ? isoWeekday : nil,
            dayOfMonth: frequency == "monthly" ? Calendar.current.component(.day, from: startDate) : nil,
            timezone: TimeZone.current.identifier,
            autoPost: autoPost
        )
        if await store.growth.createTransactionSchedule(token: token, request: request) {
            isPresented = false
        }
    }
}

struct BudgetsView: View {
    @Bindable var store: MoneyManagerStore
    @State private var isEditorPresented = false

    var body: some View {
        List {
            if let error = store.growth.error { Section { ErrorBanner(message: error) } }
            Section {
                if store.growth.budgets.isEmpty && !store.growth.isLoadingPlanning {
                    ContentUnavailableView(
                        "No budgets yet",
                        systemImage: "gauge.with.dots.needle.50percent",
                        description: Text("Set an overall or category limit and choose when to be warned.")
                    )
                } else {
                    ForEach(store.growth.budgets) { budget in
                        BudgetRow(budget: budget)
                            .swipeActions {
                                Button(role: .destructive) {
                                    guard let token = store.token else { return }
                                    Task { await store.growth.deleteBudget(token: token, id: budget.id) }
                                } label: { Label("Archive", systemImage: "archivebox") }
                            }
                    }
                }
            } footer: {
                Text("Only booked expenses are counted. You can exclude individual manual transactions from budgets.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Budgets")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { isEditorPresented = true } label: { Label("New budget", systemImage: "plus") }
            }
        }
        .task { await load(false) }
        .refreshable { await load(true) }
        .sheet(isPresented: $isEditorPresented) {
            BudgetEditorView(store: store, isPresented: $isEditorPresented)
        }
    }

    private func load(_ force: Bool) async {
        guard let token = store.token else { return }
        await store.growth.loadPlanning(token: token, force: force)
    }
}

private struct BudgetRow: View {
    let budget: Budget

    private var progress: Double {
        min(max(Double(budget.progressPercent) ?? 0, 0), 100) / 100
    }

    private var tint: Color {
        switch budget.alertLevel {
        case "exceeded": AppColor.expense
        case "approaching": AppColor.crypto
        default: AppColor.financeGreen
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(budget.name).font(.headline)
                    Text((budget.category?.isEmpty == false ? categoryTitle(budget.category ?? "") : "All spending") + " · " + categoryTitle(budget.period))
                        .font(.caption).foregroundStyle(AppColor.mutedText)
                }
                Spacer()
                Text("\(budget.progressPercent)%")
                    .font(.subheadline.weight(.bold).monospacedDigit()).foregroundStyle(tint)
            }
            ProgressView(value: progress).tint(tint)
            HStack {
                Text("Spent \(MoneyFormat.amount(MoneyFormat.decimal(from: budget.spentAmount), currency: budget.currency))")
                Spacer()
                Text("Limit \(MoneyFormat.amount(MoneyFormat.decimal(from: budget.amount), currency: budget.currency))")
            }
            .font(.caption).foregroundStyle(AppColor.mutedText)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

private struct BudgetEditorView: View {
    @Bindable var store: MoneyManagerStore
    @Binding var isPresented: Bool
    @State private var name = ""
    @State private var category = ""
    @State private var amount = ""
    @State private var period = "monthly"
    @State private var threshold = 80

    var body: some View {
        NavigationStack {
            Form {
                Section("Limit") {
                    TextField("Budget name", text: $name)
                    Picker("Scope", selection: $category) {
                        Text("All spending").tag("")
                        ForEach(store.expenseCategories) { Text(categoryTitle($0.name)).tag($0.name) }
                    }
                    TextField("Amount", text: $amount).keyboardType(.decimalPad)
                    Picker("Period", selection: $period) {
                        Text("Weekly").tag("weekly")
                        Text("Monthly").tag("monthly")
                    }
                }
                Section("Alert") {
                    Stepper("Warn at \(threshold)%", value: $threshold, in: 50...100, step: 5)
                    Text("A second alert is generated when the full limit is reached.")
                        .font(.caption).foregroundStyle(AppColor.mutedText)
                }
                if let error = store.growth.error { Section { ErrorBanner(message: error) } }
            }
            .navigationTitle("New budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isPresented = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || amount.isEmpty || store.growth.isSaving)
                }
            }
        }
    }

    private func save() async {
        guard let token = store.token else { return }
        let request = BudgetRequest(
            name: name,
            category: category.isEmpty ? nil : category,
            amount: normalizedNumericInput(amount),
            currency: "EUR",
            period: period,
            warningThreshold: threshold
        )
        if await store.growth.createBudget(token: token, request: request) {
            isPresented = false
        }
    }
}

struct NotificationPreferencesView: View {
    @Bindable var store: MoneyManagerStore
    @State private var preferences = NotificationPreferences.defaults
    @State private var authorizationStatus = "Not requested"

    var body: some View {
        Form {
            Section("Alerts") {
                Toggle("Bank spending", isOn: $preferences.bankSpending)
                Toggle("Budget limits", isOn: $preferences.budgetAlerts)
                Toggle("Scheduled money", isOn: $preferences.scheduledMoney)
                Toggle("Investment reminders", isOn: $preferences.investmentReminders)
            }
            Section {
                LabeledContent("Device permission", value: authorizationStatus)
                Button("Enable push notifications") { Task { await requestPermission() } }
            } footer: {
                Text("Money Manager only sends the alert types enabled above. Bank and broker access remains read-only.")
            }
            if let error = store.growth.error { Section { ErrorBanner(message: error) } }
        }
        .navigationTitle("Notifications")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { Task { await save() } }.disabled(store.growth.isSaving)
            }
        }
        .task {
            guard let token = store.token else { return }
            await store.growth.loadPlanning(token: token)
            preferences = store.growth.notificationPreferences
            await refreshAuthorizationStatus()
        }
    }

    private func save() async {
        guard let token = store.token else { return }
        preferences.timezone = TimeZone.current.identifier
        _ = await store.growth.saveNotificationPreferences(token: token, preferences: preferences)
    }

    private func requestPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
            }
            await refreshAuthorizationStatus()
        } catch {
            store.growth.error = error.localizedDescription
        }
    }

    private func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: "Enabled"
        case .denied: "Disabled in Settings"
        case .notDetermined: "Not requested"
        @unknown default: "Unknown"
        }
    }
}

private func scheduleDescription(_ schedule: TransactionSchedule) -> String {
    let cadence = schedule.frequencyInterval == 1
        ? categoryTitle(schedule.frequency)
        : "Every \(schedule.frequencyInterval) \(schedule.frequency)"
    return "\(cadence) · \(categoryTitle(schedule.category))" + (schedule.autoPost ? " · Auto" : " · Forecast")
}

func normalizedNumericInput(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: Locale.current.decimalSeparator ?? ".", with: ".")
}
