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
        UserDefaults.standard.removeObject(forKey: "game.complete")
    }

    override func tearDownWithError() throws {
        Magic.shared.points = 0
        UserDefaults.standard.removeObject(forKey: "magic.points")
        UserDefaults.standard.removeObject(forKey: "game.complete")
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

    // MARK: - Frozen accrual after the v1 ending (Phase 7b, task 8)

    func testAddIsANoOpOnceGameIsComplete() {
        Magic.shared.points = 3000
        Store.saveGameComplete()

        XCTAssertNil(Magic.shared.add(50), "add(_:) must return nil once the game is complete")
        XCTAssertEqual(Magic.shared.points, 3000, "points must not change once the game is complete")
    }

    func testAddStillWorksNormallyBeforeGameIsComplete() {
        // Regression guard: confirms the frozen-accrual guard is keyed on
        // Store.loadGameComplete(), not on the point total already being
        // past every MagicLevelUpThreshold — 3000 is past both, but accrual
        // must still work normally until the game-complete flag is set.
        Magic.shared.points = 3000
        Magic.shared.add(50)
        XCTAssertEqual(Magic.shared.points, 3050)
    }

    // MARK: - spend(_:) — the ✨ ability's 10-마력 cost (2026-09-10)

    func testSpendDeductsPoints() {
        Magic.shared.points = 100
        Magic.shared.spend(10)
        XCTAssertEqual(Magic.shared.points, 90)
    }

    func testSpendFloorsAtZeroRatherThanGoingNegative() {
        Magic.shared.points = 5
        Magic.shared.spend(10)
        XCTAssertEqual(Magic.shared.points, 0, "Spending more than the current total must floor at 0, not go negative")
    }

    func testSpendWithZeroOrNegativeAmountIsANoOp() {
        Magic.shared.points = 50
        Magic.shared.spend(0)
        Magic.shared.spend(-10)
        XCTAssertEqual(Magic.shared.points, 50, "A non-positive amount must not mutate points")
    }

    func testSpendIsANoOpOnceGameIsComplete() {
        Magic.shared.points = 3000
        Store.saveGameComplete()

        Magic.shared.spend(10)
        XCTAssertEqual(Magic.shared.points, 3000, "points must not change once the game is complete — the frozen HUD keeps showing the final total")
    }
}
