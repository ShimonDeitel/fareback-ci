import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: FarebackStore
    @EnvironmentObject private var purchases: PurchaseManager
    @AppStorage("fareback_haptics_enabled") private var hapticsEnabled: Bool = true
    @State private var activeSheet: FarebackSheet?
    @State private var showResetConfirm = false
    @State private var restoreMessage: String?
    @State private var gasPriceText: String = ""
    @State private var mpgText: String = ""
    @State private var baselineMilesText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Cost Assumptions") {
                    HStack {
                        Text("Gas price ($/gal)")
                        Spacer()
                        TextField("3.50", text: $gasPriceText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("gasPriceField")
                            .onChange(of: gasPriceText) { _, newValue in
                                if let v = Double(newValue) { store.settings.gasPricePerGallon = v; store.save() }
                            }
                    }
                    HStack {
                        Text("Car MPG")
                        Spacer()
                        TextField("28", text: $mpgText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("mpgField")
                            .onChange(of: mpgText) { _, newValue in
                                if let v = Double(newValue) { store.settings.mpg = v; store.save() }
                            }
                    }
                    HStack {
                        Text("Baseline commute miles")
                        Spacer()
                        TextField("20", text: $baselineMilesText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("baselineMilesField")
                            .onChange(of: baselineMilesText) { _, newValue in
                                if let v = Double(newValue) { store.settings.baselineRoundTripMiles = v; store.save() }
                            }
                    }
                }

                Section("Preferences") {
                    Toggle("Haptic feedback", isOn: $hapticsEnabled)
                        .accessibilityIdentifier("hapticsToggle")
                }

                Section("Fareback Pro") {
                    if purchases.isPro {
                        Label("Pro unlocked", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(FBTheme.rust)
                    } else {
                        Button("Upgrade to Pro") {
                            activeSheet = .paywall
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("upgradeProButton")
                    }
                    Button("Restore Purchases") {
                        Task {
                            await purchases.restore()
                            restoreMessage = purchases.isPro ? "Purchases restored." : "No purchases found."
                        }
                    }
                    .buttonStyle(.plain)
                    if let restoreMessage {
                        Text(restoreMessage)
                            .font(.caption)
                            .foregroundStyle(FBTheme.inkFaded)
                    }
                }

                Section("About") {
                    Link("Privacy Policy", destination: URL(string: "https://shimondeitel.github.io/fareback-site/privacy.html")!)
                    Link("Contact Support", destination: URL(string: "mailto:s0533495227@gmail.com")!)
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0")
                            .foregroundStyle(FBTheme.inkFaded)
                    }
                }

                Section {
                    Button("Reset All Data", role: .destructive) {
                        showResetConfirm = true
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Settings")
            .dismissKeyboardOnTap()
            .onAppear {
                gasPriceText = String(store.settings.gasPricePerGallon)
                mpgText = String(store.settings.mpg)
                baselineMilesText = String(store.settings.baselineRoundTripMiles)
            }
            .confirmationDialog(
                "Reset all routes and settings?",
                isPresented: $showResetConfirm,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) {
                    store.deleteAllData()
                    gasPriceText = String(store.settings.gasPricePerGallon)
                    mpgText = String(store.settings.mpg)
                    baselineMilesText = String(store.settings.baselineRoundTripMiles)
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .paywall:
                    PaywallView()
                default:
                    EmptyView()
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(FarebackStore())
        .environmentObject(PurchaseManager())
}
