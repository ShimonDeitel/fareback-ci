import Foundation

enum CommuteMode: String, Codable, CaseIterable, Identifiable {
    case drive = "Drive"
    case transit = "Transit"
    case remote = "Remote"

    var id: String { rawValue }
}

/// A single commute route the user tracks: cost per round trip and how
/// many days a week they make it. Remote days have zero direct cost but
/// still count toward the "days back" quirky odometer as full savings.
struct CommuteRoute: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var mode: CommuteMode
    /// Round-trip miles driven (drive mode only; used with mpg + gas price).
    var roundTripMiles: Double
    /// Fixed round-trip fare (transit mode only).
    var transitFare: Double
    var daysPerWeek: Int
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        mode: CommuteMode,
        roundTripMiles: Double = 0,
        transitFare: Double = 0,
        daysPerWeek: Int = 5,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.mode = mode
        self.roundTripMiles = roundTripMiles
        self.transitFare = transitFare
        self.daysPerWeek = daysPerWeek
        self.isEnabled = isEnabled
    }

    /// Cost of one round trip given shared assumptions.
    func costPerTrip(gasPricePerGallon: Double, mpg: Double) -> Double {
        switch mode {
        case .drive:
            guard mpg > 0 else { return 0 }
            return (roundTripMiles / mpg) * gasPricePerGallon
        case .transit:
            return transitFare
        case .remote:
            return 0
        }
    }

    func weeklyCost(gasPricePerGallon: Double, mpg: Double) -> Double {
        costPerTrip(gasPricePerGallon: gasPricePerGallon, mpg: mpg) * Double(daysPerWeek)
    }

    /// Miles NOT driven on remote days, vs. a baseline commute distance.
    /// Used for the "miles saved" side of the odometer.
    func weeklyMilesSaved(baselineRoundTripMiles: Double) -> Double {
        guard mode == .remote else { return 0 }
        return baselineRoundTripMiles * Double(daysPerWeek)
    }
}

/// Shared assumptions used to price drive-mode routes.
struct FarebackSettings: Codable, Equatable {
    var gasPricePerGallon: Double = 3.50
    var mpg: Double = 28
    /// Baseline round-trip miles assumed for remote-day savings comparisons.
    var baselineRoundTripMiles: Double = 20
}
