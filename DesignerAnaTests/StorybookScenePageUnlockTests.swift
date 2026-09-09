//
//  StorybookScenePageUnlockTests.swift
//  DesignerAnaTests
//
//  Regression coverage for StorybookScene.storyChapterPageUnlocked(_:) —
//  the unified story chapter's per-page unlock table (Phase 7b, task 9b;
//  extended for page 5 in task 7). Pulled out specifically so it's testable
//  without instantiating the SKScene itself, the same reasoning as
//  AuroraChamberScene.closingLine(_:).
//

import XCTest
@testable import DesignerAna

final class StorybookScenePageUnlockTests: XCTestCase {

    func testOpeningPageUnlocksOnItsOwnFlagOnly() {
        XCTAssertTrue(StorybookScene.storyChapterPageUnlocked(
            pageIndex: 0, hasSeenOpening: true, relicQuestComplete: false,
            tailorHandoffShown: false, gameComplete: false))
        XCTAssertFalse(StorybookScene.storyChapterPageUnlocked(
            pageIndex: 0, hasSeenOpening: false, relicQuestComplete: true,
            tailorHandoffShown: true, gameComplete: true),
            "The opening must not unlock off any other flag — only its own")
    }

    func testTailorChoiceAuroraAndPrincessAnaShareTheRelicQuestFlag() {
        for page in [1, 2, 3] {
            XCTAssertTrue(StorybookScene.storyChapterPageUnlocked(
                pageIndex: page, hasSeenOpening: false, relicQuestComplete: true,
                tailorHandoffShown: false, gameComplete: false),
                "Page \(page) must unlock once the relic quest completes")
            XCTAssertFalse(StorybookScene.storyChapterPageUnlocked(
                pageIndex: page, hasSeenOpening: true, relicQuestComplete: false,
                tailorHandoffShown: true, gameComplete: true),
                "Page \(page) must not unlock off any other flag — only the relic quest")
        }
    }

    func testTailorHandoffPageUnlocksOnItsOwnFlagOnly() {
        XCTAssertTrue(StorybookScene.storyChapterPageUnlocked(
            pageIndex: 4, hasSeenOpening: false, relicQuestComplete: false,
            tailorHandoffShown: true, gameComplete: false))
        XCTAssertFalse(StorybookScene.storyChapterPageUnlocked(
            pageIndex: 4, hasSeenOpening: true, relicQuestComplete: true,
            tailorHandoffShown: false, gameComplete: true),
            "The handoff page must not unlock off any other flag — only its own")
    }

    func testEstelleEpiloguePageUnlocksOnItsOwnFlagOnly() {
        XCTAssertTrue(StorybookScene.storyChapterPageUnlocked(
            pageIndex: 5, hasSeenOpening: false, relicQuestComplete: false,
            tailorHandoffShown: false, gameComplete: true))
        XCTAssertFalse(StorybookScene.storyChapterPageUnlocked(
            pageIndex: 5, hasSeenOpening: true, relicQuestComplete: true,
            tailorHandoffShown: true, gameComplete: false),
            "The epilogue page must not unlock off any other flag — only game-complete")
    }

    func testOutOfRangePageIndexIsAlwaysLocked() {
        XCTAssertFalse(StorybookScene.storyChapterPageUnlocked(
            pageIndex: 6, hasSeenOpening: true, relicQuestComplete: true,
            tailorHandoffShown: true, gameComplete: true))
        XCTAssertFalse(StorybookScene.storyChapterPageUnlocked(
            pageIndex: -1, hasSeenOpening: true, relicQuestComplete: true,
            tailorHandoffShown: true, gameComplete: true))
    }
}
