//
//  UserDefaultsStore.swift
//  DesignerAna
//
//  All on-disk persistence flows through this file.
//

import Foundation

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
    static let relicChoiceFirst     = "relics.choiceFirst"
    static let relicQuestComplete   = "relics.questComplete"
    static let currentTailor        = "tailor.current"
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
    static func loadRelicChoiceFirst() -> String? {
        defaults.string(forKey: UserDefaultsKey.relicChoiceFirst)
    }
    static func saveRelicChoiceFirst(_ choice: String) {
        // Only records the *first* choice — don't overwrite if already set.
        guard defaults.string(forKey: UserDefaultsKey.relicChoiceFirst) == nil else { return }
        defaults.set(choice, forKey: UserDefaultsKey.relicChoiceFirst)
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
        defaults.removeObject(forKey: UserDefaultsKey.relicChoiceFirst)
        defaults.removeObject(forKey: UserDefaultsKey.relicQuestComplete)
    }

    // MARK: - Current tailor (Phase 7 — tailor-side, not touched by 새 손님)

    static func loadCurrentTailor() -> String {
        defaults.string(forKey: UserDefaultsKey.currentTailor) ?? Tailor.defaultID
    }
    static func saveCurrentTailor(_ id: String) {
        defaults.set(id, forKey: UserDefaultsKey.currentTailor)
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
