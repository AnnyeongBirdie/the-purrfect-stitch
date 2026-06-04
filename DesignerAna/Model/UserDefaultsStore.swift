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
    static let magicPoints          = "magic.points"
    static let customerSelected     = "customer.selected"
    static let collectedRelics      = "relics.collected"
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

    // MARK: - Magic (tailor's 마력)

    static func loadMagicPoints() -> Int? {
        defaults.object(forKey: UserDefaultsKey.magicPoints) as? Int
    }
    static func saveMagicPoints(_ points: Int) {
        defaults.set(points, forKey: UserDefaultsKey.magicPoints)
    }

    // MARK: - Selected customer (sticky)

    static func loadSelectedCustomer() -> String? {
        defaults.string(forKey: UserDefaultsKey.customerSelected)
    }
    static func saveSelectedCustomer(_ assetName: String) {
        defaults.set(assetName, forKey: UserDefaultsKey.customerSelected)
    }
    static func clearSelectedCustomer() {
        defaults.removeObject(forKey: UserDefaultsKey.customerSelected)
    }

    // MARK: - Collected relics (tailor-side; not cleared by resetCustomerSide)

    static func loadCollectedRelics() -> Set<DungeonItem> {
        guard let data = defaults.data(forKey: UserDefaultsKey.collectedRelics) else { return [] }
        let array = (try? decoder.decode([DungeonItem].self, from: data)) ?? []
        return Set(array)
    }
    static func saveCollectedRelics(_ relics: Set<DungeonItem>) {
        guard let data = try? encoder.encode(Array(relics)) else { return }
        defaults.set(data, forKey: UserDefaultsKey.collectedRelics)
    }

    // MARK: - 새 손님 reset

    /// Wipes customer-side state. Tailor-side (Magic, relics, dungeons)
    /// and global state (storybook, profile migration flag) are preserved.
    /// Called by the 새 손님 button in Settings — UI wired in Economy refactor #2.
    static func resetCustomerSide() {
        // Go through Wallet's setter so the in-memory singleton stays in sync
        // (raw defaults.removeObject would let Wallet's cached balance re-save itself stale).
        Wallet.shared.balance = 0

        // Wardrobe + badge counters reload from Store each access — clearing
        // the persisted values is sufficient.
        saveGarments([])
        saveGarmentCount(0)
        saveLastSeenCount(0)

        // Active order — full clear.
        clearActiveOrder()

        // Customer identity flag — back to unset; first-launch picker UX
        // (wired in Economy refactor #2) will re-prompt.
        clearSelectedCustomer()
    }
}
