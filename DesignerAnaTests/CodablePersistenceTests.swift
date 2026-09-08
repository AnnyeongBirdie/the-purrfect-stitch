//
//  CodablePersistenceTests.swift
//  DesignerAnaTests
//
//  ClothingType/FabricColor are String-raw specifically to keep Codable
//  persistence byte-compatible with saves written before they were enums
//  (Order.swift's own header comment). ActiveOrder's header comment makes a
//  similar claim about earnedMinigameRewards being safely ignorable on old
//  saves. Both claims are directly testable without needing the app to run
//  at all — this test asserts them instead of just trusting the comment.
//

import XCTest
@testable import DesignerAna

final class CodablePersistenceTests: XCTestCase {

    func testActiveOrderRoundTripsThroughJSON() throws {
        let original = ActiveOrder(clothingType: .shirt, fabricColor: .blue,
                                    depositAmount: 250, backRoomStateName: "waitingForSewing",
                                    savedAt: Date(timeIntervalSince1970: 1_700_000_000))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ActiveOrder.self, from: data)

        XCTAssertEqual(decoded.clothingType, original.clothingType)
        XCTAssertEqual(decoded.fabricColor, original.fabricColor)
        XCTAssertEqual(decoded.depositAmount, original.depositAmount)
        XCTAssertEqual(decoded.backRoomStateName, original.backRoomStateName)
    }

    func testActiveOrderDecodesAnOldSaveThatStillHasTheRemovedRewardsField() throws {
        // Hand-written JSON matching the pre-"Economy refactor #2" shape,
        // with the now-deleted earnedMinigameRewards key still present —
        // exactly what a save written by an older build would look like.
        let oldFormatJSON = """
        {
            "clothingType": "드레스",
            "fabricColor": "분홍",
            "depositAmount": 100,
            "backRoomStateName": "waitingForCabinetTap",
            "savedAt": 719000000.0,
            "earnedMinigameRewards": [10, 20, 30]
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(ActiveOrder.self, from: oldFormatJSON)
        XCTAssertEqual(decoded.clothingType, .dress)
        XCTAssertEqual(decoded.fabricColor, .pink)
        XCTAssertEqual(decoded.depositAmount, 100)
    }

    func testFinishedGarmentRoundTripsThroughJSON() throws {
        let original = FinishedGarment(clothingType: .pants, fabricColor: .yellow, completedAt: Date())
        let data = try JSONEncoder().encode([original])
        let decoded = try JSONDecoder().decode([FinishedGarment].self, from: data)

        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].clothingType, .pants)
        XCTAssertEqual(decoded[0].fabricColor, .yellow)
    }

    func testClothingTypeAndFabricColorRawValuesAreTheirKoreanDisplayNames() {
        // Pins the exact on-disk representation — these raw values ARE the
        // persisted strings for any save written while these were plain
        // Swift Strings (Order.swift's own compatibility note). Changing
        // any of these breaks every existing save file.
        XCTAssertEqual(ClothingType.dress.rawValue, "드레스")
        XCTAssertEqual(ClothingType.shirt.rawValue, "셔츠")
        XCTAssertEqual(ClothingType.pants.rawValue, "바지")
        XCTAssertEqual(FabricColor.pink.rawValue, "분홍")
        XCTAssertEqual(FabricColor.blue.rawValue, "파랑")
        XCTAssertEqual(FabricColor.yellow.rawValue, "노랑")
    }

    func testDungeonItemCollectionRoundTripsAsASet() throws {
        let relics: Set<DungeonItem> = [.purpleScepter, .royalFamilyPortrait]
        let data = try JSONEncoder().encode(Array(relics))
        let decodedArray = try JSONDecoder().decode([DungeonItem].self, from: data)
        XCTAssertEqual(Set(decodedArray), relics)
    }
}
