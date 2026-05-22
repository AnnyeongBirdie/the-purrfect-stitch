//
//  RiddleScene.swift
//  DesignerAna
//
//  Riddle economy: shopkeeper quizzes the player, up to 3 questions per visit,
//  +15냥 per correct answer.
//
//  Layout (landscape):
//    Left half  → shopkeeper sprite
//    Right half → speech bubble with question + 2×2 answer buttons
//    Right edge → ← close button (same style as DressingRoomScene)
//

import SpriteKit

class RiddleScene: SKScene {

    // ── Riddle state ────────────────────────────────────────────────────────
    private let bank: [Riddle] = RiddleBank.load()
    private var bankIndex    = 0
    private var sessionCount = 0       // riddles answered correctly this visit
    private var currentRiddle: Riddle?
    private var answering    = false   // prevents double-tap during feedback

    // ── UI ──────────────────────────────────────────────────────────────────
    private var bubbleNode: SKShapeNode!
    private var safeBottom: CGFloat = 0

    // Bubble dimensions — computed from scene size so layout scales to device
    private var bubbleW: CGFloat { min(size.width * 0.44, 310) }
    private var bubbleH: CGFloat { min(size.height * 0.84, 290) }

    // ── Lifecycle ────────────────────────────────────────────────────────────
    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        safeBottom = view.safeAreaInsets.bottom

        setupBackground()
        setupShopkeeper()
        setupBubbleShell()
        setupCloseButton()
        nextRiddle()
    }

    // MARK: - Scene construction

    private func setupBackground() {
        backgroundColor = UIColor(red: 0.10, green: 0.09, blue: 0.14, alpha: 1)
        let bg = SKSpriteNode(imageNamed: "Tailorshop_Background")
        bg.position = .zero
        bg.size = self.size
        bg.zPosition = 0
        bg.alpha = 0.45
        addChild(bg)
    }

    private func setupShopkeeper() {
        let keeper = SKSpriteNode(imageNamed: "Shopkeeper")
        // Scale so the shopkeeper fills roughly the left half height
        let targetH = size.height * 0.80
        let native  = keeper.size
        let fit     = native.height > 0 ? targetH / native.height : 0.55
        keeper.setScale(fit)
        keeper.position = CGPoint(x: -size.width * 0.20, y: -safeBottom * 0.3)
        keeper.zPosition = 2
        addChild(keeper)
    }

    private func setupBubbleShell() {
        let bubble = SKShapeNode(
            rectOf: CGSize(width: bubbleW, height: bubbleH),
            cornerRadius: 28
        )
        bubble.fillColor = UIColor(red: 0.98, green: 0.95, blue: 0.85, alpha: 0.97)
        bubble.strokeColor = .brown
        bubble.lineWidth   = 4
        bubble.position    = CGPoint(x: size.width * 0.16, y: 0)
        bubble.zPosition   = 5
        addChild(bubble)
        bubbleNode = bubble
    }

    private func setupCloseButton() {
        // Matches DressingRoomScene / FrontShopScene back-button style
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

    // MARK: - Riddle flow

    private func nextRiddle() {
        guard sessionCount < 3 else {
            showSessionComplete()
            return
        }
        if bankIndex >= bank.count { bankIndex = 0 }
        let riddle    = bank[bankIndex]
        bankIndex    += 1
        currentRiddle = riddle
        answering     = false
        fillBubble(riddle: riddle, number: sessionCount + 1)
    }

    /// Rebuild the speech bubble content for the given riddle.
    private func fillBubble(riddle: Riddle, number: Int) {
        bubbleNode.removeAllChildren()

        let hw = bubbleW / 2
        let hh = bubbleH / 2

        // Header row: "1/3" left · "💰 Xnyang" centre · "+15냥" right
        let headerY = hh - 22

        let counter = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        counter.text                    = "\(number)/3"
        counter.fontSize                = 17
        counter.fontColor               = UIColor(red: 0.55, green: 0.35, blue: 0.10, alpha: 1.0)
        counter.horizontalAlignmentMode = .left
        counter.verticalAlignmentMode   = .center
        counter.position                = CGPoint(x: -hw + 16, y: headerY)
        counter.zPosition               = 1
        bubbleNode.addChild(counter)

        let walletLbl = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        walletLbl.text                    = "💰 \(Wallet.shared.balance)냥"
        walletLbl.fontSize                = 17
        walletLbl.fontColor               = UIColor(red: 0.55, green: 0.35, blue: 0.10, alpha: 1.0)
        walletLbl.horizontalAlignmentMode = .center
        walletLbl.verticalAlignmentMode   = .center
        walletLbl.position                = CGPoint(x: 0, y: headerY)
        walletLbl.zPosition               = 1
        bubbleNode.addChild(walletLbl)

        let rewardHint = SKLabelNode(fontNamed: "AppleSDGothicNeo-Regular")
        rewardHint.text                    = "+\(riddle.reward)냥"
        rewardHint.fontSize                = 15
        rewardHint.fontColor               = UIColor(red: 0.65, green: 0.45, blue: 0.10, alpha: 1.0)
        rewardHint.horizontalAlignmentMode = .right
        rewardHint.verticalAlignmentMode   = .center
        rewardHint.position                = CGPoint(x: hw - 16, y: headerY)
        rewardHint.zPosition               = 1
        bubbleNode.addChild(rewardHint)

        // Question text
        let qLabel = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        qLabel.text                    = riddle.question
        qLabel.fontSize                = 24
        qLabel.fontColor               = .black
        qLabel.horizontalAlignmentMode = .center
        qLabel.verticalAlignmentMode   = .center
        qLabel.numberOfLines           = 2
        qLabel.preferredMaxLayoutWidth = bubbleW - 32
        qLabel.position                = CGPoint(x: 0, y: hh * 0.42)
        qLabel.zPosition               = 1
        bubbleNode.addChild(qLabel)

        // 2×2 answer buttons
        let btnW  = (bubbleW - 48) / 2   // split width minus gap and padding
        let btnH: CGFloat = 46
        let colX  = (btnW + 8) / 2       // half-gap between columns
        let row1Y = -hh * 0.05
        let row2Y = row1Y - btnH - 10

        let positions: [CGPoint] = [
            CGPoint(x: -colX, y: row1Y),
            CGPoint(x:  colX, y: row1Y),
            CGPoint(x: -colX, y: row2Y),
            CGPoint(x:  colX, y: row2Y),
        ]

        for (i, choice) in riddle.choices.enumerated() {
            let btn = SKShapeNode(rectOf: CGSize(width: btnW, height: btnH), cornerRadius: 12)
            btn.fillColor   = UIColor(red: 0.78, green: 0.52, blue: 0.33, alpha: 1.0)
            btn.strokeColor = .brown
            btn.lineWidth   = 2
            btn.position    = positions[i]
            btn.zPosition   = 1
            btn.name        = "choice_\(i)"

            let lbl = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
            lbl.text                    = choice
            lbl.fontSize                = 18
            lbl.fontColor               = .white
            lbl.horizontalAlignmentMode = .center
            lbl.verticalAlignmentMode   = .center
            lbl.name                    = "choice_\(i)"
            lbl.zPosition               = 2
            btn.addChild(lbl)
            bubbleNode.addChild(btn)
        }
    }

    // MARK: - Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        for node in nodes(at: location) {
            guard let name = node.name else { continue }

            if name == "closeBtn" {
                transitionToFrontShop()
                return
            }

            if !answering,
               name.hasPrefix("choice_"),
               let idxStr = name.split(separator: "_").last,
               let idx    = Int(String(idxStr)) {
                answering = true
                handleAnswer(index: idx)
                return
            }
        }
    }

    // MARK: - Answer handling

    private func handleAnswer(index: Int) {
        guard let riddle = currentRiddle,
              index < riddle.choices.count else { return }

        if riddle.choices[index] == riddle.answer {
            Wallet.shared.balance += riddle.reward
            sessionCount += 1
            showCorrectFeedback(reward: riddle.reward)
        } else {
            showWrongFeedback()
        }
    }

    private func showCorrectFeedback(reward: Int) {
        // Gold coin label floats up from the bubble
        let coin = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        coin.text                    = "+\(reward)냥!"
        coin.fontSize                = 30
        coin.fontColor               = UIColor(red: 1.0, green: 0.8, blue: 0.1, alpha: 1.0)
        coin.horizontalAlignmentMode = .center
        coin.verticalAlignmentMode   = .center
        coin.position                = bubbleNode.position
        coin.zPosition               = 20
        addChild(coin)
        coin.run(.sequence([
            .group([
                .moveBy(x: 0, y: 60, duration: 0.9),
                .sequence([
                    .fadeIn(withDuration: 0.15),
                    .wait(forDuration: 0.55),
                    .fadeOut(withDuration: 0.20),
                ]),
            ]),
            .removeFromParent(),
        ]))

        // Replace bubble content with success message
        bubbleNode.removeAllChildren()
        let msg = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        msg.text                    = "맞아요! 잘했어요 🎉"
        msg.fontSize                = 24
        msg.fontColor               = .black
        msg.horizontalAlignmentMode = .center
        msg.verticalAlignmentMode   = .center
        msg.position                = .zero
        msg.zPosition               = 1
        bubbleNode.addChild(msg)

        run(.sequence([
            .wait(forDuration: 1.2),
            .run { [weak self] in self?.nextRiddle() },
        ]))
    }

    private func showWrongFeedback() {
        // Shake the bubble, then re-enable taps
        bubbleNode.run(.sequence([
            .moveBy(x: -10, y: 0, duration: 0.06),
            .moveBy(x:  20, y: 0, duration: 0.06),
            .moveBy(x: -20, y: 0, duration: 0.06),
            .moveBy(x:  10, y: 0, duration: 0.06),
        ])) { [weak self] in
            self?.answering = false
        }

        // Brief "다시 해봐요!" hint at the bottom of the bubble
        let hint = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        hint.text                    = "다시 해봐요!"
        hint.fontSize                = 17
        hint.fontColor               = UIColor(red: 0.75, green: 0.10, blue: 0.10, alpha: 1.0)
        hint.horizontalAlignmentMode = .center
        hint.verticalAlignmentMode   = .center
        hint.position                = CGPoint(x: 0, y: -bubbleH / 2 + 20)
        hint.zPosition               = 10
        hint.alpha                   = 0
        bubbleNode.addChild(hint)

        hint.run(.sequence([
            .fadeIn(withDuration: 0.15),
            .wait(forDuration: 1.0),
            .fadeOut(withDuration: 0.20),
            .removeFromParent(),
        ]))
    }

    // MARK: - Session complete

    private func showSessionComplete() {
        bubbleNode.removeAllChildren()

        let msg = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        msg.text                    = "퀴즈 끝!\n열심히 했어요 🎉"
        msg.fontSize                = 22
        msg.fontColor               = .black
        msg.horizontalAlignmentMode = .center
        msg.verticalAlignmentMode   = .center
        msg.numberOfLines           = 2
        msg.preferredMaxLayoutWidth = bubbleW - 32
        msg.position                = .zero
        msg.zPosition               = 1
        bubbleNode.addChild(msg)

        run(.sequence([
            .wait(forDuration: 2.5),
            .run { [weak self] in self?.transitionToFrontShop() },
        ]))
    }

    // MARK: - Navigation

    private func transitionToFrontShop() {
        guard let view = self.view,
              let scene = FrontShopScene(fileNamed: "GameScene") else { return }
        scene.scaleMode = .resizeFill
        scene.suppressEntryBell = true
        let transition = SKTransition.crossFade(withDuration: 0.5)
        view.presentScene(scene, transition: transition)
    }
}
