//
//  ActiveOrder.swift
//  DesignerAna
//
//  Snapshot of an in-flight order. Saved on every relevant state
//  transition so the player can resume after an unplanned exit.
//

import Foundation

struct ActiveOrder: Codable {
    let clothingType: String
    let fabricColor: String
    let depositAmount: Int
    let backRoomStateName: String   // raw string of BackRoomState case
    let earnedMinigameRewards: Int
    let savedAt: Date
}
