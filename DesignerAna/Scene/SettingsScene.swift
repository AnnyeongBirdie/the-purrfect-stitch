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
    private var newCustomerOverlayNode: SKNode?

    var isFirstLaunchPicker: Bool = false

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
        // Hidden in first-launch mode — the panel's start button is the only exit.
        guard !isFirstLaunchPicker else { return }

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
        let btnW: CGFloat = panelW - 48
        let brown = UIColor(red: 0.55, green: 0.35, blue: 0.10, alpha: 1.0)

        // ── Title ────────────────────────────────────────────────────────────
        let title = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        title.text                    = isFirstLaunchPicker ? "손님을 골라주세요" : "설정"
        title.fontSize                = 22
        title.fontColor               = brown
        title.horizontalAlignmentMode = .center
        title.verticalAlignmentMode   = .center
        title.position                = CGPoint(x: 0, y: hh - 28)
        title.zPosition               = 1
        panelNode.addChild(title)

       
            let muted = SoundManager.shared.isMuted

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

            // ── Divider ──────────────────────────────────────────────────────
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
        avatarSectionLbl.text                    = "손님 선택"
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

        if isFirstLaunchPicker {
            // ── "이 손님으로 시작!" primary action ─────────────────────────────
            let startBtn = SKShapeNode(rectOf: CGSize(width: btnW, height: 52), cornerRadius: 14)
            startBtn.fillColor   = UIColor(red: 0.25, green: 0.62, blue: 0.38, alpha: 1.0)
            startBtn.strokeColor = .clear
            startBtn.position    = CGPoint(x: 0, y: -hh + 52)
            startBtn.zPosition   = 1
            startBtn.name        = "startPickerBtn"

            let startLbl = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
            startLbl.text                    = "이 손님으로 시작!"
            startLbl.fontSize                = 20
            startLbl.fontColor               = .white
            startLbl.horizontalAlignmentMode = .center
            startLbl.verticalAlignmentMode   = .center
            startLbl.name                    = "startPickerBtn"
            startLbl.zPosition               = 2
            startBtn.addChild(startLbl)
            panelNode.addChild(startBtn)
        } else {
            // ── 새 손님 button (destructive) ─────────────────────────────────
            let newBtn = SKShapeNode(rectOf: CGSize(width: btnW, height: 44), cornerRadius: 12)
            newBtn.fillColor   = UIColor(red: 0.70, green: 0.30, blue: 0.25, alpha: 1.0)
            newBtn.strokeColor = .clear
            newBtn.position    = CGPoint(x: 0, y: hh - 224)
            newBtn.zPosition   = 1
            newBtn.name        = "newCustomerBtn"

            let newLbl = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
            newLbl.text                    = "새 손님"
            newLbl.fontSize                = 18
            newLbl.fontColor               = .white
            newLbl.horizontalAlignmentMode = .center
            newLbl.verticalAlignmentMode   = .center
            newLbl.name                    = "newCustomerBtn"
            newLbl.zPosition               = 2
            newBtn.addChild(newLbl)
            panelNode.addChild(newBtn)
        }
    }

    private func showNewCustomerConfirmation() {
        newCustomerOverlayNode?.removeFromParent()

        let overlay = SKNode()
        overlay.zPosition = 20
        overlay.name = "newCustomerOverlay"
        addChild(overlay)
        newCustomerOverlayNode = overlay

        let dim = SKShapeNode(rectOf: size)
        dim.fillColor = UIColor(white: 0, alpha: 0.5)
        dim.strokeColor = .clear
        dim.zPosition = -1
        overlay.addChild(dim)

        let panel = SKShapeNode(rectOf: CGSize(width: 340, height: 240), cornerRadius: 24)
        panel.fillColor = UIColor(red: 0.96, green: 0.91, blue: 0.80, alpha: 0.98)
        panel.strokeColor = UIColor.brown
        panel.lineWidth = 4
        panel.zPosition = 1
        overlay.addChild(panel)

        let title = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        title.text = "정말 새 손님으로 시작할까요?"
        title.fontSize = 18
        title.fontColor = .black
        title.position = CGPoint(x: 0, y: 88)
        title.verticalAlignmentMode = .center
        panel.addChild(title)

        for (i, line) in ["지금까지 모은 옷과 냥은 사라져요.", "(재단사의 마력과 이야기책은 그대로 남아요.)"].enumerated() {
            let lbl = SKLabelNode(fontNamed: "AppleSDGothicNeo-Regular")
            lbl.text = line
            lbl.fontSize = 13
            lbl.fontColor = UIColor(red: 0.35, green: 0.18, blue: 0.0, alpha: 1.0)
            lbl.position = CGPoint(x: 0, y: 58 - CGFloat(i) * 22)
            lbl.verticalAlignmentMode = .center
            panel.addChild(lbl)
        }

        let confirmBtn = makeSettingsDialogButton(
            text: "예, 새 손님으로 시작할래요",
            name: "newCustomerConfirm",
            position: CGPoint(x: 0, y: 0),
            width: 300, height: 46
        )
        confirmBtn.fillColor = UIColor(red: 0.70, green: 0.30, blue: 0.25, alpha: 1.0)
        panel.addChild(confirmBtn)

        let cancelBtn = makeSettingsDialogButton(
            text: "아니요, 취소",
            name: "newCustomerCancel",
            position: CGPoint(x: 0, y: -68),
            width: 180, height: 44
        )
        panel.addChild(cancelBtn)
    }

    private func makeSettingsDialogButton(text: String, name: String,
                                          position: CGPoint, width: CGFloat,
                                          height: CGFloat) -> SKShapeNode {
        let btn = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 12)
        btn.fillColor = UIColor(red: 0.78, green: 0.52, blue: 0.33, alpha: 1.0)
        btn.strokeColor = .clear
        btn.position = position
        btn.name = name
        btn.zPosition = 2

        let lbl = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        lbl.text = text
        lbl.fontSize = 15
        lbl.fontColor = .white
        lbl.horizontalAlignmentMode = .center
        lbl.verticalAlignmentMode = .center
        lbl.name = name
        lbl.zPosition = 3
        btn.addChild(lbl)
        return btn
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
                    SoundManager.shared.play("sfx_button_tap.mp3")
                }
                return

            case "avatarLeft":
                SoundManager.shared.play("sfx_button_tap.mp3")
                ProfileManager.shared.retreat()
                refreshAvatar()
                return

            case "avatarRight":
                SoundManager.shared.play("sfx_button_tap.mp3")
                ProfileManager.shared.advance()
                refreshAvatar()
                return

            case "startPickerBtn":
                SoundManager.shared.play("sfx_button_tap.mp3")
                Store.saveSelectedCustomer(ProfileManager.shared.selectedAssetName)
                transitionToFrontShop()
                return

            case "newCustomerBtn":
                SoundManager.shared.play("sfx_button_tap.mp3")
                showNewCustomerConfirmation()
                return

            case "newCustomerConfirm":
                SoundManager.shared.play("sfx_button_tap.mp3")
                newCustomerOverlayNode?.removeFromParent()
                newCustomerOverlayNode = nil
                Store.resetCustomerSide()
                ProfileManager.shared.selectedIndex = 0
                guard let view = self.view else { return }
                let picker = SettingsScene(size: size)
                picker.scaleMode = scaleMode
                picker.isFirstLaunchPicker = true
                view.presentScene(picker, transition: SKTransition.crossFade(withDuration: 0.4))
                return

            case "newCustomerCancel":
                newCustomerOverlayNode?.removeFromParent()
                newCustomerOverlayNode = nil
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
        scene.scaleMode         = .resizeFill
        // First-launch picker is a genuine entry — let the shop bell ring.
        scene.suppressEntryBell = !isFirstLaunchPicker
        let transition = SKTransition.crossFade(withDuration: 0.5)
        view.presentScene(scene, transition: transition)
    }
}
