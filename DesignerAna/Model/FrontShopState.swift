//
//  FrontShopState.swift
//  DesignerAna
//
//  Created by Kah-ul Kim on 4/21/26.
//

import Foundation

enum FrontShopState {
    case greeting
    case choosingClothing
    case choosingFabricColor
    case reviewingOrder
    case awaitingPayment
    case sendingOrder
    /// A finished garment is on the front mannequin awaiting a trophy save.
    /// All navigation is blocked here so the player can't leave (and rebuild
    /// the scene) before the trophy is stored.
    case showingFinishedGarment
}

/// A category of player input the front shop can receive. Each value maps to
/// a button (or button group) handled in `FrontShopScene.touchesBegan`.
enum ShopInput {
    case sideNavigation   // wardrobe / wallet nav icons
    case appNavigation    // settings / storybook nav icons
    case saveTrophy       // "save to wardrobe" button after a finished order
    case clothingChoice   // dress / shirt / pants
    case fabricChoice     // pink / blue / yellow
    case fabricBack       // back arrow on the fabric-color step
    case orderReview      // confirm / cancel on the order sheet
    case payment          // pay / go-back on the payment panel
}

extension FrontShopState {

    /// Whether the shop should act on `input` while in this state.
    ///
    /// The `switch self` below — with no `default` — is the one place the
    /// state→input rules live. Add a `FrontShopState` case and the compiler
    /// forces a decision here, instead of the old scattered `if currentState
    /// == .x` guards that would silently keep compiling.
    func accepts(_ input: ShopInput) -> Bool {
        // Settings and storybook are reachable from every state except the
        // finished-garment moment, where the trophy must be saved first.
        if input == .appNavigation { return self != .showingFinishedGarment }

        switch self {
        case .greeting:
            return input == .sideNavigation
        case .choosingClothing:
            return input == .sideNavigation || input == .clothingChoice
        case .choosingFabricColor:
            return input == .fabricChoice || input == .fabricBack
        case .reviewingOrder:
            return input == .orderReview
        case .awaitingPayment:
            return input == .payment
        case .sendingOrder:
            return false
        case .showingFinishedGarment:
            return input == .saveTrophy
        }
    }
}
