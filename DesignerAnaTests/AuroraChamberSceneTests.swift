//
//  AuroraChamberSceneTests.swift
//  DesignerAnaTests
//
//  Regression test for a real shipped bug (see CLAUDE.md's "Dialogue bug
//  found + fixed", 2026-09-06): Aurora's line used to unconditionally tell
//  Daphne to "come back once you're stronger," which was flatly contradicted
//  if the player already had reached the handoff threshold (levelTwo — 1000
//  마력 as of Phase 7b's retune, was 300) before finishing the relics quest.
//  closingLine(forMagicPoints:) was pulled out of didMove(to:) specifically
//  so this branch could be tested without instantiating the scene itself.
//
//  Threshold values below retuned 2026-09-09 alongside MagicLevelUpThreshold
//  (150/300 → 500/1000) — see MagicTests.swift for the same retune. 999 used
//  to be "well above 300"; it is now just below the 1000 threshold, so that
//  case moved to 1999.
//

import XCTest
@testable import DesignerAna

final class AuroraChamberSceneTests: XCTestCase {

    func testBelowThresholdUsesTheComeBackLaterLine() {
        let line = AuroraChamberScene.closingLine(forMagicPoints: 500)
        XCTAssertTrue(line.contains("좀 더 강해지면"),
                       "Below the 1000-마력 handoff threshold, Aurora should still say to come back once stronger")
        XCTAssertFalse(line.contains("이미 충분히 강해졌구나"))
    }

    func testAtThresholdUsesTheAcknowledgingLineInstead() {
        let line = AuroraChamberScene.closingLine(forMagicPoints: 1000)
        XCTAssertTrue(line.contains("이미 충분히 강해졌구나"),
                       "At/above the 1000-마력 handoff threshold, the line must not contradict the imminent handoff")
        XCTAssertFalse(line.contains("좀 더 강해지면"),
                        "The old 'not ready yet' line must not appear once the handoff is imminent")
    }

    func testWellAboveThresholdStillUsesTheAcknowledgingLine() {
        let line = AuroraChamberScene.closingLine(forMagicPoints: 1999)
        XCTAssertTrue(line.contains("이미 충분히 강해졌구나"))
    }

    func testLineAlwaysIncludesTheCurrentPointTotal() {
        XCTAssertTrue(AuroraChamberScene.closingLine(forMagicPoints: 120).contains("120"))
        XCTAssertTrue(AuroraChamberScene.closingLine(forMagicPoints: 1000).contains("1000"))
    }
}
