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

enum TailorMinigameCategory {
    case platformer   // Daphne — MinigameNode / BossMinigameNode, unchanged
    case puzzle       // Ana — not yet built
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
    let minigameCategory: TailorMinigameCategory

    /// Puzzle genre per regular station. Empty for platformer tailors.
    let puzzleGenres: [MinigameStation: PuzzleGenre]
    /// Puzzle genre for the mannequin/boss-equivalent station. Nil for
    /// platformer tailors (Daphne's boss stays BossMinigameNode).
    let bossPuzzleGenre: PuzzleGenre?
}

enum Tailor {
    static let defaultID = "daphne"

    static let all: [TailorIdentity] = [
        TailorIdentity(
            id: "daphne",
            displayName: "다프네",
            spriteAssetName: "Tailor",
            minigameCategory: .platformer,
            puzzleGenres: [:],
            bossPuzzleGenre: nil
        ),
        TailorIdentity(
            id: "ana",
            displayName: "아나 공주",
            spriteAssetName: "SecondPrincessCat",
            minigameCategory: .puzzle,
            puzzleGenres: [
                .fabricCabinet: .sudoku,
                .sewingStation: .spotTheDifference,
                .buttonStation: .crossword,
            ],
            bossPuzzleGenre: .mysteryBoard
        ),
    ]

    static func identity(for id: String) -> TailorIdentity {
        all.first(where: { $0.id == id })
            ?? all.first(where: { $0.id == defaultID })!
    }
}
