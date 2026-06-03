//
//  Magic.swift
//  DesignerAna
//

import Foundation

final class Magic {
    static let shared = Magic()
    private init() {
        points = Store.loadMagicPoints() ?? 0
    }

    /// Monotonically-accumulating 마력 (cat wizarding XP).
    /// Tailor-side, not customer-side — survives 새 손님 resets.
    var points: Int {
        didSet { Store.saveMagicPoints(points) }
    }

    /// Production callers use this; direct setter is for testing / migration only.
    func add(_ amount: Int) {
        guard amount > 0 else { return }
        points += amount
    }
}
