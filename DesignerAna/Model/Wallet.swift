//
//  Wallet.swift
//  DesignerAna
//

import Foundation

final class Wallet {
    static let shared = Wallet()
    private init() {
        // First launch only — afterwards the saved balance is loaded.
        // New players start broke and earn their way in via riddles.
        balance = Store.loadWalletBalance() ?? 0
    }

    var balance: Int {
        didSet { Store.saveWalletBalance(balance) }
    }
}
