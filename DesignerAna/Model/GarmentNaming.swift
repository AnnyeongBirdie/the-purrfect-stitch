//
//  GarmentNaming.swift
//  DesignerAna
//
//  Per-Order presentation helpers — garment text noun, completion text,
//  image name, and fabric color palette. Free functions so any scene or
//  node can derive without duplicating switches.
//

import UIKit

func garmentNoun(for order: Order?) -> String {
    switch order?.clothingType {
    case "셔츠": return "셔츠"
    case "바지": return "바지"
    default:     return "드레스"
    }
}

func garmentCompletionText(for order: Order?) -> String {
    "\(garmentNoun(for: order)) 완성!"
}

func garmentImageName(for order: Order?) -> String {
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

func fabricColors(for order: Order?) -> (background: UIColor, accent: UIColor) {
    switch order?.fabricColor {
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
