import SwiftUI

@main
@MainActor
struct MoneyManagerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = MoneyManagerStore()

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-investment-preview") {
                GrowthPreviewHost(kind: .investments)
            } else if ProcessInfo.processInfo.arguments.contains("-planning-preview") {
                GrowthPreviewHost(kind: .planning)
            } else if ProcessInfo.processInfo.arguments.contains("-open-banking-preview") {
                OpenBankingPreviewHost(
                    isEmpty: ProcessInfo.processInfo.arguments.contains("-open-banking-preview-empty")
                )
            } else if ProcessInfo.processInfo.arguments.contains("-ai-insights-preview") {
                AIInsightsPreviewHost()
            } else {
                AppRootView(store: store)
            }
            #else
            AppRootView(store: store)
            #endif
        }
    }
}
