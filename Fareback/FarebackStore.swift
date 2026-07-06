import Foundation
import Combine

@MainActor
final class FarebackStore: ObservableObject {
    @Published private(set) var routes: [CommuteRoute] = []
    @Published var settings = FarebackSettings()

    static let freeRouteLimit = 2

    private let fileURL: URL

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("fareback_data.json")
        if ProcessInfo.processInfo.arguments.contains("-uiTestReset") {
            try? FileManager.default.removeItem(at: fileURL)
        }
        load()
        if routes.isEmpty {
            seedDefaults()
        }
    }

    private func seedDefaults() {
        routes = [
            CommuteRoute(name: "Office Commute", mode: .drive, roundTripMiles: 24, daysPerWeek: 3),
            CommuteRoute(name: "Work From Home", mode: .remote, daysPerWeek: 2)
        ]
        save()
    }

    func canAddRoute(isPro: Bool) -> Bool {
        isPro || routes.count < Self.freeRouteLimit
    }

    @discardableResult
    func addRoute(name: String, mode: CommuteMode, roundTripMiles: Double, transitFare: Double, daysPerWeek: Int, isPro: Bool) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, daysPerWeek > 0, canAddRoute(isPro: isPro) else { return false }
        routes.append(CommuteRoute(name: trimmed, mode: mode, roundTripMiles: roundTripMiles, transitFare: transitFare, daysPerWeek: daysPerWeek))
        save()
        return true
    }

    func updateRoute(_ id: UUID, name: String, mode: CommuteMode, roundTripMiles: Double, transitFare: Double, daysPerWeek: Int) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, daysPerWeek > 0, let idx = routes.firstIndex(where: { $0.id == id }) else { return }
        routes[idx].name = trimmed
        routes[idx].mode = mode
        routes[idx].roundTripMiles = roundTripMiles
        routes[idx].transitFare = transitFare
        routes[idx].daysPerWeek = daysPerWeek
        save()
    }

    func deleteRoute(_ id: UUID) {
        routes.removeAll { $0.id == id }
        save()
    }

    func toggleEnabled(_ id: UUID) {
        guard let idx = routes.firstIndex(where: { $0.id == id }) else { return }
        routes[idx].isEnabled.toggle()
        save()
    }

    func deleteAllData() {
        routes = []
        settings = FarebackSettings()
        seedDefaults()
    }

    // MARK: - Derived totals

    var weeklyTotalCost: Double {
        routes.filter(\.isEnabled).reduce(0) { $0 + $1.weeklyCost(gasPricePerGallon: settings.gasPricePerGallon, mpg: settings.mpg) }
    }

    var monthlyTotalCost: Double { weeklyTotalCost * 4.33 }

    var yearlyTotalCost: Double { weeklyTotalCost * 52 }

    /// Quirky "highway odometer" figure: total dollars saved by remote
    /// days, computed against the baseline commute cost, rolled up
    /// year-to-date-equivalent (52 weeks) for a satisfying big number.
    var yearlySavingsFromRemote: Double {
        let remoteMilesPerWeek = routes.filter { $0.isEnabled && $0.mode == .remote }
            .reduce(0.0) { $0 + $1.weeklyMilesSaved(baselineRoundTripMiles: settings.baselineRoundTripMiles) }
        guard settings.mpg > 0 else { return 0 }
        let costPerMile = settings.gasPricePerGallon / settings.mpg
        return remoteMilesPerWeek * costPerMile * 52
    }

    var yearlyMilesSaved: Double {
        routes.filter { $0.isEnabled && $0.mode == .remote }
            .reduce(0.0) { $0 + $1.weeklyMilesSaved(baselineRoundTripMiles: settings.baselineRoundTripMiles) } * 52
    }

    // MARK: - Persistence

    private struct Snapshot: Codable {
        var routes: [CommuteRoute]
        var settings: FarebackSettings
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if let decoded = try? JSONDecoder().decode(Snapshot.self, from: data) {
            routes = decoded.routes
            settings = decoded.settings
        }
    }

    func save() {
        let snapshot = Snapshot(routes: routes, settings: settings)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
