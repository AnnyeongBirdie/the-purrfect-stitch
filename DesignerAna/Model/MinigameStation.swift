//
//  MinigameStation.swift
//  DesignerAna
//

import UIKit

enum MinigameStation {
    case fabricCabinet
    case sewingStation
    case buttonStation
    case mannequin
}

enum EnemyKind {
    case dustMonster   // 먼지 괴물 — default for all stations in Phase 3
}

// Both stomp (hero lands on monster from above) and proximity tap count as defeat.
enum DefeatMechanism {
    case either        // stomp OR tap when within range (Phase 3 default)
    case stompOnly
    case tapOnly
}

enum MonsterBehavior {
    case stationary                                  // fabric cabinet — tutorial, doesn't move
    case pacing(speed: CGFloat, range: CGFloat)      // sewing — walks back and forth
    case lunging(lungeInterval: TimeInterval)        // button station — charges at hero periodically
}

enum HazardKind {
    case none                                        // fabric cabinet — no floor obstacles
    case scissorBlades(count: Int, spacing: CGFloat) // sewing — scissors to jump over
    case fallingButtons(spawnInterval: TimeInterval) // button station — buttons rain from ceiling
}

struct MinigameConfig {
    let station: MinigameStation
    let levelSeed: Int                  // 1–4; selects a hardcoded platform layout
    let enemyKind: EnemyKind
    let enemyCount: Int
    let defeatMechanism: DefeatMechanism
    let monsterBehavior: MonsterBehavior
    let hazardKind: HazardKind
    let chestRewardLabel: String        // shown when chest opens, e.g. "원단 획득!"
    let chestRewardImageName: String    // item sprite inside the chest
    let backgroundTint: UIColor         // dungeon atmosphere, derived from fabricColor
    let accentColor: UIColor            // platform tint and UI accents

    static func make(for station: MinigameStation, order: Order?) -> MinigameConfig {
        let (bgTint, accent) = colors(for: order?.fabricColor)
        switch station {
        case .fabricCabinet:
            return MinigameConfig(
                station: station, levelSeed: 1, enemyKind: .dustMonster, enemyCount: 1,
                defeatMechanism: .either, monsterBehavior: .stationary, hazardKind: .none,
                chestRewardLabel: "원단 획득!", chestRewardImageName: "pinkFabric",
                backgroundTint: bgTint, accentColor: accent)
        case .sewingStation:
            return MinigameConfig(
                station: station, levelSeed: 2, enemyKind: .dustMonster, enemyCount: 1,
                defeatMechanism: .either, monsterBehavior: .pacing(speed: 80, range: 70),
                hazardKind: .scissorBlades(count: 2, spacing: 90),
                chestRewardLabel: "실 획득!", chestRewardImageName: "Thread_Gold",
                backgroundTint: bgTint, accentColor: accent)
        case .buttonStation:
            return MinigameConfig(
                station: station, levelSeed: 3, enemyKind: .dustMonster, enemyCount: 1,
                defeatMechanism: .either, monsterBehavior: .lunging(lungeInterval: 3.0),
                hazardKind: .fallingButtons(spawnInterval: 1.5),
                chestRewardLabel: "단추 획득!", chestRewardImageName: "Buttons_Regular",
                backgroundTint: bgTint, accentColor: accent)
        case .mannequin:
            return MinigameConfig(
                station: station, levelSeed: 4, enemyKind: .dustMonster, enemyCount: 1,
                defeatMechanism: .either, monsterBehavior: .stationary, hazardKind: .none,
                chestRewardLabel: finishedGarmentLabel(for: order),
                chestRewardImageName: finishedGarmentImageName(for: order),
                backgroundTint: bgTint, accentColor: accent)
        }
    }

    private static func finishedGarmentImageName(for order: Order?) -> String {
        let garment: String
        switch order?.clothingType {
        case "셔츠": garment = "Shirt"
        case "바지": garment = "Pants"
        default:     garment = "Dress"
        }
        switch order?.fabricColor {
        case "파랑": return "Mannequin_\(garment)_Blue"
        case "노랑": return "Mannequin_\(garment)_Yellow"
        default:     return "Mannequin_\(garment)_Pink"
        }
    }

    private static func finishedGarmentLabel(for order: Order?) -> String {
        switch order?.clothingType {
        case "셔츠": return "셔츠 완성!"
        case "바지": return "바지 완성!"
        default:     return "드레스 완성!"
        }
    }

    private static func colors(for fabricColor: String?) -> (UIColor, UIColor) {
        switch fabricColor {
        case "파랑": return (
            UIColor(red: 0.10, green: 0.15, blue: 0.35, alpha: 1.0),
            UIColor(red: 0.20, green: 0.50, blue: 0.95, alpha: 1.0))
        case "노랑": return (
            UIColor(red: 0.30, green: 0.25, blue: 0.05, alpha: 1.0),
            UIColor(red: 0.95, green: 0.80, blue: 0.10, alpha: 1.0))
        default: return (   // 분홍 or nil
            UIColor(red: 0.30, green: 0.10, blue: 0.18, alpha: 1.0),
            UIColor(red: 0.95, green: 0.38, blue: 0.60, alpha: 1.0))
        }
    }
}
