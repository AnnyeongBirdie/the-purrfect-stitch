import SpriteKit

class BackRoomScene: SKScene {

    private enum BackRoomState: String {
        case waitingForCabinetTap
        case walkingToCabinet

        case waitingForSewing
        case walkingToSewing

        case waitingForButtons
        case walkingToButtons

        case waitingForMannequin
        case walkingToMannequin
        case finalCheck

        case completed
    }

    private var currentState: BackRoomState = .waitingForCabinetTap {
        didSet { saveActiveOrderSnapshot() }
    }

    var order: Order?
    var resumeStateName: String?
    var resumeEarnedRewards: Int = 0

    private let cabinetInteractionX: CGFloat = -180

    private var haloLight: UIColor {
        switch order?.fabricColor {
        case "파랑": return UIColor(red: 0.75, green: 0.88, blue: 1.00, alpha: 1.0)
        case "노랑": return UIColor(red: 1.00, green: 0.97, blue: 0.65, alpha: 1.0)
        default:     return UIColor(red: 1.00, green: 0.80, blue: 0.86, alpha: 1.0)
        }
    }
    private var haloMedium: UIColor {
        switch order?.fabricColor {
        case "파랑": return UIColor(red: 0.20, green: 0.50, blue: 0.95, alpha: 1.0)
        case "노랑": return UIColor(red: 0.95, green: 0.80, blue: 0.10, alpha: 1.0)
        default:     return UIColor(red: 0.95, green: 0.38, blue: 0.60, alpha: 1.0)
        }
    }
    private var haloDark: UIColor {
        switch order?.fabricColor {
        case "파랑": return UIColor(red: 0.05, green: 0.15, blue: 0.70, alpha: 1.0)
        case "노랑": return UIColor(red: 0.75, green: 0.50, blue: 0.00, alpha: 1.0)
        default:     return UIColor(red: 0.70, green: 0.05, blue: 0.28, alpha: 1.0)
        }
    }

    private var tailor: SKSpriteNode!
    private var fabricCabinet: SKShapeNode?
    private var instructionLabel: SKLabelNode!

    private var tailorHaloNode: SKShapeNode?
    private var mannequinZone: SKShapeNode?
    private var activeMinigame: MinigameNode?

    private var sewingStation: SKShapeNode?

    private var buttonStation: SKShapeNode?

    private var activeBossMinigame: BossMinigameNode?
    private var walletLabel: SKLabelNode?

    private var earnedMinigameRewards: Int = 0
    private var quitButton: SKShapeNode?
    private var exitDialogNode: SKNode?


    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = true
        anchorPoint = CGPoint(x: 0.5, y: 0.5)

        setupBackground()
        setupTailor()
        setupFabricCabinetZone()
        setupSewingStationZone()
        setupButtonZone()
        setupMannequinZone()
        setupInstructionLabel()
        setupWalletHUD()
        setupStationFireflies()
        setupQuitButton()
        applyResumeStateIfNeeded()
        saveActiveOrderSnapshot()
    }

    private func setupBackground() {
        let background = SKSpriteNode(imageNamed: "Backroom_Background")
        background.position = CGPoint(x: 0, y: 0)
        background.zPosition = 0
        background.size = self.size
        addChild(background)
    }

    private func setupTailor() {
        let tailor = SKSpriteNode(imageNamed: "Tailor")
        tailor.position = CGPoint(x: 0, y: -40)
        tailor.zPosition = 10
        tailor.setScale(0.5)
        tailor.name = "tailor"

        self.tailor = tailor
        addChild(tailor)
    }

    private func setupFabricCabinetZone() {
        let zone = SKShapeNode(rectOf: CGSize(width: 130, height: 260), cornerRadius: 12)
        zone.position = CGPoint(x: -280, y: 20)
        zone.fillColor = .clear
        zone.strokeColor = .clear
        zone.lineWidth = 3
        zone.name = "fabricCabinet"
        zone.zPosition = 5

        self.fabricCabinet = zone
        addChild(zone)
    }
    
    private func setupSewingStationZone() {
        let zone = SKShapeNode(rectOf: CGSize(width: 150, height: 200), cornerRadius: 12)
        zone.position = CGPoint(x: 190, y: 0)

        zone.fillColor = .clear
        zone.strokeColor = .clear

        zone.name = "sewingStation"
        zone.zPosition = 5

        self.sewingStation = zone
        addChild(zone)
    }
    
    private func setupButtonZone() {
        let zone = SKShapeNode(rectOf: CGSize(width: 150, height: 200), cornerRadius: 12)
        zone.position = CGPoint(x: 300, y: 0)

        zone.fillColor = .clear
        zone.strokeColor = .clear

        zone.name = "buttonStation"
        zone.zPosition = 5

        self.buttonStation = zone
        addChild(zone)
    }

    private func setupInstructionLabel() {
        instructionLabel = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        instructionLabel.text = "원단 보관장을 눌러보세요."
        instructionLabel.fontSize = 24
        instructionLabel.fontColor = .white
        instructionLabel.position = CGPoint(x: 0, y: 150)
        instructionLabel.zPosition = 20
        addChild(instructionLabel)
    }

    private func setupStationFireflies() {
        let centers: [CGPoint] = [
            CGPoint(x: -280, y: 20),   // fabric cabinet
            CGPoint(x: 190, y: 0),     // sewing station
            CGPoint(x: 300, y: 0),     // button station
            CGPoint(x: 0, y: 10),      // mannequin
        ]
        let fireflyColor = UIColor(red: 1.0, green: 0.95, blue: 0.5, alpha: 1.0)

        for center in centers {
            for i in 0..<4 {
                let firefly = SKShapeNode(circleOfRadius: 3.5)
                firefly.fillColor = fireflyColor
                firefly.strokeColor = .clear
                firefly.glowWidth = 6
                firefly.zPosition = 4
                firefly.alpha = 0
                firefly.position = CGPoint(
                    x: center.x + CGFloat.random(in: -40...40),
                    y: center.y + CGFloat.random(in: -60...30)
                )
                addChild(firefly)

                let cycle = SKAction.sequence([
                    SKAction.run { [weak firefly] in
                        firefly?.position = CGPoint(
                            x: center.x + CGFloat.random(in: -40...40),
                            y: center.y + CGFloat.random(in: -60...30)
                        )
                        firefly?.alpha = 0
                    },
                    SKAction.fadeIn(withDuration: 0.5),
                    SKAction.group([
                        SKAction.moveBy(x: 0, y: 55, duration: 1.6),
                        SKAction.sequence([
                            SKAction.wait(forDuration: 0.9),
                            SKAction.fadeOut(withDuration: 0.7)
                        ])
                    ]),
                    SKAction.wait(forDuration: 0.3)
                ])
                firefly.run(.sequence([
                    .wait(forDuration: Double(i) * 0.6),
                    .repeatForever(cycle)
                ]))
            }
        }
    }

    private func setupWalletHUD() {
        let bubble = SKShapeNode(rectOf: CGSize(width: 138, height: 36), cornerRadius: 18)
        bubble.fillColor = UIColor(red: 0.98, green: 0.95, blue: 0.85, alpha: 0.93)
        bubble.strokeColor = UIColor(red: 0.55, green: 0.35, blue: 0.10, alpha: 1.0)
        bubble.lineWidth = 2
        bubble.position = CGPoint(x: size.width * 0.36, y: size.height * 0.44)
        bubble.zPosition = 20
        addChild(bubble)

        let lbl = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        lbl.text = "💰 \(Wallet.shared.balance)냥"
        lbl.fontSize = 17
        lbl.fontColor = UIColor(red: 0.30, green: 0.14, blue: 0.00, alpha: 1.0)
        lbl.horizontalAlignmentMode = .center
        lbl.verticalAlignmentMode = .center
        lbl.position = .zero
        lbl.zPosition = 1
        bubble.addChild(lbl)
        walletLabel = lbl
    }

    private func updateWalletHUD() {
        walletLabel?.text = "💰 \(Wallet.shared.balance)냥"
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let minigame = activeMinigame {
            for touch in touches { minigame.handleTouchBegan(touch) }
            return
        }
        if let boss = activeBossMinigame {
            for touch in touches { boss.handleTouchBegan(touch) }
            return
        }

        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        // Exit dialog intercepts all taps when visible
        if exitDialogNode != nil {
            handleExitDialogTap(at: location)
            return
        }

        // Quit button
        if let qBtn = quitButton, !qBtn.isHidden,
           qBtn.contains(touch.location(in: self)) {
            showExitDialog()
            return
        }

        if handleInteraction(at: location) {
            return
        }

        handleMovement(at: location)
    }

    private func handleExitDialogTap(at location: CGPoint) {
        guard let order = order else { return }
        for node in nodes(at: location) {
            guard let name = node.name else { continue }
            switch name {
            case "exitRefund":
                exitDialogNode?.removeFromParent()
                exitDialogNode = nil
                Wallet.shared.balance += order.depositAmount - earnedMinigameRewards
                Store.clearActiveOrder()
                returnToFrontShopEmpty()
                return
            case "exitCashOut":
                exitDialogNode?.removeFromParent()
                exitDialogNode = nil
                Store.clearActiveOrder()
                returnToFrontShopEmpty()
                return
            case "exitCancel":
                exitDialogNode?.removeFromParent()
                exitDialogNode = nil
                return
            default:
                continue
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let minigame = activeMinigame {
            for touch in touches { minigame.handleTouchEnded(touch) }
        }
        if let boss = activeBossMinigame {
            for touch in touches { boss.handleTouchEnded(touch) }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let minigame = activeMinigame {
            for touch in touches { minigame.handleTouchEnded(touch) }
        }
        if let boss = activeBossMinigame {
            for touch in touches { boss.handleTouchEnded(touch) }
        }
    }
    
    override func update(_ currentTime: TimeInterval) {
        activeMinigame?.update(currentTime: currentTime)
        activeBossMinigame?.update(currentTime: currentTime)

        // Clear all rings, then light up the currently active target if the tailor is close.
        fabricCabinet?.strokeColor = .clear
        sewingStation?.strokeColor = .clear
        buttonStation?.strokeColor = .clear
        mannequinZone?.strokeColor = .clear

        let activeZone: SKShapeNode?
        switch currentState {
        case .waitingForCabinetTap: activeZone = fabricCabinet
        case .waitingForSewing:     activeZone = sewingStation
        case .waitingForButtons:    activeZone = buttonStation
        case .waitingForMannequin:  activeZone = mannequinZone
        default:                    activeZone = nil
        }

        if let zone = activeZone, abs(tailor.position.x - zone.position.x) < 120 {
            zone.strokeColor = .yellow
            zone.lineWidth = 3
        }

        if let halo = tailorHaloNode {
            halo.position = CGPoint(x: tailor.position.x, y: tailor.position.y)
        }
    }
    
    private func handleInteraction(at location: CGPoint) -> Bool {
        let tappedNodes = nodes(at: location)

        for node in tappedNodes {
            guard let nodeName = node.name else { continue }

            switch nodeName {
            case "fabricCabinet":
                guard currentState == .waitingForCabinetTap else { return true }

                instructionLabel.text = "원단 보관장으로 가는 중이에요."
                currentState = .walkingToCabinet

                moveTailor(to: cabinetInteractionX) { [weak self] in
                    guard let self = self else { return }
                    self.presentMinigame(for: .fabricCabinet)
                }

                return true
                
            case "sewingStation":
                guard currentState == .waitingForSewing else { return true }

                instructionLabel.text = "재봉대로 이동 중이에요."
                currentState = .walkingToSewing

                moveTailor(to: 120) { [weak self] in
                    guard let self = self else { return }
                    self.presentMinigame(for: .sewingStation)
                }

                return true
                
            case "buttonStation":
                guard currentState == .waitingForButtons else { return true }

                instructionLabel.text = "단추 공간으로 이동 중이에요."
                currentState = .walkingToButtons

                moveTailor(to: 300) { [weak self] in
                    guard let self = self else { return }
                    self.presentMinigame(for: .buttonStation)
                }

                return true
                
            case "mannequin":
                guard currentState == .waitingForMannequin else { return true }

                instructionLabel.text = "마네킹으로 이동 중이에요."
                currentState = .walkingToMannequin

                moveTailor(to: 0) { [weak self] in
                    guard let self = self else { return }
                    self.presentBossMinigame()
                }

                return true
                
            default:
                continue
            
            }
        }

        return false
    }

    private func handleMovement(at location: CGPoint) {
        let movableStates: [BackRoomState] = [
            .waitingForCabinetTap,
            .waitingForSewing,
            .waitingForButtons,
            .waitingForMannequin
        ]

        guard movableStates.contains(currentState) else { return }

        if location.x < 0 {
            moveTailor(by: -80)
        } else {
            moveTailor(by: 80)
        }
    }

    private func moveTailor(by amount: CGFloat) {
        let newX = tailor.position.x + amount

        let leftLimit = -self.size.width / 2 + 50
        let rightLimit = self.size.width / 2 - 50

        let clampedX = max(leftLimit, min(rightLimit, newX))

        let move = SKAction.moveTo(x: clampedX, duration: 0.2)
        move.timingMode = .easeOut

        let moveUp = SKAction.moveBy(x: 0, y: 10, duration: 0.1)
        let moveDown = SKAction.moveBy(x: 0, y: -10, duration: 0.1)

        let bounce = SKAction.sequence([moveUp, moveDown])
        let group = SKAction.group([move, bounce])

        if amount < 0 {
            tailor.xScale = abs(tailor.xScale)
        } else {
            tailor.xScale = -abs(tailor.xScale)
        }

        tailor.run(group)
    }
    
    private func moveTailor(to targetX: CGFloat, completion: (() -> Void)? = nil) {
        let leftLimit = -self.size.width / 2 + 50
        let rightLimit = self.size.width / 2 - 50
        let clampedX = max(leftLimit, min(rightLimit, targetX))

        let distance = abs(tailor.position.x - clampedX)
        let duration = max(0.15, TimeInterval(distance / 300))

        let move = SKAction.moveTo(x: clampedX, duration: duration)
        move.timingMode = .easeOut

        let moveUp = SKAction.moveBy(x: 0, y: 10, duration: 0.1)
        let moveDown = SKAction.moveBy(x: 0, y: -10, duration: 0.1)
        let bounce = SKAction.sequence([moveUp, moveDown])

        let bounceCount = max(1, Int(duration / 0.2))
        let repeatedBounce = SKAction.repeat(bounce, count: bounceCount)

        let group = SKAction.group([move, repeatedBounce])

        if clampedX < tailor.position.x {
            tailor.xScale = abs(tailor.xScale)
        } else {
            tailor.xScale = -abs(tailor.xScale)
        }

        tailor.run(group) {
            completion?()
        }
    }
    
    // MARK: - Minigame overlay

    private func presentMinigame(for station: MinigameStation) {
        guard let scene = self.scene else { return }

        // Pause back-room tailor while minigame runs
        tailor.isPaused = true
        quitButton?.isHidden = true

        // Save gravity and set platformer gravity
        scene.physicsWorld.gravity = CGVector(dx: 0, dy: -18)

        // Back-room touches are intercepted in touchesBegan via the activeMinigame
        // early-return, so no separate touch-shield node is needed.

        let config = MinigameConfig.make(for: station, order: order)
        let minigame = MinigameNode(config: config) { [weak self] completedStation in
            self?.handleMinigameCompletion(for: completedStation)
        }
        minigame.zPosition = 50
        minigame.name = "minigame"
        activeMinigame = minigame
        addChild(minigame)
        minigame.setup(in: scene)
    }

    private func presentBossMinigame() {
        guard let scene = self.scene else { return }
        tailor.isPaused = true
        quitButton?.isHidden = true
        scene.physicsWorld.gravity = CGVector(dx: 0, dy: -18)

        let boss = BossMinigameNode(order: order) { [weak self] in
            self?.handleBossCompletion()
        }
        boss.zPosition = 50
        boss.name = "bossMinigame"
        activeBossMinigame = boss
        addChild(boss)
        boss.setup(in: scene)
    }

    private func handleBossCompletion() {
        activeBossMinigame?.removeFromParent()
        activeBossMinigame = nil
        scene?.physicsWorld.gravity = .zero
        tailor.isPaused = false
        updateQuitButtonVisibility()

        earnedMinigameRewards += 50
        Store.clearActiveOrder()

        // .finalCheck: the brief beat between boss defeat and the dress appearing.
        currentState = .finalCheck
        instructionLabel.text = garmentCompletionText(for: order)
        updateWalletHUD()
        placeDressOnMannequin()
    }

    private func handleMinigameCompletion(for station: MinigameStation) {
        // Tear down overlay
        activeMinigame?.removeFromParent()
        activeMinigame = nil

        // Restore gravity (back room has no physics bodies, so zero is correct)
        scene?.physicsWorld.gravity = .zero

        // Resume tailor
        tailor.isPaused = false

        // Advance back-room state machine
        switch station {
        case .fabricCabinet:
            earnedMinigameRewards += 10
            celebrateTailor()
            showTailorHalo(color: haloLight)
            instructionLabel.text = "잘했어요! 재봉대로 가보세요."
            currentState = .waitingForSewing
        case .sewingStation:
            earnedMinigameRewards += 20
            instructionLabel.text = "단추를 달아볼까요?"
            updateHaloColor(to: haloMedium)
            currentState = .waitingForButtons
        case .buttonStation:
            earnedMinigameRewards += 30
            instructionLabel.text = "완성된 \(garmentNoun(for: order))를 마네킹에 입혀볼까요?"
            updateHaloColor(to: haloDark)
            currentState = .waitingForMannequin
        }
        updateQuitButtonVisibility()
        updateWalletHUD()
    }

    private func setupMannequinZone() {
        let zone = SKShapeNode(rectOf: CGSize(width: 120, height: 220), cornerRadius: 12)
        zone.position = CGPoint(x: 0, y: 10)

        zone.fillColor = .clear
        zone.strokeColor = .clear

        zone.name = "mannequin"
        zone.zPosition = 5

        self.mannequinZone = zone
        addChild(zone)
    }
    
    private func showTailorHalo(color: UIColor) {
        tailorHaloNode?.removeFromParent()

        let halo = SKShapeNode(rectOf: CGSize(width: 70, height: 200), cornerRadius: 35)
        halo.fillColor = color.withAlphaComponent(0.45)
        halo.strokeColor = color.withAlphaComponent(0.85)
        halo.lineWidth = 3
        halo.glowWidth = 24
        halo.position = CGPoint(x: tailor.position.x, y: tailor.position.y)
        halo.zPosition = 8
        halo.name = "tailorHalo"

        tailorHaloNode = halo
        addChild(halo)

        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 1.0, duration: 0.65),
            SKAction.fadeAlpha(to: 0.10, duration: 0.65)
        ])
        halo.run(.repeatForever(pulse), withKey: "haloPulse")
    }

    private func updateHaloColor(to color: UIColor) {
        let oldHalo = tailorHaloNode
        tailorHaloNode = nil
        oldHalo?.removeAllActions()
        oldHalo?.run(.sequence([.fadeOut(withDuration: 0.25), .removeFromParent()]))

        run(.wait(forDuration: 0.15)) { [weak self] in
            self?.showTailorHalo(color: color)
        }
    }

    private func placeDressOnMannequin() {
        celebrateTailor()

        guard let halo = tailorHaloNode else {
            returnToFrontShop()
            return
        }

        tailorHaloNode = nil
        halo.removeAllActions()
        halo.alpha = 1.0

        let targetScale = max(size.width, size.height) * 2.0 / 70.0
        let expand = SKAction.scale(to: targetScale, duration: 0.85)
        expand.timingMode = .easeIn

        halo.run(expand) { [weak self] in
            self?.returnToFrontShop()
        }
    }
    
    private func returnToFrontShop() {
        guard let view = self.view else { return }
        guard let scene = FrontShopScene(fileNamed: "GameScene") else {
            print("Could not load GameScene.sks")
            return
        }

        scene.scaleMode = .resizeFill
        scene.shouldShowFinishedGarment = true
        scene.finishedGarmentImageName = garmentImageName(for: order)
        scene.completedOrder = order

        let transition = SKTransition.crossFade(withDuration: 0.6)
        view.presentScene(scene, transition: transition)
    }
    
    private func celebrateTailor() {
        let up = SKAction.moveBy(x: 0, y: 12, duration: 0.1)
        let down = SKAction.moveBy(x: 0, y: -12, duration: 0.1)
        tailor.run(SKAction.sequence([up, down]))
    }

    // MARK: - Active order persistence

    private func saveActiveOrderSnapshot() {
        guard let order = order else { return }
        // Don't overwrite a cleared record after order completes
        let snapshot = ActiveOrder(
            clothingType: order.clothingType,
            fabricColor: order.fabricColor,
            depositAmount: order.depositAmount,
            backRoomStateName: currentState.rawValue,
            earnedMinigameRewards: earnedMinigameRewards,
            savedAt: Date()
        )
        Store.saveActiveOrder(snapshot)
    }

    private func applyResumeStateIfNeeded() {
        guard let stateName = resumeStateName,
              let saved = BackRoomState(rawValue: stateName) else { return }

        earnedMinigameRewards = resumeEarnedRewards

        // Map saved state → nearest forward .waitingForX station
        let resumeTarget: BackRoomState
        switch saved {
        case .waitingForCabinetTap, .walkingToCabinet:
            resumeTarget = .waitingForCabinetTap
        case .waitingForSewing, .walkingToSewing:
            resumeTarget = .waitingForSewing
            showTailorHalo(color: haloLight)
            instructionLabel.text = "재봉대로 가보세요."
        case .waitingForButtons, .walkingToButtons:
            resumeTarget = .waitingForButtons
            showTailorHalo(color: haloMedium)
            instructionLabel.text = "단추를 달아볼까요?"
        case .waitingForMannequin, .walkingToMannequin:
            resumeTarget = .waitingForMannequin
            showTailorHalo(color: haloDark)
            instructionLabel.text = "완성된 \(garmentNoun(for: order))를 마네킹에 입혀볼까요?"
        default:
            resumeTarget = .waitingForCabinetTap
        }

        // Set without triggering didSet save (order not yet serialized at this point)
        currentState = resumeTarget
        updateQuitButtonVisibility()
    }

    // MARK: - Quit button

    private func setupQuitButton() {
        let button = SKShapeNode(rectOf: CGSize(width: 108, height: 40), cornerRadius: 12)
        button.fillColor = UIColor(red: 0.55, green: 0.20, blue: 0.15, alpha: 0.88)
        button.strokeColor = .clear
        button.position = CGPoint(x: size.width / 2 - 70, y: size.height / 2 - 40)
        button.zPosition = 20
        button.name = "quitButton"
        addChild(button)
        quitButton = button

        let label = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        label.text = "그만할래"
        label.fontSize = 18
        label.fontColor = .white
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.name = "quitButton"
        label.zPosition = 1
        button.addChild(label)
    }

    private func updateQuitButtonVisibility() {
        let visibleStates: [BackRoomState] = [
            .waitingForCabinetTap, .walkingToCabinet,
            .waitingForSewing,     .walkingToSewing,
            .waitingForButtons,    .walkingToButtons,
            .waitingForMannequin,  .walkingToMannequin
        ]
        let minigameActive = (activeMinigame != nil || activeBossMinigame != nil)
        quitButton?.isHidden = minigameActive || !visibleStates.contains(currentState)
    }

    private func showExitDialog() {
        guard let order = order else { return }

        exitDialogNode?.removeFromParent()

        let deposit = order.depositAmount
        let refundedBalance  = Wallet.shared.balance + deposit - earnedMinigameRewards
        let currentBalance   = Wallet.shared.balance

        let overlay = SKNode()
        overlay.zPosition = 60
        overlay.name = "exitDialog"
        addChild(overlay)
        exitDialogNode = overlay

        // Dim background
        let dim = SKShapeNode(rectOf: size)
        dim.fillColor = UIColor(white: 0, alpha: 0.55)
        dim.strokeColor = .clear
        dim.zPosition = -1
        overlay.addChild(dim)

        // Panel
        let panel = SKShapeNode(rectOf: CGSize(width: 320, height: 280), cornerRadius: 24)
        panel.fillColor = UIColor(red: 0.96, green: 0.91, blue: 0.80, alpha: 0.98)
        panel.strokeColor = UIColor.brown
        panel.lineWidth = 4
        panel.zPosition = 1
        overlay.addChild(panel)

        let title = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        title.text = "정말 그만할래요?"
        title.fontSize = 24
        title.fontColor = .black
        title.position = CGPoint(x: 0, y: 100)
        title.verticalAlignmentMode = .center
        panel.addChild(title)

        // Option A: refund deposit
        let btnA = makeDialogButton(
            text: "보증금 환불 → 지갑 \(refundedBalance)냥",
            name: "exitRefund",
            position: CGPoint(x: 0, y: 30),
            width: 280
        )
        panel.addChild(btnA)

        // Option B: cash out
        let btnB = makeDialogButton(
            text: "지금까지 모은 거 챙기기 → 지갑 \(currentBalance)냥",
            name: "exitCashOut",
            position: CGPoint(x: 0, y: -45),
            width: 280
        )
        panel.addChild(btnB)

        // Cancel
        let btnC = makeDialogButton(
            text: "취소",
            name: "exitCancel",
            position: CGPoint(x: 0, y: -115),
            width: 160
        )
        panel.addChild(btnC)
    }

    private func makeDialogButton(text: String, name: String, position: CGPoint, width: CGFloat) -> SKShapeNode {
        let button = SKShapeNode(rectOf: CGSize(width: width, height: 50), cornerRadius: 14)
        button.fillColor = UIColor(red: 0.78, green: 0.52, blue: 0.33, alpha: 1.0)
        button.strokeColor = UIColor.brown
        button.lineWidth = 2
        button.position = position
        button.name = name

        let label = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        label.text = text
        label.fontSize = 15
        label.fontColor = .white
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.name = name
        label.zPosition = 1
        button.addChild(label)
        return button
    }

    private func returnToFrontShopEmpty() {
        guard let view = self.view else { return }
        guard let scene = FrontShopScene(fileNamed: "GameScene") else { return }
        scene.scaleMode = .resizeFill
        let transition = SKTransition.crossFade(withDuration: 0.6)
        view.presentScene(scene, transition: transition)
    }
}
