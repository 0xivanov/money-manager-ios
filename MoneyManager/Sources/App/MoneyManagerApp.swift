import SwiftUI

@main
@MainActor
struct MoneyManagerApp: App {
    @State private var store = MoneyManagerStore()

    var body: some Scene {
        WindowGroup {
            AppRootView(store: store)
        }
    }
}
