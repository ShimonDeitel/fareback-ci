import SwiftUI

@main
struct FarebackApp: App {
    @StateObject private var store = FarebackStore()
    @StateObject private var purchases = PurchaseManager()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(store)
                .environmentObject(purchases)
        }
    }
}
