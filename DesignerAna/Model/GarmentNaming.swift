//
//  GarmentNaming.swift
//  DesignerAna
//
//  Per-Order presentation helpers — garment text noun, completion text,
//  image name, and fabric color palette. Free functions so any scene or
//  node can derive without duplicating switches.
//

import UIKit

// A nil Order falls back to dress / pink — the original prototype defaults.

func garmentNoun(for order: Order?) -> String {
    (order?.clothingType ?? .dress).displayName
}

func garmentCompletionText(for order: Order?) -> String {
    "\(garmentNoun(for: order)) 완성!"
}

func garmentImageName(for order: Order?) -> String {
    let garment = (order?.clothingType ?? .dress).assetFragment
    let color   = (order?.fabricColor  ?? .pink).assetSuffix
    return "Mannequin_\(garment)_\(color)"
}

func fabricColors(for order: Order?) -> (background: UIColor, accent: UIColor) {
    (order?.fabricColor ?? .pink).palette
}
