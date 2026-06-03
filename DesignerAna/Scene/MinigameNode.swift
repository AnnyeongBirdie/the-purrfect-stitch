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
    private var isOnGround = true   // hero spawns standing on the floor
    private var isJumping = false
    private var monsterDefeated = false
    private var chestOpened = false
    private var chestClaimable = false   // locked for 0.8s after spawn so hero must walk to it
    private var isCompleting = false
    private var isDead = false

    private var heroStartPosition: CGPoint = .zero

    // Horizontal movement direction: -1 left, 0 none, +1 right
    private var moveDirection: CGFloat = 0
    private var leftButtonTouch: UITouch?
    private var rightButtonTouch: UITouch?
    private var jumpButtonTouch: UITouch?
    private var lastUpdateTime: TimeInterval = 0

    // Haptic generators — created once, reused on every button press
    private let hapticLight  = UIImpactFeedbackGenerator(style: .light)
    private let hapticMedium = UIImpactFeedbackGenerator(style: .medium)

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
    // Floor center Y in scene coordinates. Set in setup(in:) so everything
    // that depends on the floor (hero, monster, chest, hazards) uses one source.
    private var floorCenterY: CGFloat = 0
    private let heroSpeed: CGFloat = 160      // pts/sec
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
    private var platformRects: [CGRect] = []  // floor + platforms, for landing checks
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
        // Floor sits high enough that all three D-pad buttons fit below it.
        // Buttons land at -sceneH*0.38; floor top = -sceneH*0.26+9, safely above.
        floorCenterY = -sceneH * 0.26
        // Jump physics derived from the tuning knobs above. For a launch velocity v
        // under constant gravity g: time-to-apex = v / g and apex height = v² / (2g).
        // Solving both for the desired apex height and time gives:
        //   g = 2·height / timeToApex²        v = 2·height / timeToApex
        let peakHeight = sceneH * jumpPeakFraction
        gAscent = 2 * peakHeight / (timeToApex * timeToApex)
        jumpVelocity = 2 * peakHeight / timeToApex
        // Stored so touch handling can map touches into scene coordinates.
        sceneRef = scene

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

    private weak var sceneRef: SKScene?

    // MARK: - Build

    // Adds stone-brick lines, a ceiling shadow, and a floor-edge highlight so
    // the dungeon reads as an enclosed room rather than an abstract void.
    private func buildDungeonAtmosphere() {
        let lineColor = UIColor.white.withAlphaComponent(0.07)
        let brickH: CGFloat = 44
        let floorY = floorCenterY

        // Horizontal mortar lines + staggered vertical joints
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

        // Ceiling shadow band
        let ceiling = SKSpriteNode(color: UIColor.black.withAlphaComponent(0.28),
                                   size: CGSize(width: sceneW, height: 55))
        ceiling.position = CGPoint(x: 0, y: sceneH * 0.5 - 27)
        ceiling.zPosition = 0.2
        addChild(ceiling)

        // Bright edge strip on top of the floor so it reads as a solid surface
        let floorEdge = SKShapeNode(rectOf: CGSize(width: sceneW, height: 4))
        floorEdge.position = CGPoint(x: 0, y: floorY + 9 + 2)
        floorEdge.fillColor = UIColor.white.withAlphaComponent(0.18)
        floorEdge.strokeColor = .clear
        floorEdge.zPosition = 1.5
        addChild(floorEdge)
    }

    private func buildDungeon() {
        // Full-screen dark background panel
        let bg = SKSpriteNode(color: config.backgroundTint, size: CGSize(width: sceneW, height: sceneH))
        bg.position = .zero
        bg.zPosition = 0
        bg.name = "minigameBg"
        addChild(bg)

        buildDungeonAtmosphere()

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
        let floor = makePlatform(x: 0, y: floorCenterY, width: sceneW, height: 18)

        switch seed {
        case 2:
            // Scissors station: three stepped platforms. Blades sit on the left
            // side of the floor (see buildHazards). Platforms are lower and more
            // numerous than the other seeds so there are plenty of safe spots.
            return [
                floor,
                makePlatform(x: -90, y: -sceneH * 0.18, width: 130, height: 16),
                makePlatform(x:  40, y: -sceneH * 0.08, width: 120, height: 16),
                makePlatform(x: 170, y:  sceneH * 0.04, width: 120, height: 16),
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
        default: // seed 1 — tutorial: two platforms that require a real jump to reach the monster.
            return [
                floor,
                makePlatform(x: -60, y: -sceneH * 0.08, width: 130, height: 16),
                makePlatform(x: 100, y:  sceneH * 0.06, width: 200, height: 16),
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
        body.friction = 0
        body.restitution = 0          // no bounce — pairs with the hero body
        body.categoryBitMask = PhysicsCategory.ground
        body.contactTestBitMask = PhysicsCategory.none
        body.collisionBitMask = PhysicsCategory.hero
        node.physicsBody = body

        // Record geometry so update() can do kinematic landing checks.
        platformRects.append(CGRect(x: x - width / 2, y: y - height / 2,
                                    width: width, height: height))
        return node
    }

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
        // affectedByGravity is off and collisions are disabled so the physics
        // engine never moves her; her Y is integrated by hand.
        let body = SKPhysicsBody(rectangleOf: CGSize(width: 28, height: 44))
        body.isDynamic = true
        body.affectedByGravity = false
        body.allowsRotation = false
        body.categoryBitMask = PhysicsCategory.hero
        body.contactTestBitMask = PhysicsCategory.hazard
        body.collisionBitMask = PhysicsCategory.none
        hero.physicsBody = body
    }

    private func buildMonster() {
        // Illustrated thread-ball creature. The PNG is 1024×1536 (2:3 ratio),
        // so width 60 → height 90 preserves the natural proportions.
        // Monster center = floor top (floorCenterY+9) + half-height (45).
        let node = SKSpriteNode(imageNamed: "Monster")
        node.size = CGSize(width: 60, height: 90)
        // PNG transparent-padding rule: monster PNGs have ~20pt of transparent space at the
        // bottom of their bounding box. Always subtract half-height MINUS ~20 when placing a
        // monster on a surface, i.e. surfaceTop + (halfHeight - 20) = surfaceTop + 25.
        // (Applies to all sprite characters placed on floors or platforms — remind Claude Code too.)
        let platformTop = sceneH * 0.06 + 8   // top of the seed-1 upper platform
        // Seed-1 platform is positioned with an absolute x (x: 100, width: 200,
        // so it spans 0..200). The monster's x must be absolute too — using
        // sceneW * 0.22 puts it past the right edge on landscape phones
        // (~187 of 0..200, half off the platform). 80 keeps it cleanly inside.
        let monsterX = config.levelSeed == 1 ? CGFloat(80) : sceneW * 0.10
        let monsterY = config.levelSeed == 1
            ? platformTop + 25                  // on the upper platform, padding-corrected
            : floorCenterY + 34                 // on the floor (seeds 2-4), padding-corrected
        node.position = CGPoint(x: monsterX, y: monsterY)
        node.zPosition = 2
        node.name = "monster"

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

        let radius: CGFloat = 40
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

        // Small scissor blades standing on the floor — short enough to hop over
        // one at a time. The sprite is sized directly (not via setScale) so the
        // node stays at scale 1.0 and the physics body keeps its true size.
        let floorTop = floorCenterY + 9
        let bladeSize = CGSize(width: 26, height: 50)   // a touch shorter than the hero
        let startX: CGFloat = -sceneW * 0.28            // blades on the left side of the arena
        for i in 0..<count {
            let blade = SKSpriteNode(imageNamed: "Scissors")
            blade.size = bladeSize
            blade.position = CGPoint(x: startX + CGFloat(i) * spacing,
                                     y: floorTop + bladeSize.height / 2)   // sits on the floor
            blade.zPosition = 2
            blade.name = "scissorHazard"

            // Hitbox a little smaller than the sprite so near-misses don't kill.
            let body = SKPhysicsBody(rectangleOf: CGSize(width: 20, height: 38))
            body.isDynamic = false
            body.categoryBitMask = PhysicsCategory.hazard
            body.contactTestBitMask = PhysicsCategory.hero
            body.collisionBitMask = PhysicsCategory.none
            blade.physicsBody = body

            addChild(blade)
        }
    }

    private func buildDirectionalButtons() {
        // All three control buttons sit at the same Y, below the floor bar.
        let buttonY = -sceneH * 0.38
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
        // x = sceneW * 0.36 (not 0.42) keeps the jump button reachable for a
        // wrap-grip with a shorter right thumb — the thumb bends in toward
        // center rather than extending out toward the edge.
        btn.position = CGPoint(x: sceneW * 0.36, y: -sceneH * 0.38)
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
        // Short fade so the hero is visible almost immediately — 0.4s felt like a delay.
        hero.alpha = 0
        hero.run(.fadeIn(withDuration: 0.1))
        // Pre-warm haptic engines so the very first press fires without latency.
        hapticLight.prepare()
        hapticMedium.prepare()
    }

    // MARK: - Touch handling (called by BackRoomScene.touchesBegan)

    func handleTouchBegan(_ touch: UITouch) {
        guard !isCompleting, !isDead else { return }
        guard let scene = sceneRef else { return }
        let location = touch.location(in: scene)

        if jumpButton.contains(location) {
            jumpButtonTouch = touch
            setPressed(jumpButton, true)
            hapticMedium.impactOccurred()
            tryJump()
            return
        }

        if leftArrowButton.contains(location) {
            leftButtonTouch = touch
            setPressed(leftArrowButton, true)
            hapticLight.impactOccurred()
            updateMoveDirection()
            return
        }
        if rightArrowButton.contains(location) {
            rightButtonTouch = touch
            setPressed(rightArrowButton, true)
            hapticLight.impactOccurred()
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

        if moveDirection != 0 {
            hero.position.x += moveDirection * heroSpeed * CGFloat(dt)
        }

        // Clamp to dungeon bounds (x)
        hero.position.x = max(-sceneW * 0.47, min(sceneW * 0.47, hero.position.x))

        // --- Vertical motion (fully kinematic) -------------------------------
        // The hero's Y is integrated here by hand — the physics engine never
        // moves her (her body has affectedByGravity = false, collisions off).
        // This makes the jump deterministic: no physics/clamp tug-of-war, no
        // tunnelling, and no reliance on contact callbacks for grounding.
        let g = inDescent ? gDescent : gAscent
        heroVelY -= g * CGFloat(dt)
        let newHeroY = hero.position.y + heroVelY * CGFloat(dt)

        // The surface under the hero: the floor, or a platform she is
        // descending onto from above (one-way — she jumps up through them).
        let footOffset: CGFloat = 31              // hero sprite half-height
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

        // Stomp vs. side-hit. Coming down onto the monster while descending
        // defeats him; touching him any other way — walking into him, or rising
        // into him on a too-late jump — sends the hero back to the start. A jump
        // that sails clear over him is just a harmless miss.
        if !monsterDefeated, !isDead, let monster = monster {
            let dx = abs(hero.position.x - monster.position.x)
            let dy = abs(hero.position.y - monster.position.y)
            let touching = dx < monster.size.width  / 2 + 14    // + hero half-width
                        && dy < monster.size.height / 2 + 22    // + hero half-body
            if touching {
                if heroVelY < -40 {        // descending onto him → stomp
                    defeatMonster()
                } else {                   // walked or rose into him → back to start
                    handleDeath()
                }
            }
        }

        // Hazard contact (scissor blades, falling buttons). Checked here by hand:
        // the kinematically-moved hero does not reliably trip the physics contact
        // delegate, so we test overlap directly — the same approach as the stomp.
        if !isDead, !isCompleting {
            for hazard in children where hazard.name == "scissorHazard"
                                      || hazard.name == "fallingButton" {
                let isButton = (hazard.name == "fallingButton")
                let hzHalfW: CGFloat = isButton ? 28 : 9
                let hzHalfH: CGFloat = isButton ? 28 : 18
                if abs(hero.position.x - hazard.position.x) < 14 + hzHalfW,
                   abs(hero.position.y - hazard.position.y) < 22 + hzHalfH {
                    handleDeath()
                    break
                }
            }
        }

        // Proximity chest claim — hero walks up to the chest to open it.
        // The 80-pt x-range is forgiving enough for young players without firing
        // accidentally while the hero is still fighting the monster; the 60-pt
        // y-range prevents a mid-fall claim when the chest is on a different
        // surface (the seed-1 chest sits on the upper platform).
        if monsterDefeated, chestClaimable, !chestOpened, !isCompleting, !isDead,
           let chest = chestNode,
           abs(hero.position.x - chest.position.x) < 80,
           abs(hero.position.y - chest.position.y) < 60 {
            openChest()
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
        SoundManager.shared.play("sfx_hero_hurt.mp3")
        moveDirection = 0
        leftButtonTouch = nil
        rightButtonTouch = nil
        jumpButtonTouch = nil
        setPressed(leftArrowButton, false)
        setPressed(rightArrowButton, false)
        setPressed(jumpButton, false)
        heroVelY = 0

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
            self.heroVelY = 0
            self.isJumping = false
            self.inDescent = false
            self.isOnGround = true
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
        SoundManager.shared.play("sfx_monster_stomp.mp3")
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

        // Bounce hero upward as feedback (kinematic).
        heroVelY = 200
        isJumping = true
        inDescent = false
    }

    private func spawnChest() {
        chestClaimable = false
        // Lock claim for 0.8s so the hero must physically walk to the chest.
        // Fixes seed-1 bug where the hero's x after stomping the upper-platform
        // monster was already within the 80pt claim radius of the chest spawn point.
        run(.wait(forDuration: 0.8)) { [weak self] in self?.chestClaimable = true }

        let chest = SKSpriteNode(imageNamed: "Chest")
        chest.size = CGSize(width: 70, height: 58)
        // Seed 1: chest sits on the upper platform a short walk to the right
        // of where the monster was, so the hero claims it without leaving the
        // platform — and the chest can't open mid-fall through the x-only
        // proximity check below. Seeds 2-4: chest on the dungeon floor.
        let chestPosition: CGPoint
        if config.levelSeed == 1 {
            let platformTop = sceneH * 0.06 + 8
            chestPosition = CGPoint(x: 160, y: platformTop + 29)
        } else {
            let floorTop = floorCenterY + 9
            chestPosition = CGPoint(x: sceneW * 0.30, y: floorTop + 29)
        }
        chest.position = chestPosition
        chest.zPosition = 2
        chest.name = "chest"

        chest.setScale(0)
        chestNode = chest
        addChild(chest)

        // Pop in, then pulse gently to draw the hero toward it
        chest.run(.sequence([
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

    private func openChest() {
        guard !chestOpened else { return }
        chestOpened = true
        isCompleting = true

        // Sound cascade: chest creak now, ascending coin jingle as the +냥 pop-up
        // rises, then a short celebration sting as the station clears.
        SoundManager.shared.play("sfx_chest_open.mp3")
        run(.sequence([
            .wait(forDuration: 0.25),
            .run { [weak self] in
                guard let self = self else { return }
                SoundManager.shared.play("sfx_coin_earn.mp3")
            },
            .wait(forDuration: 0.45),
            .run { [weak self] in
                guard let self = self else { return }
                SoundManager.shared.play("sfx_station_complete.mp3")
            }
        ]))

        // Stop the attract pulse, swap to the open-chest art, then bounce
        chestNode?.removeAction(forKey: "chestPulse")
        chestNode?.texture = SKTexture(imageNamed: "ChestOpen")
        chestNode?.size = CGSize(width: 84, height: 70)   // lid-open art is a touch wider

        instructionLabel.text = config.chestRewardLabel

        let bounce = SKAction.sequence([
            .scale(to: 1.3, duration: 0.12),
            .scale(to: 1.0, duration: 0.10)
        ])
        chestNode?.run(bounce)

        let chestPos = chestNode?.position ?? .zero

        // Reward item label rises from chest
        let reward = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        reward.text = config.chestRewardLabel
        reward.fontSize = 26
        reward.fontColor = .white
        reward.position = chestPos
        reward.zPosition = 6
        addChild(reward)

        let rise = SKAction.moveBy(x: 0, y: 80, duration: 0.6)
        rise.timingMode = .easeOut
        reward.run(.sequence([rise, .fadeOut(withDuration: 0.3), .removeFromParent()]))

        // 마력 reward awarded and displayed
        Magic.shared.add(config.completionReward)
        let coinPop = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        coinPop.text = "+\(config.completionReward)마력"
        coinPop.fontSize = 28
        coinPop.fontColor = UIColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1.0)
        coinPop.position = CGPoint(x: chestPos.x, y: chestPos.y + 40)
        coinPop.zPosition = 7
        addChild(coinPop)

        let coinRise = SKAction.moveBy(x: 0, y: 70, duration: 0.7)
        coinRise.timingMode = .easeOut
        coinPop.run(.sequence([coinRise, .fadeOut(withDuration: 0.3), .removeFromParent()]))

        spawnSparkles(at: chestPos)

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
}
