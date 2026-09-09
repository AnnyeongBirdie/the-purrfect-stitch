//
//  TailorIdentity.swift
//  DesignerAna
//
//  Phase 7 — which character is currently playing as the tailor in
//  BackRoomScene. Daphne today; Ana (and eventually the rest of the royal
//  family, per world lore that the number of dungeons is unknown) later.
//  Mirrors ProfileManager's roster shape, but keyed by a stable string id
//  rather than an index — a growing roster with a persisted "current"
//  pointer should survive reordering, the way customer.selected already
//  does for customers.
//

import Foundation
import CoreGraphics
import UIKit

enum TailorMinigameCategory {
    case platformer   // Daphne — MinigameNode / BossMinigameNode, unchanged
    case puzzle       // Ana — not yet built
}

/// Per-tailor colors for the in-dungeon ✨ ability (the travelling light that
/// puts a monster/boss to sleep) — see MAGIC.md's color-language rule, now
/// per-tailor rather than global. `hasCometTrail` is a behavior flag, not a
/// color: Daphne's spell is a plain travelling orb (unchanged since Phase
/// 7a); Ana's ports the continuously-spawned trailing-particle look from
/// `PrincessAnaScene.animateSelfieGift()` ("think of Tinker Bell" — owner
/// direction), so the two tailors' casts read differently, not just tint
/// differently.
struct DungeonMagicPalette {
    let orbOuter: UIColor
    let orbInner: UIColor
    let haloOuter: UIColor
    let haloMidFill: UIColor
    let haloMidStroke: UIColor
    let trailColor: UIColor
    let hasCometTrail: Bool
}

/// Placeholder puzzle genres for Ana's four stations. The puzzle minigames
/// themselves are a separate, not-yet-designed piece of work (Phase 7) —
/// this only fixes the per-station *shape* so that work slots in later
/// without reshaping TailorIdentity again. Names are working placeholders,
/// not locked.
enum PuzzleGenre: String, Codable, CaseIterable {
    case sudoku
    case spotTheDifference
    case crossword
    case mysteryBoard   // mannequin/boss-equivalent finale
}

struct TailorIdentity {
    let id: String                 // stable persisted identifier, e.g. "daphne"
    let displayName: String        // Korean name, shown in the tailor HUD
    let spriteAssetName: String    // BackRoomScene sprite
    let renderedHeight: CGFloat     // target on-screen height in BackRoomScene, in points
    let minigameCategory: TailorMinigameCategory

    /// Puzzle genre per regular station. Empty for platformer tailors.
    let puzzleGenres: [MinigameStation: PuzzleGenre]
    /// Puzzle genre for the mannequin/boss-equivalent station. Nil for
    /// platformer tailors (Daphne's boss stays BossMinigameNode).
    let bossPuzzleGenre: PuzzleGenre?
    /// In-dungeon ✨ ability visuals — see DungeonMagicPalette.
    let magicPalette: DungeonMagicPalette
}

enum Tailor {
    static let defaultID = "daphne"
    static let anaID = "ana"

    // Ana's on-screen height already reads correctly against the back
    // room's furniture, so it's kept as the shared reference point. Daphne
    // renders shorter than that (chibi, younger-looking proportions) rather
    // than the two matching — the old shared scale (0.32 of Daphne's own
    // texture, applied to every tailor alike) had this backwards. Height in
    // points, not a scale factor, since each sprite has its own pixel size
    // and asset-catalog scale-slot registration (see applyTailorScale).
    private static let anaReferenceHeight: CGFloat = 251.52

    // Daphne's wizard-magic gold — the exact colors both MinigameNode and
    // BossMinigameNode already hardcoded for the ✨ ability before this was
    // pulled out into shared per-tailor data. Unchanged values, just relocated.
    private static let daphnePalette = DungeonMagicPalette(
        orbOuter: UIColor(red: 1.00, green: 0.88, blue: 0.45, alpha: 0.28),
        orbInner: UIColor(red: 1.00, green: 0.97, blue: 0.80, alpha: 0.90),
        haloOuter: UIColor(red: 1.00, green: 0.88, blue: 0.45, alpha: 0.16),
        haloMidFill: UIColor(red: 1.00, green: 0.84, blue: 0.31, alpha: 0.30),
        haloMidStroke: UIColor(red: 1.00, green: 0.95, blue: 0.65, alpha: 0.65),
        trailColor: UIColor(red: 1.00, green: 0.84, blue: 0.31, alpha: 1.0),  // unused — hasCometTrail is false
        hasCometTrail: false
    )

    // Ana's fairy-magic green/mint — ported, not invented, from
    // PrincessAnaScene.animateSelfieGift()'s device-confirmed recipe:
    // anaGreen UIColor(0.30, 0.72, 0.48) ≈ #4CB87A for the core light, and a
    // brighter mint UIColor(0.55, 0.95, 0.75) for trail particles (plain
    // anaGreen alone read as "barely visible" on device per owner feedback
    // there). Alphas mirror Daphne's palette role-for-role so the two spells
    // differ in hue and behavior (comet trail), not in overall intensity.
    private static let anaGreen = UIColor(red: 0.30, green: 0.72, blue: 0.48, alpha: 1.0)
    private static let anaMint  = UIColor(red: 0.55, green: 0.95, blue: 0.75, alpha: 1.0)
    private static let anaPalette = DungeonMagicPalette(
        orbOuter: anaGreen.withAlphaComponent(0.28),
        orbInner: UIColor(red: 0.85, green: 1.00, blue: 0.92, alpha: 0.90),
        haloOuter: anaGreen.withAlphaComponent(0.16),
        haloMidFill: anaGreen.withAlphaComponent(0.30),
        haloMidStroke: anaMint.withAlphaComponent(0.65),
        trailColor: anaMint,
        hasCometTrail: true
    )

    static let all: [TailorIdentity] = [
        TailorIdentity(
            id: "daphne",
            displayName: "다프네",
            spriteAssetName: "Tailor",
            renderedHeight: anaReferenceHeight * 0.70,
            minigameCategory: .platformer,
            puzzleGenres: [:],
            bossPuzzleGenre: nil,
            magicPalette: daphnePalette
        ),
        TailorIdentity(
            id: anaID,
            displayName: "아나 공주",
            spriteAssetName: "SecondPrincessCat",
            renderedHeight: anaReferenceHeight,
            minigameCategory: .puzzle,
            puzzleGenres: [
                .fabricCabinet: .sudoku,
                .sewingStation: .spotTheDifference,
                .buttonStation: .crossword,
            ],
            bossPuzzleGenre: .mysteryBoard,
            magicPalette: anaPalette
        ),
    ]

    static func identity(for id: String) -> TailorIdentity {
        all.first(where: { $0.id == id })
            ?? all.first(where: { $0.id == defaultID })!
    }

    /// Scale factor (1.0 for Ana, 0.70 for Daphne) for any on-screen effect
    /// sized around the tailor sprite — e.g. BackRoomScene's tailor halo,
    /// which was tuned against Ana's reference height and visibly stuck out
    /// past Daphne's shorter silhouette until it was scaled down to match.
    static func haloScale(for identity: TailorIdentity) -> CGFloat {
        identity.renderedHeight / anaReferenceHeight
    }
}
