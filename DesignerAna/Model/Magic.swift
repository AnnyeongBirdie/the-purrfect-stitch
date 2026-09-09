//
//  Magic.swift
//  DesignerAna
//

import Foundation

/// Daphne's two hand-picked wizard-apprentice growth thresholds — not a
/// generic XP curve. See CLAUDE.md's "150 마력" / "300 마력" plans (values
/// retuned to 500/1000 in Phase 7b — 150/300 were a testing convenience,
/// reachable in a short playtest, not a real progression curve). They stay
/// hers: Ana's era runs on this same shared `Magic.shared` counter rather
/// than resetting or getting her own currency (a deliberate v1 shortcut —
/// see CLAUDE.md's Currency & economy), so these thresholds also gate her
/// ✨ ability's mid-run VFX in principle, though in practice she starts at
/// `levelTwo`'s value already and can never cross either from below.
enum MagicLevelUpThreshold: Int {
    case levelOne = 500
    case levelTwo = 1000
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
    /// threshold — real reward sizes (≤50) can't jump the 500-point gap
    /// between levelOne and levelTwo in one add. (The `#if DEBUG` triple-tap
    /// shortcut grants 250 at once as of Phase 7b — still can't jump a
    /// 500-point gap either, so this invariant holds for it too.)
    ///
    /// Once `Store.loadGameComplete()` is true (Phase 7b, task 8 — free
    /// play after the v1 ending), this is a full no-op: `points` doesn't
    /// change and nil is always returned. This is the single seam that
    /// stops 마력 accrual post-ending — every real call site (breadcrumb
    /// pickup, chest rewards, the debug grant) is unchanged and simply
    /// stops having an effect, rather than each one learning about the end
    /// state. `points` itself is untouched (not reset, not capped) — she
    /// earned the total and the frozen HUD keeps showing it.
    @discardableResult
    func add(_ amount: Int) -> MagicLevelUpThreshold? {
        guard amount > 0, !Store.loadGameComplete() else { return nil }
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

    /// v1's final ending gate (Phase 7b, task 6) — reached at 3000 마력 in
    /// Ana's era. Ana doesn't get her own currency in v1: she continues this
    /// same shared counter from her 1000-마력 handoff onward (Daphne 0→1000,
    /// handoff, Ana 1000→3000), so unlike `add(_:)`'s threshold-crossing
    /// report, this can't be "the call that crossed 3000" — she starts at
    /// 1000, already past both `MagicLevelUpThreshold` cases, and no later
    /// call can ever report crossing anything again. Checked as a plain
    /// `>=` comparison against the live totals instead, gated on tailor
    /// identity so Daphne (who could in principle keep accumulating past
    /// 3000 herself if the player stalls the relics quest past her own
    /// handoff point) can never trigger it.
    static let endingThreshold = 3000

    static func hasReachedEnding(points: Int, tailorID: String) -> Bool {
        tailorID == Tailor.anaID && points >= endingThreshold
    }
}
