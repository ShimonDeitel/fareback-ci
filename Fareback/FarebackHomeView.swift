import SwiftUI

struct FarebackHomeView: View {
    @EnvironmentObject private var store: FarebackStore
    @EnvironmentObject private var purchases: PurchaseManager
    @State private var activeSheet: FarebackSheet?
    @State private var animatedOdometer: Double = 0

    var body: some View {
        NavigationStack {
            ZStack {
                FBTheme.backdrop.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        HStack {
                            Text("Fareback")
                                .font(FBTheme.titleFont)
                                .foregroundStyle(FBTheme.ink)
                            Spacer()
                            Button {
                                if store.canAddRoute(isPro: purchases.isPro) {
                                    activeSheet = .addRoute
                                } else {
                                    activeSheet = .paywall
                                }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(FBTheme.rust)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("addRouteButton")
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 8)

                        odometerCard
                        costSummaryCard

                        if store.routes.isEmpty {
                            emptyState
                        } else {
                            routesList
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                withAnimation(.easeOut(duration: 1.2)) {
                    animatedOdometer = store.yearlySavingsFromRemote
                }
            }
            .onChange(of: store.yearlySavingsFromRemote) { _, newValue in
                withAnimation(.easeOut(duration: 0.8)) {
                    animatedOdometer = newValue
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .addRoute:
                    RouteFormView(existing: nil)
                case .editRoute(let route):
                    RouteFormView(existing: route)
                case .paywall:
                    PaywallView()
                }
            }
        }
    }

    /// Quirky signature feature: a mechanical highway-odometer strip that
    /// visibly rolls up year-equivalent dollars saved from remote days,
    /// like the digits on a car's dashboard odometer.
    private var odometerCard: some View {
        VStack(spacing: 10) {
            Text("SAVED THIS YEAR BY STAYING HOME")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.7))
                .tracking(1.0)

            OdometerStrip(value: animatedOdometer)
                .accessibilityIdentifier("odometerStrip")
                .accessibilityValue("\(Int(animatedOdometer)) dollars saved")

            Text("\(Int(store.yearlyMilesSaved)) miles not driven")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(FBTheme.ink)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 18)
    }

    private var costSummaryCard: some View {
        HStack(spacing: 24) {
            summaryTile(label: "Weekly", value: store.weeklyTotalCost)
            summaryTile(label: "Monthly", value: store.monthlyTotalCost)
            summaryTile(label: "Yearly", value: store.yearlyTotalCost)
        }
        .padding(.horizontal, 18)
    }

    private func summaryTile(label: String, value: Double) -> some View {
        VStack(spacing: 4) {
            Text("$\(Int(value))")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(FBTheme.rust)
                .accessibilityIdentifier("summaryTile_\(label)")
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(FBTheme.inkFaded)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(FBTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(FBTheme.rule, lineWidth: 1))
    }

    private var routesList: some View {
        VStack(spacing: 10) {
            ForEach(store.routes) { route in
                RouteRow(
                    route: route,
                    weeklyCost: route.weeklyCost(gasPricePerGallon: store.settings.gasPricePerGallon, mpg: store.settings.mpg),
                    onToggle: { store.toggleEnabled(route.id) },
                    onEdit: { activeSheet = .editRoute(route) }
                )
            }
        }
        .padding(.horizontal, 18)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "car.fill")
                .font(.system(size: 48))
                .foregroundStyle(FBTheme.inkFaded)
            Text("No commute routes yet")
                .font(FBTheme.headlineFont)
                .foregroundStyle(FBTheme.ink)
            Text("Add a route to start tracking cost vs. staying home.")
                .font(.subheadline)
                .foregroundStyle(FBTheme.inkFaded)
        }
        .padding(.top, 24)
        .padding(.horizontal, 18)
    }
}

/// A dashboard-style odometer: fixed-width monospaced digit slots on a
/// dark strip, with a subtle rolling number-transition animation as the
/// underlying value changes.
struct OdometerStrip: View {
    let value: Double

    private var digits: [Character] {
        let clamped = max(0, min(value, 999999))
        let text = String(format: "%06d", Int(clamped))
        return Array(text)
    }

    var body: some View {
        HStack(spacing: 3) {
            Text("$")
                .font(.system(size: 30, weight: .heavy, design: .monospaced))
                .foregroundStyle(FBTheme.rustBright)
            ForEach(Array(digits.enumerated()), id: \.offset) { _, digit in
                Text(String(digit))
                    .font(.system(size: 30, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(width: 20)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .contentTransition(.numericText())
                    .animation(.spring(), value: digit)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct RouteRow: View {
    let route: CommuteRoute
    let weeklyCost: Double
    var onToggle: () -> Void
    var onEdit: () -> Void

    private var iconName: String {
        switch route.mode {
        case .drive: return "car.fill"
        case .transit: return "bus.fill"
        case .remote: return "house.fill"
        }
    }

    var body: some View {
        HStack {
            Button(action: onEdit) {
                HStack(spacing: 12) {
                    Image(systemName: iconName)
                        .foregroundStyle(FBTheme.rust)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(route.name)
                            .font(FBTheme.headlineFont)
                            .foregroundStyle(FBTheme.ink)
                        Text("\(route.mode.rawValue) · \(route.daysPerWeek)x/week · $\(String(format: "%.2f", weeklyCost))/wk")
                            .font(.caption)
                            .foregroundStyle(FBTheme.inkFaded)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Toggle("", isOn: Binding(get: { route.isEnabled }, set: { _ in onToggle() }))
                .labelsHidden()
                .tint(FBTheme.signGreen)
                .accessibilityIdentifier("enableRouteToggle_\(route.name)")
        }
        .padding(12)
        .background(FBTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(FBTheme.rule, lineWidth: 1))
    }
}

#Preview {
    FarebackHomeView()
        .environmentObject(FarebackStore())
        .environmentObject(PurchaseManager())
}
