import SpriteKit

class FrontShopScene: SKScene {
    
    private var dialogLabel: SKLabelNode!
    private var speechBubble: SKShapeNode!
    
    private var currentState: FrontShopState = .greeting
    private var currentOrder: Order?
    private var pendingClothingType: String = ""
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
    
    private var playerMoney = 200
    private var paymentPanel: SKShapeNode?
    private var payButton: SKShapeNode?
    
    var shouldShowFinishedDress = false
    var finishedDressImageName: String = "Mannequin_Dress_Pink"
    
    override func didMove(to view: SKView) {
        fitBackgroundToScene()
        setupDialogueUI()
        fixCharacterLayout()

        if shouldShowFinishedDress {
            showFinishedDressOnFrontMannequin()
            showCompletionGreeting()
            currentState = .greeting
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
    
    private func setupDialogueUI() {
        let bubbleWidth = size.width * 0.72
        let bubbleHeight: CGFloat = 95
        
        speechBubble = SKShapeNode(rectOf: CGSize(width: bubbleWidth, height: bubbleHeight), cornerRadius: 28)
        speechBubble.fillColor = UIColor(red: 0.98, green: 0.95, blue: 0.85, alpha: 0.95)
        speechBubble.strokeColor = UIColor.brown
        speechBubble.lineWidth = 4
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
    
        let clothingType: String
        let deposit: Int

        switch nodeName {
        case "dressButton":
            clothingType = "드레스"
            deposit = 50
        case "shirtButton":
            clothingType = "셔츠"
            deposit = 30
        case "pantsButton":
            clothingType = "바지"
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
        fabricBackButton = createChoiceButton(
            text: "← 다시",
            name: "fabricBackButton",
            position: CGPoint(x: 0, y: frame.minY + 155)
        )
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
        let fabricColor: String
        switch nodeName {
        case "pinkColorButton":  fabricColor = "분홍"
        case "blueColorButton":  fabricColor = "파랑"
        case "yellowColorButton": fabricColor = "노랑"
        default: return
        }

        currentOrder = Order(clothingType: pendingClothingType,
                             depositAmount: pendingDeposit,
                             fabricColor: fabricColor)
        currentState = .reviewingOrder
        hideFabricColorChoices()
        dialogLabel.text = "\(fabricColor) 원단으로 주문서를 준비할게요."
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
        clothingLabel.text = "의상: \(order.clothingType)"
        clothingLabel.fontSize = 20
        clothingLabel.fontColor = .black
        clothingLabel.position = CGPoint(x: 0, y: 20)
        clothingLabel.verticalAlignmentMode = .center
        clothingLabel.zPosition = 81

        let fabricLabel = SKLabelNode(fontNamed: "AppleSDGothicNeo-Regular")
        fabricLabel.text = "원단: \(order.fabricColor)"
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
            
            switch nodeName {
            case "dressButton", "shirtButton", "pantsButton":
                if currentState == .choosingClothing {
                    handleChoice(named: nodeName)
                    return
                }

            case "pinkColorButton", "blueColorButton", "yellowColorButton":
                if currentState == .choosingFabricColor {
                    handleFabricColorChoice(named: nodeName)
                    return
                }

            case "fabricBackButton":
                if currentState == .choosingFabricColor {
                    hideFabricColorChoices()
                    currentState = .choosingClothing
                    showClothingChoicesAgain()
                    dialogLabel.text = "어떤 옷을 만들어 드릴까요?"
                    return
                }

            case "confirmOrderButton":
                if currentState == .reviewingOrder {
                    handleConfirmOrder()
                    return
                }
                
            case "cancelOrderButton":
                if currentState == .reviewingOrder {
                    handleCancelOrder()
                    return
                }
                
            case "confirmPayButton":
                if currentState == .awaitingPayment {
                    handlePayment()
                    return
                }

            case "goBackButton":
                if currentState == .awaitingPayment {
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
        clothingLabel.text = "보유 냥: \(playerMoney)냥"
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
            playerMoney -= order.depositAmount
            currentState = .sendingOrder
            hidePaymentPanel()
            hidePayButtons()
            sendOrderToBackRoom()
        } else {
            currentState = .choosingClothing
            hidePaymentPanel()
            hidePayButtons()
            currentOrder = nil
            dialogLabel.text = "냥이 부족해요. 다시 골라주세요."
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
        return playerMoney >= order.depositAmount
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
    
    private func showFinishedDressOnFrontMannequin() {
        guard let mannequin = childNode(withName: "//mannequin") as? SKSpriteNode else {
            print("Could not find mannequin node in FrontShopScene")
            return
        }

        let texture = SKTexture(imageNamed: finishedDressImageName)
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
    
    private func fitBackgroundToScene() {
        guard let background = childNode(withName: "//background") as? SKSpriteNode else {
            print("Could not find background node in FrontShopScene")
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

        shopkeeper.position = CGPoint(x: 0, y: -60)     // adjust Y
        mannequin.position = CGPoint(x: 200, y: -60)    // adjust Y
    }
}
