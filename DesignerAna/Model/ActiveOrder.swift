//
//  ActiveOrder.swift
//  DesignerAna
//
//  Snapshot of an in-flight order. Saved on every relevant state
//  transition so the player can resume after an unplanned exit.
//

import Foundation

struct ActiveOrder: Codable {
    let clothingType: ClothingType
    let fabricColor: FabricColor
    let depositAmount: Int
    let backRoomStateName: String   // raw string of BackRoomState case
    let savedAt: Date
    // earnedMinigameRewards was removed in Economy refactor #2. Swift's synthesized
    // Decodable silently ignores extra JSON keys, so old saved records decode fine.
}
