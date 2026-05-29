//
//  SoundManager.swift
//  DesignerAna
//
//  Thin singleton that gates all SFX behind a persistent mute flag.
//  Backed by AVAudioPlayer so in-flight audio can be stopped — important
//  for long cues (footstep loops, boss telegraphs) that would otherwise
//  leak past scene transitions when the SKAction sequence is removed but
//  the audio file keeps playing.
//
//  Usage:
//      SoundManager.shared.play("sfx_button_tap.mp3")
//      SoundManager.shared.stop("sfx_boss_telegraph_slam.mp3")
//

import AVFoundation
import Foundation

final class SoundManager {

    static let shared = SoundManager()

    private init() {
        // .ambient + .mixWithOthers so we don't fight other audio on the
        // device (music apps, podcasts) and we follow the iOS silent switch.
        try? AVAudioSession.sharedInstance().setCategory(
            .ambient, mode: .default, options: [.mixWithOthers]
        )
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    // MARK: - Mute state (persisted across launches)

    private let muteKey = "sfx_muted"

    var isMuted: Bool {
        get { UserDefaults.standard.bool(forKey: muteKey) }
        set { UserDefaults.standard.set(newValue, forKey: muteKey) }
    }

    func toggleMute() {
        isMuted = !isMuted
        if isMuted { stopAll() }
    }

    // MARK: - Players
    //
    // One pool per filename. The same cue can be in flight more than once
    // (e.g., rapid jumps overlapping); each play creates its own player
    // and we keep all currently-playing instances under the filename key
    // so stop(_:) can cancel every in-flight copy at once.

    private var players: [String: [AVAudioPlayer]] = [:]

    /// Play a sound file (extension included, e.g. "sfx_button_tap.mp3").
    /// Silent no-op when muted or when the file can't be located.
    func play(_ filename: String) {
        guard !isMuted else { return }
        guard let url = soundURL(for: filename) else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.play()

            // Prune any instances that have finished playing so the pool
            // doesn't grow unbounded over a long session.
            var list = (players[filename] ?? []).filter { $0.isPlaying }
            list.append(player)
            players[filename] = list
        } catch {
            // Audio failures are non-fatal — fall through silently.
        }
    }

    /// Stop every currently-playing copy of `filename`.
    ///
    /// Used at scene exits to prevent long cues (footstep loops, boss
    /// telegraphs) from continuing into the next scene.
    func stop(_ filename: String) {
        guard let list = players[filename] else { return }
        list.forEach { $0.stop() }
        players[filename] = nil
    }

    /// Stop every in-flight sound. Called when mute is toggled on.
    func stopAll() {
        for (_, list) in players {
            list.forEach { $0.stop() }
        }
        players.removeAll()
    }

    // MARK: - Helpers

    private func soundURL(for filename: String) -> URL? {
        // Accept "name.mp3" or just "name"; pull the extension out either way.
        let parts = filename.split(separator: ".", maxSplits: 1)
        let name  = parts.first.map(String.init) ?? filename
        let ext   = parts.count == 2 ? String(parts[1]) : "mp3"
        return Bundle.main.url(forResource: name, withExtension: ext)
    }
}
