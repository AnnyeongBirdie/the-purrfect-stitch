//
//  GameProgressTests.swift
//  DesignerAnaTests
//

import XCTest
@testable import DesignerAna

final class GameProgressTests: XCTestCase {

    /// Daphne, fresh start: no relics, no thresholds crossed, nothing shown.
    /// Every test builds off this by mutating only the fields it cares
    /// about, so each test's intent is legible from its diff off a known-
    /// valid baseline rather than restating every field.
    private var freshDaphne: GameProgress.Snapshot {
        GameProgress.Snapshot(
            magicPoints: 0,
            currentTailor: Tailor.defaultID,
            collectedRelicsCount: 0,
            relicDeductionShown: false,
            relicQuestComplete: false,
            tailorHandoffShown: false,
            kingQueenSceneShown: false,
            endingShown: false,
            gameComplete: false
        )
    }

    // MARK: - nextStoryGate

    func testNextStoryGateIsNilAtFreshStart() {
        XCTAssertNil(GameProgress.nextStoryGate(freshDaphne))
    }

    func testTailorHandoffFiresOnceMagicRelicsAndTailorAllAlign() {
        var s = freshDaphne
        s.magicPoints = MagicLevelUpThreshold.levelTwo.rawValue
        s.relicQuestComplete = true
        XCTAssertEqual(GameProgress.nextStoryGate(s), .tailorHandoff)
    }

    func testTailorHandoffWithheldBelowThreshold() {
        var s = freshDaphne
        s.magicPoints = MagicLevelUpThreshold.levelTwo.rawValue - 1
        s.relicQuestComplete = true
        XCTAssertNil(GameProgress.nextStoryGate(s))
    }

    func testTailorHandoffWithheldUntilRelicQuestComplete() {
        var s = freshDaphne
        s.magicPoints = MagicLevelUpThreshold.levelTwo.rawValue
        s.relicQuestComplete = false
        XCTAssertNil(GameProgress.nextStoryGate(s))
    }

    func testTailorHandoffWithheldOnceAlreadyShown() {
        var s = freshDaphne
        s.magicPoints = MagicLevelUpThreshold.levelTwo.rawValue
        s.relicQuestComplete = true
        s.tailorHandoffShown = true
        XCTAssertNil(GameProgress.nextStoryGate(s))
    }

    func testTailorHandoffWithheldOnceTailorIsAlreadyAna() {
        // Reachable if the handoff already happened via some other path --
        // the gate must not re-fire just because the magic/quest conditions
        // still numerically hold.
        var s = freshDaphne
        s.magicPoints = MagicLevelUpThreshold.levelTwo.rawValue
        s.relicQuestComplete = true
        s.currentTailor = Tailor.anaID
        XCTAssertNil(GameProgress.nextStoryGate(s))
    }

    func testKingQueenSceneFiresOnceAnaCrossesItsThreshold() {
        var s = freshDaphne
        s.currentTailor = Tailor.anaID
        s.magicPoints = Magic.kingQueenSceneThreshold
        s.relicQuestComplete = true
        s.tailorHandoffShown = true
        XCTAssertEqual(GameProgress.nextStoryGate(s), .kingQueenScene)
    }

    func testKingQueenSceneWithheldWhileDaphneIsStillTheTailor() {
        var s = freshDaphne
        s.magicPoints = Magic.kingQueenSceneThreshold
        XCTAssertNil(GameProgress.nextStoryGate(s))
    }

    func testKingQueenSceneWithheldOnceAlreadyShown() {
        var s = freshDaphne
        s.currentTailor = Tailor.anaID
        s.magicPoints = Magic.kingQueenSceneThreshold
        s.relicQuestComplete = true
        s.tailorHandoffShown = true
        s.kingQueenSceneShown = true
        XCTAssertNil(GameProgress.nextStoryGate(s))
    }

    func testEndingFiresOnceAnaCrossesTheEndingThreshold() {
        var s = freshDaphne
        s.currentTailor = Tailor.anaID
        s.magicPoints = Magic.endingThreshold
        s.relicQuestComplete = true
        s.tailorHandoffShown = true
        s.kingQueenSceneShown = true
        XCTAssertEqual(GameProgress.nextStoryGate(s), .ending)
    }

    func testEndingWithheldForDaphneEvenPastTheThreshold() {
        // relicQuestComplete deliberately left false too, so this isolates
        // the ending gate's own tailor check rather than tripping the
        // (correctly earlier-priority) tailor-handoff gate instead.
        var s = freshDaphne
        s.magicPoints = Magic.endingThreshold
        XCTAssertNil(GameProgress.nextStoryGate(s))
    }

    func testEndingWithheldOnceAlreadyShown() {
        var s = freshDaphne
        s.currentTailor = Tailor.anaID
        s.magicPoints = Magic.endingThreshold
        s.relicQuestComplete = true
        s.tailorHandoffShown = true
        s.kingQueenSceneShown = true
        s.endingShown = true
        XCTAssertNil(GameProgress.nextStoryGate(s))
    }

    func testKingQueenSceneTakesPriorityOverEndingWhenBothThresholdsHold() {
        // Ana can in principle jump straight past 1500 to 3000+ in one
        // dungeon run. The King/Queen interlude must still get its turn
        // before the ending fires, not get skipped because a later
        // threshold also happens to be crossed.
        var s = freshDaphne
        s.currentTailor = Tailor.anaID
        s.magicPoints = Magic.endingThreshold
        s.relicQuestComplete = true
        s.tailorHandoffShown = true
        XCTAssertEqual(GameProgress.nextStoryGate(s), .kingQueenScene)
    }

    // MARK: - relicDeductionShouldFire

    func testRelicDeductionFiresOnceAllRelicsAreCollected() {
        var s = freshDaphne
        s.collectedRelicsCount = GameProgress.relicTotal
        XCTAssertTrue(GameProgress.relicDeductionShouldFire(s))
    }

    func testRelicDeductionWithheldUntilAllRelicsAreCollected() {
        var s = freshDaphne
        s.collectedRelicsCount = GameProgress.relicTotal - 1
        XCTAssertFalse(GameProgress.relicDeductionShouldFire(s))
    }

    func testRelicDeductionWithheldOnceAlreadyShown() {
        var s = freshDaphne
        s.collectedRelicsCount = GameProgress.relicTotal
        s.relicDeductionShown = true
        XCTAssertFalse(GameProgress.relicDeductionShouldFire(s))
    }

    // MARK: - violations

    func testFreshStartHasNoViolations() {
        XCTAssertTrue(GameProgress.violations(freshDaphne).isEmpty)
    }

    func testFullyProgressedAnaHasNoViolations() {
        var s = freshDaphne
        s.currentTailor = Tailor.anaID
        s.magicPoints = Magic.endingThreshold
        s.collectedRelicsCount = GameProgress.relicTotal
        s.relicDeductionShown = true
        s.relicQuestComplete = true
        s.tailorHandoffShown = true
        s.kingQueenSceneShown = true
        s.endingShown = true
        s.gameComplete = true
        XCTAssertTrue(GameProgress.violations(s).isEmpty)
    }

    func testViolationWhenRelicQuestCompleteWithMissingRelics() {
        var s = freshDaphne
        s.relicQuestComplete = true
        s.collectedRelicsCount = GameProgress.relicTotal - 1
        XCTAssertEqual(GameProgress.violations(s).count, 1)
    }

    func testViolationWhenHandoffShownWithoutRelicQuestComplete() {
        var s = freshDaphne
        s.currentTailor = Tailor.anaID
        s.tailorHandoffShown = true
        s.collectedRelicsCount = GameProgress.relicTotal
        // relicQuestComplete deliberately left false.
        XCTAssertTrue(GameProgress.violations(s).contains {
            $0.contains("tailorHandoffShown is set but relicQuestComplete is not")
        })
    }

    func testViolationWhenHandoffShownWithMissingRelics() {
        var s = freshDaphne
        s.currentTailor = Tailor.anaID
        s.tailorHandoffShown = true
        s.relicQuestComplete = true
        // collectedRelicsCount deliberately left at 0 -- this is the exact
        // shape of the 2026-09-10 device bug this type was written to catch.
        XCTAssertTrue(GameProgress.violations(s).contains {
            $0.contains("uncollected relics will respawn")
        })
    }

    func testViolationWhenGameCompleteWithoutHandoffShown() {
        var s = freshDaphne
        s.gameComplete = true
        XCTAssertTrue(GameProgress.violations(s).contains {
            $0.contains("gameComplete is set but tailorHandoffShown is not")
        })
    }

    func testViolationWhenCurrentTailorIsAnaWithoutHandoffShown() {
        var s = freshDaphne
        s.currentTailor = Tailor.anaID
        XCTAssertTrue(GameProgress.violations(s).contains {
            $0.contains("currentTailor is Ana but tailorHandoffShown is not set")
        })
    }

    func testViolationWhenHandoffShownButCurrentTailorIsNotAna() {
        var s = freshDaphne
        s.tailorHandoffShown = true
        s.relicQuestComplete = true
        s.collectedRelicsCount = GameProgress.relicTotal
        // currentTailor deliberately left as Daphne.
        XCTAssertTrue(GameProgress.violations(s).contains {
            $0.contains("tailorHandoffShown is set but currentTailor is not Ana")
        })
    }
}
