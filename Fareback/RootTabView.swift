import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            FarebackHomeView()
                .tabItem {
                    Label("Commute", systemImage: "car.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(FBTheme.rust)
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(FBTheme.surface)
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

#Preview {
    RootTabView()
        .environmentObject(FarebackStore())
        .environmentObject(PurchaseManager())
}
