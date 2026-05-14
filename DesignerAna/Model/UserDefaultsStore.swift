//
//  UserDefaultsStore.swift
//  DesignerAna
//
//  All on-disk persistence flows through this file.
//

import Foundation

enum UserDefaultsKey {
    static let walletBalance    = "wallet.balance"
    static let wardrobeGarments = "wardrobe.garments"
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
}
