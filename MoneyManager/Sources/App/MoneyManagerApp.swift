import SwiftUI

@main
@MainActor
struct MoneyManagerApp: App {
    @State private var store = MoneyManagerStore()

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-open-banking-preview") {
                OpenBankingPreviewHost(
                    isEmpty: ProcessInfo.processInfo.arguments.contains("-open-banking-preview-empty")
                )
            } else {
                AppRootView(store: store)
            }
            #else
            AppRootView(store: store)
            #endif
        }
    }
}
