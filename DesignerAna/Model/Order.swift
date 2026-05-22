//
//  Order.swift
//  DesignerAna
//
//  Created by Kah-ul Kim on 4/21/26.
//

import UIKit

/// The kind of garment an Order is for.
///
/// Raw values are the Korean display names. They double as the on-disk
/// representation: `ActiveOrder` / `FinishedGarment` are `Codable` and were
/// previously persisted with plain `String` fields holding exactly these
/// words, so a String-backed enum keeps saved data byte-compatible.
enum ClothingType: String, Codable, CaseIterable {
    case dress = "드레스"
    case shirt = "셔츠"
    case pants = "바지"

    /// Korean display name — dialog text, the order sheet, trophy labels.
    var displayName: String { rawValue }

    /// English fragment used in mannequin asset names:
    /// `Mannequin_<fragment>_<colorSuffix>`.
    var assetFragment: String {
        switch self {
        case .dress: return "Dress"
        case .shirt: return "Shirt"
        case .pants: return "Pants"
        }
    }
}

/// The fabric color an Order is made in. Raw values are Korean display
/// names, for the same persistence-compatibility reason as `ClothingType`.
enum FabricColor: String, Codable, CaseIterable {
    case pink   = "분홍"
    case blue   = "파랑"
    case yellow = "노랑"

    /// Korean display name — dialog text, the order sheet, trophy labels.
    var displayName: String { rawValue }

    /// English suffix used in mannequin asset names.
    var assetSuffix: String {
        switch self {
        case .pink:   return "Pink"
        case .blue:   return "Blue"
        case .yellow: return "Yellow"
        }
    }

    /// Dungeon atmosphere palette derived from the fabric color —
    /// a dark background tint plus a brighter accent.
    var palette: (background: UIColor, accent: UIColor) {
        switch self {
        case .pink: return (
            UIColor(red: 0.30, green: 0.10, blue: 0.18, alpha: 1.0),
            UIColor(red: 0.95, green: 0.38, blue: 0.60, alpha: 1.0))
        case .blue: return (
            UIColor(red: 0.10, green: 0.15, blue: 0.35, alpha: 1.0),
            UIColor(red: 0.20, green: 0.50, blue: 0.95, alpha: 1.0))
        case .yellow: return (
            UIColor(red: 0.30, green: 0.25, blue: 0.05, alpha: 1.0),
            UIColor(red: 0.95, green: 0.80, blue: 0.10, alpha: 1.0))
        }
    }
}

struct Order {
    let clothingType: ClothingType
    let depositAmount: Int
    let fabricColor: FabricColor
}
