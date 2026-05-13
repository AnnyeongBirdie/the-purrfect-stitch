//
//  Wallet.swift
//  DesignerAna
//

import Foundation

final class Wallet {
    static let shared = Wallet()
    private init() {}
    var balance: Int = 200
}
