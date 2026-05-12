import SpriteKit

class BackRoomScene: SKScene {

    private enum BackRoomState {
        case waitingForCabinetTap
        case walkingToCabinet
        case choosingFabric
        
        case waitingForSewing
        case walkingToSewing

        case waitingForButtons
        case walkingToButtons
        case addingButtons
        
        case waitingForMannequin
        case walkingToMannequin
        case finalCheck
        
        case completed
    }

    private var currentState: BackRoomState = .waitingForCabinetTap

    var order: Order?

    private var expectedFabricNodeName: String {
        switch order?.fabricColor {
        case "파랑": return "blueFabric"
        case "노랑": return "yellowFabric"
        default:     return "pinkFabric"
        }
    }

    private var finishedDressImageName: String {
        switch order?.fabricColor {
        case "파랑": return "Mannequin_Dress_Blue"
        case "노랑": return "Mannequin_Dress_Yellow"
        default:     return "Mannequin_Dress_Pink"
        }
    }

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

    private var pinkFabricButton: SKShapeNode?
    private var blueFabricButton: SKShapeNode?
    private var yellowFabricButton: SKShapeNode?
    
    private var tailorHaloNode: SKShapeNode?
    private var mannequinZone: SKShapeNode?
    private var activeMinigame: MinigameNode?

    private var sewingStation: SKShapeNode?

    private var buttonStation: SKShapeNode?
    private var regularButtonNode: SKSpriteNode?
    private var fancyButtonNode: SKSpriteNode?
    
    private var regularButtonTapZone: SKShapeNode?
    private var fancyButtonTapZone: SKShapeNode?
 

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)

        setupBackground()
        setupTailor()
        setupFabricCabinetZone()
        setupSewingStationZone()
        setupButtonZone()
        setupMannequinZone()
        setupInstructionLabel()
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

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let minigame = activeMinigame {
            for touch in touches {
                minigame.handleTouchBegan(at: touch.location(in: self))
            }
            return
        }

        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        if handleInteraction(at: location) {
            return
        }

        handleMovement(at: location)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let minigame = activeMinigame {
            for touch in touches {
                minigame.handleTouchEnded(at: touch.location(in: self))
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let minigame = activeMinigame {
            for touch in touches {
                minigame.handleTouchEnded(at: touch.location(in: self))
            }
        }
    }
    
    override func update(_ currentTime: TimeInterval) {
        activeMinigame?.update(currentTime: currentTime)

        guard let cabinet = fabricCabinet else { return }

        if isTailorNearCabinet() {
            cabinet.strokeColor = .yellow
            cabinet.lineWidth = 3
        } else {
            cabinet.strokeColor = .clear
            cabinet.lineWidth = 0
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
                
            case "pinkFabric", "blueFabric", "yellowFabric":
                guard currentState == .choosingFabric else { return true }
                handleFabricChoice(named: nodeName)
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

                instructionLabel.text = "바느질 공간으로 이동 중이에요."
                currentState = .walkingToButtons

                moveTailor(to: 300) { [weak self] in
                    guard let self = self else { return }

                    self.instructionLabel.text = "버튼을 고르세요."
                    self.showButtonTypes()
                    self.currentState = .addingButtons
                }

                return true
            
            case "regularButton":
                guard currentState == .addingButtons else { return true }

                instructionLabel.text = "단추를 달았어요!"
                playButtonAnimation(node: regularButtonNode)

                run(SKAction.wait(forDuration: 0.2)) { [weak self] in
                    self?.finishButtonStep()
                }

                return true

            case "fancyButton":
                guard currentState == .addingButtons else { return true }

                instructionLabel.text = "예쁜 단추를 달았어요!"
                playButtonAnimation(node: fancyButtonNode)

                run(SKAction.wait(forDuration: 0.2)) { [weak self] in
                    self?.finishButtonStep()
                }

                return true
                
            case "mannequin":
                guard currentState == .waitingForMannequin else { return true }

                instructionLabel.text = "마네킹으로 이동 중이에요."
                currentState = .walkingToMannequin

                moveTailor(to: 0) { [weak self] in
                    guard let self = self else { return }
                    self.currentState = .completed
                    self.instructionLabel.text = "드레스 완성!"
                    self.placeDressOnMannequin()
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
    
    private func isTailorNearCabinet() -> Bool {
        guard let cabinet = fabricCabinet else { return false }
        
        let distance = abs(tailor.position.x - cabinet.position.x)
        return distance < 120 // tweak this value
    }

    // MARK: - Minigame overlay

    private func presentMinigame(for station: MinigameStation) {
        guard let scene = self.scene else { return }

        // Pause back-room tailor while minigame runs
        tailor.isPaused = true

        // Save gravity and set platformer gravity
        scene.physicsWorld.gravity = CGVector(dx: 0, dy: -18)

        // Full-screen touch shield at zPosition 49
        let shield = SKSpriteNode(color: .clear, size: scene.size)
        shield.position = .zero
        shield.zPosition = 49
        shield.name = "minigameShield"
        shield.isUserInteractionEnabled = false   // scene receives touches; shield blocks via zPos ordering
        addChild(shield)

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

    private func handleMinigameCompletion(for station: MinigameStation) {
        // Tear down overlay
        activeMinigame?.removeFromParent()
        activeMinigame = nil
        childNode(withName: "minigameShield")?.removeFromParent()

        // Restore gravity (back room has no physics bodies, so zero is correct)
        scene?.physicsWorld.gravity = .zero

        // Resume tailor
        tailor.isPaused = false

        // Advance back-room state machine
        switch station {
        case .fabricCabinet:
            instructionLabel.text = "잘했어요! 보관장이 열렸으니 원단을 골라볼까요?"
            showFabricChoices()
            currentState = .choosingFabric
        case .sewingStation:
            instructionLabel.text = "단추를 달아볼까요?"
            updateHaloColor(to: haloMedium)
            currentState = .waitingForButtons
        case .buttonStation:
            instructionLabel.text = "버튼을 고르세요."
            showButtonTypes()
            currentState = .addingButtons
        case .mannequin:
            currentState = .finalCheck
        }
    }

    private func showFabricChoices() {
        hideFabricChoices()

        pinkFabricButton = createFabricButton(
            text: "분홍 원단",
            name: "pinkFabric",
            position: CGPoint(x: -120, y: -50)
        )

        blueFabricButton = createFabricButton(
            text: "파랑 원단",
            name: "blueFabric",
            position: CGPoint(x: 0, y: -50)
        )

        yellowFabricButton = createFabricButton(
            text: "노랑 원단",
            name: "yellowFabric",
            position: CGPoint(x: 120, y: -50)
        )
    }

    private func createFabricButton(text: String, name: String, position: CGPoint) -> SKShapeNode {
        let button = SKShapeNode(rectOf: CGSize(width: 110, height: 46), cornerRadius: 14)
        button.fillColor = UIColor(red: 0.78, green: 0.52, blue: 0.33, alpha: 1.0)
        button.strokeColor = .brown
        button.lineWidth = 3
        button.position = position
        button.name = name
        button.zPosition = 20

        let label = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        label.text = text
        label.fontSize = 16
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = CGPoint.zero
        label.name = name
        label.zPosition = 21

        button.addChild(label)
        addChild(button)

        return button
    }

    private func hideFabricChoices() {
        pinkFabricButton?.removeFromParent()
        pinkFabricButton = nil

        blueFabricButton?.removeFromParent()
        blueFabricButton = nil

        yellowFabricButton?.removeFromParent()
        yellowFabricButton = nil
    }

    private func handleFabricChoice(named choice: String) {
        if choice == expectedFabricNodeName {
            instructionLabel.text = "좋아요! 원단을 골랐어요."
            hideFabricChoices()
            celebrateTailor()
            showTailorHalo(color: haloLight)
            currentState = .waitingForSewing
            instructionLabel.text = "재봉대로 가보세요."
        } else {
            let ordered = order?.fabricColor ?? "분홍"
            instructionLabel.text = "고객이 주문한 건 \(ordered) 원단이에요. 다시 골라봐요!"
        }
    }
    
    private func showButtonTypes() {
        regularButtonTapZone?.removeFromParent()
        fancyButtonTapZone?.removeFromParent()
        regularButtonNode?.removeFromParent()
        fancyButtonNode?.removeFromParent()
        
        let regularButtonZone = SKShapeNode(rectOf: CGSize(width: 100, height: 100), cornerRadius: 16)
        regularButtonZone.position = CGPoint(x: 220, y: -60)
        regularButtonZone.fillColor = .red.withAlphaComponent(0.2)
        regularButtonZone.strokeColor = .red
        regularButtonZone.lineWidth = 2
        regularButtonZone.name = "regularButton"
        regularButtonZone.zPosition = 19
        addChild(regularButtonZone)
        regularButtonTapZone = regularButtonZone

        let fancyButtonZone = SKShapeNode(rectOf: CGSize(width: 100, height: 100), cornerRadius: 16)
        fancyButtonZone.position = CGPoint(x: 340, y: -60)
        fancyButtonZone.fillColor = .yellow.withAlphaComponent(0.2)
        fancyButtonZone.strokeColor = .yellow
        fancyButtonZone.lineWidth = 2
        fancyButtonZone.name = "fancyButton"
        fancyButtonZone.zPosition = 19
        addChild(fancyButtonZone)
        fancyButtonTapZone = fancyButtonZone

        regularButtonNode = SKSpriteNode(imageNamed: "Buttons_Regular")
        regularButtonNode?.position = regularButtonZone.position
        regularButtonNode?.setScale(0.10)
        regularButtonNode?.name = "regularButton"
        regularButtonNode?.zPosition = 20

        fancyButtonNode = SKSpriteNode(imageNamed: "Buttons_Fancy")
        fancyButtonNode?.position = fancyButtonZone.position
        fancyButtonNode?.setScale(0.10)
        fancyButtonNode?.name = "fancyButton"
        fancyButtonNode?.zPosition = 20

        if let regularButtonNode { addChild(regularButtonNode) }
        if let fancyButtonNode { addChild(fancyButtonNode) }
    }
    
    private func finishButtonStep() {
        regularButtonNode?.removeFromParent()
        fancyButtonNode?.removeFromParent()
        regularButtonTapZone?.removeFromParent()
        fancyButtonTapZone?.removeFromParent()

        regularButtonNode = nil
        fancyButtonNode = nil
        regularButtonTapZone = nil
        fancyButtonTapZone = nil

        updateHaloColor(to: haloDark)

        currentState = .waitingForMannequin
        instructionLabel.text = "완성된 드레스를 마네킹에 입혀볼까요?"
    }
    
    private func playButtonAnimation(node: SKSpriteNode?) {
        playWiggleAnimation(on: node)
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
        scene.shouldShowFinishedDress = true
        scene.finishedDressImageName = finishedDressImageName

        let transition = SKTransition.crossFade(withDuration: 0.6)
        view.presentScene(scene, transition: transition)
    }
    
    private func playWiggleAnimation(on node: SKNode?) {
        let rotateRight = SKAction.rotate(byAngle: 0.12, duration: 0.08)
        let rotateLeft = SKAction.rotate(byAngle: -0.24, duration: 0.08)
        let backToCenter = SKAction.rotate(byAngle: 0.12, duration: 0.08)

        node?.run(SKAction.sequence([rotateRight, rotateLeft, backToCenter]))
    }

    private func celebrateTailor() {
        let up = SKAction.moveBy(x: 0, y: 12, duration: 0.1)
        let down = SKAction.moveBy(x: 0, y: -12, duration: 0.1)
        tailor.run(SKAction.sequence([up, down]))
    }
    
    private func addDebugBox(at position: CGPoint, size: CGSize, color: UIColor, name: String) {
        let box = SKShapeNode(rectOf: size, cornerRadius: 12)
        box.position = position
        box.fillColor = color.withAlphaComponent(0.25)
        box.strokeColor = color
        box.lineWidth = 2
        box.name = name
        box.zPosition = 19
        addChild(box)
    }
}
