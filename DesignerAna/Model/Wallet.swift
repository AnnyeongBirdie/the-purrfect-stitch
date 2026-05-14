//
//  Wallet.swift
//  DesignerAna
//

import Foundation

final class Wallet {
    static let shared = Wallet()
    private init() {
        balance = Store.loadWalletBalance() ?? 200
    }

    var balance: Int {
        didSet { Store.saveWalletBalance(balance) }
    }
}
