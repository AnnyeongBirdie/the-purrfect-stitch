//
//  StorybookScenePageUnlockTests.swift
//  DesignerAnaTests
//
//  Regression coverage for StorybookScene.storyChapterPageUnlocked(_:) —
//  the unified story chapter's per-page unlock table (Phase 7b, task 9b).
//  Pulled out specifically so it's testable without instantiating the
//  SKScene itself, the same reasoning as AuroraChamberScene.closingLine(_:).
//

import XCTest
@testable import DesignerAna

final class StorybookScenePageUnlockTests: XCTestCase {

    func testOpeningPageUnlocksOnItsOwnFlagOnly() {
        XCTAssertTrue(StorybookScene.storyChapterPageUnlocked(
            pageIndex: 0, hasSeenOpening: true, relicQuestComplete: false, tailorHandoffShown: false))
        XCTAssertFalse(StorybookScene.storyChapterPageUnlocked(
            pageIndex: 0, hasSeenOpening: false, relicQuestComplete: true, tailorHandoffShown: true),
            "The opening must not unlock off the relic-quest or handoff flags — only its own")
    }

    func testTailorChoiceAuroraAndPrincessAnaShareTheRelicQuestFlag() {
        for page in [1, 2, 3] {
            XCTAssertTrue(StorybookScene.storyChapterPageUnlocked(
                pageIndex: page, hasSeenOpening: false, relicQuestComplete: true, tailorHandoffShown: false),
                "Page \(page) must unlock once the relic quest completes")
            XCTAssertFalse(StorybookScene.storyChapterPageUnlocked(
                pageIndex: page, hasSeenOpening: true, relicQuestComplete: false, tailorHandoffShown: true),
                "Page \(page) must not unlock off the opening or handoff flags — only the relic quest")
        }
    }

    func testTailorHandoffPageUnlocksOnItsOwnFlagOnly() {
        XCTAssertTrue(StorybookScene.storyChapterPageUnlocked(
            pageIndex: 4, hasSeenOpening: false, relicQuestComplete: false, tailorHandoffShown: true))
        XCTAssertFalse(StorybookScene.storyChapterPageUnlocked(
            pageIndex: 4, hasSeenOpening: true, relicQuestComplete: true, tailorHandoffShown: false),
            "The handoff page must not unlock off the opening or relic-quest flags — only its own")
    }

    func testOutOfRangePageIndexIsAlwaysLocked() {
        // Page 5 (the Estelle epilogue, task 7) doesn't exist in the
        // storybook yet — the table must not accidentally unlock it just
        // because every other flag happens to be true.
        XCTAssertFalse(StorybookScene.storyChapterPageUnlocked(
            pageIndex: 5, hasSeenOpening: true, relicQuestComplete: true, tailorHandoffShown: true))
        XCTAssertFalse(StorybookScene.storyChapterPageUnlocked(
            pageIndex: -1, hasSeenOpening: true, relicQuestComplete: true, tailorHandoffShown: true))
    }
}
