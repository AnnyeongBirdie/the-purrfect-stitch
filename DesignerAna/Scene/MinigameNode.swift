//
//  MinigameNode.swift
//  DesignerAna
//

import SpriteKit

class MinigameNode: SKNode {

    // MARK: - Physics categories
    private struct PhysicsCategory {
        static let none:     UInt32 = 0
        static let hero:     UInt32 = 0b0001
        static let ground:   UInt32 = 0b0010
        static let monster:  UInt32 = 0b0100
        static let hazard:   UInt32 = 0b1000
    }

    // MARK: - Config + callback
    private let config: MinigameConfig
    private let onCompletion: (MinigameStation) -> Void

    // MARK: - Nodes
    private var hero: SKSpriteNode!
    private var monster: SKSpriteNode?
    private var chestNode: SKSpriteNode?
    private var instructionLabel: SKLabelNode!
    private var jumpButton: SKShapeNode!
    private var leftArrowButton: SKShapeNode!
    private var rightArrowButton: SKShapeNode!

    // MARK: - State
    private var isOnGround = false
    private var isJumping = false
    private var monsterDefeated = false
    private var chestOpened = false
    private var isCompleting = false
    private var isDead = false

    private var heroStartPosition: CGPoint = .zero

    // Horizontal movement direction: -1 left, 0 none, +1 right
    private var moveDirection: CGFloat = 0
    private var leftButtonTouch: UITouch?
    private var rightButtonTouch: UITouch?
    private var jumpButtonTouch: UITouch?
    private var lastUpdateTime: TimeInterval = 0

    // D-pad button fill colors — buttons darken when held so a thumb sliding
    // off has visible feedback instead of relying on the hero stopping.
    private let buttonRestingFill = UIColor.white.withAlphaComponent(0.25)
    private let buttonPressedFill = UIColor.black.withAlphaComponent(0.35)

    // Pacing monster state
    private var monsterStartX: CGFloat = 0
    private var monsterPaceOffset: CGFloat = 0
    private var monsterPaceDirection: CGFloat = 1

    // MARK: - Layout constants (sceneW/sceneH set at runtime in setup(in:))
    private var sceneW: CGFloat = 0
    private var sceneH: CGFloat = 0
    private let heroSpeed: CGFloat = 160      // pts/sec
    private var jumpImpulse: CGFloat = 0      // computed from sceneH in setup
    private let proximityRange: CGFloat = 60  // tap-to-defeat range

    // MARK: - Init
    init(config: MinigameConfig, onCompletion: @escaping (MinigameStation) -> Void) {
        self.config = config
        self.onCompletion = onCompletion
        super.init()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    // Called by BackRoomScene immediately after addChild(minigameNode).
    func setup(in scene: SKScene) {
        sceneW = scene.size.width
        sceneH = scene.size.height
        // Impulse that produces a jump peak ~1.75% of sceneH above the floor,
        // derived from kinematics: v = sqrt(2 * |g| * desiredHeight)
        jumpImpulse = (2.0 * 18.0 * sceneH * 0.0175).squareRoot()
        scene.physicsWorld.gravity = CGVector(dx: 0, dy: -18)
        // ContactDelegate needs to be set on the scene; we bridge through a stored ref.
        sceneRef = scene
        scene.physicsWorld.contactDelegate = contactBridge

        buildDungeon()
        buildHero()
        buildMonster()
        buildHazards()
        startDynamicBehaviors()
        buildDirectionalButtons()
        buildJumpButton()
        buildInstructionLabel()
        animateEntrance()
    }

    // Weak bridge so we can be the contact delegate without subclassing SKScene.
    private weak var sceneRef: SKScene?
    private lazy var contactBridge = ContactBridge(owner: self)

    // MARK: - Build

    private func buildDungeon() {
        // Full-screen dark background panel
        let bg = SKSpriteNode(color: config.backgroundTint, size: CGSize(width: sceneW, height: sceneH))
        bg.position = .zero
        bg.zPosition = 0
        bg.name = "minigameBg"
        addChild(bg)

        // Title card
        let title = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        title.text = "보물 던전에 입장!"
        title.fontSize = 28
        title.fontColor = .white
        title.position = CGPoint(x: 0, y: sceneH * 0.25)
        title.zPosition = 5
        title.name = "titleCard"
        addChild(title)

        title.run(.sequence([
            .wait(forDuration: 1.5),
            .fadeOut(withDuration: 0.5),
            .removeFromParent()
        ]))

        // Platforms from level seed
        for platform in platformLayout(seed: config.levelSeed) {
            addChild(platform)
        }
    }

    // Returns platform nodes for a given seed. All layouts share: a full-width floor,
    // plus 2–3 elevated platforms the hero must use to reach the monster and chest.
    private func platformLayout(seed: Int) -> [SKShapeNode] {
        let floor = makePlatform(x: 0, y: -sceneH * 0.40, width: sceneW, height: 18)

        switch seed {
        case 2:
            return [
                floor,
                makePlatform(x: -80, y: -sceneH * 0.15, width: 130, height: 16),
                makePlatform(x:  90, y:  sceneH * 0.02, width: 130, height: 16),
            ]
        case 3:
            return [
                floor,
                makePlatform(x: -60, y: -sceneH * 0.18, width: 110, height: 16),
                makePlatform(x:  80, y: -sceneH * 0.05, width: 110, height: 16),
                makePlatform(x: -20, y:  sceneH * 0.10, width: 110, height: 16),
            ]
        case 4:
            return [
                floor,
                makePlatform(x: -100, y: -sceneH * 0.20, width: 100, height: 16),
                makePlatform(x:    0, y: -sceneH * 0.05, width: 100, height: 16),
                makePlatform(x:  110, y:  sceneH * 0.08, width: 100, height: 16),
            ]
        default: // seed 1
            return [
                floor,
                makePlatform(x: -70, y: -sceneH * 0.18, width: 120, height: 16),
                makePlatform(x:  80, y:  sceneH * 0.00, width: 120, height: 16),
            ]
        }
    }

    private func makePlatform(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> SKShapeNode {
        let node = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 6)
        node.position = CGPoint(x: x, y: y)
        node.fillColor = config.accentColor.withAlphaComponent(0.7)
        node.strokeColor = config.accentColor
        node.lineWidth = 2
        node.zPosition = 1

        let body = SKPhysicsBody(rectangleOf: CGSize(width: width, height: height))
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.ground
        body.contactTestBitMask = PhysicsCategory.none
        body.collisionBitMask = PhysicsCategory.hero
        node.physicsBody = body

        return node
    }

    private func buildHero() {
        hero = SKSpriteNode(imageNamed: "Tailor")
        hero.setScale(0.075)
        heroStartPosition = CGPoint(x: -sceneW * 0.38, y: -sceneH * 0.28)
        hero.position = heroStartPosition
        hero.zPosition = 3
        hero.name = "hero"
        addChild(hero)

        let body = SKPhysicsBody(rectangleOf: CGSize(width: 14, height: 22))
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

    private func buildMonster() {
        // Placeholder circle until a monster sprite asset exists.
        let node = SKSpriteNode(color: UIColor(red: 0.4, green: 0.2, blue: 0.6, alpha: 1), size: CGSize(width: 44, height: 44))
        node.position = CGPoint(x: sceneW * 0.10, y: -sceneH * 0.28)
        node.zPosition = 2
        node.name = "monster"

        // Label inside placeholder
        let label = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        label.text = "👾"
        label.fontSize = 28
        label.verticalAlignmentMode = .center
        label.position = .zero
        label.zPosition = 1
        node.addChild(label)

        let body = SKPhysicsBody(rectangleOf: node.size)
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.monster
        body.contactTestBitMask = PhysicsCategory.hero
        body.collisionBitMask = PhysicsCategory.none
        node.physicsBody = body

        monster = node
        monsterStartX = node.position.x
        addChild(node)
    }

    private func startDynamicBehaviors() {
        if case .lunging(let interval) = config.monsterBehavior {
            startLungePattern(interval: interval)
        }
        if case .fallingButtons(let interval) = config.hazardKind {
            startFallingButtonSpawn(interval: interval)
        }
    }

    private func startLungePattern(interval: TimeInterval) {
        guard let monster = monster else { return }

        let telegraph = SKAction.sequence([
            .fadeAlpha(to: 0.25, duration: 0.12),
            .fadeAlpha(to: 1.00, duration: 0.12),
            .fadeAlpha(to: 0.25, duration: 0.12),
            .fadeAlpha(to: 1.00, duration: 0.12),
        ])
        let charge = SKAction.run { [weak self] in
            guard let self, let monster = self.monster else { return }
            let targetX = self.hero.position.x
            let dist = abs(targetX - monster.position.x)
            let duration = max(0.12, TimeInterval(dist / 400))
            monster.run(.moveTo(x: targetX, duration: duration), withKey: "lunge")
        }
        let pause = SKAction.wait(forDuration: 0.35)
        let returnHome = SKAction.run { [weak self] in
            guard let self, let monster = self.monster else { return }
            monster.run(.moveTo(x: self.monsterStartX, duration: 0.45), withKey: "lunge")
        }
        let rest = SKAction.wait(forDuration: interval)

        monster.run(.repeatForever(.sequence([rest, telegraph, charge, pause, returnHome])),
                    withKey: "lungePattern")
    }

    private func startFallingButtonSpawn(interval: TimeInterval) {
        let spawn = SKAction.run { [weak self] in self?.spawnFallingButton() }
        run(.repeatForever(.sequence([spawn, .wait(forDuration: interval)])),
            withKey: "spawnButtons")
    }

    private func spawnFallingButton() {
        guard !monsterDefeated else { return }

        let radius: CGFloat = 20
        let btn = makeButtonIcon(radius: radius)
        btn.position = CGPoint(x: CGFloat.random(in: -sceneW * 0.40 ... sceneW * 0.40),
                               y: sceneH * 0.46)
        btn.zPosition = 2
        btn.name = "fallingButton"

        let body = SKPhysicsBody(circleOfRadius: radius)
        body.isDynamic = true
        body.affectedByGravity = false
        body.velocity = CGVector(dx: 0, dy: -190)
        body.categoryBitMask = PhysicsCategory.hazard
        body.contactTestBitMask = PhysicsCategory.hero
        body.collisionBitMask = PhysicsCategory.none
        btn.physicsBody = body

        addChild(btn)
        btn.run(.sequence([.wait(forDuration: 3.5), .removeFromParent()]))
    }

    private func makeButtonIcon(radius: CGFloat) -> SKNode {
        let container = SKNode()

        // Button body
        let body = SKShapeNode(circleOfRadius: radius)
        body.fillColor = config.accentColor
        body.strokeColor = .clear
        container.addChild(body)

        // Inner ring
        let ring = SKShapeNode(circleOfRadius: radius * 0.72)
        ring.fillColor = .clear
        ring.strokeColor = UIColor.white.withAlphaComponent(0.75)
        ring.lineWidth = 2
        container.addChild(ring)

        // 4 thread holes in a 2×2 arrangement
        let holeRadius = radius * 0.13
        let offset = radius * 0.28
        for (dx, dy): (CGFloat, CGFloat) in [(-offset,  offset), ( offset,  offset),
                                              (-offset, -offset), ( offset, -offset)] {
            let hole = SKShapeNode(circleOfRadius: holeRadius)
            hole.fillColor = .white
            hole.strokeColor = .clear
            hole.position = CGPoint(x: dx, y: dy)
            container.addChild(hole)
        }

        return container
    }

    private func buildHazards() {
        guard case .scissorBlades(let count, let spacing) = config.hazardKind else { return }

        // Place scissors on the floor surface between hero start and monster.
        // Floor top is at -sceneH*0.40 + 9 (half of floor height 18). Sprite sits on top.
        let floorTop = -sceneH * 0.40 + 9
        let startX: CGFloat = -sceneW * 0.20  // first blade slightly past hero start
        for i in 0..<count {
            let blade = SKSpriteNode(imageNamed: "Scissors")
            blade.setScale(0.12)
            blade.position = CGPoint(x: startX + CGFloat(i) * spacing, y: floorTop + 18)
            blade.zPosition = 2
            blade.name = "scissorHazard"

            let hitSize = CGSize(width: 24, height: 24)
            let body = SKPhysicsBody(rectangleOf: hitSize)
            body.isDynamic = false
            body.categoryBitMask = PhysicsCategory.hazard
            body.contactTestBitMask = PhysicsCategory.hero
            body.collisionBitMask = PhysicsCategory.none
            blade.physicsBody = body

            addChild(blade)
        }
    }

    private func buildDirectionalButtons() {
        leftArrowButton = makeArrowButton(label: "←", x: -sceneW * 0.42, y: -sceneH * 0.39)
        rightArrowButton = makeArrowButton(label: "→", x: -sceneW * 0.29, y: -sceneH * 0.39)
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

        let label = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        label.text = text
        label.fontSize = 24
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.position = .zero
        btn.addChild(label)

        return btn
    }

    private func buildJumpButton() {
        let btn = SKShapeNode(circleOfRadius: 34)
        btn.position = CGPoint(x: sceneW * 0.42, y: -sceneH * 0.39)
        btn.fillColor = buttonRestingFill
        btn.strokeColor = UIColor.white.withAlphaComponent(0.7)
        btn.lineWidth = 2
        btn.zPosition = 5
        btn.name = "jumpBtn"

        let label = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        label.text = "↑"
        label.fontSize = 24
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.position = .zero
        label.name = "jumpBtn"
        btn.addChild(label)

        jumpButton = btn
        addChild(btn)
    }

    private func setPressed(_ button: SKShapeNode?, _ pressed: Bool) {
        button?.fillColor = pressed ? buttonPressedFill : buttonRestingFill
    }

    private func buildInstructionLabel() {
        instructionLabel = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        instructionLabel.text = "괴물을 물리치고 보물 상자를 찾아라!"
        instructionLabel.fontSize = 18
        instructionLabel.fontColor = .white
        instructionLabel.position = CGPoint(x: 0, y: sceneH * 0.42)
        instructionLabel.zPosition = 5
        addChild(instructionLabel)
    }

    private func animateEntrance() {
        hero.alpha = 0
        hero.run(.fadeIn(withDuration: 0.4))
        let bounceUp = SKAction.moveBy(x: 0, y: 12, duration: 0.12)
        let bounceDown = SKAction.moveBy(x: 0, y: -12, duration: 0.12)
        hero.run(.sequence([.wait(forDuration: 0.5), bounceUp, bounceDown]))
    }

    // MARK: - Touch handling (called by BackRoomScene.touchesBegan)

    func handleTouchBegan(_ touch: UITouch) {
        guard !isCompleting, !isDead else { return }
        guard let scene = sceneRef else { return }
        let location = touch.location(in: scene)

        if jumpButton.contains(location) {
            jumpButtonTouch = touch
            setPressed(jumpButton, true)
            tryJump()
            return
        }

        if leftArrowButton.contains(location) {
            leftButtonTouch = touch
            setPressed(leftArrowButton, true)
            updateMoveDirection()
            return
        }
        if rightArrowButton.contains(location) {
            rightButtonTouch = touch
            setPressed(rightArrowButton, true)
            updateMoveDirection()
            return
        }

        // Tap-to-defeat: tap the monster when hero is within proximityRange
        if !monsterDefeated, let monster = monster, monster.contains(location) {
            let dist = abs(hero.position.x - monster.position.x)
            if dist <= proximityRange {
                defeatMonster()
                return
            } else {
                instructionLabel.text = "더 가까이 가보세요!"
                return
            }
        }

        // Tap chest to open
        if monsterDefeated, !chestOpened, let chest = chestNode, chest.contains(location) {
            openChest()
            return
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
        let goLeft = leftButtonTouch != nil
        let goRight = rightButtonTouch != nil
        if goLeft && !goRight {
            moveDirection = -1
            hero.xScale = abs(hero.xScale)
        } else if goRight && !goLeft {
            moveDirection = 1
            hero.xScale = -abs(hero.xScale)
        } else {
            moveDirection = 0
        }
    }

    private func tryJump() {
        guard isOnGround, !isJumping else { return }
        isOnGround = false
        isJumping = true
        hero.removeAction(forKey: "step")
        hero.physicsBody?.applyImpulse(CGVector(dx: 0, dy: jumpImpulse))
    }

    // MARK: - Update (called by BackRoomScene.update)

    func update(currentTime: TimeInterval) {
        guard lastUpdateTime > 0 else { lastUpdateTime = currentTime; return }
        let dt = currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        guard !isDead, !isCompleting else { return }

        if moveDirection != 0 {
            let dx = moveDirection * heroSpeed * CGFloat(dt)
            hero.position.x += dx

            // Bounce step animation
            let bounce = SKAction.sequence([
                .moveBy(x: 0, y: 6, duration: 0.08),
                .moveBy(x: 0, y: -6, duration: 0.08)
            ])
            if hero.action(forKey: "step") == nil {
                hero.run(bounce, withKey: "step")
            }
        }

        // Clamp to dungeon bounds (x)
        hero.position.x = max(-sceneW * 0.47, min(sceneW * 0.47, hero.position.x))

        // Floor failsafe: snap hero back if she tunnels through the floor
        let floorSurface = -sceneH * 0.40 + 20   // floor top + hero half-body
        if hero.position.y < floorSurface {
            hero.position.y = floorSurface
            hero.physicsBody?.velocity = CGVector(dx: hero.physicsBody?.velocity.dx ?? 0, dy: 0)
            isOnGround = true
            isJumping = false
        }

        // Stomp + side-contact detection — both done here rather than in the physics
        // contact delegate because hero.position.x is set manually each frame, which
        // can cause the physics engine to miss contacts between simulation steps.
        if !monsterDefeated, !isDead, let monster = monster {
            let vdy = hero.physicsBody?.velocity.dy ?? 0
            let dx = abs(hero.position.x - monster.position.x)
            let dy = abs(hero.position.y - monster.position.y)
            let heroFeet = hero.position.y - 11
            let monsterTop = monster.position.y + 22

            let overlapping = dx < 29 && dy < 33  // hero half(7,11) + monster half(22,22)
            let isStomp = vdy < -50 && heroFeet <= monsterTop && heroFeet >= monsterTop - 30

            if overlapping {
                if isStomp { defeatMonster() } else { handleDeath() }
            }
        }

        // Pacing monster movement
        if !monsterDefeated, let monster = monster,
           case .pacing(let speed, let range) = config.monsterBehavior {
            monsterPaceOffset += monsterPaceDirection * speed * CGFloat(dt)
            if abs(monsterPaceOffset) >= range {
                monsterPaceDirection *= -1
                monsterPaceOffset = monsterPaceOffset > 0 ? range : -range
            }
            monster.position.x = monsterStartX + monsterPaceOffset
            monster.xScale = monsterPaceDirection > 0 ? 1 : -1
        }
    }

    // MARK: - Defeat + chest

    private func handleDeath() {
        guard !isDead, !isCompleting else { return }
        isDead = true
        isJumping = false
        moveDirection = 0
        leftButtonTouch = nil
        rightButtonTouch = nil
        jumpButtonTouch = nil
        setPressed(leftArrowButton, false)
        setPressed(rightArrowButton, false)
        setPressed(jumpButton, false)
        hero.physicsBody?.velocity = .zero

        let deathLabel = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        deathLabel.text = "다시 도전해봐요!"
        deathLabel.fontSize = 26
        deathLabel.fontColor = UIColor(red: 1.0, green: 0.9, blue: 0.3, alpha: 1)
        deathLabel.position = CGPoint(x: 0, y: sceneH * 0.05)
        deathLabel.zPosition = 6
        addChild(deathLabel)

        hero.run(.sequence([
            .fadeAlpha(to: 0.2, duration: 0.15),
            .wait(forDuration: 0.7),
            .fadeIn(withDuration: 0.2)
        ]))

        run(.wait(forDuration: 1.1)) { [weak self] in
            guard let self else { return }
            deathLabel.removeFromParent()
            self.hero.position = self.heroStartPosition
            self.monsterPaceOffset = 0
            self.monsterPaceDirection = 1
            if let monster = self.monster {
                monster.position.x = self.monsterStartX
            }
            // Remove in-flight falling buttons
            self.children.filter { $0.name == "fallingButton" }.forEach { $0.removeFromParent() }
            self.isDead = false
            self.instructionLabel.text = "괴물을 물리치고 보물 상자를 찾아라!"
        }
    }

    private func defeatMonster() {
        guard !monsterDefeated else { return }
        monsterDefeated = true
        removeAction(forKey: "spawnButtons")
        monster?.removeAction(forKey: "lungePattern")
        // Sweep already-airborne falling buttons so they can't kill the hero
        // in the ~3.5s window between defeating the monster and reaching the chest.
        children.filter { $0.name == "fallingButton" }.forEach { $0.removeFromParent() }
        instructionLabel.text = "해냈어요! 보물 상자를 찾아봐요!"

        let pop = SKAction.sequence([
            .scale(to: 1.4, duration: 0.1),
            .fadeOut(withDuration: 0.2),
            .removeFromParent()
        ])
        monster?.run(pop) { [weak self] in
            self?.monster = nil
            self?.spawnChest()
        }

        // Sparkle burst at monster position
        if let pos = monster?.position {
            spawnSparkles(at: pos)
        }

        // Bounce hero upward as feedback
        hero.physicsBody?.applyImpulse(CGVector(dx: 0, dy: 200))
    }

    private func spawnChest() {
        let chest = SKSpriteNode(color: UIColor(red: 0.7, green: 0.5, blue: 0.1, alpha: 1),
                                 size: CGSize(width: 50, height: 42))
        chest.position = CGPoint(x: sceneW * 0.30, y: -sceneH * 0.25)
        chest.zPosition = 2
        chest.name = "chest"

        let label = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        label.text = "📦"
        label.fontSize = 28
        label.verticalAlignmentMode = .center
        label.position = .zero
        chest.addChild(label)

        chest.setScale(0)
        chestNode = chest
        addChild(chest)

        chest.run(.sequence([
            .scale(to: 1.2, duration: 0.2),
            .scale(to: 1.0, duration: 0.1)
        ]))
    }

    private func openChest() {
        guard !chestOpened else { return }
        chestOpened = true
        isCompleting = true
        instructionLabel.text = config.chestRewardLabel

        let bounce = SKAction.sequence([
            .scale(to: 1.3, duration: 0.12),
            .scale(to: 1.0, duration: 0.10)
        ])
        chestNode?.run(bounce)

        // Reward item pops out
        let reward = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        reward.text = config.chestRewardLabel
        reward.fontSize = 26
        reward.fontColor = .white
        reward.position = chestNode?.position ?? .zero
        reward.zPosition = 6
        addChild(reward)

        let rise = SKAction.moveBy(x: 0, y: 80, duration: 0.6)
        rise.timingMode = .easeOut
        reward.run(.sequence([rise, .fadeOut(withDuration: 0.3), .removeFromParent()]))

        spawnSparkles(at: chestNode?.position ?? .zero)

        run(.wait(forDuration: 1.0)) { [weak self] in
            guard let self else { return }
            self.onCompletion(self.config.station)
        }
    }

    // MARK: - Sparkles

    private func spawnSparkles(at position: CGPoint) {
        for i in 0..<8 {
            let spark = SKShapeNode(circleOfRadius: 4)
            spark.fillColor = config.accentColor
            spark.strokeColor = .clear
            spark.position = position
            spark.zPosition = 4
            addChild(spark)

            let angle = CGFloat(i) / 8 * .pi * 2
            let dist: CGFloat = 50
            let target = CGPoint(x: position.x + cos(angle) * dist,
                                 y: position.y + sin(angle) * dist)
            spark.run(.sequence([
                .move(to: target, duration: 0.35),
                .fadeOut(withDuration: 0.2),
                .removeFromParent()
            ]))
        }
    }

    // MARK: - Ground contact (called from ContactBridge)

    fileprivate func didBeginContact(_ contact: SKPhysicsContact) {
        let maskA = contact.bodyA.categoryBitMask
        let maskB = contact.bodyB.categoryBitMask

        let isHeroGroundContact =
            (maskA == PhysicsCategory.hero && maskB == PhysicsCategory.ground) ||
            (maskA == PhysicsCategory.ground && maskB == PhysicsCategory.hero)

        if isHeroGroundContact {
            let vy = hero.physicsBody?.velocity.dy ?? 0
            if vy <= 0 {
                isOnGround = true
                isJumping = false
            }
        }

        let isHeroHazardContact =
            (maskA == PhysicsCategory.hero && maskB == PhysicsCategory.hazard) ||
            (maskA == PhysicsCategory.hazard && maskB == PhysicsCategory.hero)

        if isHeroHazardContact {
            handleDeath()
        }
    }
}

// MARK: - ContactBridge
// SKScene.physicsWorld.contactDelegate must be an SKPhysicsContactDelegate.
// MinigameNode is an SKNode (not SKScene), so we use a tiny bridge object.
private class ContactBridge: NSObject, SKPhysicsContactDelegate {
    weak var owner: MinigameNode?
    init(owner: MinigameNode) { self.owner = owner }

    func didBegin(_ contact: SKPhysicsContact) {
        owner?.didBeginContact(contact)
    }
}
