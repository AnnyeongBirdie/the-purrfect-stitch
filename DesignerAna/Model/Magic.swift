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
    /// Returns true exactly once in the currency's lifetime — the specific
    /// `add(_:)` call where `points` first reaches 150 (Daphne's magic-light
    /// ability threshold, see CLAUDE.md's "150 마력" plan). Relies on `points`
    /// being monotonic: once past 150, no later call can cross it again, so
    /// no extra persisted "shown" flag is needed the way other one-shot
    /// scenes (relicDeductionShown, tailorHandoffShown) require.
    @discardableResult
    func add(_ amount: Int) -> Bool {
        guard amount > 0 else { return false }
        let before = points
        points += amount
        return before < 150 && points >= 150
    }
}
