//
//  Copyright © Saurabh Sharan. All rights reserved.
//

import Cocoa

class AnimationConfig: NSObject {
    // Stage 1 config
    @objc dynamic var flipDuration = 1.35
    @objc dynamic var flipScaleFactor = 0.96

    // Stage 2 config
    @objc dynamic var albumScaleOutDuration = 1.5
    @objc dynamic var albumScaleMinimumScaleFactor: Float = -700 // I think (-700, 700) is actually pretty close to the actual wwdc2006 one...
    @objc dynamic var albumScaleMaximumScaleFactor: Float = 700
    @objc dynamic var mouseRotationMinimumDelta = 5 // the minimum delta for a mouse drag to create a rotation around the y-axis
    @objc dynamic var mouseRotationAnimationDuration = 3.5
    @objc dynamic var verticalScrollVelocity: Float = 75 // velocity unit is pixels/sec
}

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    @IBOutlet var mainWindow: NSWindow!
    @IBOutlet var mainView: MainView!

    @objc dynamic var animationConfig = AnimationConfig()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let albumImages = Bundle.main.paths(forResourcesOfType: "jpg", inDirectory: nil).map { URL(fileURLWithPath: $0) }.map { $0.lastPathComponent }.sorted()
        mainView.albumVendingMachine = AlbumVendingMachine(albumImages: albumImages)

        mainView.animationConfig = animationConfig
        mainView.png = RandomFloatGenerator(seed: arc4random())
        mainView.setupLayerTreeStage1()

        // Kick off the initial flip animation
        mainView.stage1FlipTimer = Timer.scheduledTimer(timeInterval: 0.5, target: mainView!, selector: #selector(mainView.performFlip), userInfo: nil, repeats: false)
    }
}

/// @IBActions
extension AppDelegate {
    @IBAction func startStage2(_ sender: Any) {
        self.mainView.startStage2()
    }

    @IBAction func goFullScreen(_ sender: Any) {
        self.mainWindow.toggleFullScreen(nil)
    }
}
