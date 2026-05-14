//
//  FinishedGarment.swift
//  DesignerAna
//
//  One completed order's trophy. Persists in the wardrobe.
//

import Foundation

struct FinishedGarment: Codable {
    let clothingType: String   // "드레스" | "셔츠" | "바지"
    let fabricColor: String    // "분홍" | "파랑" | "노랑"
    let completedAt: Date
}
