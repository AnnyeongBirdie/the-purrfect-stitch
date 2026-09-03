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

    // MARK: - Keyboard play (dev/testing convenience — Simulator + hardware
    // keyboard on device). SKNode isn't part of the UIKit responder chain,
    // so key events land here first and get forwarded through BackRoomScene
    // to whichever minigame is active, the same way it already forwards
    // touches to activeMinigame/activeBossMinigame.

    override var canBecomeFirstResponder: Bool { true }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var handled = false
        for press in presses {
            if let keyCode = press.key?.keyCode,
               let scene = (view as? SKView)?.scene as? BackRoomScene {
                handled = scene.handleKeyDown(keyCode) || handled
            }
        }
        if !handled { super.pressesBegan(presses, with: event) }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var handled = false
        for press in presses {
            if let keyCode = press.key?.keyCode,
               let scene = (view as? SKView)?.scene as? BackRoomScene {
                handled = scene.handleKeyUp(keyCode) || handled
            }
        }
        if !handled { super.pressesEnded(presses, with: event) }
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            if let keyCode = press.key?.keyCode,
               let scene = (view as? SKView)?.scene as? BackRoomScene {
                _ = scene.handleKeyUp(keyCode)
            }
        }
        super.pressesCancelled(presses, with: event)
    }
}
