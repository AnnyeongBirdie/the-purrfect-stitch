//
//  ProfileManager.swift
//  DesignerAna
//
//  Manages Ana's selected avatar. Selection persists across launches.
//  V2 note: expand to full multi-profile support when needed.
//

import Foundation

final class ProfileManager {

    static let shared = ProfileManager()
    private static let migrationKey = "profile.migrationV2Done"

    private init() {
        runProfileMigrationV2IfNeeded()
    }

    private func runProfileMigrationV2IfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.migrationKey) else { return }

        // Pre-removal 11-entry snapshot (historical; do not edit).
        let oldAvatars: [String] = [
            "ChefCat", "FlutistCat", "HunterCat", "KnightCat",
            "NobleWomanCat", "PirateCat", "ProfessorCat", "RenaissanceCat",
            "GodmotherCat", "VillageGirlCat", "WizardCat",
        ]

        // old-asset-name → new-index (resets the two removed avatars to ChefCat).
        let remap: [String: Int] = [
            "ChefCat": 0, "FlutistCat": 1, "HunterCat": 2, "KnightCat": 3,
            "NobleWomanCat": 4, "PirateCat": 5, "ProfessorCat": 6,
            "RenaissanceCat": 7, "VillageGirlCat": 8,
            "GodmotherCat": 0, "WizardCat": 0,
        ]

        let oldIndex = defaults.integer(forKey: "selectedAvatarIndex")
        if oldIndex >= 0, oldIndex < oldAvatars.count {
            let oldAsset = oldAvatars[oldIndex]
            if let newIndex = remap[oldAsset] {
                defaults.set(newIndex, forKey: "selectedAvatarIndex")
            }
        }
        // If oldIndex was out of range, clamped(to:) on selectedIndex getter catches it.

        defaults.set(true, forKey: Self.migrationKey)
    }

    // ── Avatar catalogue ─────────────────────────────────────────────────────
    // Asset filenames match the PNGs in DesignerAna/ProfileAvatars/.
    // Korean display names are shown in the settings carousel.

    static let avatars: [(asset: String, displayName: String)] = [
        ("ChefCat",         "요리사 냥"),     // 0
        ("FlutistCat",      "피리꾼 냥"),     // 1
        ("HunterCat",       "사냥꾼 냥"),     // 2
        ("KnightCat",       "기사 냥"),       // 3
        ("NobleWomanCat",   "귀부인 냥"),     // 4
        ("PirateCat",       "해적 냥"),       // 5
        ("ProfessorCat",    "교수 냥"),       // 6
        ("RenaissanceCat",  "다빈치 냥"),     // 7
        ("VillageGirlCat",  "마을 소녀 냥"),  // 8
    ]

    // ── Persistence ──────────────────────────────────────────────────────────

    private let key = "selectedAvatarIndex"

    var selectedIndex: Int {
        get {
            let v = UserDefaults.standard.integer(forKey: key)
            return v.clamped(to: 0 ..< ProfileManager.avatars.count)
        }
        set {
            UserDefaults.standard.set(
                newValue.clamped(to: 0 ..< ProfileManager.avatars.count),
                forKey: key
            )
        }
    }

    var selectedAssetName: String  { ProfileManager.avatars[selectedIndex].asset }
    var selectedDisplayName: String { ProfileManager.avatars[selectedIndex].displayName }

    // ── Navigation ───────────────────────────────────────────────────────────

    func advance() {
        selectedIndex = (selectedIndex + 1) % ProfileManager.avatars.count
    }

    func retreat() {
        selectedIndex = (selectedIndex - 1 + ProfileManager.avatars.count) % ProfileManager.avatars.count
    }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

private extension Int {
    func clamped(to range: Range<Int>) -> Int {
        Swift.max(range.lowerBound, Swift.min(self, range.upperBound - 1))
    }
}
