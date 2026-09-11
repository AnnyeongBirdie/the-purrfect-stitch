//
//  StoreTests.swift
//  DesignerAnaTests
//

import XCTest
@testable import DesignerAna

final class StoreTests: XCTestCase {

    // Store reads/writes UserDefaults.standard directly (no injectable
    // suite), so every test clears exactly the keys it touches in
    // setUp/tearDown rather than wiping all of UserDefaults.standard —
    // that would blow away unrelated state on a real device/simulator.
    private let customerA = "ChefCat"
    private let customerB = "PirateCat"

    override func setUpWithError() throws {
        Store.clearSelectedCustomer()
        // "_none" is perCustomerKey's fallback suffix when no customer is
        // selected — and this test bundle is hosted inside the real
        // DesignerAna.app process (TEST_HOST), so it shares actual
        // UserDefaults.standard with whatever's been played on this
        // simulator. Must clear that slot too, not just the two synthetic
        // test customers, or leftover real playtest data leaks into a test
        // expecting a clean "no customer selected" state.
        for customer in [customerA, customerB, "_none"] {
            UserDefaults.standard.removeObject(forKey: "wallet.balance.\(customer)")
            UserDefaults.standard.removeObject(forKey: "wardrobe.garments.\(customer)")
            UserDefaults.standard.removeObject(forKey: "wardrobe.garmentCount.\(customer)")
            UserDefaults.standard.removeObject(forKey: "wardrobe.lastSeenCount.\(customer)")
        }
        UserDefaults.standard.removeObject(forKey: "order.active")
        UserDefaults.standard.removeObject(forKey: "relics.deductionShown")
        UserDefaults.standard.removeObject(forKey: "relics.questComplete")
        UserDefaults.standard.removeObject(forKey: "tailor.handoffShown")
        UserDefaults.standard.removeObject(forKey: "storybook.opened")
        UserDefaults.standard.removeObject(forKey: "magic.levelUpBadgeFlashed")
        UserDefaults.standard.removeObject(forKey: "walletWardrobe.migrationPerCustomerDone")
    }

    override func tearDownWithError() throws {
        try setUpWithError()
    }

    // MARK: - Per-customer keying

    func testWalletBalanceIsIsolatedPerCustomer() {
        Store.saveSelectedCustomer(customerA)
        Store.saveWalletBalance(500)

        Store.saveSelectedCustomer(customerB)
        Store.saveWalletBalance(100)

        Store.saveSelectedCustomer(customerA)
        XCTAssertEqual(Store.loadWalletBalance(), 500,
                        "Customer A's balance must not be clobbered by customer B's save")

        Store.saveSelectedCustomer(customerB)
        XCTAssertEqual(Store.loadWalletBalance(), 100)
    }

    func testGarmentsAreIsolatedPerCustomer() {
        let garmentA = FinishedGarment(clothingType: .dress, fabricColor: .pink, completedAt: Date())
        let garmentB = FinishedGarment(clothingType: .shirt, fabricColor: .blue, completedAt: Date())

        Store.saveSelectedCustomer(customerA)
        Store.saveGarments([garmentA])

        Store.saveSelectedCustomer(customerB)
        Store.saveGarments([garmentB])

        Store.saveSelectedCustomer(customerA)
        XCTAssertEqual(Store.loadGarments().map(\.clothingType), [.dress])

        Store.saveSelectedCustomer(customerB)
        XCTAssertEqual(Store.loadGarments().map(\.clothingType), [.shirt])
    }

    // MARK: - resetCustomerSide

    func testResetCustomerSideZeroesCustomerStateButPreservesTailorState() {
        Store.saveSelectedCustomer(customerA)
        Store.saveWalletBalance(300)
        Store.saveGarments([FinishedGarment(clothingType: .pants, fabricColor: .yellow, completedAt: Date())])
        Store.saveGarmentCount(3)
        Store.saveLastSeenCount(2)
        Store.saveActiveOrder(ActiveOrder(clothingType: .dress, fabricColor: .pink,
                                           depositAmount: 100, backRoomStateName: "waitingForCabinetTap",
                                           savedAt: Date()))
        Store.saveRelicDeductionShown()   // tailor-side; must survive the reset

        Store.resetCustomerSide()

        XCTAssertNil(Store.loadSelectedCustomer(), "새 손님 must re-prompt the customer picker")
        XCTAssertNil(Store.loadActiveOrder())
        XCTAssertTrue(Store.loadRelicDeductionShown(), "Tailor-side state must not be touched by a customer reset")

        // resetCustomerSide() clears the selected customer *after* zeroing
        // the balance/wardrobe, so reading Wallet.shared.balance right now
        // (no customer selected) would resolve to the unrelated "_none"
        // fallback slot, not customerA's just-cleared one. Re-select
        // customerA to check the slot that was actually supposed to be wiped.
        Store.saveSelectedCustomer(customerA)
        XCTAssertEqual(Wallet.shared.balance, 0)
        XCTAssertTrue(Store.loadGarments().isEmpty)
        XCTAssertEqual(Store.loadGarmentCount(), 0)
        XCTAssertEqual(Store.loadLastSeenCount(), 0)
    }

    // MARK: - One-shot flags

    func testOneShotFlagsDefaultFalseAndLatchTrue() {
        XCTAssertFalse(Store.loadRelicDeductionShown())
        Store.saveRelicDeductionShown()
        XCTAssertTrue(Store.loadRelicDeductionShown())

        XCTAssertFalse(Store.loadTailorHandoffShown())
        Store.saveTailorHandoffShown()
        XCTAssertTrue(Store.loadTailorHandoffShown())

        XCTAssertFalse(Store.loadLevelUpBadgeFlashed())
        Store.saveLevelUpBadgeFlashed()
        XCTAssertTrue(Store.loadLevelUpBadgeFlashed())
    }

    // MARK: - Per-customer migration

    func testMigrationCopiesOldFlatValuesIntoNewlySelectedCustomersSlotOnce() {
        // Simulate pre-Phase-7 flat state.
        UserDefaults.standard.set(250, forKey: "wallet.balance")
        UserDefaults.standard.removeObject(forKey: "walletWardrobe.migrationPerCustomerDone")

        Store.saveSelectedCustomer(customerA)
        Store.runPerCustomerMigrationIfNeeded()

        XCTAssertEqual(Store.loadWalletBalance(), 250,
                        "First migration must attribute the old flat balance to the selected customer")

        // Now change the customer's balance and re-run migration — must not
        // re-copy the stale flat value over the customer's real progress.
        Store.saveWalletBalance(999)
        Store.runPerCustomerMigrationIfNeeded()
        XCTAssertEqual(Store.loadWalletBalance(), 999, "Migration must be idempotent — one-time only")

        UserDefaults.standard.removeObject(forKey: "wallet.balance")
    }

    func testMigrationDoesNothingWithoutASelectedCustomer() {
        UserDefaults.standard.set(42, forKey: "wallet.balance")
        UserDefaults.standard.removeObject(forKey: "walletWardrobe.migrationPerCustomerDone")
        Store.clearSelectedCustomer()

        Store.runPerCustomerMigrationIfNeeded()

        // Nothing to attribute the old value to — the per-"_none"-slot balance
        // must stay unset rather than silently adopting the flat value.
        XCTAssertNil(Store.loadWalletBalance())

        UserDefaults.standard.removeObject(forKey: "wallet.balance")
    }
}
