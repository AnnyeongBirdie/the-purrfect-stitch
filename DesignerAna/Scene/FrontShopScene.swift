import SpriteKit

class FrontShopScene: SKScene {
    
    private var dialogLabel: SKLabelNode!
    private var speechBubble: SKShapeNode!
    
    private var currentState: FrontShopState = .greeting
    private var currentOrder: Order?
    private var pendingClothingType: ClothingType = .dress
    private var pendingDeposit: Int = 0

    private var dressButton: SKShapeNode!
    private var shirtButton: SKShapeNode!
    private var pantsButton: SKShapeNode!

    private var pinkColorButton: SKShapeNode?
    private var blueColorButton: SKShapeNode?
    private var yellowColorButton: SKShapeNode?
    private var fabricBackButton: SKShapeNode?
    
    private var orderSheet: SKShapeNode?
    private var confirmButton: SKShapeNode?
    private var cancelButton: SKShapeNode?
    
    private var paymentPanel: SKShapeNode?
    private var payButton: SKShapeNode?
    
    var shouldShowFinishedGarment = false
    var suppressEntryBell = false   // set by side-scenes (Wardrobe/Riddle/Settings) on return
    var finishedGarmentImageName: String = "Mannequin_Dress_Pink"
    var completedOrder: Order?

    private var saveTrophyButton: SKShapeNode?
    private var relaunchDialogNode: SKNode?

    private var safeBottom: CGFloat = 0


    override func didMove(to view: SKView) {
        safeBottom = view.safeAreaInsets.bottom
        fitBackgroundToScene()
        setupDialogueUI()
        fixCharacterLayout()
        setupNavIcons()
        if !suppressEntryBell {
            SoundManager.shared.play("sfx_shop_bell.mp3")
        }

        if shouldShowFinishedGarment {
            showFinishedGarmentOnFrontMannequin()
            showCompletionGreeting()
            showSaveTrophyButton()
            currentState = .showingFinishedGarment
            setNavIconsDimmed(true)   // block leaving before the trophy is saved
        } else if let saved = Store.loadActiveOrder(),
                  Date().timeIntervalSince(saved.savedAt) < 30 * 24 * 3600 {
            showGreeting()
            currentState = .greeting
            showRelaunchDialog(for: saved)
        } else {
            showGreeting()
            showClothingChoices()
            currentState = .choosingClothing
        }

        if let shopkeeper = childNode(withName: "shopkeeper") as? SKSpriteNode {
            shopkeeper.zPosition = 20
        }

        if let mannequin = childNode(withName: "//mannequin") as? SKSpriteNode {
            mannequin.zPosition = 20
        }
    }

    // MARK: - Nav icon strip (left edge)
    // Four circular icon buttons stacked on the left side:
    // ⚙ Settings, 💰 Wallet (riddles), 👗 Wardrobe, 📖 Storybook.
    private func setupNavIcons() {
        let icons: [(symbol: String, name: String, y: CGFloat)] = [
            ("⚙",  "settingsNav",   105),
            ("💰", "walletNav",      40),
            ("👗", "wardrobeNav",   -25),
            ("📖", "storybookNav",  -90),
        ]
        let x: CGFloat = -size.width * 0.38

        for icon in icons {
            let btn = SKShapeNode(rectOf: CGSize(width: 54, height: 54), cornerRadius: 14)
            btn.fillColor = UIColor(red: 0.78, green: 0.52, blue: 0.33, alpha: 0.88)
            btn.strokeColor = UIColor(red: 0.55, green: 0.35, blue: 0.10, alpha: 0.6)
            btn.lineWidth = 2
            btn.position = CGPoint(x: x, y: icon.y)
            btn.zPosition = 30
            btn.name = icon.name

            let label = SKLabelNode(text: icon.symbol)
            label.fontSize = 26
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            label.name = icon.name
            btn.addChild(label)
            addChild(btn)
        }
    }

    /// Dim or restore the four nav icons. They are dimmed while a finished
    /// garment waits to be saved, so it reads as "inactive" rather than
    /// silently swallowing taps — and so the trophy can't be lost by
    /// navigating away before it is stored.
    private func setNavIconsDimmed(_ dimmed: Bool) {
        for name in ["settingsNav", "walletNav", "wardrobeNav", "storybookNav"] {
            childNode(withName: name)?.alpha = dimmed ? 0.35 : 1.0
        }
    }

    private func setupDialogueUI() {
        let bubbleWidth = size.width * 0.58
        let bubbleHeight: CGFloat = 95

        speechBubble = SKShapeNode(rectOf: CGSize(width: bubbleWidth, height: bubbleHeight), cornerRadius: 28)
        speechBubble.fillColor = UIColor(red: 0.98, green: 0.95, blue: 0.85, alpha: 0.95)
        speechBubble.strokeColor = UIColor.brown
        speechBubble.lineWidth = 4
        // Centered above the shopkeeper (x:0). At 58% width the left edge sits at
        // -0.29*width, which clears the nav icon strip at -0.35*width.
        speechBubble.position = CGPoint(x: 0, y: frame.maxY - 70)
        speechBubble.zPosition = 90
        
        addChild(speechBubble)
        
        dialogLabel = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        dialogLabel.text = ""
        dialogLabel.fontSize = 28
        dialogLabel.fontColor = .black
        dialogLabel.horizontalAlignmentMode = .center
        dialogLabel.verticalAlignmentMode = .center
        dialogLabel.position = CGPoint(x: 0, y: -4)
        dialogLabel.zPosition = 100
        
        speechBubble.addChild(dialogLabel)
    }
    
    private func showGreeting() {
        dialogLabel.text = "안녕하세요! 어떤 옷을 만들어 드릴까요?"
        
        speechBubble.alpha = 0.0
        speechBubble.setScale(0.9)
        
        let fadeIn = SKAction.fadeIn(withDuration: 0.2)
        let scaleUp = SKAction.scale(to: 1.0, duration: 0.2)
        scaleUp.timingMode = .easeOut
        
        speechBubble.run(SKAction.group([fadeIn, scaleUp]))
    }
    
    private func showClothingChoices() {
        dressButton = createChoiceButton(
            text: "드레스",
            name: "dressButton",
            position: CGPoint(x: -180, y: frame.minY + 90)
        )
        
       shirtButton = createChoiceButton(
            text: "셔츠",
            name: "shirtButton",
            position: CGPoint(x: 0, y: frame.minY + 90)
        )
        
       pantsButton = createChoiceButton(
            text: "바지",
            name: "pantsButton",
            position: CGPoint(x: 180, y: frame.minY + 90)
        )
    }
    
    private func createChoiceButton(text: String, name: String, position: CGPoint) -> SKShapeNode {
        let button = SKShapeNode(rectOf: CGSize(width: 140, height: 56), cornerRadius: 18)
        button.fillColor = UIColor(red: 0.78, green: 0.52, blue: 0.33, alpha: 1.0)
        button.strokeColor = UIColor.brown
        button.lineWidth = 3
        button.position = position
        button.name = name
        button.zPosition = 50
        
        let label = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        label.text = text
        label.fontSize = 24
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: 0)
        label.name = name
        label.zPosition = 51
        
        button.addChild(label)
        addChild(button)
        
        return button
    }
    
    private func hideClothingChoices() {
        dressButton.isHidden = true
        shirtButton.isHidden = true
        pantsButton.isHidden = true
    }
    
    private func handleChoice(named nodeName: String) {
    
        let clothingType: ClothingType
        let deposit: Int

        switch nodeName {
        case "dressButton":
            clothingType = .dress
            deposit = 50
        case "shirtButton":
            clothingType = .shirt
            deposit = 30
        case "pantsButton":
            clothingType = .pants
            deposit = 40
        default:
            return
        }

        pendingClothingType = clothingType
        pendingDeposit = deposit
        currentState = .choosingFabricColor
        hideClothingChoices()
        dialogLabel.text = "어떤 색 원단으로 만들까요?"
        showFabricColorChoices()
    
    }
    
    private func showFabricColorChoices() {
        pinkColorButton = createChoiceButton(
            text: "분홍",
            name: "pinkColorButton",
            position: CGPoint(x: -180, y: frame.minY + 90)
        )
        blueColorButton = createChoiceButton(
            text: "파랑",
            name: "blueColorButton",
            position: CGPoint(x: 0, y: frame.minY + 90)
        )
        yellowColorButton = createChoiceButton(
            text: "노랑",
            name: "yellowColorButton",
            position: CGPoint(x: 180, y: frame.minY + 90)
        )
        // Nav-icon style — matches the left-edge nav strip and DressingRoom back button
        let backBtn = SKShapeNode(rectOf: CGSize(width: 54, height: 54), cornerRadius: 14)
        backBtn.fillColor = UIColor(red: 0.78, green: 0.52, blue: 0.33, alpha: 0.88)
        backBtn.strokeColor = UIColor(red: 0.55, green: 0.35, blue: 0.10, alpha: 0.6)
        backBtn.lineWidth = 2
        backBtn.position = CGPoint(x: frame.maxX - 37, y: 0)
        backBtn.zPosition = 50
        backBtn.name = "fabricBackButton"
        let backLabel = SKLabelNode(text: "←")
        backLabel.fontSize = 26
        backLabel.verticalAlignmentMode = .center
        backLabel.horizontalAlignmentMode = .center
        backLabel.name = "fabricBackButton"
        backBtn.addChild(backLabel)
        addChild(backBtn)
        fabricBackButton = backBtn
    }

    private func hideFabricColorChoices() {
        pinkColorButton?.removeFromParent()
        pinkColorButton = nil
        blueColorButton?.removeFromParent()
        blueColorButton = nil
        yellowColorButton?.removeFromParent()
        yellowColorButton = nil
        fabricBackButton?.removeFromParent()
        fabricBackButton = nil
    }

    private func handleFabricColorChoice(named nodeName: String) {
        let fabricColor: FabricColor
        switch nodeName {
        case "pinkColorButton":   fabricColor = .pink
        case "blueColorButton":   fabricColor = .blue
        case "yellowColorButton": fabricColor = .yellow
        default: return
        }

        currentOrder = Order(clothingType: pendingClothingType,
                             depositAmount: pendingDeposit,
                             fabricColor: fabricColor)
        currentState = .reviewingOrder
        hideFabricColorChoices()
        dialogLabel.text = "\(fabricColor.displayName) 원단으로 주문서를 준비할게요."
        showOrderSheet()
    }

    private func showOrderSheet() {
        guard let order = currentOrder else { return }
        
        let panelWidth: CGFloat = 250
        let panelHeight: CGFloat = 180

        let panel = SKShapeNode(rectOf: CGSize(width: panelWidth, height: panelHeight), cornerRadius: 24)
        panel.fillColor = UIColor(red: 0.96, green: 0.91, blue: 0.80, alpha: 0.98)
        panel.strokeColor = UIColor.brown
        panel.lineWidth = 4
        panel.position = CGPoint(x: -120, y: -45)
        panel.zPosition = 80
        panel.name = "orderSheet"

        let titleLabel = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        titleLabel.text = "주문서"
        titleLabel.fontSize = 26
        titleLabel.fontColor = .black
        titleLabel.position = CGPoint(x: 0, y: 60)
        titleLabel.verticalAlignmentMode = .center
        titleLabel.zPosition = 81

        let clothingLabel = SKLabelNode(fontNamed: "AppleSDGothicNeo-Regular")
        clothingLabel.text = "의상: \(order.clothingType.displayName)"
        clothingLabel.fontSize = 20
        clothingLabel.fontColor = .black
        clothingLabel.position = CGPoint(x: 0, y: 20)
        clothingLabel.verticalAlignmentMode = .center
        clothingLabel.zPosition = 81

        let fabricLabel = SKLabelNode(fontNamed: "AppleSDGothicNeo-Regular")
        fabricLabel.text = "원단: \(order.fabricColor.displayName)"
        fabricLabel.fontSize = 20
        fabricLabel.fontColor = .black
        fabricLabel.position = CGPoint(x: 0, y: -15)
        fabricLabel.verticalAlignmentMode = .center
        fabricLabel.zPosition = 81

        let depositLabel = SKLabelNode(fontNamed: "AppleSDGothicNeo-Regular")
        depositLabel.text = "선수금: \(order.depositAmount)냥"
        depositLabel.fontSize = 20
        depositLabel.fontColor = .black
        depositLabel.position = CGPoint(x: 0, y: -50)
        depositLabel.verticalAlignmentMode = .center
        depositLabel.zPosition = 81

        panel.addChild(titleLabel)
        panel.addChild(clothingLabel)
        panel.addChild(fabricLabel)
        panel.addChild(depositLabel)
        
        addChild(panel)
        orderSheet = panel
        
        showReviewButtons()
    }
    
    private func showReviewButtons() {
        confirmButton = createActionButton(
            text: "확인",
            name: "confirmOrderButton",
            position: CGPoint(x: 170, y: 20)
        )
        
        cancelButton = createActionButton(
            text: "취소",
            name: "cancelOrderButton",
            position: CGPoint(x: 170, y: -50)
        )
    }
    
    private func createActionButton(text: String, name: String, position: CGPoint) -> SKShapeNode {
        let button = SKShapeNode(rectOf: CGSize(width: 120, height: 50), cornerRadius: 16)
        button.fillColor = UIColor(red: 0.78, green: 0.52, blue: 0.33, alpha: 1.0)
        button.strokeColor = UIColor.brown
        button.lineWidth = 3
        button.position = position
        button.name = name
        button.zPosition = 85
        
        let label = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        label.text = text
        label.fontSize = 22
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: 0)
        label.name = name
        label.zPosition = 86
        
        button.addChild(label)
        addChild(button)
        
        return button
    }
    
    private func hideOrderSheet() {
        orderSheet?.removeFromParent()
        orderSheet = nil
    }

    private func hideReviewButtons() {
        confirmButton?.removeFromParent()
        confirmButton = nil
        
        cancelButton?.removeFromParent()
        cancelButton = nil
    }
    
    private func showClothingChoicesAgain() {
        dressButton.isHidden = false
        shirtButton.isHidden = false
        pantsButton.isHidden = false
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        
        let location = touch.location(in: self)
        let tappedNodes = nodes(at: location)

        for node in tappedNodes {
            guard let nodeName = node.name else { continue }
            
            // Relaunch dialog intercepts all taps when visible
            switch nodeName {
            case "relaunchContinue", "relaunchRefund", "relaunchCashOut":
                handleRelaunchTap(nodeName: nodeName)
                return
            default:
                break
            }

            switch nodeName {
            case "wardrobeNav":
                if currentState.accepts(.sideNavigation) {
                    SoundManager.shared.play("sfx_button_tap.mp3")
                    Store.saveLastSeenCount(Store.loadGarmentCount())
                    transitionToDressingRoom()
                    return
                }

            case "walletNav":
                if currentState.accepts(.sideNavigation) {
                    SoundManager.shared.play("sfx_button_tap.mp3")
                    transitionToRiddleScene()
                }
                return

            case "settingsNav":
                if currentState.accepts(.appNavigation) {
                    SoundManager.shared.play("sfx_button_tap.mp3")
                    transitionToSettingsScene()
                }
                return

            case "storybookNav":
                if currentState.accepts(.appNavigation) {
                    SoundManager.shared.play("sfx_button_tap.mp3")
                    transitionToStorybookScene()
                }
                return

            case "saveTrophyButton":
                if currentState.accepts(.saveTrophy) && shouldShowFinishedGarment {
                    handleSaveTrophy()
                    return
                }

            case "dressButton", "shirtButton", "pantsButton":
                if currentState.accepts(.clothingChoice) {
                    SoundManager.shared.play("sfx_button_tap.mp3")
                    handleChoice(named: nodeName)
                    return
                }

            case "pinkColorButton", "blueColorButton", "yellowColorButton":
                if currentState.accepts(.fabricChoice) {
                    SoundManager.shared.play("sfx_button_tap.mp3")
                    handleFabricColorChoice(named: nodeName)
                    return
                }

            case "fabricBackButton":
                if currentState.accepts(.fabricBack) {
                    hideFabricColorChoices()
                    currentState = .choosingClothing
                    showClothingChoicesAgain()
                    dialogLabel.text = "어떤 옷을 만들어 드릴까요?"
                    return
                }

            case "confirmOrderButton":
                if currentState.accepts(.orderReview) {
                    SoundManager.shared.play("sfx_button_tap.mp3")
                    handleConfirmOrder()
                    return
                }

            case "cancelOrderButton":
                if currentState.accepts(.orderReview) {
                    SoundManager.shared.play("sfx_button_tap.mp3")
                    handleCancelOrder()
                    return
                }

            case "confirmPayButton":
                if currentState.accepts(.payment) {
                    SoundManager.shared.play("sfx_button_tap.mp3")
                    handlePayment()
                    return
                }

            case "goBackButton":
                if currentState.accepts(.payment) {
                    SoundManager.shared.play("sfx_button_tap.mp3")
                    handleGoBackFromPayment()
                    return
                }
                
            default:
                continue
            }
        }
    }
    
    private func handleConfirmOrder() {
        currentState = .awaitingPayment
        hideOrderSheet()
        hideReviewButtons()
        dialogLabel.text = "좋아요! 선수금을 내주세요."
        SoundManager.shared.play("sfx_order_stamp.mp3")
        showPaymentPanel()
        
    }
    
    private func handleCancelOrder() {
        currentOrder = nil
        currentState = .choosingClothing
        
        hideOrderSheet()
        hideReviewButtons()
        showClothingChoicesAgain()
        
        dialogLabel.text = "괜찮아요. 다시 골라주세요."
    }
        
    private func showPaymentPanel() {
        guard let order = currentOrder else { return }
        
        let panelWidth: CGFloat = 250
        let panelHeight: CGFloat = 150
        
        let panel = SKShapeNode(rectOf: CGSize(width: panelWidth, height: panelHeight), cornerRadius: 24)
        panel.fillColor = UIColor(red: 0.96, green: 0.91, blue: 0.80, alpha: 0.98)
        panel.strokeColor = UIColor.brown
        panel.lineWidth = 4
        panel.position = CGPoint(x: -120, y: -20)
        panel.zPosition = 80
        panel.name = "walletSheet"
        
        let titleLabel = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        titleLabel.text = "내 지갑"
        titleLabel.fontSize = 26
        titleLabel.fontColor = .black
        titleLabel.position = CGPoint(x: 0, y: 40)
        titleLabel.verticalAlignmentMode = .center
        titleLabel.zPosition = 81
        
        let clothingLabel = SKLabelNode(fontNamed: "AppleSDGothicNeo-Regular")
        clothingLabel.text = "보유 냥: \(Wallet.shared.balance)냥"
        clothingLabel.fontSize = 20
        clothingLabel.fontColor = .black
        clothingLabel.position = CGPoint(x: 0, y: 5)
        clothingLabel.verticalAlignmentMode = .center
        clothingLabel.zPosition = 81
        
        let depositLabel = SKLabelNode(fontNamed: "AppleSDGothicNeo-Regular")
        depositLabel.text = "선수금: \(order.depositAmount)냥"
        depositLabel.fontSize = 20
        depositLabel.fontColor = .black
        depositLabel.position = CGPoint(x: 0, y: -28)
        depositLabel.verticalAlignmentMode = .center
        depositLabel.zPosition = 81
        
        panel.addChild(titleLabel)
        panel.addChild(clothingLabel)
        panel.addChild(depositLabel)
        
        addChild(panel)
        paymentPanel = panel
        
        showPayButtons()
        
    }
    
    private func showPayButtons() {
        payButton = createActionButton(
            text: "지불하기",
            name: "confirmPayButton",
            position: CGPoint(x: 170, y: 20)
        )
        
        cancelButton = createActionButton(
            text: "돌아가기",
            name: "goBackButton",
            position: CGPoint(x: 170, y: -50)
        )
    }
    
    private func handlePayment() {
        guard let order = currentOrder else { return }

        if canAffordCurrentOrder() {
            Wallet.shared.balance -= order.depositAmount
            currentState = .sendingOrder
            hidePaymentPanel()
            hidePayButtons()
            SoundManager.shared.play("sfx_coin_pay.mp3")
            sendOrderToBackRoom()
        } else {
            currentState = .choosingClothing
            hidePaymentPanel()
            hidePayButtons()
            currentOrder = nil
            dialogLabel.text = "냥이 부족해요! 💰 눌러서 퀴즈로 버세요!"
            showClothingChoicesAgain()
        }
    }
    
    private func hidePaymentPanel() {
        paymentPanel?.removeFromParent()
        paymentPanel = nil
    }
    
    private func hidePayButtons() {
        payButton?.removeFromParent()
        payButton = nil

        cancelButton?.removeFromParent()
        cancelButton = nil
    }
    
    private func handleGoBackFromPayment() {
        currentState = .reviewingOrder
        hidePaymentPanel()
        hidePayButtons()
        showOrderSheet()
        dialogLabel.text = "주문서를 다시 확인해주세요."
    }
   
    private func canAffordCurrentOrder() -> Bool {
        guard let order = currentOrder else { return false }
        return Wallet.shared.balance >= order.depositAmount
    }

    
    private func sendOrderToBackRoom() {
        currentState = .sendingOrder
        dialogLabel.text = "주문서를 작업실로 보냈어요!"
        
        let popUp = SKAction.scale(to: 1.05, duration: 0.12)
        let popDown = SKAction.scale(to: 1.0, duration: 0.12)
        let wait = SKAction.wait(forDuration: 1.3)
        let goNext = SKAction.run { [weak self] in
            self?.transitionToBackRoom()
        }
        
        speechBubble.run(SKAction.sequence([popUp, popDown]))
        run(SKAction.sequence([wait, goNext]))
    }
    
    private func transitionToBackRoom() {
        guard let view = self.view else { return }
        SoundManager.shared.play("sfx_transition_fade.mp3")

        let backRoomScene = BackRoomScene(size: self.size)
        backRoomScene.scaleMode = self.scaleMode
        backRoomScene.order = currentOrder

        let transition = SKTransition.fade(withDuration: 0.8)
        view.presentScene(backRoomScene, transition: transition)
    }
    
    private func showCompletionGreeting() {
        dialogLabel.text = "여기 있습니다. 맘에드시길 바래요!"

        speechBubble.alpha = 0.0
        speechBubble.setScale(0.9)

        let fadeIn = SKAction.fadeIn(withDuration: 0.2)
        let scaleUp = SKAction.scale(to: 1.0, duration: 0.2)
        scaleUp.timingMode = .easeOut

        speechBubble.run(SKAction.group([fadeIn, scaleUp]))
    }
    
    private func showFinishedGarmentOnFrontMannequin() {
        guard let mannequin = childNode(withName: "//mannequin") as? SKSpriteNode else {
            return
        }

        let texture = SKTexture(imageNamed: finishedGarmentImageName)
        mannequin.texture = texture

        // Remove any old stretching from the original mannequin node
        mannequin.xScale = 1.0
        mannequin.yScale = 1.0

        // Use the PNG's natural size first
        mannequin.size = texture.size()

        // Then scale uniformly to a target height that fits your shop
        let targetHeight: CGFloat = 260
        let scale = targetHeight / texture.size().height
        mannequin.setScale(scale)
    }

    // Restore the shop mannequin to the blank white form after the finished
    // garment has been stored in the wardrobe.
    private func revertFrontMannequin() {
        guard let mannequin = childNode(withName: "//mannequin") as? SKSpriteNode else { return }
        let texture = SKTexture(imageNamed: "Mannequin_White")
        mannequin.texture = texture
        mannequin.xScale = 1.0
        mannequin.yScale = 1.0
        mannequin.size = texture.size()
        mannequin.setScale(0.3)
    }
    
    private func fitBackgroundToScene() {
        guard let background = childNode(withName: "//background") as? SKSpriteNode else {
            return
        }

        background.position = CGPoint(x: frame.midX, y: frame.midY)
        background.size = self.size
    }
    
    private func fixCharacterLayout() {
        guard let shopkeeper = childNode(withName: "//shopkeeper") as? SKSpriteNode else { return }
        guard let mannequin = childNode(withName: "//mannequin") as? SKSpriteNode else { return }

        // Scale them up slightly to match resized background
        shopkeeper.setScale(0.6)   // tweak this
        mannequin.setScale(0.3)    // keep your current mannequin scale

        let layout = Layout.frontShopCharacters(in: size)
        shopkeeper.position = layout.shopkeeper
        mannequin.position = layout.mannequin
    }

    // MARK: - Relaunch dialog (active order recovery)

    private func showRelaunchDialog(for saved: ActiveOrder) {
        relaunchDialogNode?.removeFromParent()

        let refundedBalance = Wallet.shared.balance + saved.depositAmount
        let currentBalance  = Wallet.shared.balance

        let overlay = SKNode()
        overlay.zPosition = 60
        overlay.name = "relaunchDialog"
        addChild(overlay)
        relaunchDialogNode = overlay

        let dim = SKShapeNode(rectOf: size)
        dim.fillColor = UIColor(white: 0, alpha: 0.55)
        dim.strokeColor = .clear
        dim.zPosition = -1
        overlay.addChild(dim)

        let geo = Layout.relaunchDialogFrame(in: size, below: speechBubble.frame.minY, safeBottom: safeBottom)
        let panel = SKShapeNode(rectOf: geo.size, cornerRadius: 24)
        panel.fillColor = UIColor(red: 0.96, green: 0.91, blue: 0.80, alpha: 0.98)
        panel.strokeColor = UIColor.brown
        panel.lineWidth = 4
        panel.position = geo.center
        panel.zPosition = 1
        overlay.addChild(panel)

        // Scale internal positions proportionally to panel height so nothing clips.
        let s = geo.size.height / 320.0

        let title = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        title.text = "이전에 하던 게 있어요!"
        title.fontSize = 22
        title.fontColor = .black
        title.position = CGPoint(x: 0, y: 120 * s)
        title.verticalAlignmentMode = .center
        panel.addChild(title)

        let subtitle = SKLabelNode(fontNamed: "AppleSDGothicNeo-Regular")
        subtitle.text = "\(saved.fabricColor.displayName) \(saved.clothingType.displayName)"
        subtitle.fontSize = 18
        subtitle.fontColor = UIColor(red: 0.4, green: 0.2, blue: 0.0, alpha: 1.0)
        subtitle.position = CGPoint(x: 0, y: 88 * s)
        subtitle.verticalAlignmentMode = .center
        panel.addChild(subtitle)

        // Button A: continue. Continue and Cash Out leave the wallet at the same
        // number — the real difference is that only Continue keeps the garment's
        // trophy earnable. The 🏆 prefix and gold tint make that the visible cue.
        let btnA = makeFrontShopDialogButton(
            text: "🏆 이어서 만들래 → 지갑 \(currentBalance)냥",
            name: "relaunchContinue",
            position: CGPoint(x: 0, y: 35 * s),
            width: 300
        )
        btnA.fillColor = UIColor(red: 0.85, green: 0.62, blue: 0.30, alpha: 1.0)
        panel.addChild(btnA)

        // Button B: refund
        let btnB = makeFrontShopDialogButton(
            text: "보증금 환불 → 지갑 \(refundedBalance)냥",
            name: "relaunchRefund",
            position: CGPoint(x: 0, y: -45 * s),
            width: 300
        )
        panel.addChild(btnB)

        // Button C: cash out. Same wallet number as Continue, but this path
        // forfeits the active order — so the label says so explicitly.
        let btnC = makeFrontShopDialogButton(
            text: "트로피 없이 챙기기 → 지갑 \(currentBalance)냥",
            name: "relaunchCashOut",
            position: CGPoint(x: 0, y: -120 * s),
            width: 300
        )
        panel.addChild(btnC)
    }

    private func makeFrontShopDialogButton(text: String, name: String,
                                           position: CGPoint, width: CGFloat) -> SKShapeNode {
        let button = SKShapeNode(rectOf: CGSize(width: width, height: 50), cornerRadius: 14)
        button.fillColor = UIColor(red: 0.78, green: 0.52, blue: 0.33, alpha: 1.0)
        button.strokeColor = UIColor.brown
        button.lineWidth = 2
        button.position = position
        button.name = name

        let label = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        label.text = text
        label.fontSize = 14
        label.fontColor = .white
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.name = name
        label.zPosition = 1
        button.addChild(label)
        return button
    }

    private func handleRelaunchTap(nodeName: String) {
        guard let saved = Store.loadActiveOrder() else { return }

        switch nodeName {
        case "relaunchContinue":
            relaunchDialogNode?.removeFromParent()
            relaunchDialogNode = nil
            resumeSavedOrder(saved)

        case "relaunchRefund":
            relaunchDialogNode?.removeFromParent()
            relaunchDialogNode = nil
            Wallet.shared.balance += saved.depositAmount
            Store.clearActiveOrder()
            showGreeting()
            showClothingChoices()
            currentState = .choosingClothing

        case "relaunchCashOut":
            relaunchDialogNode?.removeFromParent()
            relaunchDialogNode = nil
            Store.clearActiveOrder()
            showGreeting()
            showClothingChoices()
            currentState = .choosingClothing

        default:
            break
        }
    }

    private func resumeSavedOrder(_ saved: ActiveOrder) {
        guard let view = self.view else { return }
        Store.clearActiveOrder()

        let order = Order(clothingType: saved.clothingType,
                          depositAmount: saved.depositAmount,
                          fabricColor: saved.fabricColor)

        let backRoom = BackRoomScene(size: self.size)
        backRoom.scaleMode = self.scaleMode
        backRoom.order = order
        backRoom.resumeStateName = saved.backRoomStateName

        let transition = SKTransition.fade(withDuration: 0.8)
        view.presentScene(backRoom, transition: transition)
    }

    private func showSaveTrophyButton() {
        let button = SKShapeNode(rectOf: CGSize(width: 200, height: 52), cornerRadius: 18)
        button.fillColor = UIColor(red: 0.55, green: 0.35, blue: 0.10, alpha: 1.0)
        button.strokeColor = UIColor.brown
        button.lineWidth = 3
        button.position = CGPoint(x: 0, y: frame.minY + 90)
        button.zPosition = 50
        button.name = "saveTrophyButton"
        addChild(button)
        saveTrophyButton = button

        let label = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        label.text = "옷장에 보관"
        label.fontSize = 24
        label.fontColor = .white
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.name = "saveTrophyButton"
        label.zPosition = 51
        button.addChild(label)
    }

    private func handleSaveTrophy() {
        // Warm "saved" sound as the garment is stored in the wardrobe.
        SoundManager.shared.play("sfx_trophy_save.mp3")
        if let order = completedOrder {
            var garments = Store.loadGarments()
            garments.append(FinishedGarment(
                clothingType: order.clothingType,
                fabricColor: order.fabricColor,
                completedAt: Date()
            ))
            Store.saveGarments(garments)
            Store.saveGarmentCount(Store.loadGarmentCount() + 1)
        }

        saveTrophyButton?.removeFromParent()
        saveTrophyButton = nil

        revertFrontMannequin()

        shouldShowFinishedGarment = false
        completedOrder = nil

        setNavIconsDimmed(false)   // trophy saved — navigation is safe again
        currentState = .choosingClothing
        showGreeting()
        showClothingChoices()
        dialogLabel.text = "안녕하세요! 어떤 옷을 만들어 드릴까요?"
    }

    private func transitionToSettingsScene() {
        guard let view = self.view else { return }
        let scene = SettingsScene(size: self.size)
        scene.scaleMode = self.scaleMode
        let transition = SKTransition.crossFade(withDuration: 0.4)
        view.presentScene(scene, transition: transition)
    }

    private func transitionToRiddleScene() {
        guard let view = self.view else { return }
        let scene = RiddleScene(size: self.size)
        scene.scaleMode = self.scaleMode
        let transition = SKTransition.crossFade(withDuration: 0.4)
        view.presentScene(scene, transition: transition)
    }

    private func transitionToDressingRoom() {
        guard let view = self.view else { return }
        let scene = DressingRoomScene(size: self.size)
        scene.scaleMode = self.scaleMode
        let transition = SKTransition.crossFade(withDuration: 0.5)
        view.presentScene(scene, transition: transition)
    }

    private func transitionToStorybookScene() {
        guard let view = self.view else { return }
        let scene = StorybookScene(size: self.size)
        scene.scaleMode = self.scaleMode
        let transition = SKTransition.crossFade(withDuration: 0.4)
        view.presentScene(scene, transition: transition)
    }
}
