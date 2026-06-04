//
//  DungeonItem.swift
//  DesignerAna
//
//  The four relics Princess Estelle left behind in the dungeons.
//  Canonical order (HUD left → right): Scepter → Brushes → Palette → Portrait.
//

import Foundation

enum DungeonItem: String, Codable, CaseIterable {
    case purpleScepter       = "PurpleScepter"
    case paintBrush          = "PaintBrush"
    case palette             = "Palette"
    case royalFamilyPortrait = "RoyalFamilyPortrait"

    /// Image asset name (== rawValue — single source of truth for the imageset).
    var assetName: String { rawValue }

    /// Korean display name for narrative / debug surfaces.
    var displayName: String {
        switch self {
        case .purpleScepter:       return "보랏빛 지팡이"
        case .paintBrush:          return "그림 붓"
        case .palette:             return "팔레트"
        case .royalFamilyPortrait: return "왕실 가족 초상화"
        }
    }

    /// The dungeon (level seed 1–4) this relic comes from.
    var dungeonSeed: Int {
        switch self {
        case .purpleScepter:       return 1
        case .paintBrush:          return 2
        case .palette:             return 3
        case .royalFamilyPortrait: return 4
        }
    }
}
