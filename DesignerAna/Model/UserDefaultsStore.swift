//
//  UserDefaultsStore.swift
//  DesignerAna
//
//  All on-disk persistence flows through this file.
//

import Foundation
import os.log

enum UserDefaultsKey {
    static let walletBalance        = "wallet.balance"
    static let wardrobeGarments     = "wardrobe.garments"
    static let garmentCount         = "wardrobe.garmentCount"
    static let lastSeenGarmentCount = "wardrobe.lastSeenCount"
    static let activeOrder          = "order.active"
    static let magicPoints          = "magic.points"
    static let customerSelected     = "customer.selected"
    static let collectedRelics      = "relics.collected"
    static let relicDeductionShown  = "relics.deductionShown"
    static let relicQuestComplete   = "relics.questComplete"
    static let currentTailor        = "tailor.current"
    static let tailorHandoffShown   = "tailor.handoffShown"
    static let storybookOpened      = "storybook.opened"
    static let levelUpBadgeFlashed  = "magic.levelUpBadgeFlashed"
    static let endingShown          = "ending.shown"
    static let hasSeenOpening       = "storybook.hasSeenOpening"
    static let gameComplete         = "game.complete"
    static let gameCompleteBadgeFlashed = "game.completeBadgeFlashed"
    static let kingQueenSceneShown  = "royalParents.sceneShown"
}

enum Store {
    private static let defaults = UserDefaults.standard
    private static let decoder  = JSONDecoder()
    private static let encoder  = JSONEncoder()

    // MARK: - Per-customer keying (Phase 7)
    // Wallet and wardrobe are each customer's own — "the wardrobe is theirs,
    // not the shop's" — so every key below is suffixed by whichever customer
    // is currently selected. No call site outside this file needs to change:
    // Wallet.balance and every Store.load/saveGarments*-family call already
    // goes through here, so the re-keying is transparent to the rest of the
    // codebase. Falls back to a placeholder suffix if somehow called before
    // any customer is selected, so these never crash — just read/write an
    // isolated, harmless slot.
    private static func perCustomerKey(_ base: String) -> String {
        "\(base).\(loadSelectedCustomer() ?? "_none")"
    }

    private static let perCustomerMigrationKey = "walletWardrobe.migrationPerCustomerDone"

    /// One-time migration: copies the old flat (pre-Phase-7) wallet/wardrobe
    /// values into the currently-selected customer's new per-customer slot,
    /// so existing test progress isn't silently dropped when this ships.
    /// Only writes into a slot that's still empty — never overwrites.
    static func runPerCustomerMigrationIfNeeded() {
        guard !defaults.bool(forKey: perCustomerMigrationKey) else { return }
        defer { defaults.set(true, forKey: perCustomerMigrationKey) }
        guard loadSelectedCustomer() != nil else { return }   // nothing to attribute the old data to

        if defaults.object(forKey: perCustomerKey(UserDefaultsKey.walletBalance)) == nil,
           let oldBalance = defaults.object(forKey: UserDefaultsKey.walletBalance) as? Int {
            defaults.set(oldBalance, forKey: perCustomerKey(UserDefaultsKey.walletBalance))
        }
        if defaults.object(forKey: perCustomerKey(UserDefaultsKey.wardrobeGarments)) == nil,
           let oldGarments = defaults.data(forKey: UserDefaultsKey.wardrobeGarments) {
            defaults.set(oldGarments, forKey: perCustomerKey(UserDefaultsKey.wardrobeGarments))
        }
        if defaults.object(forKey: perCustomerKey(UserDefaultsKey.garmentCount)) == nil {
            let oldCount = defaults.integer(forKey: UserDefaultsKey.garmentCount)
            if oldCount > 0 { defaults.set(oldCount, forKey: perCustomerKey(UserDefaultsKey.garmentCount)) }
        }
        if defaults.object(forKey: perCustomerKey(UserDefaultsKey.lastSeenGarmentCount)) == nil {
            let oldSeen = defaults.integer(forKey: UserDefaultsKey.lastSeenGarmentCount)
            if oldSeen > 0 { defaults.set(oldSeen, forKey: perCustomerKey(UserDefaultsKey.lastSeenGarmentCount)) }
        }
    }

    // MARK: - Wallet

    static func loadWalletBalance() -> Int? {
        defaults.object(forKey: perCustomerKey(UserDefaultsKey.walletBalance)) as? Int
    }
    static func saveWalletBalance(_ balance: Int) {
        defaults.set(balance, forKey: perCustomerKey(UserDefaultsKey.walletBalance))
    }

    // MARK: - Wardrobe trophies

    static func loadGarments() -> [FinishedGarment] {
        guard let data = defaults.data(forKey: perCustomerKey(UserDefaultsKey.wardrobeGarments)) else { return [] }
        return (try? decoder.decode([FinishedGarment].self, from: data)) ?? []
    }
    static func saveGarments(_ garments: [FinishedGarment]) {
        guard let data = try? encoder.encode(garments) else { return }
        defaults.set(data, forKey: perCustomerKey(UserDefaultsKey.wardrobeGarments))
    }

    // MARK: - Garment count badge

    static func loadGarmentCount() -> Int {
        defaults.integer(forKey: perCustomerKey(UserDefaultsKey.garmentCount))
    }
    static func saveGarmentCount(_ count: Int) {
        defaults.set(count, forKey: perCustomerKey(UserDefaultsKey.garmentCount))
    }
    static func loadLastSeenCount() -> Int {
        defaults.integer(forKey: perCustomerKey(UserDefaultsKey.lastSeenGarmentCount))
    }
    static func saveLastSeenCount(_ count: Int) {
        defaults.set(count, forKey: perCustomerKey(UserDefaultsKey.lastSeenGarmentCount))
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

    // MARK: - Relic quest milestones (tailor-side; not cleared by resetCustomerSide)

    static func loadRelicDeductionShown() -> Bool {
        defaults.bool(forKey: UserDefaultsKey.relicDeductionShown)
    }
    static func saveRelicDeductionShown() {
        defaults.set(true, forKey: UserDefaultsKey.relicDeductionShown)
    }
    static func loadRelicQuestComplete() -> Bool {
        defaults.bool(forKey: UserDefaultsKey.relicQuestComplete)
    }
    static func saveRelicQuestComplete() {
        defaults.set(true, forKey: UserDefaultsKey.relicQuestComplete)
    }

    /// Debug helper — wipes all relic quest flags so the full arc can be
    /// replayed from the start. Does NOT touch collectedRelics separately;
    /// call saveCollectedRelics([]) before this if you also want a fresh relic set.
    static func clearRelicQuestState() {
        defaults.removeObject(forKey: UserDefaultsKey.relicDeductionShown)
        defaults.removeObject(forKey: UserDefaultsKey.relicQuestComplete)
    }

    // MARK: - Current tailor (Phase 7 — tailor-side, not touched by 새 손님)

    static func loadCurrentTailor() -> String {
        defaults.string(forKey: UserDefaultsKey.currentTailor) ?? Tailor.defaultID
    }
    static func saveCurrentTailor(_ id: String) {
        defaults.set(id, forKey: UserDefaultsKey.currentTailor)
    }

    /// Gates the Daphne→Ana handoff scene (MagicLevelUpThreshold.levelTwo —
    /// 1000 마력 as of Phase 7b's retune, was 300) so it fires only once,
    /// mirroring relicDeductionShown's one-shot pattern.
    static func loadTailorHandoffShown() -> Bool {
        defaults.bool(forKey: UserDefaultsKey.tailorHandoffShown)
    }
    static func saveTailorHandoffShown() {
        defaults.set(true, forKey: UserDefaultsKey.tailorHandoffShown)
    }

    /// Gates the King/Queen narrative interlude (task 8 — 1500 마력 in
    /// Ana's era) so it fires only once, mirroring tailorHandoffShown's
    /// one-shot pattern exactly. Checked in FrontShopScene.handleSaveTrophy()
    /// alongside the handoff/ending gates, since it sits between them
    /// (1000 < 1500 < 3000) — same reasoning as both: firing before the
    /// wardrobe save would let the scene conclude and THEN show the
    /// trophy, reading as if the tailor finished a dress she never touched.
    static func loadKingQueenSceneShown() -> Bool {
        defaults.bool(forKey: UserDefaultsKey.kingQueenSceneShown)
    }
    static func saveKingQueenSceneShown() {
        defaults.set(true, forKey: UserDefaultsKey.kingQueenSceneShown)
    }

    /// Gates the v1 final ending (Phase 7b, task 6/7 — Ana's Estelle
    /// epilogue at 3000 마력) so it fires only once, mirroring
    /// tailorHandoffShown's one-shot pattern exactly. Not yet set from
    /// anywhere — FrontShopScene.handleSaveTrophy() will call
    /// saveEndingShown() the moment it presents the real epilogue scene
    /// (task 7), not before; see Magic.hasReachedEnding(points:tailorID:)
    /// for the pure, tested gate condition this flag pairs with.
    static func loadEndingShown() -> Bool {
        defaults.bool(forKey: UserDefaultsKey.endingShown)
    }
    static func saveEndingShown() {
        defaults.set(true, forKey: UserDefaultsKey.endingShown)
    }

    /// Gates the mandatory first-play opening (Phase 7b, task 9c) —
    /// DaphneBecomesTailorScene plays automatically once, right after the
    /// first-launch customer picker and before the player ever sees the
    /// shop. Also doubles as this page's own unlock condition in the new
    /// unified story chapter (task 9b) — a player who opens the storybook
    /// before ever picking a customer sees it locked, same as any other
    /// unreached story page. Mirrors tailorHandoffShown's one-shot pattern.
    static func loadHasSeenOpening() -> Bool {
        defaults.bool(forKey: UserDefaultsKey.hasSeenOpening)
    }
    static func saveHasSeenOpening() {
        defaults.set(true, forKey: UserDefaultsKey.hasSeenOpening)
    }

    /// The v1 ending has actually been reached and free play has begun
    /// (Phase 7b, task 8) — distinct from `endingShown` (Magic.swift), which
    /// only guards presenting the epilogue scene once. This flag is set
    /// *after* the epilogue's own outro (task 7's "save → epilogue → game
    /// complete" sequence), not at the moment it's presented, mirroring how
    /// PrincessAnaScene sets relicQuestComplete in its own outro rather than
    /// at RelicDeductionScene's start. Read by Magic.add(_:), which becomes a
    /// full no-op once this is true — the single seam that stops 마력
    /// accrual, so no call site needs to learn about the end state — and by
    /// BackRoomScene's frozen-HUD completion badge.
    static func loadGameComplete() -> Bool {
        defaults.bool(forKey: UserDefaultsKey.gameComplete)
    }
    static func saveGameComplete() {
        defaults.set(true, forKey: UserDefaultsKey.gameComplete)
    }

    /// Gates the frozen-HUD completion badge's attention-getting flash —
    /// same one-shot pattern as levelUpBadgeFlashed.
    static func loadGameCompleteBadgeFlashed() -> Bool {
        defaults.bool(forKey: UserDefaultsKey.gameCompleteBadgeFlashed)
    }
    static func saveGameCompleteBadgeFlashed() {
        defaults.set(true, forKey: UserDefaultsKey.gameCompleteBadgeFlashed)
    }

    /// Gates TitleScene's "바로 시작하기" — locked until the player has opened
    /// the storybook at least once, so a first-time player meets the world
    /// and cast (including the veiled "???" character) before jumping into play.
    static func loadHasOpenedStorybook() -> Bool {
        defaults.bool(forKey: UserDefaultsKey.storybookOpened)
    }
    static func saveHasOpenedStorybook() {
        defaults.set(true, forKey: UserDefaultsKey.storybookOpened)
    }

    /// Gates the Tailor Status HUD's ✨ level-up badge's attention-getting
    /// flash — it should flash a few times only the first time it appears
    /// (the first BackRoomScene load after Magic.points crosses 500, or
    /// immediately for Ana's era, which unlocks the badge by identity —
    /// see BackRoomScene.updateLevelUpBadge()), then just sit there
    /// statically on every load after, mirroring tailorHandoffShown's
    /// one-shot pattern.
    static func loadLevelUpBadgeFlashed() -> Bool {
        defaults.bool(forKey: UserDefaultsKey.levelUpBadgeFlashed)
    }
    static func saveLevelUpBadgeFlashed() {
        defaults.set(true, forKey: UserDefaultsKey.levelUpBadgeFlashed)
    }

    // MARK: - 새 손님 reset

    /// Wipes customer-side state. Tailor-side (Magic, relics, dungeons)
    /// and global state (storybook, profile migration flag) are preserved.
    /// Called by the 새 손님 button in Settings — UI wired in Economy refactor #2.
    static func resetCustomerSide() {
        // Order matters: wallet/wardrobe are keyed by the *current* customer
        // (perCustomerKey resolves loadSelectedCustomer() live), so these
        // must run before clearSelectedCustomer() below, or they'd target
        // the wrong (already-cleared) slot. This is what makes 새 손님 honor
        // its own confirmation dialog's promise ("지금까지 모은 옷과 냥은
        // 사라져요") under the per-customer model — without this ordering,
        // picking the same customer again later would silently un-delete
        // their old progress instead of actually starting them over.
        Wallet.shared.balance = 0
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

// MARK: - Progression invariants (DEBUG only)

#if DEBUG
extension Store {

    private static let progressLog = OSLog(subsystem: "com.annyeongbirdie.thepurrfectstitch",
                                           category: "Progress")

    /// Consistency check over the story-progression flags.
    ///
    /// These flags encode one ordered progression -- collect four relics, finish
    /// the quest, hand the shop to Ana, reach the ending -- but they are stored
    /// as independent values, so nothing structurally prevents a combination the
    /// game's own logic treats as impossible. Added 2026-09-10 after exactly such
    /// a combination reached a device playtest: Ana as the working tailor with an
    /// empty relic set, which makes uncollected relics respawn in her dungeons.
    /// It arrived through the then-unguarded SettingsScene debug shortcut (now
    /// corner-gated), and because collecting the respawned relic repairs the
    /// state, the corruption was both silent and self-healing -- so it could not
    /// be reproduced. This turns that whole class of state into a loud failure at
    /// the moment gameplay first trusts it.
    ///
    /// ⚠️ Every check here is keyed on `tailorHandoffShown`, never on
    /// `currentTailor` alone. BackRoomScene's `#if DEBUG` roster-cycle shortcut
    /// deliberately sets the tailor independently of the story flags, so
    /// "currentTailor is Ana" is not on its own a violation while that shortcut
    /// exists -- asserting on it would fire on every use of the fastest route to
    /// Ana and train the alarm to be ignored. Once the debug shortcuts come out
    /// (step 1 of the economy calibration pass), the stricter predicate becomes
    /// available and this comment is the note to revisit it.
    ///
    /// Compiled out of release builds entirely. If a trap mid-playtest proves
    /// disruptive during the outstanding on-device verification pass, drop the
    /// `assertionFailure` and keep the `os_log` -- the log line alone still
    /// records the violation, with the same message.
    static func assertProgressInvariants(_ context: String) {
        let relics       = loadCollectedRelics()
        let relicTotal   = DungeonItem.allCases.count
        let questDone    = loadRelicQuestComplete()
        let handoffShown = loadTailorHandoffShown()
        let gameDone     = loadGameComplete()

        var violations: [String] = []

        if questDone && relics.count != relicTotal {
            violations.append("relicQuestComplete is set but \(relics.count)/\(relicTotal) relics are collected")
        }
        if handoffShown && !questDone {
            violations.append("tailorHandoffShown is set but relicQuestComplete is not")
        }
        if handoffShown && relics.count != relicTotal {
            violations.append("the handoff to Ana has happened but \(relics.count)/\(relicTotal) relics are collected -- uncollected relics will respawn in her dungeons")
        }
        if gameDone && !handoffShown {
            violations.append("gameComplete is set but tailorHandoffShown is not")
        }

        guard !violations.isEmpty else { return }

        let message = "Progression invariant violated at \(context): " + violations.joined(separator: "; ")
        os_log("%{public}@", log: progressLog, type: .fault, message)
        assertionFailure(message)
    }
}
#endif
