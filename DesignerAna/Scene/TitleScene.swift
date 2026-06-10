//
//  TitleScene.swift
//  DesignerAna
//
//  Shown on every launch. Lets the player choose between the storybook
//  introduction and jumping straight to the tailor shop.
//

import SpriteKit
import UIKit

class TitleScene: SKScene {

    // MARK: - Scene setup

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        setupBackdrop()
        setupTitleLogo()
        setupButtons()
    }

    private func setupBackdrop() {
        let bg = SKSpriteNode(imageNamed: "Tailorshop_Background")
        bg.position = .zero
        bg.size = size
        bg.zPosition = 0
        addChild(bg)

        // Gentle dark overlay so buttons read clearly over the shop art.
        let dim = SKSpriteNode(color: UIColor.black.withAlphaComponent(0.35),
                               size: size)
        dim.position = .zero
        dim.zPosition = 1
        addChild(dim)
    }

    private func setupTitleLogo() {
        let sign = SKSpriteNode(imageNamed: "ShopSign_Title")
        guard sign.size.width > 0 else { return }

        // Scale to 45 % of scene width for title-screen presence
        let targetW = size.width * 0.45
        let scale   = targetW / sign.size.width
        sign.setScale(scale)

        let scaledH = sign.size.height * scale
        // Sit the sign in the upper portion of the screen. The 0.60 factor is a
        // fraction of the sign's height — larger drops it lower; below 0.5 the
        // chains bleed past the top edge.
        sign.position  = CGPoint(x: 0, y: size.height * 0.5 - scaledH * 0.60)
        sign.zPosition = 2
        addChild(sign)
    }

    private func setupButtons() {
        let buttonH: CGFloat = 58
        let gap:     CGFloat = 20
        let centerY: CGFloat = -size.height * 0.18

        addChild(makeButton(
            text: "📖  이야기 소개",
            name: "introBtn",
            position: CGPoint(x: 0, y: centerY + buttonH / 2 + gap / 2)
        ))

        addChild(makeButton(
            text: "✂️  바로 시작하기",
            name: "shopBtn",
            position: CGPoint(x: 0, y: centerY - buttonH / 2 - gap / 2)
        ))
    }

    // Matches the FrontShopScene customer choice button style exactly.
    private func makeButton(text: String, name: String,
                             position: CGPoint) -> SKShapeNode {
        let buttonW: CGFloat = min(size.width * 0.62, 280)
        let buttonH: CGFloat = 58

        let btn = SKShapeNode(rectOf: CGSize(width: buttonW, height: buttonH),
                              cornerRadius: 18)
        btn.fillColor   = UIColor(red: 0.78, green: 0.52, blue: 0.33, alpha: 1.0)
        btn.strokeColor = UIColor.brown
        btn.lineWidth   = 3
        btn.position    = position
        btn.zPosition   = 3
        btn.name        = name

        let label = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        label.text                  = text
        label.fontSize              = 22
        label.fontColor             = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position              = .zero
        label.name                  = name
        btn.addChild(label)

        return btn
    }

    // MARK: - Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let view = self.view else { return }
        let loc  = touch.location(in: self)
        let name = nodes(at: loc).compactMap { $0.name }.first

        switch name {
        case "introBtn":
            let storybook = StorybookScene(size: size)
            storybook.scaleMode = .resizeFill
            view.presentScene(storybook, transition: SKTransition.crossFade(withDuration: 0.5))

        case "shopBtn":
            goToShop(view: view)

        default:
            break
        }
    }

    // MARK: - Routing

    private func goToShop(view: SKView) {
        if Store.loadSelectedCustomer() != nil {
            // Returning player — straight to front shop.
            guard let scene = FrontShopScene(fileNamed: "GameScene") else { return }
            scene.scaleMode = .resizeFill
            view.presentScene(scene, transition: SKTransition.crossFade(withDuration: 0.5))
        } else {
            // No customer yet — run the first-time customer picker first.
            let settings = SettingsScene(size: size)
            settings.scaleMode = .resizeFill
            settings.isFirstLaunchPicker = true
            view.presentScene(settings, transition: SKTransition.crossFade(withDuration: 0.5))
        }
    }
}
