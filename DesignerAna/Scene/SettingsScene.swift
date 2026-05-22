//
//  SettingsScene.swift
//  DesignerAna
//
//  Settings hub: selected avatar left / settings panel right.
//  Panel contains a mute toggle and an avatar carousel (◀ name ▶ + dots).
//

import SpriteKit

class SettingsScene: SKScene {

    // ── Persistent UI refs ───────────────────────────────────────────────────
    private var avatarSprite: SKSpriteNode!
    private var panelNode: SKShapeNode!
    private var muteButtonNode: SKShapeNode!
    private var muteLabel: SKLabelNode!
    private var avatarNameLabel: SKLabelNode!
    private var dotNodes: [SKShapeNode] = []

    private var safeBottom: CGFloat = 0

    private var panelW: CGFloat { min(size.width * 0.44, 310) }
    private var panelH: CGFloat { min(size.height * 0.84, 290) }

    // ── Lifecycle ────────────────────────────────────────────────────────────

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        safeBottom = view.safeAreaInsets.bottom

        setupBackground()
        setupAvatarSprite()
        setupPanelShell()
        setupCloseButton()
        fillPanel()
    }

    // MARK: - Scene construction

    private func setupBackground() {
        backgroundColor = UIColor(red: 0.10, green: 0.09, blue: 0.14, alpha: 1)
        let bg = SKSpriteNode(imageNamed: "Tailorshop_Background")
        bg.position  = .zero
        bg.size      = self.size
        bg.zPosition = 0
        bg.alpha     = 0.45
        addChild(bg)
    }

    private func setupAvatarSprite() {
        let sprite = SKSpriteNode(imageNamed: ProfileManager.shared.selectedAssetName)
        let targetH = size.height * 0.80
        let native  = sprite.size
        let fit     = native.height > 0 ? targetH / native.height : 0.55
        sprite.setScale(fit)
        sprite.position  = CGPoint(x: -size.width * 0.20, y: -safeBottom * 0.3)
        sprite.zPosition = 2
        addChild(sprite)
        avatarSprite = sprite
    }

    private func setupPanelShell() {
        let panel = SKShapeNode(
            rectOf: CGSize(width: panelW, height: panelH),
            cornerRadius: 28
        )
        panel.fillColor   = UIColor(red: 0.98, green: 0.95, blue: 0.85, alpha: 0.97)
        panel.strokeColor = .brown
        panel.lineWidth   = 4
        panel.position    = CGPoint(x: size.width * 0.16, y: 0)
        panel.zPosition   = 5
        addChild(panel)
        panelNode = panel
    }

    private func setupCloseButton() {
        let btn = SKShapeNode(rectOf: CGSize(width: 54, height: 54), cornerRadius: 14)
        btn.fillColor   = UIColor(red: 0.78, green: 0.52, blue: 0.33, alpha: 0.88)
        btn.strokeColor = UIColor(red: 0.55, green: 0.35, blue: 0.10, alpha: 0.6)
        btn.lineWidth   = 2
        btn.position    = CGPoint(x: size.width / 2 - 37, y: 0)
        btn.zPosition   = 10
        btn.name        = "closeBtn"
        addChild(btn)

        let lbl = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        lbl.text                    = "←"
        lbl.fontSize                = 26
        lbl.fontColor               = .white
        lbl.horizontalAlignmentMode = .center
        lbl.verticalAlignmentMode   = .center
        lbl.name                    = "closeBtn"
        lbl.zPosition               = 11
        btn.addChild(lbl)
    }

    // MARK: - Panel content

    private func fillPanel() {
        panelNode.removeAllChildren()
        dotNodes.removeAll()

        let hh  = panelH / 2
        let hw  = panelW / 2
        let brown = UIColor(red: 0.55, green: 0.35, blue: 0.10, alpha: 1.0)

        // ── Title ────────────────────────────────────────────────────────────
        let title = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        title.text                    = "설정"
        title.fontSize                = 22
        title.fontColor               = brown
        title.horizontalAlignmentMode = .center
        title.verticalAlignmentMode   = .center
        title.position                = CGPoint(x: 0, y: hh - 28)
        title.zPosition               = 1
        panelNode.addChild(title)

        // ── Mute toggle ──────────────────────────────────────────────────────
        let btnW: CGFloat = panelW - 48
        let muted         = SoundManager.shared.isMuted

        let muteBtn = SKShapeNode(rectOf: CGSize(width: btnW, height: 50), cornerRadius: 14)
        muteBtn.fillColor   = muted
            ? UIColor(red: 0.45, green: 0.45, blue: 0.45, alpha: 1.0)
            : UIColor(red: 0.78, green: 0.52, blue: 0.33, alpha: 1.0)
        muteBtn.strokeColor = .brown
        muteBtn.lineWidth   = 2
        muteBtn.position    = CGPoint(x: 0, y: hh - 72)
        muteBtn.zPosition   = 1
        muteBtn.name        = "muteToggle"

        let muteLbl = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        muteLbl.text                    = muted ? "🔇  소리 꺼짐" : "🔊  소리 켜짐"
        muteLbl.fontSize                = 20
        muteLbl.fontColor               = .white
        muteLbl.horizontalAlignmentMode = .center
        muteLbl.verticalAlignmentMode   = .center
        muteLbl.name                    = "muteToggle"
        muteLbl.zPosition               = 2
        muteBtn.addChild(muteLbl)
        panelNode.addChild(muteBtn)
        muteButtonNode = muteBtn
        muteLabel      = muteLbl

        // ── Divider ──────────────────────────────────────────────────────────
        let divider = SKShapeNode()
        let path    = CGMutablePath()
        path.move(to: CGPoint(x: -hw + 20, y: hh - 108))
        path.addLine(to: CGPoint(x: hw - 20, y: hh - 108))
        divider.path        = path
        divider.strokeColor = UIColor(red: 0.55, green: 0.35, blue: 0.10, alpha: 0.3)
        divider.lineWidth   = 1.5
        divider.zPosition   = 1
        panelNode.addChild(divider)

        // ── Avatar section label ─────────────────────────────────────────────
        let avatarSectionLbl = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        avatarSectionLbl.text                    = "캐릭터 선택"
        avatarSectionLbl.fontSize                = 16
        avatarSectionLbl.fontColor               = UIColor(red: 0.55, green: 0.35, blue: 0.10, alpha: 0.85)
        avatarSectionLbl.horizontalAlignmentMode = .center
        avatarSectionLbl.verticalAlignmentMode   = .center
        avatarSectionLbl.position                = CGPoint(x: 0, y: hh - 130)
        avatarSectionLbl.zPosition               = 1
        panelNode.addChild(avatarSectionLbl)

        // ── ◀  name  ▶ carousel row ──────────────────────────────────────────
        let carouselY: CGFloat = hh - 163

        let leftArrow = makeArrowButton(symbol: "◀", name: "avatarLeft",
                                        x: -hw + 28, y: carouselY)
        panelNode.addChild(leftArrow)

        let rightArrow = makeArrowButton(symbol: "▶", name: "avatarRight",
                                         x: hw - 28, y: carouselY)
        panelNode.addChild(rightArrow)

        let nameLbl = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        nameLbl.text                    = ProfileManager.shared.selectedDisplayName
        nameLbl.fontSize                = 20
        nameLbl.fontColor               = .black
        nameLbl.horizontalAlignmentMode = .center
        nameLbl.verticalAlignmentMode   = .center
        nameLbl.position                = CGPoint(x: 0, y: carouselY)
        nameLbl.zPosition               = 1
        panelNode.addChild(nameLbl)
        avatarNameLabel = nameLbl

        // ── Dot indicators ───────────────────────────────────────────────────
        let dotY: CGFloat    = hh - 196
        let dotR: CGFloat    = 5
        let dotSpacing: CGFloat = 18
        let count            = ProfileManager.avatars.count
        let totalW           = CGFloat(count - 1) * dotSpacing
        let startX           = -totalW / 2

        for i in 0 ..< count {
            let dot = SKShapeNode(circleOfRadius: dotR)
            dot.position    = CGPoint(x: startX + CGFloat(i) * dotSpacing, y: dotY)
            dot.strokeColor = .clear
            dot.zPosition   = 1
            dot.fillColor   = i == ProfileManager.shared.selectedIndex
                ? UIColor(red: 0.78, green: 0.52, blue: 0.33, alpha: 1.0)   // selected
                : UIColor(red: 0.78, green: 0.52, blue: 0.33, alpha: 0.28)  // unselected
            panelNode.addChild(dot)
            dotNodes.append(dot)
        }
    }

    private func makeArrowButton(symbol: String, name: String, x: CGFloat, y: CGFloat) -> SKNode {
        let container = SKNode()
        container.position = CGPoint(x: x, y: y)
        container.name     = name
        container.zPosition = 1

        let circle = SKShapeNode(circleOfRadius: 18)
        circle.fillColor   = UIColor(red: 0.78, green: 0.52, blue: 0.33, alpha: 0.88)
        circle.strokeColor = .clear
        circle.name        = name

        let lbl = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        lbl.text                    = symbol
        lbl.fontSize                = 16
        lbl.fontColor               = .white
        lbl.horizontalAlignmentMode = .center
        lbl.verticalAlignmentMode   = .center
        lbl.name                    = name
        circle.addChild(lbl)
        container.addChild(circle)
        return container
    }

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        for node in nodes(at: location) {
            guard let name = node.name else { continue }

            switch name {
            case "closeBtn":
                transitionToFrontShop()
                return

            case "muteToggle":
                SoundManager.shared.toggleMute()
                refreshMuteButton()
                if !SoundManager.shared.isMuted {
                    SoundManager.shared.play("sfx_button_tap.mp3", on: self)
                }
                return

            case "avatarLeft":
                SoundManager.shared.play("sfx_button_tap.mp3", on: self)
                ProfileManager.shared.retreat()
                refreshAvatar()
                return

            case "avatarRight":
                SoundManager.shared.play("sfx_button_tap.mp3", on: self)
                ProfileManager.shared.advance()
                refreshAvatar()
                return

            default:
                break
            }
        }
    }

    // MARK: - Refresh helpers

    private func refreshMuteButton() {
        let muted = SoundManager.shared.isMuted
        muteButtonNode.fillColor = muted
            ? UIColor(red: 0.45, green: 0.45, blue: 0.45, alpha: 1.0)
            : UIColor(red: 0.78, green: 0.52, blue: 0.33, alpha: 1.0)
        muteLabel.text = muted ? "🔇  소리 꺼짐" : "🔊  소리 켜짐"
    }

    private func refreshAvatar() {
        // Swap texture and recompute scale from scratch
        let texture = SKTexture(imageNamed: ProfileManager.shared.selectedAssetName)
        avatarSprite.texture = texture
        let targetH = size.height * 0.80
        let nativeH = texture.size().height
        let fit     = nativeH > 0 ? targetH / nativeH : 0.55

        // Update name label
        avatarNameLabel.text = ProfileManager.shared.selectedDisplayName

        // Update dots
        let selected = ProfileManager.shared.selectedIndex
        for (i, dot) in dotNodes.enumerated() {
            dot.fillColor = i == selected
                ? UIColor(red: 0.78, green: 0.52, blue: 0.33, alpha: 1.0)
                : UIColor(red: 0.78, green: 0.52, blue: 0.33, alpha: 0.28)
        }

        // Pop-in animation using the locally captured fit — no xScale reads mid-action
        avatarSprite.removeAllActions()
        avatarSprite.setScale(fit * 0.88)
        avatarSprite.run(.sequence([
            .scale(to: fit * 1.05, duration: 0.12),
            .scale(to: fit,        duration: 0.08),
        ]))
    }

    // MARK: - Navigation

    private func transitionToFrontShop() {
        guard let view = self.view,
              let scene = FrontShopScene(fileNamed: "GameScene") else { return }
        scene.scaleMode        = .resizeFill
        scene.suppressEntryBell = true
        let transition = SKTransition.crossFade(withDuration: 0.5)
        view.presentScene(scene, transition: transition)
    }
}
