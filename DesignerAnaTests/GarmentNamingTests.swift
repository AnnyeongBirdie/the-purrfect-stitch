//
//  GarmentNamingTests.swift
//  DesignerAnaTests
//
//  GarmentNaming's asset-name construction is exactly the kind of dynamic
//  string-building that made a real difference in this project's own
//  bundle-size diagnostics — confirming Mannequin_Black.imageset was
//  genuinely unreachable meant proving every value this function can
//  possibly produce. This test pins that reachable set down explicitly.
//

import XCTest
@testable import DesignerAna

final class GarmentNamingTests: XCTestCase {

    func testGarmentImageNameForEveryClothingAndColorCombination() {
        let expected: [ClothingType: [FabricColor: String]] = [
            .dress: [.pink: "Mannequin_Dress_Pink", .blue: "Mannequin_Dress_Blue", .yellow: "Mannequin_Dress_Yellow"],
            .shirt: [.pink: "Mannequin_Shirt_Pink", .blue: "Mannequin_Shirt_Blue", .yellow: "Mannequin_Shirt_Yellow"],
            .pants: [.pink: "Mannequin_Pants_Pink", .blue: "Mannequin_Pants_Blue", .yellow: "Mannequin_Pants_Yellow"],
        ]

        for clothingType in ClothingType.allCases {
            for fabricColor in FabricColor.allCases {
                let order = Order(clothingType: clothingType, depositAmount: 0, fabricColor: fabricColor)
                XCTAssertEqual(garmentImageName(for: order), expected[clothingType]?[fabricColor],
                                "\(clothingType)/\(fabricColor) must resolve to the matching Mannequin_ asset")
            }
        }
    }

    func testNilOrderFallsBackToDressAndPink() {
        XCTAssertEqual(garmentNoun(for: nil), ClothingType.dress.displayName)
        XCTAssertEqual(garmentImageName(for: nil), "Mannequin_Dress_Pink")
        XCTAssertEqual(fabricColors(for: nil).accent, FabricColor.pink.palette.accent)
    }

    func testGarmentCompletionTextAppendsTheCompletionSuffix() {
        let order = Order(clothingType: .shirt, depositAmount: 100, fabricColor: .blue)
        XCTAssertEqual(garmentCompletionText(for: order), "셔츠 완성!")
    }

    func testFabricColorsMatchesTheOrdersOwnPalette() {
        for fabricColor in FabricColor.allCases {
            let order = Order(clothingType: .dress, depositAmount: 0, fabricColor: fabricColor)
            XCTAssertEqual(fabricColors(for: order).accent, fabricColor.palette.accent)
            XCTAssertEqual(fabricColors(for: order).background, fabricColor.palette.background)
        }
    }
}
