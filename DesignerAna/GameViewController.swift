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
            // Always open at the title screen. Routing to the shop or
            // storybook is handled inside TitleScene.
            let title = TitleScene(size: view.bounds.size)
            title.scaleMode = .resizeFill
            view.presentScene(title)

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
