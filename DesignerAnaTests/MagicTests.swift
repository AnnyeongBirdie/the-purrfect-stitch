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
        Magic.shared.points = 120
        XCTAssertEqual(Magic.shared.add(50), .levelOne, "The call that crosses 150 must report it")
        XCTAssertEqual(Magic.shared.points, 170)

        XCTAssertNil(Magic.shared.add(10), "A later call must not re-report a threshold already passed")
    }

    func testAddCrossingLevelTwoReturnsLevelTwoExactlyOnce() {
        Magic.shared.points = 280
        XCTAssertEqual(Magic.shared.add(30), .levelTwo, "The call that crosses 300 must report it")
        XCTAssertEqual(Magic.shared.points, 310)

        XCTAssertNil(Magic.shared.add(10))
    }

    func testASingleAddCanOnlyCrossOneThreshold() {
        // Real reward sizes are ≤50, well under the 150-point gap, but the
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
}
