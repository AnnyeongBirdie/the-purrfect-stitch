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
    private init() {}

    // ── Avatar catalogue ─────────────────────────────────────────────────────
    // Asset filenames match the PNGs in DesignerAna/ProfileAvatars/.
    // Korean display names are shown in the settings carousel.

    static let avatars: [(asset: String, displayName: String)] = [
        ("ChefCat",         "요리사 냥"),
        ("FlutistCat",      "피리꾼 냥"),
        ("HunterCat",       "사냥꾼 냥"),
        ("KnightCat",       "기사 냥"),
        ("NobleWomanCat",   "귀부인 냥"),
        ("PirateCat",       "해적 냥"),
        ("ProfessorCat",    "교수 냥"),
        ("RenaissanceCat",  "다빈치 냥"),
        ("GodmotherCat",    "요정 대모 냥"),
        ("VillageGirlCat",  "마을 소녀 냥"),
        ("WizardCat",       "마법사 냥"),
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
