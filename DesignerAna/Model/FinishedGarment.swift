//
//  FinishedGarment.swift
//  DesignerAna
//
//  One completed order's trophy. Persists in the wardrobe.
//

import Foundation

struct FinishedGarment: Codable {
    let clothingType: ClothingType
    let fabricColor: FabricColor
    let completedAt: Date
}
