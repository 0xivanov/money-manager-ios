import Foundation
import Observation

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

@MainActor
@Observable
final class MoneyManagerStore {
    enum ActionScope: Hashable {
        case transactionEditor
        case export
        case importCSV
    }

    let api: MoneyManagerAPI
    let tokenStore: TokenStore
    @ObservationIgnored private let preferences: UserDefaults
    @ObservationIgnored var refreshTask: Task<Void, Never>?
    @ObservationIgnored var categoryClassificationTask: Task<Void, Never>?
    @ObservationIgnored var refreshGeneration = 0
    @ObservationIgnored var sessionGeneration = 0
    @ObservationIgnored var openBankingReloadRequested = false
    @ObservationIgnored var actionTasks: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored var scopedActionIDs: [ActionScope: UUID] = [:]
    @ObservationIgnored var activeRequestIDs: Set<UUID> = []

    var token: String?
    var email = ""
    var password = ""
    var selectedTab: AppTab = .dashboard
    var activeSheet: AppSheet?
    var isRegisterMode = false
    var isLoading = false
    var error: String?
    var dashboardLoadState: DashboardLoadState = .idle
    var connectionStatus: ConnectionStatus = .unknown
    var openBankingLoadState: OpenBankingLoadState = .idle
    var openBankingInstitutions: [OpenBankingInstitution] = []
    var openBankingConnections: [OpenBankingConnection] = []
    var openBankingAccounts: [OpenBankingAccount] = []
    var openBankingBalances: [Int: OpenBankingBalanceResponse] = [:]
    var openBankingBalanceLoadStates: [Int: OpenBankingLoadState] = [:]
    var openBankingAccountSnapshots: [Int: OpenBankingAccountSnapshot] = [:]
    var openBankingAccountLoadStates: [Int: OpenBankingLoadState] = [:]
    var openBankingCountry = OpenBankingRegion.defaultCode
    var openBankingCallbackState: OpenBankingCallbackState = .idle
    var openBankingError: String?
    var isLoadingOpenBankingInstitutions = false
    var isStartingOpenBankingAuthorization = false
    var isDeletingOpenBankingConnection = false
    var isDeletingAccount = false
    var month = DateFormat.currentMonthKey()
    var filterType: String?
    var filterCategory: String?
    var searchQuery = ""
    var summary: TransactionSummary?
    var transactions: [Transaction] = []
    var selectedExpenseCategory: String?
    var editingID: Int?
    var formType = TransactionType.expense.rawValue
    var formCategory = "groceries"
    var formDescription = ""
    var formAmount = ""
    var formOccurredAt = Date()
    var expenseCategories: [Category] = []
    var incomeCategories: [Category] = []
    var newCategoryName = ""
    var exportFrom = DateFormat.firstDayDate(of: DateFormat.currentMonthKey())
    var exportTo = Date()
    var exportShareItem: ExportShareItem?
    var importResultMessage: String?
    var isImporting = false
    var growth: GrowthStore
    var hidePortfolioBalances: Bool {
        didSet {
            preferences.set(hidePortfolioBalances, forKey: PreferenceKey.hidePortfolioBalances)
        }
    }
    var appAppearance: AppAppearance {
        didSet {
            preferences.set(appAppearance.rawValue, forKey: PreferenceKey.appAppearance)
        }
    }

    init(
        api: MoneyManagerAPI = MoneyManagerAPI(),
        tokenStore: TokenStore = TokenStore(),
        preferences: UserDefaults = .standard
    ) {
        self.api = api
        self.tokenStore = tokenStore
        self.preferences = preferences
        self.token = tokenStore.getToken()
        self.growth = GrowthStore(api: api)
        self.hidePortfolioBalances = preferences.object(
            forKey: PreferenceKey.hidePortfolioBalances
        ) as? Bool ?? true
        self.appAppearance = preferences.string(forKey: PreferenceKey.appAppearance)
            .flatMap(AppAppearance.init(rawValue:)) ?? .system
    }

    var isAuthenticated: Bool {
        token != nil
    }

    var apiBaseURL: URL {
        api.baseURL
    }
}

private enum PreferenceKey {
    static let hidePortfolioBalances = "privacy.hidePortfolioBalances"
    static let appAppearance = "appearance"
}
