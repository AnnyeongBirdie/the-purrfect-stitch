//
//  SoundManager.swift
//  DesignerAna
//
//  Thin singleton that gates all SFX behind a persistent mute flag.
//  Usage:  SoundManager.shared.play("sfx_button_tap.mp3", on: self)
//

import SpriteKit

final class SoundManager {

    static let shared = SoundManager()
    private init() {}

    // MARK: - Mute state (persisted across launches)

    private let muteKey = "sfx_muted"

    var isMuted: Bool {
        get { UserDefaults.standard.bool(forKey: muteKey) }
        set { UserDefaults.standard.set(newValue, forKey: muteKey) }
    }

    func toggleMute() {
        isMuted = !isMuted
    }

    // MARK: - Playback

    /// Play a sound file (extension included, e.g. "sfx_button_tap.mp3").
    /// Silent no-op when muted.
    func play(_ filename: String, on node: SKNode) {
        guard !isMuted else { return }
        node.run(.playSoundFileNamed(filename, waitForCompletion: false))
    }
}
