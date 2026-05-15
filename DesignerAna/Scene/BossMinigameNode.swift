//
//  BossMinigameNode.swift
//  DesignerAna
//
//  Station 4 — mannequin boss fight.
//  Sibling to MinigameNode; does not extend it.
//  Instantiated directly by BackRoomScene with the player's Order.
//

import SpriteKit

class BossMinigameNode: SKNode {

    // MARK: - Physics categories
    private struct PhysicsCategory {
        static let none:   UInt32 = 0
        static let hero:   UInt32 = 0b0001
        static let ground: UInt32 = 0b0010
        static let hazard: UInt32 = 0b0100   // sweep projectile; slam damage is a manual check
    }

    // MARK: - Attack type
    private enum BossAttack: CaseIterable { case slam, sweep, summon }

    // MARK: - Inputs / callback
    private let order: Order?
    private let onCompletion: () -> Void

    // MARK: - Nodes
    private var hero: SKSpriteNode!
    private var boss: SKSpriteNode!
    private var hpDots: [SKShapeNode] = []
    private var chestNode: SKSpriteNode?
    private var instructionLabel: SKLabelNode!
    private var jumpButton: SKShapeNode!
    private var leftArrowButton: SKShapeNode!
    private var rightArrowButton: SKShapeNode!
    private var adds: [SKSpriteNode] = []

    // MARK: - Hero state
    private var isOnGround = false
    private var isJumping = false
    private var moveDirection: CGFloat = 0
    private var leftButtonTouch: UITouch?
    private var rightButtonTouch: UITouch?
    private var jumpButtonTouch: UITouch?
    private var lastUpdateTime: TimeInterval = 0
    private var heroStartPosition: CGPoint = .zero

    // MARK: - Boss state
    private var bossHP = 3
    private var bossAnchor: CGPoint = .zero
    private var bossDefeated = false
    private var isVulnerable = false
    private var isInvulnerable = false   // brief 0.4s window after each hit
    private var lastAttack: BossAttack?
    private var attackRunning = false

    // MARK: - Misc state
    private var chestOpened = false
    private var isCompleting = false
    private var isDead = false

    // MARK: - Layout
    private var sceneW: CGFloat = 0
    private var sceneH: CGFloat = 0
    private let heroSpeed: CGFloat = 160
    private let jumpPeakFraction: CGFloat = 0.24
    private var jumpVelocity: CGFloat = 0
    private let descentMultiplier: CGFloat = 1.8
    private let gAscent: CGFloat = 18
    private var gDescent: CGFloat { gAscent * descentMultiplier }
    private var inDescent = false
    private let proximityRange: CGFloat = 80

    // MARK: - Theming (derived from order.fabricColor)
    private var bgTint: UIColor = .black
    private var accentColor: UIColor = .white

    // D-pad button colors
    private let buttonRestingFill = UIColor.white.withAlphaComponent(0.25)
    private let buttonPressedFill = UIColor.black.withAlphaComponent(0.35)

    // MARK: - Init

    init(order: Order?, onCompletion: @escaping () -> Void) {
        self.order = order
        self.onCompletion = onCompletion
        super.init()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    // MARK: - Setup (called by BackRoomScene after addChild)

    func setup(in scene: SKScene) {
        sceneW = scene.size.width
        sceneH = scene.size.height
        jumpVelocity = (2.0 * 18.0 * sceneH * jumpPeakFraction).squareRoot()
        scene.physicsWorld.gravity = CGVector(dx: 0, dy: -gAscent)
        sceneRef = scene
        scene.physicsWorld.contactDelegate = contactBridge

        (bgTint, accentColor) = fabricColors(for: order)

        buildArena()
        buildHero()
        buildBoss()
        buildDirectionalButtons()
        buildJumpButton()
        buildInstructionLabel()
        animateEntrance()

        run(.wait(forDuration: 2.0)) { [weak self] in self?.runAttackLoop() }
    }

    private weak var sceneRef: SKScene?
    private lazy var contactBridge = BossContactBridge(owner: self)

    // MARK: - Arena

    private func buildDungeonAtmosphere() {
        let lineColor = UIColor.white.withAlphaComponent(0.07)
        let brickH: CGFloat = 44
        let floorY = -sceneH * 0.40

        var y = floorY + brickH
        var row = 0
        while y < sceneH * 0.52 {
            let h = SKShapeNode(rectOf: CGSize(width: sceneW, height: 1.5))
            h.position = CGPoint(x: 0, y: y)
            h.fillColor = lineColor
            h.strokeColor = .clear
            h.zPosition = 0.1
            addChild(h)

            let offset: CGFloat = row % 2 == 0 ? 0 : 52
            var x = -sceneW * 0.5 + offset
            while x < sceneW * 0.5 {
                let v = SKShapeNode(rectOf: CGSize(width: 1.5, height: brickH))
                v.position = CGPoint(x: x, y: y - brickH / 2)
                v.fillColor = lineColor
                v.strokeColor = .clear
                v.zPosition = 0.1
                addChild(v)
                x += 104
            }
            y += brickH
            row += 1
        }

        let ceiling = SKSpriteNode(color: UIColor.black.withAlphaComponent(0.28),
                                   size: CGSize(width: sceneW, height: 55))
        ceiling.position = CGPoint(x: 0, y: sceneH * 0.5 - 27)
        ceiling.zPosition = 0.2
        addChild(ceiling)

        let floorEdge = SKShapeNode(rectOf: CGSize(width: sceneW, height: 4))
        floorEdge.position = CGPoint(x: 0, y: floorY + 9 + 2)
        floorEdge.fillColor = UIColor.white.withAlphaComponent(0.18)
        floorEdge.strokeColor = .clear
        floorEdge.zPosition = 1.5
        addChild(floorEdge)
    }

    private func buildArena() {
        let bg = SKSpriteNode(color: bgTint, size: CGSize(width: sceneW, height: sceneH))
        bg.position = .zero
        bg.zPosition = 0
        addChild(bg)

        buildDungeonAtmosphere()

        let title = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        title.text = "최후의 대결!"
        title.fontSize = 32
        title.fontColor = .white
        title.position = CGPoint(x: 0, y: sceneH * 0.25)
        title.zPosition = 5
        addChild(title)
        title.run(.sequence([.wait(forDuration: 1.5), .fadeOut(withDuration: 0.5), .removeFromParent()]))

        let floorSize = CGSize(width: sceneW, height: 18)
        let floorNode = SKShapeNode(rectOf: floorSize)
        floorNode.position = CGPoint(x: 0, y: -sceneH * 0.40)
        floorNode.fillColor = accentColor.withAlphaComponent(0.7)
        floorNode.strokeColor = accentColor
        floorNode.lineWidth = 2
        floorNode.zPosition = 1

        let floorBody = SKPhysicsBody(rectangleOf: floorSize)
        floorBody.isDynamic = false
        floorBody.categoryBitMask = PhysicsCategory.ground
        floorBody.contactTestBitMask = PhysicsCategory.none
        floorBody.collisionBitMask = PhysicsCategory.hero
        floorNode.physicsBody = floorBody
        addChild(floorNode)
    }

    // MARK: - Hero

    private func buildHero() {
        hero = SKSpriteNode(imageNamed: "Tailor")
        hero.setScale(0.15)
        heroStartPosition = CGPoint(x: -sceneW * 0.38, y: -sceneH * 0.28)
        hero.position = heroStartPosition
        hero.zPosition = 3
        hero.name = "hero"
        addChild(hero)

        let body = SKPhysicsBody(rectangleOf: CGSize(width: 28, height: 44))
        body.isDynamic = true
        body.allowsRotation = false
        body.friction = 0
        body.linearDamping = 0
        body.usesPreciseCollisionDetection = true
        body.categoryBitMask = PhysicsCategory.hero
        body.contactTestBitMask = PhysicsCategory.ground | PhysicsCategory.hazard
        body.collisionBitMask = PhysicsCategory.ground
        hero.physicsBody = body
    }

    private func animateEntrance() {
        hero.alpha = 0
        hero.run(.fadeIn(withDuration: 0.4))
        hero.run(.sequence([.wait(forDuration: 0.5),
                            .moveBy(x: 0, y: 12, duration: 0.12),
                            .moveBy(x: 0, y: -12, duration: 0.12)]))
    }

    // MARK: - Boss

    private func buildBoss() {
        let floorTop = -sceneH * 0.40 + 9
        bossAnchor = CGPoint(x: sceneW * 0.20, y: floorTop + 88)

        let node = SKSpriteNode(color: UIColor(red: 0.4, green: 0.2, blue: 0.6, alpha: 1),
                                size: CGSize(width: 176, height: 176))
        node.position = bossAnchor
        node.zPosition = 2
        node.name = "boss"

        let emoji = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        emoji.text = "👾"
        emoji.fontSize = 104
        emoji.verticalAlignmentMode = .center
        emoji.position = .zero
        emoji.zPosition = 1
        node.addChild(emoji)

        boss = node
        addChild(node)
        buildHPDots()
    }

    private func buildHPDots() {
        hpDots.forEach { $0.removeFromParent() }
        hpDots = []
        let maxHP = 3
        let spacing: CGFloat = 18
        let totalW = spacing * CGFloat(maxHP - 1)
        for i in 0..<maxHP {
            let dot = SKShapeNode(circleOfRadius: 6)
            dot.fillColor = UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1)
            dot.strokeColor = .white
            dot.lineWidth = 1.5
            dot.position = CGPoint(x: boss.position.x - totalW / 2 + CGFloat(i) * spacing,
                                   y: boss.position.y + 62)
            dot.zPosition = 4
            addChild(dot)
            hpDots.append(dot)
        }
    }

    private func syncHPDotPositions() {
        let spacing: CGFloat = 18
        let totalW = spacing * CGFloat(max(1, hpDots.count - 1))
        for (i, dot) in hpDots.enumerated() {
            dot.position = CGPoint(x: boss.position.x - totalW / 2 + CGFloat(i) * spacing,
                                   y: boss.position.y + 62)
        }
    }

    private func updateHPDots() {
        for (i, dot) in hpDots.enumerated() {
            dot.fillColor = i < bossHP
                ? UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1)
                : UIColor.gray
        }
    }

    // MARK: - D-pad

    private func buildDirectionalButtons() {
        leftArrowButton = makeArrowButton(label: "←", x: -sceneW * 0.42, y: -sceneH * 0.26)
        rightArrowButton = makeArrowButton(label: "→", x: -sceneW * 0.29, y: -sceneH * 0.26)
        addChild(leftArrowButton)
        addChild(rightArrowButton)
    }

    private func makeArrowButton(label text: String, x: CGFloat, y: CGFloat) -> SKShapeNode {
        let btn = SKShapeNode(circleOfRadius: 34)
        btn.position = CGPoint(x: x, y: y)
        btn.fillColor = buttonRestingFill
        btn.strokeColor = UIColor.white.withAlphaComponent(0.7)
        btn.lineWidth = 2
        btn.zPosition = 5
        let lbl = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        lbl.text = text
        lbl.fontSize = 24
        lbl.fontColor = .white
        lbl.verticalAlignmentMode = .center
        lbl.position = .zero
        btn.addChild(lbl)
        return btn
    }

    private func buildJumpButton() {
        let btn = SKShapeNode(circleOfRadius: 34)
        btn.position = CGPoint(x: sceneW * 0.36, y: -sceneH * 0.26)
        btn.fillColor = buttonRestingFill
        btn.strokeColor = UIColor.white.withAlphaComponent(0.7)
        btn.lineWidth = 2
        btn.zPosition = 5
        btn.name = "jumpBtn"
        let lbl = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        lbl.text = "↑"
        lbl.fontSize = 24
        lbl.fontColor = .white
        lbl.verticalAlignmentMode = .center
        lbl.position = .zero
        lbl.name = "jumpBtn"
        btn.addChild(lbl)
        jumpButton = btn
        addChild(btn)
    }

    private func setPressed(_ button: SKShapeNode?, _ pressed: Bool) {
        button?.fillColor = pressed ? buttonPressedFill : buttonRestingFill
    }

    private func buildInstructionLabel() {
        instructionLabel = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        instructionLabel.text = "보스 괴물을 물리쳐요!"
        instructionLabel.fontSize = 18
        instructionLabel.fontColor = .white
        instructionLabel.position = CGPoint(x: 0, y: sceneH * 0.42)
        instructionLabel.zPosition = 5
        addChild(instructionLabel)
    }

    // MARK: - Attack loop

    private func runAttackLoop() {
        guard !bossDefeated, !isDead, !isCompleting, !attackRunning else { return }
        attackRunning = true
        let attack = pickAttack()
        lastAttack = attack
        switch attack {
        case .slam:   executeSlamAttack()
        case .sweep:  executeSweepAttack()
        case .summon: executeSummonAttack()
        }
    }

    private func pickAttack() -> BossAttack {
        let candidates = BossAttack.allCases.filter { $0 != lastAttack }
        return candidates.randomElement() ?? .slam
    }

    private func scheduleNextAttack() {
        guard !bossDefeated, !isDead else { return }
        attackRunning = false
        run(.wait(forDuration: 1.5)) { [weak self] in self?.runAttackLoop() }
    }

    // MARK: - Slam

    private func executeSlamAttack() {
        guard !bossDefeated else { return }
        instructionLabel.text = "빨간 패드를 피하세요!"

        let padX = CGFloat.random(in: -sceneW * 0.35 ... sceneW * 0.15)
        let floorTop = -sceneH * 0.40 + 9
        let padCenterY = floorTop + 8
        let padSize = CGSize(width: 160, height: 16)

        let pad = SKShapeNode(rectOf: padSize, cornerRadius: 4)
        pad.position = CGPoint(x: padX, y: padCenterY)
        pad.fillColor = UIColor.red.withAlphaComponent(0.7)
        pad.strokeColor = .red
        pad.lineWidth = 2
        pad.zPosition = 2
        pad.name = "slamPad"
        addChild(pad)

        pad.run(.repeatForever(.sequence([
            .fadeAlpha(to: 1.0, duration: 0.2),
            .fadeAlpha(to: 0.3, duration: 0.2)
        ])), withKey: "padFlash")

        run(.wait(forDuration: 2.0)) { [weak self] in
            guard let self, !self.bossDefeated else { pad.removeFromParent(); return }
            pad.removeAllActions()
            pad.fillColor = UIColor.red.withAlphaComponent(0.95)

            // Boss drops onto pad
            let dropTarget = CGPoint(x: padX, y: self.bossAnchor.y)
            let drop = SKAction.move(to: dropTarget, duration: 0.15)
            drop.timingMode = .easeIn
            self.boss.run(drop) { [weak self] in
                guard let self else { return }
                self.spawnSparkles(at: pad.position, color: .red)
                // Point-in-time check: hero standing on the pad when boss lands
                if abs(self.hero.position.x - padX) < 88 {
                    self.handleDeath()
                }
                pad.removeFromParent()
                self.openVulnerabilityWindow(duration: 1.5) { [weak self] in
                    self?.boss.run(.move(to: self!.bossAnchor, duration: 0.4)) {
                        self?.scheduleNextAttack()
                    }
                }
            }
        }
    }

    // MARK: - Sweep

    private func executeSweepAttack() {
        guard !bossDefeated else { return }
        instructionLabel.text = "점프해서 피하세요!"

        // Telegraph: boss flashes yellow for 2s
        let chargeFlash = SKAction.repeat(.sequence([
            .colorize(with: .yellow, colorBlendFactor: 0.8, duration: 0.15),
            .colorize(with: UIColor(red: 0.4, green: 0.2, blue: 0.6, alpha: 1),
                      colorBlendFactor: 1.0, duration: 0.15)
        ]), count: 6)
        boss.run(chargeFlash)

        run(.wait(forDuration: 2.0)) { [weak self] in
            guard let self, !self.bossDefeated else { return }

            let floorTop = -self.sceneH * 0.40 + 9
            let projY = floorTop + 16   // matches hero foot height

            let projSize = CGSize(width: 100, height: 40)
            let proj = SKShapeNode(rectOf: projSize, cornerRadius: 6)
            proj.fillColor = UIColor.orange.withAlphaComponent(0.85)
            proj.strokeColor = .yellow
            proj.lineWidth = 2
            proj.position = CGPoint(x: self.boss.position.x - 50, y: projY)
            proj.zPosition = 3
            proj.name = "sweepProjectile"

            let projBody = SKPhysicsBody(rectangleOf: projSize)
            projBody.isDynamic = true
            projBody.affectedByGravity = false
            projBody.velocity = CGVector(dx: -360, dy: 0)
            projBody.categoryBitMask = PhysicsCategory.hazard
            projBody.contactTestBitMask = PhysicsCategory.hero
            projBody.collisionBitMask = PhysicsCategory.none
            proj.physicsBody = projBody

            self.addChild(proj)
            proj.run(.sequence([.wait(forDuration: 3.0), .removeFromParent()]))

            // Vulnerability opens after projectile crosses the screen
            let travelTime = self.sceneW / 360.0 + 0.3
            self.run(.wait(forDuration: travelTime)) { [weak self] in
                guard let self, !self.bossDefeated else { return }
                self.openVulnerabilityWindow(duration: 1.5) { [weak self] in
                    self?.scheduleNextAttack()
                }
            }
        }
    }

    // MARK: - Summon

    private func executeSummonAttack() {
        guard !bossDefeated else { return }
        instructionLabel.text = "작은 괴물들을 처치하세요!"

        boss.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.5, duration: 0.3),
            .fadeAlpha(to: 1.0, duration: 0.3)
        ])), withKey: "summonPulse")

        let floorTop = -sceneH * 0.40 + 9
        for i in 0..<2 {
            let add = SKSpriteNode(color: UIColor(red: 0.5, green: 0.25, blue: 0.7, alpha: 1),
                                   size: CGSize(width: 72, height: 72))
            add.position = CGPoint(x: boss.position.x + CGFloat(i == 0 ? -24 : 24),
                                   y: floorTop + 36)
            add.zPosition = 2
            add.name = "summonAdd"

            let emoji = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
            emoji.text = "👾"
            emoji.fontSize = 40
            emoji.verticalAlignmentMode = .center
            emoji.position = .zero
            emoji.zPosition = 1
            add.addChild(emoji)

            adds.append(add)
            addChild(add)
        }
    }

    private func defeatAdd(_ add: SKSpriteNode) {
        guard let idx = adds.firstIndex(of: add) else { return }
        adds.remove(at: idx)
        spawnSparkles(at: add.position, color: accentColor)
        add.removeFromParent()

        if adds.isEmpty {
            boss.removeAction(forKey: "summonPulse")
            boss.alpha = 1.0
            openVulnerabilityWindow(duration: 1.5) { [weak self] in
                self?.scheduleNextAttack()
            }
        }
    }

    // MARK: - Vulnerability window

    private func openVulnerabilityWindow(duration: TimeInterval, onClose: @escaping () -> Void) {
        guard !bossDefeated else { onClose(); return }
        isVulnerable = true
        boss.run(.colorize(with: .green, colorBlendFactor: 0.4, duration: 0.15))
        instructionLabel.text = "지금이에요! 공격!"

        run(.wait(forDuration: duration)) { [weak self] in
            guard let self else { return }
            self.isVulnerable = false
            if !self.bossDefeated {
                self.boss.run(.colorize(withColorBlendFactor: 0.0, duration: 0.15))
                self.instructionLabel.text = "보스 괴물을 물리쳐요!"
            }
            onClose()
        }
    }

    // MARK: - Boss damage

    private func hitBoss() {
        guard !bossDefeated else { return }
        guard isVulnerable, !isInvulnerable else {
            // Shield flash when hit outside vulnerability window
            boss.run(.sequence([
                .colorize(with: .white, colorBlendFactor: 0.9, duration: 0.08),
                .colorize(withColorBlendFactor: 0.0, duration: 0.08)
            ]))
            return
        }

        bossHP -= 1
        isInvulnerable = true
        updateHPDots()
        spawnSparkles(at: boss.position, color: .white)

        boss.run(.sequence([
            .colorize(with: .white, colorBlendFactor: 1.0, duration: 0.08),
            .wait(forDuration: 0.24),
            .colorize(with: .green, colorBlendFactor: 0.4, duration: 0.08)
        ]))

        run(.wait(forDuration: 0.4)) { [weak self] in self?.isInvulnerable = false }

        if bossHP <= 0 { defeatBoss() }
    }

    // MARK: - Boss defeat + chest reveal

    private func defeatBoss() {
        guard !bossDefeated else { return }
        bossDefeated = true
        isVulnerable = false
        attackRunning = false

        removeAllActions()
        boss.removeAllActions()
        let snapshot = adds
        adds.removeAll()
        snapshot.forEach { $0.removeFromParent() }
        children.filter { $0.name == "sweepProjectile" || $0.name == "slamPad" }
                .forEach { $0.removeFromParent() }

        instructionLabel.text = "해냈어요! 보물 상자를 찾아봐요!"

        let bossLastPos = boss.position
        spawnSparkles(at: bossLastPos, color: accentColor)
        spawnSparkles(at: bossLastPos, color: .white)

        // Boss collapses to reveal the chest it was sitting on
        boss.run(.sequence([
            .group([.scale(to: 0.05, duration: 1.2), .fadeOut(withDuration: 1.2)]),
            .removeFromParent()
        ])) { [weak self] in
            self?.spawnChest(at: bossLastPos)
        }
    }

    // MARK: - Chest

    private func spawnChest(at position: CGPoint) {
        let chest = SKSpriteNode(color: UIColor(red: 0.7, green: 0.5, blue: 0.1, alpha: 1),
                                 size: CGSize(width: 60, height: 50))
        chest.position = position
        chest.zPosition = 2
        chest.name = "bossChest"
        chest.alpha = 0

        let emoji = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        emoji.text = "📦"
        emoji.fontSize = 34
        emoji.verticalAlignmentMode = .center
        emoji.position = .zero
        chest.addChild(emoji)

        chestNode = chest
        addChild(chest)

        chest.run(.sequence([
            .fadeIn(withDuration: 0.5),
            .scale(to: 1.2, duration: 0.2),
            .scale(to: 1.0, duration: 0.1)
        ]))
    }

    private let bossReward = 50

    private func openChest() {
        guard !chestOpened else { return }
        chestOpened = true
        isCompleting = true

        let label = garmentCompletionText(for: order)
        instructionLabel.text = label

        chestNode?.run(.sequence([.scale(to: 1.3, duration: 0.12), .scale(to: 1.0, duration: 0.10)]))

        let chestPos = chestNode?.position ?? .zero

        // Garment label rises from chest
        let reward = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        reward.text = label
        reward.fontSize = 28
        reward.fontColor = .white
        reward.position = chestPos
        reward.zPosition = 6
        addChild(reward)

        let rise = SKAction.moveBy(x: 0, y: 80, duration: 0.6)
        rise.timingMode = .easeOut
        reward.run(.sequence([rise, .fadeOut(withDuration: 0.3), .removeFromParent()]))

        // 냥 reward awarded and displayed
        Wallet.shared.balance += bossReward
        let coinPop = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        coinPop.text = "+\(bossReward)냥"
        coinPop.fontSize = 32
        coinPop.fontColor = UIColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1.0)
        coinPop.position = CGPoint(x: chestPos.x, y: chestPos.y + 40)
        coinPop.zPosition = 7
        addChild(coinPop)

        let coinRise = SKAction.moveBy(x: 0, y: 70, duration: 0.7)
        coinRise.timingMode = .easeOut
        coinPop.run(.sequence([coinRise, .fadeOut(withDuration: 0.3), .removeFromParent()]))

        spawnSparkles(at: chestPos, color: accentColor)

        run(.wait(forDuration: 1.0)) { [weak self] in self?.onCompletion() }
    }

    // MARK: - Death / retry

    private func handleDeath() {
        guard !isDead, !isCompleting, !bossDefeated else { return }
        isDead = true
        moveDirection = 0
        leftButtonTouch = nil
        rightButtonTouch = nil
        jumpButtonTouch = nil
        setPressed(leftArrowButton, false)
        setPressed(rightArrowButton, false)
        setPressed(jumpButton, false)
        hero.physicsBody?.velocity = .zero

        let msg = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        msg.text = "다시 도전해봐요!"
        msg.fontSize = 26
        msg.fontColor = UIColor(red: 1.0, green: 0.9, blue: 0.3, alpha: 1)
        msg.position = CGPoint(x: 0, y: sceneH * 0.05)
        msg.zPosition = 6
        addChild(msg)

        hero.run(.sequence([
            .fadeAlpha(to: 0.2, duration: 0.15),
            .wait(forDuration: 0.7),
            .fadeIn(withDuration: 0.2)
        ]))

        run(.wait(forDuration: 1.1)) { [weak self] in
            msg.removeFromParent()
            self?.resetBossFight()
        }
    }

    private func resetBossFight() {
        // Clear in-flight hazards and adds
        let snapshot = adds
        adds.removeAll()
        snapshot.forEach { $0.removeFromParent() }
        children.filter { $0.name == "sweepProjectile" || $0.name == "slamPad" }
                .forEach { $0.removeFromParent() }

        // Reset hero
        hero.position = heroStartPosition
        hero.physicsBody?.velocity = .zero

        // Reset boss — cancel running actions first, then restore state
        removeAllActions()
        boss.removeAllActions()
        boss.position = bossAnchor
        boss.alpha = 1.0
        boss.setScale(1.0)
        boss.run(.colorize(withColorBlendFactor: 0.0, duration: 0.0))
        bossHP = 3
        isVulnerable = false
        isInvulnerable = false
        attackRunning = false
        bossDefeated = false
        updateHPDots()

        instructionLabel.text = "보스 괴물을 물리쳐요!"
        isDead = false

        run(.wait(forDuration: 1.5)) { [weak self] in self?.runAttackLoop() }
    }

    // MARK: - Touch handling (called by BackRoomScene)

    func handleTouchBegan(_ touch: UITouch) {
        guard !isCompleting, !isDead else { return }
        guard let scene = sceneRef else { return }
        // BossMinigameNode sits at position (0,0) in scene, so scene coords
        // and node-local coords are identical — no conversion needed.
        let loc = touch.location(in: scene)

        if jumpButton.contains(loc) {
            jumpButtonTouch = touch
            setPressed(jumpButton, true)
            tryJump()
            return
        }
        if leftArrowButton.contains(loc) {
            leftButtonTouch = touch
            setPressed(leftArrowButton, true)
            updateMoveDirection()
            return
        }
        if rightArrowButton.contains(loc) {
            rightButtonTouch = touch
            setPressed(rightArrowButton, true)
            updateMoveDirection()
            return
        }

        // Tap boss (proximity)
        if !bossDefeated, boss.contains(loc) {
            if abs(hero.position.x - boss.position.x) <= proximityRange {
                hitBoss()
            }
            return
        }

        // Tap adds (proximity)
        for add in adds {
            if add.contains(loc), abs(hero.position.x - add.position.x) <= 70 {
                defeatAdd(add)
                return
            }
        }

        // Tap chest
        if bossDefeated, !chestOpened, let chest = chestNode, chest.contains(loc) {
            openChest()
        }
    }

    func handleTouchEnded(_ touch: UITouch) {
        if touch === leftButtonTouch {
            leftButtonTouch = nil
            setPressed(leftArrowButton, false)
            updateMoveDirection()
        } else if touch === rightButtonTouch {
            rightButtonTouch = nil
            setPressed(rightArrowButton, false)
            updateMoveDirection()
        } else if touch === jumpButtonTouch {
            jumpButtonTouch = nil
            setPressed(jumpButton, false)
        }
    }

    private func updateMoveDirection() {
        let l = leftButtonTouch != nil, r = rightButtonTouch != nil
        if l && !r      { moveDirection = -1; hero.xScale =  abs(hero.xScale) }
        else if r && !l { moveDirection =  1; hero.xScale = -abs(hero.xScale) }
        else            { moveDirection =  0 }
    }

    private func tryJump() {
        guard isOnGround, !isJumping else { return }
        isOnGround = false
        isJumping = true
        hero.removeAction(forKey: "step")
        let currentDx = hero.physicsBody?.velocity.dx ?? 0
        hero.physicsBody?.velocity = CGVector(dx: currentDx, dy: jumpVelocity)
        inDescent = false
        sceneRef?.physicsWorld.gravity = CGVector(dx: 0, dy: -gAscent)
    }

    // MARK: - Update (called by BackRoomScene.update)

    func update(currentTime: TimeInterval) {
        guard lastUpdateTime > 0 else { lastUpdateTime = currentTime; return }
        let dt = currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        guard !isDead, !isCompleting else { return }

        // Hero horizontal movement
        if moveDirection != 0 {
            hero.position.x += moveDirection * heroSpeed * CGFloat(dt)
            if hero.action(forKey: "step") == nil {
                hero.run(.sequence([.moveBy(x: 0, y: 6, duration: 0.08),
                                    .moveBy(x: 0, y: -6, duration: 0.08)]),
                         withKey: "step")
            }
        }
        hero.position.x = max(-sceneW * 0.47, min(sceneW * 0.47, hero.position.x))

        // Floor failsafe
        let floorSurface = -sceneH * 0.40 + 40
        if hero.position.y < floorSurface {
            hero.position.y = floorSurface
            hero.physicsBody?.velocity = CGVector(dx: hero.physicsBody?.velocity.dx ?? 0, dy: 0)
            isOnGround = true
            isJumping = false
            inDescent = false
            sceneRef?.physicsWorld.gravity = CGVector(dx: 0, dy: -gAscent)
        }

        // Asymmetric jump: switch to descent gravity once the hero starts falling.
        if !inDescent, isJumping, let dy = hero.physicsBody?.velocity.dy, dy <= 0 {
            inDescent = true
            sceneRef?.physicsWorld.gravity = CGVector(dx: 0, dy: -gDescent)
        }

        // Boss stomp detection (only stun-eligible if vulnerable)
        if !bossDefeated {
            let vdy = hero.physicsBody?.velocity.dy ?? 0
            let dx = abs(hero.position.x - boss.position.x)
            let heroFeet = hero.position.y - 22
            let bossTop = boss.position.y + 88
            let dy = abs(hero.position.y - boss.position.y)
            let overlapping = dx < 102 && dy < 110
            let isStomp = vdy < -50 && heroFeet <= bossTop && heroFeet >= bossTop - 140
            if overlapping {
                if isStomp {
                    hitBoss()
                } else {
                    // Slide hero to just outside the overlap zone and pop them
                    // upward slightly. Using a position nudge (not velocity) avoids
                    // the zero-damping drift that sent the hero flying to the wall.
                    let pushDir: CGFloat = hero.position.x < boss.position.x ? -1 : 1
                    hero.position.x = boss.position.x + pushDir * 110
                    let curDx = hero.physicsBody?.velocity.dx ?? 0
                    hero.physicsBody?.velocity = CGVector(dx: curDx, dy: 90)
                }
            }
        }

        // Add movement + hero/add collision
        let addSnapshot = adds
        var heroKilledByAdd = false
        for add in addSnapshot {
            // Adds pace toward hero
            let dir: CGFloat = hero.position.x < add.position.x ? -1 : 1
            add.position.x += dir * 60 * CGFloat(dt)
            add.xScale = dir > 0 ? 1 : -1

            // Stomp or side-contact
            if heroKilledByAdd { continue }
            let vdy = hero.physicsBody?.velocity.dy ?? 0
            let dx = abs(hero.position.x - add.position.x)
            let dy = abs(hero.position.y - add.position.y)
            let heroFeet = hero.position.y - 22
            let addTop = add.position.y + 36
            let overlapping = dx < 50 && dy < 58
            let isStomp = vdy < -50 && heroFeet <= addTop && heroFeet >= addTop - 48
            if overlapping {
                if isStomp { defeatAdd(add) }
                else { heroKilledByAdd = true }
            }
        }
        if heroKilledByAdd { handleDeath() }

        // HP dots track boss as it moves
        syncHPDotPositions()
    }

    // MARK: - Physics contact (ground / sweep projectile)

    fileprivate func didBeginContact(_ contact: SKPhysicsContact) {
        let a = contact.bodyA.categoryBitMask
        let b = contact.bodyB.categoryBitMask

        let heroGround = (a == PhysicsCategory.hero && b == PhysicsCategory.ground) ||
                         (a == PhysicsCategory.ground && b == PhysicsCategory.hero)
        if heroGround, (hero.physicsBody?.velocity.dy ?? 0) <= 0 {
            isOnGround = true
            isJumping = false
            inDescent = false
            sceneRef?.physicsWorld.gravity = CGVector(dx: 0, dy: -gAscent)
        }

        let heroHazard = (a == PhysicsCategory.hero && b == PhysicsCategory.hazard) ||
                         (a == PhysicsCategory.hazard && b == PhysicsCategory.hero)
        if heroHazard { handleDeath() }
    }

    // MARK: - Sparkles

    private func spawnSparkles(at position: CGPoint, color: UIColor) {
        for i in 0..<8 {
            let spark = SKShapeNode(circleOfRadius: 4)
            spark.fillColor = color
            spark.strokeColor = .clear
            spark.position = position
            spark.zPosition = 4
            addChild(spark)
            let angle = CGFloat(i) / 8 * .pi * 2
            let target = CGPoint(x: position.x + cos(angle) * 50,
                                 y: position.y + sin(angle) * 50)
            spark.run(.sequence([.move(to: target, duration: 0.35),
                                 .fadeOut(withDuration: 0.2),
                                 .removeFromParent()]))
        }
    }

}

// MARK: - BossContactBridge
private class BossContactBridge: NSObject, SKPhysicsContactDelegate {
    weak var owner: BossMinigameNode?
    init(owner: BossMinigameNode) { self.owner = owner }
    func didBegin(_ contact: SKPhysicsContact) { owner?.didBeginContact(contact) }
}
