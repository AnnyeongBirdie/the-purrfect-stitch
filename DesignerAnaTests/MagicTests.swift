//
//  MagicTests.swift
//  DesignerAnaTests
//
//  Magic.shared is a real singleton (its init reads Store.loadMagicPoints()),
//  so every test resets `points` directly rather than trying to reconstruct
//  the instance.
//

import XCTest
@testable import DesignerAna

final class MagicTests: XCTestCase {

    override func setUpWithError() throws {
        Magic.shared.points = 0
    }

    override func tearDownWithError() throws {
        Magic.shared.points = 0
        UserDefaults.standard.removeObject(forKey: "magic.points")
    }

    func testAddBelowFirstThresholdReturnsNil() {
        XCTAssertNil(Magic.shared.add(50))
        XCTAssertEqual(Magic.shared.points, 50)
    }

    func testAddCrossingLevelOneReturnsLevelOneExactlyOnce() {
        Magic.shared.points = 470
        XCTAssertEqual(Magic.shared.add(50), .levelOne, "The call that crosses 500 must report it")
        XCTAssertEqual(Magic.shared.points, 520)

        XCTAssertNil(Magic.shared.add(10), "A later call must not re-report a threshold already passed")
    }

    func testAddCrossingLevelTwoReturnsLevelTwoExactlyOnce() {
        Magic.shared.points = 980
        XCTAssertEqual(Magic.shared.add(30), .levelTwo, "The call that crosses 1000 must report it")
        XCTAssertEqual(Magic.shared.points, 1010)

        XCTAssertNil(Magic.shared.add(10))
    }

    func testASingleAddCanOnlyCrossOneThreshold() {
        // Real reward sizes are ≤50, well under the 500-point gap, but the
        // logic itself should still resolve correctly even for a large jump —
        // regression guard for the "before < levelTwo" check ordering.
        Magic.shared.points = 100
        XCTAssertEqual(Magic.shared.add(1000), .levelTwo,
                        "A call crossing both thresholds at once must report the higher one, not levelOne")
    }

    func testAddWithZeroOrNegativeAmountIsANoOp() {
        Magic.shared.points = 50
        XCTAssertNil(Magic.shared.add(0))
        XCTAssertNil(Magic.shared.add(-10))
        XCTAssertEqual(Magic.shared.points, 50, "A non-positive amount must not mutate points")
    }

    func testPointsAreMonotonicAcrossASequenceOfAdds() {
        var previous = Magic.shared.points
        for amount in [10, 20, 30, 50, 1, 50, 50] {
            Magic.shared.add(amount)
            XCTAssertGreaterThanOrEqual(Magic.shared.points, previous)
            previous = Magic.shared.points
        }
    }

    // MARK: - hasReachedEnding (Phase 7b, task 6 — the v1 3000-마력 ending gate)

    func testBelowEndingThresholdInAnasEraIsNotReached() {
        XCTAssertFalse(Magic.hasReachedEnding(points: 2999, tailorID: "ana"))
    }

    func testAtEndingThresholdInAnasEraIsReached() {
        XCTAssertTrue(Magic.hasReachedEnding(points: 3000, tailorID: "ana"))
    }

    func testWellAboveEndingThresholdInAnasEraIsReached() {
        XCTAssertTrue(Magic.hasReachedEnding(points: 5000, tailorID: "ana"))
    }

    func testEndingThresholdReachedInDaphnesEraIsNeverReached() {
        // Daphne could in principle keep accumulating past 3000 herself if
        // the player stalls the relics quest past her own handoff point —
        // the gate must still require Ana's era specifically, not just the
        // point total, or Daphne could trigger Ana's ending.
        XCTAssertFalse(Magic.hasReachedEnding(points: 5000, tailorID: "daphne"))
    }
}
