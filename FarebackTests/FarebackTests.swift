import XCTest
@testable import Fareback

final class FarebackTests: XCTestCase {
    var store: FarebackStore!

    @MainActor
    override func setUp() {
        super.setUp()
        store = FarebackStore()
        store.deleteAllData()
        for r in store.routes { store.deleteRoute(r.id) }
    }

    @MainActor
    func testAddRoute() {
        let added = store.addRoute(name: "Office", mode: .drive, roundTripMiles: 20, transitFare: 0, daysPerWeek: 5, isPro: false)
        XCTAssertTrue(added)
        XCTAssertEqual(store.routes.count, 1)
        XCTAssertEqual(store.routes[0].name, "Office")
    }

    @MainActor
    func testAddRouteRejectsEmptyName() {
        let added = store.addRoute(name: "  ", mode: .drive, roundTripMiles: 20, transitFare: 0, daysPerWeek: 5, isPro: false)
        XCTAssertFalse(added)
    }

    @MainActor
    func testFreeLimitBlocksThirdRoute() {
        _ = store.addRoute(name: "A", mode: .drive, roundTripMiles: 20, transitFare: 0, daysPerWeek: 5, isPro: false)
        _ = store.addRoute(name: "B", mode: .transit, roundTripMiles: 0, transitFare: 5, daysPerWeek: 5, isPro: false)
        XCTAssertFalse(store.canAddRoute(isPro: false))
        let third = store.addRoute(name: "C", mode: .remote, roundTripMiles: 0, transitFare: 0, daysPerWeek: 2, isPro: false)
        XCTAssertFalse(third)
        XCTAssertEqual(store.routes.count, 2)
    }

    @MainActor
    func testProAllowsUnlimitedRoutes() {
        _ = store.addRoute(name: "A", mode: .drive, roundTripMiles: 20, transitFare: 0, daysPerWeek: 5, isPro: true)
        _ = store.addRoute(name: "B", mode: .transit, roundTripMiles: 0, transitFare: 5, daysPerWeek: 5, isPro: true)
        let third = store.addRoute(name: "C", mode: .remote, roundTripMiles: 0, transitFare: 0, daysPerWeek: 2, isPro: true)
        XCTAssertTrue(third)
        XCTAssertEqual(store.routes.count, 3)
    }

    @MainActor
    func testUpdateRoute() {
        _ = store.addRoute(name: "Office", mode: .drive, roundTripMiles: 20, transitFare: 0, daysPerWeek: 5, isPro: false)
        let id = store.routes[0].id
        store.updateRoute(id, name: "Office", mode: .drive, roundTripMiles: 30, transitFare: 0, daysPerWeek: 4)
        XCTAssertEqual(store.routes[0].roundTripMiles, 30)
        XCTAssertEqual(store.routes[0].daysPerWeek, 4)
    }

    @MainActor
    func testDeleteRoute() {
        _ = store.addRoute(name: "Office", mode: .drive, roundTripMiles: 20, transitFare: 0, daysPerWeek: 5, isPro: false)
        let id = store.routes[0].id
        store.deleteRoute(id)
        XCTAssertTrue(store.routes.isEmpty)
    }

    @MainActor
    func testToggleEnabled() {
        _ = store.addRoute(name: "Office", mode: .drive, roundTripMiles: 20, transitFare: 0, daysPerWeek: 5, isPro: false)
        let id = store.routes[0].id
        XCTAssertTrue(store.routes[0].isEnabled)
        store.toggleEnabled(id)
        XCTAssertFalse(store.routes[0].isEnabled)
    }

    // MARK: - Cost math

    func testDriveCostPerTrip() {
        let route = CommuteRoute(name: "Office", mode: .drive, roundTripMiles: 28, daysPerWeek: 5)
        // 28 miles / 28 mpg = 1 gallon; $3.50/gal -> $3.50 per trip
        XCTAssertEqual(route.costPerTrip(gasPricePerGallon: 3.50, mpg: 28), 3.50, accuracy: 0.001)
    }

    func testTransitCostPerTrip() {
        let route = CommuteRoute(name: "Bus", mode: .transit, transitFare: 5.75, daysPerWeek: 5)
        XCTAssertEqual(route.costPerTrip(gasPricePerGallon: 3.50, mpg: 28), 5.75, accuracy: 0.001)
    }

    func testRemoteCostIsZero() {
        let route = CommuteRoute(name: "WFH", mode: .remote, daysPerWeek: 2)
        XCTAssertEqual(route.costPerTrip(gasPricePerGallon: 3.50, mpg: 28), 0)
    }

    func testWeeklyCostMultipliesByDays() {
        let route = CommuteRoute(name: "Office", mode: .drive, roundTripMiles: 28, daysPerWeek: 4)
        XCTAssertEqual(route.weeklyCost(gasPricePerGallon: 3.50, mpg: 28), 14.0, accuracy: 0.001)
    }

    func testDriveCostZeroWhenMpgZero() {
        let route = CommuteRoute(name: "Office", mode: .drive, roundTripMiles: 28, daysPerWeek: 4)
        XCTAssertEqual(route.costPerTrip(gasPricePerGallon: 3.50, mpg: 0), 0)
    }

    func testWeeklyMilesSavedOnlyAppliesToRemote() {
        let remote = CommuteRoute(name: "WFH", mode: .remote, daysPerWeek: 3)
        XCTAssertEqual(remote.weeklyMilesSaved(baselineRoundTripMiles: 20), 60)
        let drive = CommuteRoute(name: "Office", mode: .drive, roundTripMiles: 20, daysPerWeek: 3)
        XCTAssertEqual(drive.weeklyMilesSaved(baselineRoundTripMiles: 20), 0)
    }

    // MARK: - Store-level derived totals

    @MainActor
    func testWeeklyTotalCostSumsEnabledRoutesOnly() {
        _ = store.addRoute(name: "Office", mode: .drive, roundTripMiles: 28, transitFare: 0, daysPerWeek: 5, isPro: true)
        _ = store.addRoute(name: "Bus", mode: .transit, roundTripMiles: 0, transitFare: 5, daysPerWeek: 5, isPro: true)
        store.settings.gasPricePerGallon = 3.50
        store.settings.mpg = 28
        // Office: 5 * 3.50 = 17.50; Bus: 5 * 5 = 25 -> total 42.50
        XCTAssertEqual(store.weeklyTotalCost, 42.50, accuracy: 0.01)

        store.toggleEnabled(store.routes[0].id)
        XCTAssertEqual(store.weeklyTotalCost, 25.0, accuracy: 0.01)
    }

    @MainActor
    func testYearlySavingsFromRemote() {
        _ = store.addRoute(name: "WFH", mode: .remote, roundTripMiles: 0, transitFare: 0, daysPerWeek: 2, isPro: true)
        store.settings.gasPricePerGallon = 3.50
        store.settings.mpg = 28
        store.settings.baselineRoundTripMiles = 28
        // remote miles/week = 28*2=56; cost/mile = 3.5/28=0.125; weekly saved = 7; yearly = 364
        XCTAssertEqual(store.yearlySavingsFromRemote, 364.0, accuracy: 0.01)
    }

    @MainActor
    func testDeleteAllDataReseeds() {
        _ = store.addRoute(name: "Extra", mode: .drive, roundTripMiles: 10, transitFare: 0, daysPerWeek: 1, isPro: true)
        store.deleteAllData()
        XCTAssertFalse(store.routes.isEmpty)
        XCTAssertEqual(store.settings.gasPricePerGallon, 3.50)
    }
}
