//
//  GameProgress.swift
//  DesignerAna
//

import Foundation

/// "Where is the player in the story" is spread across independent
/// persisted values -- collected relics, the relic-quest/deduction flags,
/// the current tailor, the tailor-handoff/King-Queen/ending flags, and
/// `Magic.shared.points`. Each gate site used to re-derive meaning from a
/// different subset of these inline (three stacked multi-clause booleans in
/// `FrontShopScene.handleSaveTrophy()`, a fourth in
/// `BackRoomScene.handleBossCompletion()`), with nothing declaring which
/// combinations are valid -- so an invalid one couldn't be detected except
/// by `Store.assertProgressInvariants(_:)`'s separate, DEBUG-only check.
///
/// `GameProgress` is that single derivation, in the same grain as
/// `FrontShopState.accepts(_:)` / `Magic.hasReachedEnding(_:_:)` /
/// `Tailor.identity(for:)`: pure functions over a plain `Snapshot`, not the
/// live `Store`, so every combination -- including ones the game's own
/// logic should never reach -- is directly unit-testable. `Store` still owns
/// persistence; this type owns what the persisted values *mean* together.
enum GameProgress {

    /// One-shot narrative scenes gated in `FrontShopScene.handleSaveTrophy()`,
    /// checked in this priority order -- each is causally downstream of the
    /// one before it, so at most one can be ready to fire on a given save.
    enum StoryGate: Equatable {
        case tailorHandoff
        case kingQueenScene
        case ending
    }

    /// A plain-value copy of every persisted flag that jointly defines story
    /// progress, at one instant. Build with `currentSnapshot()` for real
    /// gameplay use, or by hand in tests for combinations that may never
    /// occur in a real playthrough.
    struct Snapshot: Equatable {
        var magicPoints: Int
        var currentTailor: String
        var collectedRelicsCount: Int
        var relicDeductionShown: Bool
        var relicQuestComplete: Bool
        var tailorHandoffShown: Bool
        var kingQueenSceneShown: Bool
        var endingShown: Bool
        var gameComplete: Bool
    }

    static var relicTotal: Int { DungeonItem.allCases.count }

    static func currentSnapshot() -> Snapshot {
        Snapshot(
            magicPoints: Magic.shared.points,
            currentTailor: Store.loadCurrentTailor(),
            collectedRelicsCount: Store.loadCollectedRelics().count,
            relicDeductionShown: Store.loadRelicDeductionShown(),
            relicQuestComplete: Store.loadRelicQuestComplete(),
            tailorHandoffShown: Store.loadTailorHandoffShown(),
            kingQueenSceneShown: Store.loadKingQueenSceneShown(),
            endingShown: Store.loadEndingShown(),
            gameComplete: Store.loadGameComplete()
        )
    }

    /// Which one-shot story gate, if any, is ready to fire on a garment save.
    /// Replaces the three stacked `readyForTailorHandoff` /
    /// `readyForKingQueenScene` / `readyForEnding` booleans that used to live
    /// inline in `FrontShopScene.handleSaveTrophy()` -- same conditions,
    /// same priority order, one call.
    static func nextStoryGate(_ s: Snapshot) -> StoryGate? {
        if s.magicPoints >= MagicLevelUpThreshold.levelTwo.rawValue
            && s.relicQuestComplete
            && !s.tailorHandoffShown
            && s.currentTailor == Tailor.defaultID {
            return .tailorHandoff
        }
        if s.magicPoints >= Magic.kingQueenSceneThreshold
            && !s.kingQueenSceneShown
            && s.currentTailor == Tailor.anaID {
            return .kingQueenScene
        }
        if Magic.hasReachedEnding(points: s.magicPoints, tailorID: s.currentTailor)
            && !s.endingShown {
            return .ending
        }
        return nil
    }

    /// The fourth one-shot gate, `RelicDeductionScene`, lives in a different
    /// scene (`BackRoomScene.handleBossCompletion()`) with a different
    /// fallback (`placeDressOnMannequin()` when it doesn't fire), so it isn't
    /// part of `nextStoryGate`'s priority chain -- but it's still part of
    /// what "story progress" means, so the derivation lives here too rather
    /// than staying inline.
    static func relicDeductionShouldFire(_ s: Snapshot) -> Bool {
        s.collectedRelicsCount == relicTotal && !s.relicDeductionShown
    }

    /// Every combination this type currently knows to be invalid, in plain
    /// English. Ported from `Store.assertProgressInvariants(_:)` (added
    /// 2026-09-10 after exactly one of these reached a device playtest --
    /// Ana as the working tailor with an empty relic set, via an
    /// then-unguarded debug shortcut) so the same checks are unit-testable
    /// here and `Store`'s DEBUG-only assert becomes a thin wrapper over this.
    /// Empty result means no known violation -- not a guarantee the snapshot
    /// is reachable through real play, only that it doesn't trip a rule
    /// this type knows about yet.
    static func violations(_ s: Snapshot) -> [String] {
        var violations: [String] = []
        let isAna = s.currentTailor == Tailor.anaID

        if s.relicQuestComplete && s.collectedRelicsCount != relicTotal {
            violations.append("relicQuestComplete is set but \(s.collectedRelicsCount)/\(relicTotal) relics are collected")
        }
        if s.tailorHandoffShown && !s.relicQuestComplete {
            violations.append("tailorHandoffShown is set but relicQuestComplete is not")
        }
        if s.tailorHandoffShown && s.collectedRelicsCount != relicTotal {
            violations.append("the handoff to Ana has happened but \(s.collectedRelicsCount)/\(relicTotal) relics are collected -- uncollected relics will respawn in her dungeons")
        }
        if s.gameComplete && !s.tailorHandoffShown {
            violations.append("gameComplete is set but tailorHandoffShown is not")
        }
        if isAna && !s.tailorHandoffShown {
            violations.append("currentTailor is Ana but tailorHandoffShown is not set")
        }
        if s.tailorHandoffShown && !isAna {
            violations.append("tailorHandoffShown is set but currentTailor is not Ana")
        }

        return violations
    }
}
