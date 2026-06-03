//
//  GameViewController.swift
//  DesignerAna
//
//  Created by Kah-ul Kim on 4/20/26.
//

import UIKit
import SpriteKit
import GameplayKit

class GameViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        if let view = self.view as! SKView? {
            if Store.loadSelectedCustomer() != nil {
                // Returning player — straight to front shop.
                if let scene = FrontShopScene(fileNamed: "GameScene") {
                    scene.scaleMode = .resizeFill
                    view.presentScene(scene)
                }
            } else {
                // First launch (or post-새 손님 reset) — customer picker.
                let scene = SettingsScene(size: view.bounds.size)
                scene.scaleMode = .resizeFill
                scene.isFirstLaunchPicker = true
                view.presentScene(scene)
            }

            view.ignoresSiblingOrder = true

            view.showsFPS = true
            view.showsNodeCount = true
        }
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
