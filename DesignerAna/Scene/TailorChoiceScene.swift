//
//  TailorChoiceScene.swift
//  DesignerAna
//
//  Cinematic choice scene triggered once after all four relics are collected.
//  The tailor reflects on the relic deduction and picks one of two paths.
//

import SpriteKit
import UIKit

class TailorChoiceScene: SKScene {

    // MARK: - Public property set by BackRoomScene before presentScene

    var completedOrder: Order?

    // MARK: - Private state

    private var beatIndex = 0
    private var choiceMade = false
    private var bubbleLabel: SKLabelNode!
    private var tapHintLabel: SKLabelNode!
    private var buttonANode: SKShapeNode!
    private var buttonBNode: SKShapeNode!

    private let beats: [String] = [
        "에스텔 공주님의 보랏빛 지팡이, 그림 붓, 팔레트, 그리고 왕실 가족 초상화... 모두 던전에서 찾은 보물들이에요. 에스텔 공주님이 이 던전들을 지나가셨던 거예요! 🤍",
        "공주님은 분명 털실 몬스터와 먼지 몬스터의 숨겨진 비밀을 풀려고 하셨을 거예요. 이 보물들은... 단서일지도 몰라요. 아나 공주님께 꼭 갖다드려야겠어요.",
        "그런데... 먼저 어떻게 할까요? 🤔"
    ]

    // MARK: - Scene setup

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        setupBackdrop()
        setupTailor()
        setupRelicOrbit()
        setupNarrationBubble()
        setupChoiceButtons()
    }

    private func setupBackdrop() {
        let bg = SKSpriteNode(imageNamed: "WizardAssistant_Dungeon")
        bg.position = .zero
        bg.size = size
        bg.zPosition = 0
        addChild(bg)
    }

    private func setupTailor() {
        let tailor = SKSpriteNode(imageNamed: "Tailor")
        tailor.size = CGSize(width: 90, height: 135)
        tailor.position = CGPoint(x: 0, y: -size.height * 0.08)
        tailor.zPosition = 10
        addChild(tailor)
    }

    // MARK: - Relic orbit

    private func setupRelicOrbit() {
        let center = CGPoint(x: 0, y: -size.height * 0.08)
        let rx = size.width * 0.18
        let ry = size.height * 0.18

        let relics: [(DungeonItem, CGFloat)] = [
            (.purpleScepter,      0),
            (.paintBrush,         .pi / 2),
            (.palette,            .pi),
            (.royalFamilyPortrait, 3 * .pi / 2)
        ]

        for (item, startAngle) in relics {
            let glow = SKShapeNode(circleOfRadius: 22)
            glow.fillColor = UIColor(red: 0.55, green: 0.18, blue: 0.80, alpha: 0.35)
            glow.strokeColor = .clear
            glow.zPosition = 8

            let sprite = SKSpriteNode(imageNamed: item.rawValue)
            sprite.size = CGSize(width: 36, height: 36)
            sprite.zPosition = 9

            // Set initial positions before the action starts
            let initPos = CGPoint(
                x: center.x + cos(startAngle) * rx,
                y: center.y + sin(startAngle) * ry
            )
            glow.position = initPos
            sprite.position = initPos

            addChild(glow)
            addChild(sprite)

            let orbitAction = makeOrbitAction(startAngle: startAngle, center: center, rx: rx, ry: ry)
            sprite.run(orbitAction)
            glow.run(orbitAction)
        }
    }

    private func makeOrbitAction(startAngle: CGFloat, center: CGPoint,
                                  rx: CGFloat, ry: CGFloat) -> SKAction {
        let duration: TimeInterval = 6.0
        return SKAction.repeatForever(
            SKAction.customAction(withDuration: duration) { node, elapsed in
                let angle = startAngle + (elapsed / CGFloat(duration)) * .pi * 2
                node.position = CGPoint(
                    x: center.x + cos(angle) * rx,
                    y: center.y + sin(angle) * ry
                )
            }
        )
    }

    // MARK: - Narration bubble

    private func setupNarrationBubble() {
        let bubbleW = min(size.width * 0.72, 460)
        let bubbleH: CGFloat = 82
        let bubbleY = -size.height * 0.28

        let panel = SKShapeNode(
            rect: CGRect(x: -bubbleW / 2, y: -bubbleH / 2, width: bubbleW, height: bubbleH),
            cornerRadius: 20
        )
        panel.fillColor = UIColor(red: 0.98, green: 0.95, blue: 0.85, alpha: 0.93)
        panel.strokeColor = UIColor(red: 0.45, green: 0.25, blue: 0.10, alpha: 1.0)
        panel.lineWidth = 2
        panel.position = CGPoint(x: 0, y: bubbleY)
        panel.zPosition = 20
        addChild(panel)

        let label = SKLabelNode(fontNamed: "AppleSDGothicNeo-Regular")
        label.fontSize = 14
        label.fontColor = .black
        label.numberOfLines = 0
        label.preferredMaxLayoutWidth = bubbleW - 48
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: bubbleY)
        label.zPosition = 21
        label.text = beats[0]
        addChild(label)
        bubbleLabel = label

        let hint = SKLabelNode(fontNamed: "AppleSDGothicNeo-Regular")
        hint.fontSize = 12
        hint.fontColor = UIColor(red: 0.45, green: 0.25, blue: 0.10, alpha: 0.85)
        hint.text = "▶ 탭하세요"
        hint.horizontalAlignmentMode = .center
        hint.position = CGPoint(x: 0, y: bubbleY - bubbleH / 2 - 18)
        hint.zPosition = 21
        addChild(hint)
        tapHintLabel = hint
    }

    // MARK: - Choice buttons

    private func setupChoiceButtons() {
        let buttonY = -size.height * 0.42
        let buttonW = size.width * 0.36
        let buttonH: CGFloat = 52
        let fillColor = UIColor(red: 0.78, green: 0.52, blue: 0.33, alpha: 1.0)

        buttonANode = makeButton(
            text: "옛 선생님께 조언을 구할래요 ✨",
            name: "choiceA",
            x: -size.width * 0.22,
            y: buttonY,
            width: buttonW,
            height: buttonH,
            fill: fillColor
        )
        buttonANode.alpha = 0
        addChild(buttonANode)

        buttonBNode = makeButton(
            text: "곧장 성으로 갈래요 🏰",
            name: "choiceB",
            x: size.width * 0.22,
            y: buttonY,
            width: buttonW,
            height: buttonH,
            fill: fillColor
        )
        buttonBNode.alpha = 0
        addChild(buttonBNode)
    }

    private func makeButton(text: String, name: String,
                             x: CGFloat, y: CGFloat,
                             width: CGFloat, height: CGFloat,
                             fill: UIColor) -> SKShapeNode {
        let btn = SKShapeNode(
            rect: CGRect(x: -width / 2, y: -height / 2, width: width, height: height),
            cornerRadius: 14
        )
        btn.fillColor = fill
        btn.strokeColor = UIColor.brown
        btn.lineWidth = 2
        btn.position = CGPoint(x: x, y: y)
        btn.zPosition = 22
        btn.name = name

        let label = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        label.fontSize = 14
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.numberOfLines = 0
        label.preferredMaxLayoutWidth = width - 20
        label.text = text
        label.zPosition = 23
        label.name = name
        btn.addChild(label)

        return btn
    }

    // MARK: - Beat advancement

    private func advanceBeat() {
        guard beatIndex < 2 else { return }
        beatIndex += 1
        bubbleLabel.text = beats[beatIndex]

        if beatIndex == 2 {
            run(.sequence([
                .wait(forDuration: 0.4),
                .run { [weak self] in self?.revealButtons() }
            ]))
        }
    }

    private func revealButtons() {
        tapHintLabel.run(.fadeOut(withDuration: 0.2))
        buttonANode.run(.fadeIn(withDuration: 0.3))
        buttonBNode.run(.fadeIn(withDuration: 0.3))
    }

    // MARK: - Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !choiceMade, let touch = touches.first else { return }
        let loc = touch.location(in: self)
        let hit = nodes(at: loc).compactMap { $0.name }.first

        switch hit {
        case "choiceA":
            Store.saveRelicChoiceFirst("A")
            handleChoice("A")
        case "choiceB":
            Store.saveRelicChoiceFirst("B")
            handleChoice("B")
        default:
            advanceBeat()
        }
    }

    // MARK: - Choice routing

    private func handleChoice(_ choice: String) {
        guard !choiceMade else { return }
        choiceMade = true

        let tappedButton = choice == "A" ? buttonANode : buttonBNode
        tappedButton?.run(.sequence([
            .scale(to: 1.1, duration: 0.1),
            .scale(to: 1.0, duration: 0.1)
        ]))

        run(.sequence([
            .wait(forDuration: 0.5),
            .run { [weak self] in self?.routeAfterChoice(choice) }
        ]))
    }

    private func routeAfterChoice(_ choice: String) {
        guard let view = self.view else { return }
        // TODO: Phase 5 — Path A: present AuroraChamberScene
        // TODO: Phase 5 — Path B: present PrincessAnaScene
        // Placeholder: both paths return to front shop for now.
        guard let next = FrontShopScene(fileNamed: "GameScene") else { return }
        next.scaleMode = .resizeFill
        next.shouldShowFinishedGarment = true
        next.finishedGarmentImageName = garmentImageName(for: completedOrder)
        next.completedOrder = completedOrder
        next.suppressEntryBell = true
        view.presentScene(next, transition: SKTransition.crossFade(withDuration: 0.6))
    }
}
