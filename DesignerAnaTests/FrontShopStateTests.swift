//
//  FrontShopStateTests.swift
//  DesignerAnaTests
//
//  Exhaustive table-driven check of FrontShopState.accepts(_:) — the single
//  place the front shop's state→input rules live (FrontShopState.swift's own
//  comment: "Add a FrontShopState case and the compiler forces a decision
//  here"). This test is the compile-time exhaustiveness's runtime companion:
//  it pins down the actual truth table so a future edit that silently flips
//  one cell's behavior fails immediately instead of waiting for a manual
//  playthrough to notice.
//

import XCTest
@testable import DesignerAna

final class FrontShopStateTests: XCTestCase {

    private static let allStates: [FrontShopState] = [
        .greeting, .choosingClothing, .choosingFabricColor,
        .reviewingOrder, .awaitingPayment, .sendingOrder, .showingFinishedGarment
    ]

    private static let allInputs: [ShopInput] = [
        .sideNavigation, .appNavigation, .saveTrophy, .clothingChoice,
        .fabricChoice, .fabricBack, .orderReview, .payment
    ]

    // Every (state, input) → expected cell listed explicitly as a flat array
    // of triples, so this table can't accidentally mirror a bug in the
    // production switch back at itself. Neither enum conforms to Hashable,
    // so a Dictionary/Set-keyed table isn't available without adding that
    // conformance purely for a test — a triple list needs no production change.
    private static let expected: [(FrontShopState, ShopInput, Bool)] = [
        (.greeting, .sideNavigation, true),
        (.greeting, .appNavigation, true),
        (.greeting, .saveTrophy, false),
        (.greeting, .clothingChoice, false),
        (.greeting, .fabricChoice, false),
        (.greeting, .fabricBack, false),
        (.greeting, .orderReview, false),
        (.greeting, .payment, false),

        (.choosingClothing, .sideNavigation, true),
        (.choosingClothing, .appNavigation, true),
        (.choosingClothing, .clothingChoice, true),
        (.choosingClothing, .saveTrophy, false),
        (.choosingClothing, .fabricChoice, false),
        (.choosingClothing, .fabricBack, false),
        (.choosingClothing, .orderReview, false),
        (.choosingClothing, .payment, false),

        (.choosingFabricColor, .appNavigation, true),
        (.choosingFabricColor, .fabricChoice, true),
        (.choosingFabricColor, .fabricBack, true),
        (.choosingFabricColor, .sideNavigation, false),
        (.choosingFabricColor, .saveTrophy, false),
        (.choosingFabricColor, .clothingChoice, false),
        (.choosingFabricColor, .orderReview, false),
        (.choosingFabricColor, .payment, false),

        (.reviewingOrder, .appNavigation, true),
        (.reviewingOrder, .orderReview, true),
        (.reviewingOrder, .sideNavigation, false),
        (.reviewingOrder, .saveTrophy, false),
        (.reviewingOrder, .clothingChoice, false),
        (.reviewingOrder, .fabricChoice, false),
        (.reviewingOrder, .fabricBack, false),
        (.reviewingOrder, .payment, false),

        (.awaitingPayment, .appNavigation, true),
        (.awaitingPayment, .payment, true),
        (.awaitingPayment, .sideNavigation, false),
        (.awaitingPayment, .saveTrophy, false),
        (.awaitingPayment, .clothingChoice, false),
        (.awaitingPayment, .fabricChoice, false),
        (.awaitingPayment, .fabricBack, false),
        (.awaitingPayment, .orderReview, false),

        (.sendingOrder, .appNavigation, true),
        (.sendingOrder, .sideNavigation, false),
        (.sendingOrder, .saveTrophy, false),
        (.sendingOrder, .clothingChoice, false),
        (.sendingOrder, .fabricChoice, false),
        (.sendingOrder, .fabricBack, false),
        (.sendingOrder, .orderReview, false),
        (.sendingOrder, .payment, false),

        (.showingFinishedGarment, .saveTrophy, true),
        (.showingFinishedGarment, .appNavigation, false),
        (.showingFinishedGarment, .sideNavigation, false),
        (.showingFinishedGarment, .clothingChoice, false),
        (.showingFinishedGarment, .fabricChoice, false),
        (.showingFinishedGarment, .fabricBack, false),
        (.showingFinishedGarment, .orderReview, false),
        (.showingFinishedGarment, .payment, false),
    ]

    func testAcceptsMatchesTheFullTruthTableExactly() {
        XCTAssertEqual(Self.expected.count, Self.allStates.count * Self.allInputs.count,
                        "The table above must cover every (state, input) pair — one is missing")
        for (state, input, expectedResult) in Self.expected {
            XCTAssertEqual(state.accepts(input), expectedResult,
                            "\(state) accepting \(input) should be \(expectedResult)")
        }
    }

    func testAppNavigationIsBlockedOnlyWhileShowingFinishedGarment() {
        for state in Self.allStates where state != .showingFinishedGarment {
            XCTAssertTrue(state.accepts(.appNavigation),
                           "\(state) must allow settings/storybook navigation")
        }
        XCTAssertFalse(FrontShopState.showingFinishedGarment.accepts(.appNavigation),
                        "The trophy must be saved before the player can navigate away")
    }

    func testSendingOrderAcceptsNothingButAppNavigation() {
        for input in Self.allInputs where input != .appNavigation {
            XCTAssertFalse(FrontShopState.sendingOrder.accepts(input))
        }
    }
}
