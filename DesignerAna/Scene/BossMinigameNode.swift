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
    private var bossAura: SKShapeNode!     // state-feedback halo behind the boss
    private var sleepIndicatorNode: SKNode?    // 💤 sleep indicator shown during the vulnerability window
    private var platformRects: [CGRect] = []   // climb-up ledges (kinematic landing)
    private var hpDots: [SKShapeNode] = []
    private var chestNode: SKSpriteNode?
    private var instructionLabel: SKLabelNode!
    private var jumpButton: SKShapeNode!
    private var leftArrowButton: SKShapeNode!
    private var rightArrowButton: SKShapeNode!
    private var adds: [SKSpriteNode] = []

    // MARK: - Hero state
    private var isOnGround = true   // hero spawns standing on the floor
    private var isJumping = false
    private var moveDirection: CGFloat = 0
    private var leftButtonTouch: UITouch?
    private var rightButtonTouch: UITouch?
    private var jumpButtonTouch: UITouch?
    private var lastUpdateTime: TimeInterval = 0
    private var heroStartPosition: CGPoint = .zero

    // Haptic generators — created once, reused on every button press
    private let hapticLight  = UIImpactFeedbackGenerator(style: .light)
    private let hapticMedium = UIImpactFeedbackGenerator(style: .medium)

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
    private var floorCenterY: CGFloat = 0   // matches MinigameNode floor position
    private let heroSpeed: CGFloat = 160
    // Jump tuning knobs — a "snappy arcade" jump. Dial these without touching structure:
    //   jumpPeakFraction  — peak height as a fraction of sceneH
    //   timeToApex        — seconds from launch to the top of the arc (lower = snappier)
    //   descentMultiplier — descent gravity = ascent gravity × this (>1 = Mario-style quick fall)
    private let jumpPeakFraction: CGFloat = 0.24
    private let timeToApex: CGFloat = 0.35
    private let descentMultiplier: CGFloat = 1.8
    // Derived in setup(in:) once sceneH is known — see the kinematics there.
    private var gAscent: CGFloat = 0
    private var gDescent: CGFloat { gAscent * descentMultiplier }
    private var jumpVelocity: CGFloat = 0
    private var inDescent = false
    private var heroVelY: CGFloat = 0         // kinematic vertical velocity (pts/sec)
    private let proximityRange: CGFloat = 80

    // MARK: - Theming (derived from order.fabricColor)
    private var bgTint: UIColor = .black
    private var accentColor: UIColor = .white

    // D-pad button colors
    private let buttonRestingFill = UIColor.white.withAlphaComponent(0.25)
    private let buttonPressedFill = UIColor.black.withAlphaComponent(0.35)

    // Boss-aura state color (attack telegraph)
    private let auraCharging = UIColor(red: 1.00, green: 0.82, blue: 0.20, alpha: 1)

    // MARK: - Relic state
    private var portraitNode: SKSpriteNode?
    private var portraitCollected = false
    private var onRelicCollected: ((DungeonItem) -> Void)?

    // MARK: - Init

    init(order: Order?,
         onRelicCollected: ((DungeonItem) -> Void)? = nil,
         onCompletion: @escaping () -> Void) {
        self.order = order
        self.onRelicCollected = onRelicCollected
        self.onCompletion = onCompletion
        super.init()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    // MARK: - Setup (called by BackRoomScene after addChild)

    func setup(in scene: SKScene) {
        sceneW = scene.size.width
        sceneH = scene.size.height
        floorCenterY = -sceneH * 0.26   // same as MinigameNode floor
        // Jump physics derived from the tuning knobs above. For a launch velocity v
        // under constant gravity g: time-to-apex = v / g and apex height = v² / (2g).
        // Solving both for the desired apex height and time gives:
        //   g = 2·height / timeToApex²        v = 2·height / timeToApex
        let peakHeight = sceneH * jumpPeakFraction
        gAscent = 2 * peakHeight / (timeToApex * timeToApex)
        jumpVelocity = 2 * peakHeight / timeToApex
        sceneRef = scene

        (bgTint, accentColor) = fabricColors(for: order)

        buildArena()
        buildHero()
        buildBoss()
        buildPlatforms()
        spawnBreadcrumbs()
        spawnPortrait()
        buildDirectionalButtons()
        buildJumpButton()
        buildInstructionLabel()
        animateEntrance()

        run(.wait(forDuration: 2.0)) { [weak self] in self?.runAttackLoop() }
    }

    private weak var sceneRef: SKScene?

    // MARK: - Arena

    private func buildDungeonAtmosphere() {
        let lineColor = UIColor.white.withAlphaComponent(0.07)
        let brickH: CGFloat = 44
        let floorY = floorCenterY

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
        floorNode.position = CGPoint(x: 0, y: floorCenterY)
        floorNode.fillColor = accentColor.withAlphaComponent(0.7)
        floorNode.strokeColor = accentColor
        floorNode.lineWidth = 2
        floorNode.zPosition = 1

        let floorBody = SKPhysicsBody(rectangleOf: floorSize)
        floorBody.isDynamic = false
        floorBody.friction = 0
        floorBody.restitution = 0     // no bounce — pairs with the hero body
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
        heroStartPosition = CGPoint(x: -sceneW * 0.38, y: floorCenterY + 40)
        hero.position = heroStartPosition
        hero.zPosition = 3
        hero.name = "hero"
        addChild(hero)

        // The physics body is used ONLY for hazard contact detection. The hero's
        // movement — horizontal AND vertical — is fully kinematic (see update()).
        let body = SKPhysicsBody(rectangleOf: CGSize(width: 28, height: 44))
        body.isDynamic = true
        body.affectedByGravity = false
        body.allowsRotation = false
        body.categoryBitMask = PhysicsCategory.hero
        body.contactTestBitMask = PhysicsCategory.hazard
        body.collisionBitMask = PhysicsCategory.none
        hero.physicsBody = body
    }

    private func animateEntrance() {
        hero.alpha = 0
        hero.run(.fadeIn(withDuration: 0.4))
    }

    // MARK: - Boss

    private func buildBoss() {
        let floorTop = floorCenterY + 9
        // Boss sits on the floor: center = floorTop + half-height.
        // PNG is 1024×1536 (2:3 ratio) so width 130 → height 195; half-height = 97.
        // PNG transparent-padding rule: Boss PNG has ~30pt of transparent space at the bottom
        // (more than regular monsters), so visual feet land at surfaceTop + (halfHeight - 30)
        // = floorTop + 97 - 30 = floorTop + 67.
        bossAnchor = CGPoint(x: sceneW * 0.20 + 20, y: floorTop + 67)

        let node = SKSpriteNode(imageNamed: "Boss")
        node.size = CGSize(width: 130, height: 195)
        node.position = bossAnchor
        node.zPosition = 2
        node.name = "boss"

        // State-feedback halo behind the boss sprite. zPosition -1 so it renders
        // beneath the texture (children with negative z appear behind the sprite image).
        let aura = SKShapeNode(circleOfRadius: 70)
        aura.strokeColor = .clear
        aura.zPosition = -1
        aura.alpha = 0
        node.addChild(aura)
        bossAura = aura

        boss = node
        addChild(node)
        buildHPDots()
    }

    // Two stepping-stone ledges leading up toward the boss, so the hero can
    // climb up and drop onto it.
    private func buildPlatforms() {
        let floorTop = floorCenterY + 9
        makePlatform(x: -sceneW * 0.12, centerY: floorTop + 49, width: 150)  // lower step
        makePlatform(x:  sceneW * 0.04, centerY: floorTop + 101, width: 150) // upper step
    }

    private func makePlatform(x: CGFloat, centerY: CGFloat, width: CGFloat) {
        let height: CGFloat = 16
        let node = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 6)
        node.position = CGPoint(x: x, y: centerY)
        node.fillColor = accentColor.withAlphaComponent(0.7)
        node.strokeColor = accentColor
        node.lineWidth = 2
        node.zPosition = 1
        addChild(node)
        platformRects.append(CGRect(x: x - width / 2, y: centerY - height / 2,
                                    width: width, height: height))
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
                                   y: boss.position.y + 106)   // above 195pt boss
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
                                   y: boss.position.y + 106)   // above 195pt boss
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
        let buttonY = -sceneH * 0.38   // same level as jump button, below floor
        leftArrowButton  = makeArrowButton(label: "←", x: -sceneW * 0.42, y: buttonY)
        rightArrowButton = makeArrowButton(label: "→", x: -sceneW * 0.29, y: buttonY)
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
        btn.position = CGPoint(x: sceneW * 0.36, y: -sceneH * 0.38)
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
        let floorTop = floorCenterY + 9
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

        // Low rumble while the red slam-pad warning flashes.
        SoundManager.shared.play("sfx_boss_telegraph_slam.mp3")

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
                // Heavy thud as the boss lands.
                SoundManager.shared.play("sfx_boss_slam_impact.mp3")
                self.spawnSparkles(at: pad.position, color: .red)
                // Point-in-time check: hero standing on the pad when boss lands
                if abs(self.hero.position.x - padX) < 88 {
                    self.handleDeath()
                }
                pad.removeFromParent()
                self.openVulnerabilityWindow(duration: 3.0) { [weak self] in
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

        // Telegraph: a charging-yellow halo for the 2s wind-up.
        pulseAura(auraCharging)
        SoundManager.shared.play("sfx_boss_telegraph_sweep.mp3")

        run(.wait(forDuration: 2.0)) { [weak self] in
            guard let self, !self.bossDefeated else { return }
            self.hideAura()   // telegraph over — the sweep launches

            let floorTop = self.floorCenterY + 9
            let projY = floorTop + 16   // matches hero foot height

            let projSize = CGSize(width: 60, height: 24)
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
            // Projectile whoosh as the sweep launches.
            SoundManager.shared.play("sfx_boss_sweep_fire.mp3")
            proj.run(.sequence([.wait(forDuration: 3.0), .removeFromParent()]))

            // Vulnerability opens after projectile crosses the screen
            let travelTime = self.sceneW / 360.0 + 0.3
            self.run(.wait(forDuration: travelTime)) { [weak self] in
                guard let self, !self.bossDefeated else { return }
                self.openVulnerabilityWindow(duration: 3.0) { [weak self] in
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

        // Mystical shimmer as the minions spawn.
        SoundManager.shared.play("sfx_boss_summon.mp3")

        let floorTop = floorCenterY + 9
        for i in 0..<2 {
            let add = SKSpriteNode(imageNamed: "BossAdd")
            // BossAdd PNG is 534×550 (nearly square); 56×58 preserves proportions.
            add.size = CGSize(width: 56, height: 58)
            // Spread the two adds wide and sit them on the floor so they crawl
            // in from different distances rather than swarming together.
            add.position = CGPoint(x: boss.position.x + CGFloat(i == 0 ? -100 : 100),
                                   y: floorTop + 29)   // center = floor top + half-height
            add.zPosition = 2
            add.name = "summonAdd"

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
            openVulnerabilityWindow(duration: 3.0) { [weak self] in
                self?.scheduleNextAttack()
            }
        }
    }

    // MARK: - Boss aura (state feedback)

    /// Steady pulsing halo — vulnerability window and attack telegraphs.
    private func pulseAura(_ color: UIColor) {
        bossAura.removeAllActions()
        bossAura.fillColor = color
        bossAura.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.55, duration: 0.4),
            .fadeAlpha(to: 0.22, duration: 0.4)
        ])), withKey: "auraPulse")
    }

    /// Fade the halo out.
    private func hideAura() {
        bossAura.removeAllActions()
        bossAura.run(.fadeAlpha(to: 0, duration: 0.15))
    }

    /// Show one large blinking 💤 above the boss head — boss fell asleep after attacking.
    /// Replaces the green circle aura during the vulnerability window.
    private func showSleepIndicator() {
        hideSleepIndicator()
        let container = SKNode()
        // Boss top edge is at +97 from center; sleep bubble floats above that.
        container.position = CGPoint(x: 0, y: 118)
        container.zPosition = 5
        boss.addChild(container)
        sleepIndicatorNode = container

        let zzz = SKLabelNode(text: "💤")
        zzz.fontSize = 52
        zzz.horizontalAlignmentMode = .center
        zzz.verticalAlignmentMode = .center
        container.addChild(zzz)

        // Slow blink — appears, fades, repeats
        zzz.run(.repeatForever(.sequence([
            .fadeAlpha(to: 1.0, duration: 0.3),
            .wait(forDuration: 0.4),
            .fadeAlpha(to: 0.2, duration: 0.3),
            .wait(forDuration: 0.2)
        ])), withKey: "zzzBlink")
    }

    private func hideSleepIndicator() {
        sleepIndicatorNode?.removeFromParent()
        sleepIndicatorNode = nil
    }

    /// A quick bright flash (boss hit / shield block).
    private func flashAura(_ color: UIColor) {
        bossAura.removeAllActions()
        bossAura.fillColor = color
        bossAura.run(.sequence([
            .fadeAlpha(to: 0.85, duration: 0.06),
            .fadeAlpha(to: 0.0, duration: 0.14)
        ]))
    }

    // MARK: - Vulnerability window

    private func openVulnerabilityWindow(duration: TimeInterval, onClose: @escaping () -> Void) {
        guard !bossDefeated else { onClose(); return }
        isVulnerable = true
        hideAura()                    // no green circle — the 💤 signals the opening instead
        showSleepIndicator()
        instructionLabel.text = "지금이에요! 공격!"

        run(.wait(forDuration: duration)) { [weak self] in
            guard let self else { return }
            self.isVulnerable = false
            self.hideSleepIndicator()
            if !self.bossDefeated {
                self.instructionLabel.text = "보스 괴물을 물리쳐요!"
            }
            onClose()
        }
    }

    // MARK: - Boss damage

    private func hitBoss() {
        guard !bossDefeated else { return }
        guard isVulnerable, !isInvulnerable else {
            // Shield flash + clank when hit outside the vulnerability window.
            flashAura(.white)
            SoundManager.shared.play("sfx_boss_shield.mp3")
            return
        }

        bossHP -= 1
        isInvulnerable = true
        SoundManager.shared.play("sfx_boss_hit.mp3")
        updateHPDots()
        spawnSparkles(at: boss.position, color: .white)

        // White hit-flash; stars keep spinning so no need to resume the aura.
        flashAura(.white)

        run(.wait(forDuration: 0.4)) { [weak self] in self?.isInvulnerable = false }

        if bossHP <= 0 { defeatBoss() }
    }

    // MARK: - Boss defeat + chest reveal

    /// Silence every in-flight boss attack cue. Used whenever the boss state
    /// changes abruptly (defeat, hero death, reset) so the long telegraph
    /// audio files don't outlive the SKAction sequence that triggered them.
    private func stopBossAttackSFX() {
        SoundManager.shared.stop("sfx_boss_telegraph_slam.mp3")
        SoundManager.shared.stop("sfx_boss_telegraph_sweep.mp3")
        SoundManager.shared.stop("sfx_boss_sweep_fire.mp3")
        SoundManager.shared.stop("sfx_boss_summon.mp3")
    }

    private func defeatBoss() {
        guard !bossDefeated else { return }
        bossDefeated = true
        isVulnerable = false
        attackRunning = false

        removeAllActions()
        boss.removeAllActions()
        stopBossAttackSFX()

        // Celebratory fanfare — the climax of the whole game. Played after the
        // removeAllActions() calls above so the sound action is not cancelled.
        SoundManager.shared.play("sfx_boss_defeat.mp3")

        hideAura()
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
        let chest = SKSpriteNode(imageNamed: "Chest")
        chest.size = CGSize(width: 80, height: 66)
        chest.position = position
        chest.zPosition = 2
        chest.name = "bossChest"
        chest.alpha = 0

        chestNode = chest
        addChild(chest)

        // Fade in, pop up, then pulse to draw the hero over
        chest.run(.sequence([
            .fadeIn(withDuration: 0.5),
            .scale(to: 1.2, duration: 0.2),
            .scale(to: 1.0, duration: 0.1),
            .run {
                chest.run(.repeatForever(.sequence([
                    .scale(to: 1.08, duration: 0.55),
                    .scale(to: 1.00, duration: 0.55)
                ])), withKey: "chestPulse")
            }
        ]))
    }

    private let bossReward = 50

    private func openChest() {
        // Safety net: collect portrait now if the auto-collect timer hasn't fired yet.
        if !portraitCollected, portraitNode != nil {
            collectPortrait()
        }

        guard !chestOpened else { return }
        chestOpened = true
        isCompleting = true

        // Chest creak now, ascending jingle as the +마력 pop-up rises.
        SoundManager.shared.play("sfx_chest_open.mp3")
        run(.sequence([
            .wait(forDuration: 0.25),
            .run { [weak self] in
                guard let self = self else { return }
                SoundManager.shared.play("sfx_coin_earn.mp3")
            }
        ]))

        // Stop the attract pulse, swap to the open-chest art, then bounce
        chestNode?.removeAction(forKey: "chestPulse")
        chestNode?.texture = SKTexture(imageNamed: "ChestOpen")
        chestNode?.size = CGSize(width: 96, height: 80)   // lid-open art is a touch wider

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

        // 마력 reward awarded and displayed
        Magic.shared.add(bossReward)
        let coinPop = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        coinPop.text = "+\(bossReward)마력"
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
        SoundManager.shared.play("sfx_hero_hurt.mp3")
        stopBossAttackSFX()
        moveDirection = 0
        leftButtonTouch = nil
        rightButtonTouch = nil
        jumpButtonTouch = nil
        setPressed(leftArrowButton, false)
        setPressed(rightArrowButton, false)
        setPressed(jumpButton, false)
        heroVelY = 0

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
        heroVelY = 0
        isJumping = false
        inDescent = false
        isOnGround = true

        // Reset boss — cancel running actions first, then restore state
        removeAllActions()
        boss.removeAllActions()
        stopBossAttackSFX()
        boss.position = bossAnchor
        boss.alpha = 1.0
        boss.setScale(1.0)
        hideAura()
        hideSleepIndicator()
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
            hapticMedium.impactOccurred()
            tryJump()
            return
        }
        if leftArrowButton.contains(loc) {
            leftButtonTouch = touch
            setPressed(leftArrowButton, true)
            hapticLight.impactOccurred()
            updateMoveDirection()
            return
        }
        if rightArrowButton.contains(loc) {
            rightButtonTouch = touch
            setPressed(rightArrowButton, true)
            hapticLight.impactOccurred()
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

        // Chest is now claimed by proximity (see update()) — no tap needed
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
        // The hero can jump whenever she is not already mid-jump.
        guard !isJumping else { return }
        isOnGround = false
        isJumping = true
        inDescent = false
        heroVelY = jumpVelocity          // kinematic launch — integrated in update()
        SoundManager.shared.play("sfx_jump.mp3")
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
        }
        hero.position.x = max(-sceneW * 0.47, min(sceneW * 0.47, hero.position.x))

        // --- Vertical motion (fully kinematic) -------------------------------
        // The hero's Y is integrated here by hand — the physics engine never
        // moves her (her body has affectedByGravity = false, collisions off).
        // Deterministic: no physics tug-of-war, no reliance on contact callbacks.
        let g = inDescent ? gDescent : gAscent
        heroVelY -= g * CGFloat(dt)
        let newHeroY = hero.position.y + heroVelY * CGFloat(dt)

        // Surface under the hero: the floor, or a platform she is descending
        // onto from above (one-way — she jumps up through them).
        let footOffset: CGFloat = 31
        var landingY = floorCenterY + 40           // floor: sprite stands on surface
        if heroVelY <= 0 {
            let prevFeet = hero.position.y - footOffset
            for rect in platformRects where hero.position.x >= rect.minX - 10
                                          && hero.position.x <= rect.maxX + 10 {
                let standY = rect.maxY + footOffset
                if standY > landingY, prevFeet >= rect.maxY - 1 {
                    landingY = standY
                }
            }
        }

        if heroVelY <= 0, newHeroY <= landingY {
            // (sfx_land intentionally un-wired — owner felt the thud was unnecessary.)
            hero.position.y = landingY            // landed / standing
            heroVelY = 0
            isOnGround = true
            isJumping = false
            inDescent = false
        } else {
            hero.position.y = newHeroY            // airborne
            isOnGround = false
            if isJumping, !inDescent, heroVelY <= 0 {
                inDescent = true                  // past the apex — fall faster
            }
        }

        // Boss stomp / bump. Descending onto the boss is a stomp (it only takes
        // damage during its vulnerable window — see hitBoss). An airborne bump
        // that isn't a stomp shoves the hero clear; standing on a platform or
        // the floor beside the boss does nothing.
        //
        // The boss is now 130×195, sitting on the floor. Half-height = 97. For a
        // stomp from above, dy can reach boss_halfH + hero_halfH = 97+31 = 128.
        // The bump fires only when the hero's head has risen into the boss's body
        // (hero.y + 31 > bossAnchor.y - 40), so walking near the boss on the floor
        // does not accidentally trigger it.
        if !bossDefeated {
            let dx = abs(hero.position.x - boss.position.x)
            let dy = abs(hero.position.y - boss.position.y)
            if dx < 79, dy < 130 {
                if heroVelY < -20 {
                    hitBoss()                       // descending onto the boss
                } else if !isOnGround, hero.position.y + 31 > bossAnchor.y - 40 {
                    // Airborne and hero's head has reached the boss's lower body.
                    let pushDir: CGFloat = hero.position.x < boss.position.x ? -1 : 1
                    hero.position.x = boss.position.x + pushDir * 110
                    heroVelY = 90
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

            // Descending onto an add stomps it; touching it any other way hits.
            if heroKilledByAdd { continue }
            let dx = abs(hero.position.x - add.position.x)
            let dy = abs(hero.position.y - add.position.y)
            if dx < 40, dy < 46 {
                if heroVelY < -20 { defeatAdd(add) }
                else { heroKilledByAdd = true }
            }
        }
        if heroKilledByAdd { handleDeath() }

        // Sweep-projectile contact — checked here by hand. The kinematic hero
        // does not reliably trip the physics contact delegate, so the sweep
        // (a physics-body hazard) is tested for overlap directly.
        if !isDead, !isCompleting {
            for proj in children where proj.name == "sweepProjectile" {
                if abs(hero.position.x - proj.position.x) < 42,
                   abs(hero.position.y - proj.position.y) < 30 {
                    handleDeath()
                    break
                }
            }
        }

        // Breadcrumb paw collection
        if !isDead, !isCompleting {
            for paw in children where paw.name == "breadcrumb" {
                if abs(hero.position.x - paw.position.x) < 28,
                   abs(hero.position.y - paw.position.y) < 30 {
                    let pawPos = paw.position
                    paw.removeFromParent()
                    Magic.shared.add(1)
                    let pop = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
                    pop.text = "+1마력"
                    pop.fontSize = 16
                    pop.fontColor = UIColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1.0)
                    pop.position = CGPoint(x: pawPos.x, y: pawPos.y + 10)
                    pop.zPosition = 6
                    addChild(pop)
                    let rise = SKAction.moveBy(x: 0, y: 40, duration: 0.5)
                    rise.timingMode = .easeOut
                    pop.run(.sequence([rise, .fadeOut(withDuration: 0.2), .removeFromParent()]))
                }
            }
        }

        // Portrait walk-over collection
        if !portraitCollected, !isDead, !isCompleting,
           let pn = portraitNode,
           abs(hero.position.x - pn.position.x) < 36,
           abs(hero.position.y - pn.position.y) < 36 {
            collectPortrait()
        }

        // Proximity chest claim — hero walks up to the boss chest to open it.
        // The y-range pairs with the x-range so the chest doesn't claim from
        // an upper stepping-stone while the hero is at a different height.
        if bossDefeated, !chestOpened, !isCompleting, !isDead,
           let chest = chestNode,
           abs(hero.position.x - chest.position.x) < 80,
           abs(hero.position.y - chest.position.y) < 60 {
            openChest()
        }

        // HP dots track boss as it moves
        syncHPDotPositions()
    }

    // MARK: - Breadcrumbs

    private func spawnBreadcrumbs() {
        let floorSurface = floorCenterY + 18               // floor top + paw half
        let lowerPlatY   = floorCenterY + 9 + 49 + 8 + 9  // lower step surface + paw half
        let upperPlatY   = floorCenterY + 9 + 101 + 8 + 9 // upper step surface + paw half
        // Lower step spans x: -sceneW*0.12 ± 75; upper step spans x: sceneW*0.04 ± 75
        let positions: [CGPoint] = [
            // 3 on floor
            CGPoint(x: -sceneW * 0.30, y: floorSurface),
            CGPoint(x: -sceneW * 0.10, y: floorSurface),
            CGPoint(x:  sceneW * 0.25, y: floorSurface),
            // 3 on lower platform
            CGPoint(x: -sceneW * 0.12 - 50, y: lowerPlatY),
            CGPoint(x: -sceneW * 0.12,       y: lowerPlatY),
            CGPoint(x: -sceneW * 0.12 + 50, y: lowerPlatY),
            // 2 on upper platform, flanking the portrait at x:sceneW*0.04
            CGPoint(x:  sceneW * 0.04 - 50, y: upperPlatY),
            CGPoint(x:  sceneW * 0.04 + 50, y: upperPlatY),
        ]
        for pos in positions {
            let paw = SKSpriteNode(imageNamed: "CatPaw")
            paw.size = CGSize(width: 18, height: 18)
            paw.alpha = 0.7
            paw.position = pos
            paw.zPosition = 1
            paw.name = "breadcrumb"
            addChild(paw)
        }
    }

    // MARK: - Relic (Royal Family Portrait)

    private func spawnPortrait() {
        let relic = DungeonItem.royalFamilyPortrait
        guard !Store.loadCollectedRelics().contains(relic) else { return }

        // Upper platform: centerY = floorCenterY+9+101, top = floorCenterY+118
        // Portrait sits on top: center = platformTop + half(32) = floorCenterY + 150
        let upperPlatTop = floorCenterY + 9 + 101 + 8
        let portraitY    = upperPlatTop + 32

        let sprite = SKSpriteNode(imageNamed: relic.assetName)
        sprite.size = CGSize(width: 64, height: 64)
        sprite.position = CGPoint(x: sceneW * 0.04, y: portraitY)
        sprite.zPosition = 4

        let glow = SKShapeNode(circleOfRadius: 36)
        glow.fillColor = UIColor(red: 0.6, green: 0.2, blue: 0.9, alpha: 0.3)
        glow.strokeColor = .clear
        glow.zPosition = -1
        sprite.addChild(glow)
        addChild(sprite)
        portraitNode = sprite

        sprite.run(.repeatForever(.sequence([
            .moveBy(x: 0, y: 6, duration: 0.6),
            .moveBy(x: 0, y: -6, duration: 0.6)
        ])), withKey: "portraitBob")
        // Walk-over collection handled in update(). Safety net in openChest().
    }

    private func collectPortrait() {
        guard !portraitCollected else { return }
        portraitCollected = true
        let relic = DungeonItem.royalFamilyPortrait
        let position = portraitNode?.position ?? .zero
        portraitNode?.removeAllActions()
        portraitNode?.removeFromParent()
        portraitNode = nil

        SoundManager.shared.play("sfx_coin_earn.mp3")

        let pop = SKSpriteNode(imageNamed: relic.assetName)
        pop.size = CGSize(width: 34, height: 34)
        pop.position = position
        pop.zPosition = 55
        addChild(pop)
        spawnSparkles(at: position, color: accentColor)

        let slotSize: CGFloat = 28
        let spacing:  CGFloat = 6
        let leftPad:  CGFloat = 24
        let slotX0 = -sceneW / 2 + leftPad + slotSize / 2
        let slotY  =  sceneH / 2 - 8 - 36 - 6 - slotSize / 2
        let idx = DungeonItem.allCases.firstIndex(of: relic) ?? 3
        let target = CGPoint(x: slotX0 + CGFloat(idx) * (slotSize + spacing), y: slotY)

        let scaleUp   = SKAction.scale(to: 1.5, duration: 0.15)
        let scaleDown = SKAction.scale(to: 0.8, duration: 0.10)
        let arc = SKAction.move(to: target, duration: 0.5)
        arc.timingMode = .easeIn
        let fade = SKAction.fadeOut(withDuration: 0.15)
        pop.run(.sequence([scaleUp, scaleDown, arc, fade, .removeFromParent()])) { [weak self] in
            guard let self else { return }
            Store.saveCollectedRelics(Store.loadCollectedRelics().union([relic]))
            self.onRelicCollected?(relic)
        }
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
