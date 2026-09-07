//
//  AuroraChamberSceneTests.swift
//  DesignerAnaTests
//
//  Regression test for a real shipped bug (see CLAUDE.md's "Dialogue bug
//  found + fixed", 2026-09-06): Aurora's line used to unconditionally tell
//  Daphne to "come back once you're stronger," which was flatly contradicted
//  if the player already had 300+ 마력 before finishing the relics quest.
//  closingLine(forMagicPoints:) was pulled out of didMove(to:) specifically
//  so this branch could be tested without instantiating the scene itself.
//

import XCTest
@testable import DesignerAna

final class AuroraChamberSceneTests: XCTestCase {

    func testBelowThreeHundredUsesTheComeBackLaterLine() {
        let line = AuroraChamberScene.closingLine(forMagicPoints: 150)
        XCTAssertTrue(line.contains("좀 더 강해지면"),
                       "Below 300 마력, Aurora should still say to come back once stronger")
        XCTAssertFalse(line.contains("이미 충분히 강해졌구나"))
    }

    func testAtThreeHundredUsesTheAcknowledgingLineInstead() {
        let line = AuroraChamberScene.closingLine(forMagicPoints: 300)
        XCTAssertTrue(line.contains("이미 충분히 강해졌구나"),
                       "At/above 300 마력, the line must not contradict the imminent handoff")
        XCTAssertFalse(line.contains("좀 더 강해지면"),
                        "The old 'not ready yet' line must not appear once the handoff is imminent")
    }

    func testWellAboveThreeHundredStillUsesTheAcknowledgingLine() {
        let line = AuroraChamberScene.closingLine(forMagicPoints: 999)
        XCTAssertTrue(line.contains("이미 충분히 강해졌구나"))
    }

    func testLineAlwaysIncludesTheCurrentPointTotal() {
        XCTAssertTrue(AuroraChamberScene.closingLine(forMagicPoints: 120).contains("120"))
        XCTAssertTrue(AuroraChamberScene.closingLine(forMagicPoints: 300).contains("300"))
    }
}
