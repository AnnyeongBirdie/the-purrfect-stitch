//
//  UserDefaultsStore.swift
//  DesignerAna
//
//  All on-disk persistence flows through this file.
//

import Foundation

enum UserDefaultsKey {
    static let walletBalance        = "wallet.balance"
    static let wardrobeGarments     = "wardrobe.garments"
    static let garmentCount         = "wardrobe.garmentCount"
    static let lastSeenGarmentCount = "wardrobe.lastSeenCount"
    static let activeOrder          = "order.active"
}

enum Store {
    private static let defaults = UserDefaults.standard
    private static let decoder  = JSONDecoder()
    private static let encoder  = JSONEncoder()

    // MARK: - Wallet

    static func loadWalletBalance() -> Int? {
        defaults.object(forKey: UserDefaultsKey.walletBalance) as? Int
    }
    static func saveWalletBalance(_ balance: Int) {
        defaults.set(balance, forKey: UserDefaultsKey.walletBalance)
    }

    // MARK: - Wardrobe trophies

    static func loadGarments() -> [FinishedGarment] {
        guard let data = defaults.data(forKey: UserDefaultsKey.wardrobeGarments) else { return [] }
        return (try? decoder.decode([FinishedGarment].self, from: data)) ?? []
    }
    static func saveGarments(_ garments: [FinishedGarment]) {
        guard let data = try? encoder.encode(garments) else { return }
        defaults.set(data, forKey: UserDefaultsKey.wardrobeGarments)
    }

    // MARK: - Garment count badge

    static func loadGarmentCount() -> Int {
        defaults.integer(forKey: UserDefaultsKey.garmentCount)
    }
    static func saveGarmentCount(_ count: Int) {
        defaults.set(count, forKey: UserDefaultsKey.garmentCount)
    }
    static func loadLastSeenCount() -> Int {
        defaults.integer(forKey: UserDefaultsKey.lastSeenGarmentCount)
    }
    static func saveLastSeenCount(_ count: Int) {
        defaults.set(count, forKey: UserDefaultsKey.lastSeenGarmentCount)
    }

    // MARK: - Active order (crash / force-quit recovery)

    static func loadActiveOrder() -> ActiveOrder? {
        guard let data = defaults.data(forKey: UserDefaultsKey.activeOrder) else { return nil }
        return try? decoder.decode(ActiveOrder.self, from: data)
    }
    static func saveActiveOrder(_ activeOrder: ActiveOrder) {
        guard let data = try? encoder.encode(activeOrder) else { return }
        defaults.set(data, forKey: UserDefaultsKey.activeOrder)
    }
    static func clearActiveOrder() {
        defaults.removeObject(forKey: UserDefaultsKey.activeOrder)
    }
}
