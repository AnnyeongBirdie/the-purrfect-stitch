//
//  Wallet.swift
//  DesignerAna
//

import Foundation

final class Wallet {
    static let shared = Wallet()
    private init() {
        Store.runPerCustomerMigrationIfNeeded()
    }

    // No in-memory cache (Phase 7): balance is keyed per-customer under the
    // hood (see UserDefaultsStore's perCustomerKey), and the active customer
    // can change mid-session (새 손님, or the post-relics-quest handoff)
    // without the app relaunching. A cached value would go stale exactly
    // then — reading through to Store on every access is the only way this
    // reliably reflects whichever customer is actually selected right now.
    var balance: Int {
        get { Store.loadWalletBalance() ?? 0 }
        set { Store.saveWalletBalance(newValue) }
    }
}
