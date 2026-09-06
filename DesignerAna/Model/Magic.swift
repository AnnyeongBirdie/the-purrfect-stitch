//
//  Magic.swift
//  DesignerAna
//

import Foundation

/// Daphne's two hand-picked wizard-apprentice growth thresholds — not a
/// generic XP curve. See CLAUDE.md's "150 마력" / "300 마력" plans.
enum MagicLevelUpThreshold: Int {
    case levelOne = 150
    case levelTwo = 300
}

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
    /// Returns the threshold this specific `add(_:)` call crossed, if any —
    /// nil if it didn't cross one (already past it, or the amount was too
    /// small). Relies on `points` being monotonic: once past a threshold, no
    /// later call can cross it again, so no extra persisted "shown" flag is
    /// needed the way other one-shot scenes (relicDeductionShown,
    /// tailorHandoffShown) require. A single call can only ever cross one
    /// threshold — real reward sizes (≤50) can't jump the 150-point gap
    /// between levelOne and levelTwo in one add.
    @discardableResult
    func add(_ amount: Int) -> MagicLevelUpThreshold? {
        guard amount > 0 else { return nil }
        let before = points
        points += amount
        if before < MagicLevelUpThreshold.levelTwo.rawValue, points >= MagicLevelUpThreshold.levelTwo.rawValue {
            return .levelTwo
        }
        if before < MagicLevelUpThreshold.levelOne.rawValue, points >= MagicLevelUpThreshold.levelOne.rawValue {
            return .levelOne
        }
        return nil
    }
}
