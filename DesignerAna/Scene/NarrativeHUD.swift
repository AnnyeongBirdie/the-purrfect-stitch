//
//  NarrativeHUD.swift
//  DesignerAna
//
//  Reusable dialogue HUD for all narrative scenes. Handles:
//    • Bust-up speaker portraits — only two slots, left and right. A third
//      (or later) speaker never gets a centered portrait of their own; they
//      share an existing slot with another character, swapped in and out
//      via hideSpeaker/revealSpeaker as the active exchange changes. This
//      was a deliberate call — a bust covering the center of the scene read
//      badly — so don't reintroduce a centered slot for a future scene.
//    • Dark translucent dialogue panel with scrolling text
//    • Pulsing ▶ advance indicator
//    • In-place choice panel (transforms the dialogue panel)
//
//  Usage:
//    1.  let hud = NarrativeHUD()
//        hud.configure(speakers: [...], sceneSize: size, safeBottom: insets.bottom)
//        addChild(hud)
//    2.  hud.revealSpeaker(named:)          — fade-in a portrait
//    3.  hud.show(speaker:text:)            — update active speaker + text
//    4.  hud.showChoices(_:) / hideChoices()
//    5.  hud.hideSpeaker(named:)            — fade-out a portrait
//
//  Touch routing: the hosting scene owns touchesBegan. For choices, call
//  hud.flashChoiceResult(at:correct:) then hud.hideChoices() from the scene.
//  For plain taps, advance the beat directly in the scene.
//

import SpriteKit
import UIKit

// MARK: - SpeakerConfig

struct SpeakerConfig {
    /// Korean display name shown on the name plate.
    let name: String
    /// xcasset image name for the bust-up portrait. Pass nil → empty frame.
    let portraitAsset: String?
    /// Which corner / position this speaker occupies.
    let slot: NarrativeHUD.PortraitSlot
    /// Character color signature — tints the name label.
    let nameColor: UIColor
}

// MARK: - NarrativeHUD

class NarrativeHUD: SKNode {

    // MARK: - Portrait slot positions

    enum PortraitSlot {
        case left
        case right
    }

    // MARK: - Private state

    private var sceneSize: CGSize  = .zero
    private var safeBottom: CGFloat = 0

    private var portraits: [String: PortraitContainer] = [:]
    private var slotPositions: [PortraitSlot: CGPoint] = [:]

    private var panelNode: SKShapeNode!
    private var textLabel: SKLabelNode!
    private var advanceIndicator: SKLabelNode!
    private var choiceButtons: [SKShapeNode] = []

    // Cached layout values computed during configure() — used by buildPanel,
    // buildAdvanceIndicator, and showChoices so they all agree on the same width.
    private var portraitCenterX: CGFloat = 0
    private var computedPanelWidth: CGFloat = 0
    // Shared vertical center for both portraits and the panel (side-by-side layout).
    private var sharedCenterY: CGFloat = 0

    // Tracks which speakers have been faded in. setActiveSpeaker only touches
    // revealed portraits — prevents unrevealed late-entry characters (e.g. Godmother)
    // from being made semi-visible when setActive(false) fades them to 0.50 alpha.
    private var revealedNames: Set<String> = []

    // MARK: - Layout constants

    let  portraitSize      = CGSize(width: 110, height: 140)
    private let panelHeight: CGFloat    = 100
    private let portraitPad: CGFloat    = 24   // portrait bottom above safe area
    private let panelGap:    CGFloat    = 10   // gap between portrait inner edge and panel edge

    // MARK: - Configuration

    func configure(speakers: [SpeakerConfig], sceneSize: CGSize, safeBottom: CGFloat) {
        self.sceneSize  = sceneSize
        self.safeBottom = safeBottom

        computeSlotPositions()
        buildPanel()
        buildAdvanceIndicator()

        for config in speakers {
            guard let pos = slotPositions[config.slot] else { continue }
            let container = PortraitContainer(
                size:          portraitSize,
                portraitAsset: config.portraitAsset,
                speakerName:   config.name,
                nameColor:     config.nameColor
            )
            container.position  = pos
            container.zPosition = 25
            container.alpha     = 0
            addChild(container)
            portraits[config.name] = container
        }
    }

    // MARK: - Private setup

    private func computeSlotPositions() {
        let halfW = sceneSize.width  / 2
        let halfH = sceneSize.height / 2

        // Portrait (and panel) center Y: portrait bottom sits portraitPad above the
        // safe area. Both the portrait and dialogue panel share this Y so they appear
        // side-by-side rather than the portrait hanging below the panel.
        let cY = -halfH + safeBottom + portraitPad + portraitSize.height / 2
        sharedCenterY = cY

        // Portrait center X: 20 pt inset from screen edge.
        let cX = halfW - portraitSize.width / 2 - 20
        portraitCenterX = cX

        slotPositions[.left]  = CGPoint(x: -cX, y: cY)
        slotPositions[.right] = CGPoint(x:  cX, y: cY)
    }

    private func buildPanel() {
        // Panel fits between the inner edges of the side portraits, with panelGap
        // breathing room on each side. This gives the [portrait][dialogue][portrait]
        // side-by-side layout the user asked for.
        let portraitInnerEdge = portraitCenterX - portraitSize.width / 2
        let w = max(portraitInnerEdge * 2 - panelGap * 2, 200)
        computedPanelWidth = w

        // Panel center Y is the same as portrait center Y — side-by-side, not stacked.
        let panel = SKShapeNode(
            rect: CGRect(x: -w / 2, y: -panelHeight / 2, width: w, height: panelHeight),
            cornerRadius: 16
        )
        // Dark, warm, slightly translucent — scene shows faintly behind.
        panel.fillColor   = UIColor(red: 0.10, green: 0.07, blue: 0.04, alpha: 0.86)
        panel.strokeColor = UIColor(red: 0.58, green: 0.40, blue: 0.18, alpha: 1.0)
        panel.lineWidth   = 2
        panel.position    = CGPoint(x: 0, y: sharedCenterY)
        panel.zPosition   = 20
        addChild(panel)
        panelNode = panel

        // Dialogue text — light cream color readable on dark panel.
        let body = SKLabelNode(fontNamed: "AppleSDGothicNeo-Regular")
        body.fontSize                = 14
        body.fontColor               = UIColor(red: 0.96, green: 0.92, blue: 0.82, alpha: 1.0)
        body.numberOfLines           = 0
        body.preferredMaxLayoutWidth = w - 56
        body.verticalAlignmentMode   = .center
        body.horizontalAlignmentMode = .center
        body.position                = CGPoint(x: 0, y: 6)
        body.zPosition               = 1
        panelNode.addChild(body)
        textLabel = body
    }

    private func buildAdvanceIndicator() {
        let ind = SKLabelNode(fontNamed: "AppleSDGothicNeo-Regular")
        ind.text                    = "▶"
        ind.fontSize                = 11
        ind.fontColor               = UIColor(red: 0.85, green: 0.68, blue: 0.38, alpha: 0.9)
        ind.horizontalAlignmentMode = .right
        ind.verticalAlignmentMode   = .bottom
        ind.position   = CGPoint(x: computedPanelWidth / 2 - 12, y: -panelHeight / 2 + 10)
        ind.zPosition  = 2
        panelNode.addChild(ind)
        advanceIndicator = ind

        ind.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.12, duration: 0.55),
            .fadeAlpha(to: 0.90, duration: 0.55)
        ])), withKey: "pulse")
    }

    // MARK: - Public API — dialogue

    /// Update the active speaker and show new text.
    func show(speaker: String, text: String) {
        textLabel.text = text
        setActiveSpeaker(named: speaker)
    }

    /// Change the active speaker highlight without changing text.
    /// Only touches portraits that have been revealed — unrevealed portraits
    /// (e.g. Godmother before her entrance) are left at alpha 0.
    func setActiveSpeaker(named name: String) {
        for (n, container) in portraits where revealedNames.contains(n) {
            container.setActive(n == name)
        }
    }

    /// Fade-in a speaker portrait and mark it revealed. Also sets them as active.
    func revealSpeaker(named name: String) {
        guard let container = portraits[name] else { return }
        revealedNames.insert(name)
        container.setActive(true)
        container.run(.fadeIn(withDuration: 0.4))
    }

    /// Returns the portrait's position in HUD-local coordinates (== scene coordinates when HUD is at origin).
    /// Use to anchor relic arc animations to a character's portrait rather than a full-body sprite.
    func portraitPosition(for name: String) -> CGPoint? {
        portraits[name]?.position
    }

    /// Fade-out a speaker portrait and remove it from the revealed set.
    func hideSpeaker(named name: String) {
        revealedNames.remove(name)
        portraits[name]?.run(.fadeOut(withDuration: 0.4))
    }

    /// Fade-in all configured portraits simultaneously; mark one as active.
    /// Call once during scene setup after configure().
    func revealAll(activeSpeaker: String) {
        for (name, container) in portraits {
            revealedNames.insert(name)
            container.setActive(name == activeSpeaker)
            container.run(.fadeIn(withDuration: 0.4))
        }
    }

    /// Fade-in only the named portraits; mark one as active.
    /// Use when some speakers should stay hidden at scene start (e.g., late-entering characters).
    func revealSpeakers(_ names: [String], activeSpeaker: String) {
        let nameSet = Set(names)
        for (name, container) in portraits {
            guard nameSet.contains(name) else { continue }
            revealedNames.insert(name)
            container.setActive(name == activeSpeaker)
            container.run(.fadeIn(withDuration: 0.4))
        }
    }

    // MARK: - Public API — choices

    /// Transform the dialogue panel into a choice panel.
    /// Buttons are named "choice_0" … "choice_N" for scene-level tap routing.
    func showChoices(_ choices: [String]) {
        textLabel.isHidden        = true
        advanceIndicator.isHidden = true
        choiceButtons.forEach { $0.removeFromParent() }
        choiceButtons = []

        let panelW = computedPanelWidth
        let btnW   = (panelW - 56) / 2
        let btnH: CGFloat = 36
        let hGap:  CGFloat = 10
        let vGap:  CGFloat = 8
        let rows   = (choices.count + 1) / 2
        let totalH = CGFloat(rows) * btnH + CGFloat(max(0, rows - 1)) * vGap
        let startY = totalH / 2 - btnH / 2

        for (i, choice) in choices.enumerated() {
            let col   = CGFloat(i % 2)
            let row   = CGFloat(i / 2)
            let x     = (col - 0.5) * (btnW + hGap)
            let y     = startY - row * (btnH + vGap)

            let btn = SKShapeNode(
                rect: CGRect(x: -btnW / 2, y: -btnH / 2, width: btnW, height: btnH),
                cornerRadius: 10
            )
            btn.fillColor   = UIColor(red: 0.52, green: 0.36, blue: 0.16, alpha: 1.0)
            btn.strokeColor = UIColor(red: 0.80, green: 0.60, blue: 0.28, alpha: 1.0)
            btn.lineWidth   = 1.5
            btn.position    = CGPoint(x: x, y: y)
            btn.zPosition   = 2
            btn.name        = "choice_\(i)"

            let lbl = SKLabelNode(fontNamed: "AppleSDGothicNeo-Regular")
            lbl.fontSize                = 12
            lbl.fontColor               = UIColor(red: 0.96, green: 0.92, blue: 0.82, alpha: 1.0)
            lbl.verticalAlignmentMode   = .center
            lbl.horizontalAlignmentMode = .center
            lbl.numberOfLines           = 2
            lbl.preferredMaxLayoutWidth = btnW - 12
            lbl.text                    = choice
            lbl.name                    = "choice_\(i)"
            lbl.zPosition               = 1
            btn.addChild(lbl)

            panelNode.addChild(btn)
            choiceButtons.append(btn)
        }
    }

    /// Flash a choice button green (correct) or red (wrong), then restore.
    func flashChoiceResult(at index: Int, correct: Bool) {
        guard index < choiceButtons.count else { return }
        let btn      = choiceButtons[index]
        let flash    = correct
            ? UIColor(red: 0.18, green: 0.68, blue: 0.32, alpha: 1.0)
            : UIColor(red: 0.82, green: 0.22, blue: 0.18, alpha: 1.0)
        let original = UIColor(red: 0.52, green: 0.36, blue: 0.16, alpha: 1.0)
        btn.run(.sequence([
            .run { btn.fillColor = flash },
            .wait(forDuration: 0.38),
            .run { btn.fillColor = original }
        ]))
    }

    /// Restore the dialogue panel from choice mode.
    func hideChoices() {
        choiceButtons.forEach { $0.removeFromParent() }
        choiceButtons             = []
        textLabel.isHidden        = false
        advanceIndicator.isHidden = false
    }
}

// MARK: - PortraitContainer (file-private)

private class PortraitContainer: SKNode {

    private let sz: CGSize
    private var frameNode: SKShapeNode!

    init(size: CGSize, portraitAsset: String?, speakerName: String, nameColor: UIColor) {
        self.sz = size
        super.init()
        buildFrame()
        buildPortraitImage(asset: portraitAsset)
        buildNameBar(name: speakerName, color: nameColor)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    // MARK: - Build

    private func buildFrame() {
        let frame = SKShapeNode(
            rect: CGRect(x: -sz.width / 2, y: -sz.height / 2,
                         width: sz.width,  height: sz.height),
            cornerRadius: 12
        )
        frame.fillColor   = UIColor(red: 0.08, green: 0.05, blue: 0.02, alpha: 0.75)
        frame.strokeColor = UIColor(red: 0.45, green: 0.30, blue: 0.12, alpha: 0.70)
        frame.lineWidth   = 2.5
        frame.zPosition   = 0
        addChild(frame)
        frameNode = frame
    }

    private func buildPortraitImage(asset: String?) {
        guard let asset else { return }
        let img = SKSpriteNode(imageNamed: asset)
        guard img.size.width > 0 else { return }

        // Scale to fit frame width with a small margin; preserve aspect ratio.
        let targetW = sz.width - 6
        img.size    = CGSize(width: targetW,
                             height: img.size.height * (targetW / img.size.width))
        // Nudge up slightly so the face is centred in the upper 80% of the frame.
        img.position = CGPoint(x: 0, y: 6)

        // Clip image to rounded frame shape.
        let maskRect = SKShapeNode(
            rect: CGRect(x: -sz.width / 2, y: -sz.height / 2,
                         width: sz.width,  height: sz.height),
            cornerRadius: 12
        )
        maskRect.fillColor = .white
        let crop = SKCropNode()
        crop.maskNode  = maskRect
        crop.zPosition = 1
        crop.addChild(img)
        addChild(crop)
    }

    private func buildNameBar(name: String, color: UIColor) {
        // Frosted dark bar across bottom 22% of the portrait frame.
        let barH = sz.height * 0.22
        let bar  = SKShapeNode(
            rect: CGRect(x: -sz.width / 2, y: -sz.height / 2,
                         width: sz.width,  height: barH),
            cornerRadius: 0
        )
        bar.fillColor   = UIColor(red: 0.06, green: 0.04, blue: 0.01, alpha: 0.90)
        bar.strokeColor = .clear
        bar.zPosition   = 3
        addChild(bar)

        let lbl = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        lbl.text                    = name
        lbl.fontSize                = 11
        lbl.fontColor               = color
        lbl.verticalAlignmentMode   = .center
        lbl.horizontalAlignmentMode = .center
        lbl.position                = CGPoint(x: 0, y: -sz.height / 2 + barH / 2)
        lbl.zPosition               = 4
        addChild(lbl)
    }

    // MARK: - State

    func setActive(_ active: Bool) {
        run(.group([
            .scale(to: active ? 1.0 : 0.85, duration: 0.18),
            .fadeAlpha(to: active ? 1.0 : 0.50, duration: 0.18)
        ]))
        frameNode.strokeColor = active
            ? UIColor(red: 0.92, green: 0.74, blue: 0.32, alpha: 1.0)   // gold border when speaking
            : UIColor(red: 0.45, green: 0.30, blue: 0.12, alpha: 0.60)  // muted border when idle
    }
}
