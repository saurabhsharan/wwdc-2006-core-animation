//
//  Copyright © Saurabh Sharan. All rights reserved.
//

import Cocoa

enum AnimationStage {
    case stage1
    case stage2
}

/// Add a property called `album` so we can later get the album just from the layer without having to keep track of it separately.
class AlbumLayer: CALayer {
    public var album: String = ""

    init(album: String) {
        super.init()
        self.album = album
        self.contents = NSImage(named: album)
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class AlbumVendingMachine {
    private var albumImages: [String] = []
    private var currentAlbumIdx = 0

    init(albumImages: [String]) {
        self.albumImages = albumImages
    }

    func getNextAlbum() -> String {
        let result = self.albumImages[currentAlbumIdx]
        currentAlbumIdx += 1
        if currentAlbumIdx >= self.albumImages.count {
            currentAlbumIdx = 0
        }
        return result
    }
}

class MainView: NSView, CAAnimationDelegate {
    // This is always sorted in row-major order *from bottom-up*, i.e. first N elements are last row, last N elements are first row, etc.
    var albumWrapperLayers: [CALayer] = []

    // These need to be manually injected by a parent class
    public var albumVendingMachine: AlbumVendingMachine!
    public var animationConfig: AnimationConfig!
    public var png: RandomFloatGenerator!

    public var stage1FlipTimer: Timer?

    // State machine
    public var currentStage: AnimationStage = .stage1
    private var shouldStartStage2 = false
    private var numInflightMouseRotationAnimations = 0

    // Layout information
    private var numRows: Int = 6
    private var numCols: Int = 6
    private var albumSize: Float = 134.0

    // The "epoch" is used to invalidate async operations that may have been run in the context of an outdated layer tree
    // This should be incremented every time the layer tree is re-created, and every async animation completion block and timer block should check the epoch
    private var epoch = 1

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        self.wantsLayer = true
        self.layer!.backgroundColor = NSColor.black.cgColor
    }

    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()

        // For now, it's easiest to just reset to stage 1 when a resize happens

        // Remove all the existing layers
        for layer in self.albumWrapperLayers {
            layer.removeFromSuperlayer()
        }
        self.albumWrapperLayers = []

        // Cancel all pending timers
        if let stage1FlipTimer = self.stage1FlipTimer {
            stage1FlipTimer.invalidate()
            self.stage1FlipTimer = nil
        }

        // Advance the epoch to invalidate pending animation completion blocks
        self.epoch += 1

        // Re-create all the layers
        self.setupLayerTreeStage1()

        // Re-kick off the flip animations
        self.stage1FlipTimer = Timer.scheduledTimer(timeInterval: 1.25, target: self, selector: #selector(self.performFlip), userInfo: nil, repeats: false)
    }
}

/// Stage 1 animations
extension MainView {
    // Sets up the layer tree for stage 1.
    // Every AlbumLayer is wrapped by a transparent CALayer to faciliate the camera dolly effect during the album flip animation.
    func setupLayerTreeStage1() {
        let viewportWidth = self.layer!.bounds.width
        let viewportHeight = self.layer!.bounds.height

        // The animation in the keynote leaves some horizontal space on both sides, so set the album size to an even multiple of the viewport height
        // Hardcode 5 rows since that's from the keynote and seems to work well in practice
        let newAlbumSize = Float(Int(viewportHeight / 5.0))

        let newRows = Int(Float(viewportHeight) / newAlbumSize)
        let newCols = Int(Float(viewportWidth) / newAlbumSize)

        self.numRows = newRows
        self.numCols = newCols
        self.albumSize = newAlbumSize

        let horizontalSpace = Float(viewportWidth) - (Float(self.numCols) * self.albumSize)

        for row in 0..<self.numRows {
            for col in 0..<self.numCols {
                let albumLayer = AlbumLayer(album: self.albumVendingMachine.getNextAlbum())
                albumLayer.frame = CGRect(origin: NSMakePoint(0, 0), size: NSMakeSize(CGFloat(self.albumSize), CGFloat(self.albumSize)))
                albumLayer.isDoubleSided = false

                let albumWrapperLayer = CALayer()
                albumWrapperLayer.contents = nil
                albumWrapperLayer.frame = CGRect(
                    origin: NSMakePoint(
                        (CGFloat(self.albumSize) * CGFloat(col)) + CGFloat(horizontalSpace / 2.0),
                        (CGFloat(row) * CGFloat(self.albumSize))),
                    size: NSMakeSize(CGFloat(self.albumSize), CGFloat(self.albumSize)))
                albumWrapperLayer.backgroundColor = NSColor.clear.cgColor
                albumWrapperLayer.isDoubleSided = false

                var perspectiveTransform = CATransform3DIdentity
                perspectiveTransform.m34 = -1.0 / 2000.0
                albumWrapperLayer.sublayerTransform = perspectiveTransform

                albumWrapperLayer.addSublayer(albumLayer)
                self.layer?.addSublayer(albumWrapperLayer)
                self.albumWrapperLayers.append(albumWrapperLayer)
            }
        }
    }

    /// Pick a random album and flip it to a new album.
    @objc func performFlip() {
        // https://web.archive.org/web/20150701005402/https://blog.radi.ws/post/11484924164/flipping-with-proper-perspective-distortion-in with some modifications
        let frontAnimation = CAKeyframeAnimation()
        frontAnimation.keyPath = "transform"
        frontAnimation.timingFunction = CAMediaTimingFunction(name: .easeIn)
        frontAnimation.isRemovedOnCompletion = false
        frontAnimation.fillMode = .forwards
        frontAnimation.duration = animationConfig.flipDuration
        frontAnimation.values = [
            CATransform3DRotate(CATransform3DIdentity, 0, 0, 1, 0),
            CATransform3DRotate(CATransform3DIdentity, .pi * -0.5, 0, 1, 0),
            CATransform3DRotate(CATransform3DIdentity, .pi * -1.0, 0, 1, 0),
        ]
        let backAnimation = CAKeyframeAnimation()
        backAnimation.keyPath = "transform"
        backAnimation.timingFunction = CAMediaTimingFunction(name: .easeIn)
        backAnimation.isRemovedOnCompletion = false
        backAnimation.fillMode = .forwards
        backAnimation.duration = animationConfig.flipDuration
        backAnimation.values = [
            CATransform3DRotate(CATransform3DIdentity, .pi, 0, 1, 0),
            CATransform3DRotate(CATransform3DIdentity, .pi * 0.5, 0, 1, 0),
            CATransform3DRotate(CATransform3DIdentity, .pi * 2.0, 0, 1, 0),
        ]

        let containerViewScaleAnimation = CAKeyframeAnimation()
        containerViewScaleAnimation.keyPath = "transform"
        containerViewScaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        containerViewScaleAnimation.isRemovedOnCompletion = true
        containerViewScaleAnimation.fillMode = .forwards
        containerViewScaleAnimation.duration = animationConfig.flipDuration
        containerViewScaleAnimation.values = [
            CATransform3DIdentity,
            CATransform3DMakeScale(animationConfig.flipScaleFactor, animationConfig.flipScaleFactor, animationConfig.flipScaleFactor),
            CATransform3DIdentity
        ]

        // Randomly select a wrapper layer to flip
        let albumWrapperLayer = self.albumWrapperLayers.randomElement()!

        let frontAlbumLayer = (albumWrapperLayer.sublayers![0] as! AlbumLayer)

        // Create the new album layer
        let backAlbumLayer = AlbumLayer(album: albumVendingMachine.getNextAlbum())
        backAlbumLayer.frame = frontAlbumLayer.frame
        backAlbumLayer.isDoubleSided = false
        backAlbumLayer.transform = CATransform3DRotate(CATransform3DIdentity, .pi, 0, 1, 0)

        albumWrapperLayer.addSublayer(backAlbumLayer)

        let currentEpoch = self.epoch

        CATransaction.begin()

        CATransaction.setCompletionBlock { [weak self] in
            guard let self = self else { return }

            guard self.epoch == currentEpoch else { return }

            frontAlbumLayer.removeFromSuperlayer()

            if self.shouldStartStage2 {
                self._actuallyStartStage2()
            } else {
                self.stage1FlipTimer = Timer.scheduledTimer(timeInterval: 1.25, target: self, selector: #selector(self.performFlip), userInfo: nil, repeats: false)
            }
        }

        albumWrapperLayer.add(containerViewScaleAnimation, forKey: nil)
        frontAlbumLayer.add(frontAnimation, forKey: nil)
        backAlbumLayer.add(backAnimation, forKey: nil)

        CATransaction.commit()
    }
}

// Stage 2 animations
extension MainView {
    func startStage2() {
        assert(self.currentStage == .stage1, "can only start stage 2 from stage 1")
        // Mark a flag so that in the next animation completion handler we move to stage 2
        self.shouldStartStage2 = true
        self.currentStage = .stage2 // TODO: would probably be better to have a discrete .inBetweenStage1And2 enum
    }

    func _actuallyStartStage2() {
        var newAlbumWrapperLayers: [CALayer] = []

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        CATransaction.setCompletionBlock { [weak self] in
            guard let self = self else { return }

            self.scaleOutAlbums()
        }

        // Recreate the layer hierarchy but without the album wrapper layers
        for albumWrapperLayer in albumWrapperLayers {
            assert(albumWrapperLayer.sublayers!.count == 1, "album wrapper layer has more than 1 sublayer")

            let currentAlbumLayer = albumWrapperLayer.sublayers!.first! as! AlbumLayer
            let newAlbumLayer = AlbumLayer(album: currentAlbumLayer.album)
            newAlbumLayer.frame = albumWrapperLayer.frame

            self.layer!.addSublayer(newAlbumLayer)
            newAlbumWrapperLayers.append(newAlbumLayer)

            currentAlbumLayer.removeFromSuperlayer()
            albumWrapperLayer.removeFromSuperlayer()
        }

        CATransaction.commit()

        self.albumWrapperLayers = newAlbumWrapperLayers

        // This is necessary so that changing the z translation in stage 2 scale will actually work
        var perspectiveTransform = CATransform3DIdentity
        perspectiveTransform.m34 = -1.0 / 2000.0
        self.layer!.sublayerTransform = perspectiveTransform

        // Note: once we change the anchorPoint to (0.5, 0.5), then CA will layout such that the `anchorPoint` coordinates within the layer will be placed at the `position` coordinates of the superlayer, this is why we need to update the `position` of the layer when changing its `anchorPoint`
        // Changing the `anchorPoint` to (0.5, 0.5) will have the vanishing point be at the center of the parent layer (otherwise seems like anchorPoint defaults to (0, 0))
        self.layer!.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        self.layer!.position = CGPoint(x: self.window!.contentView!.frame.width/2.0, y: self.window!.contentView!.frame.height/2.0)
    }

    @objc func scaleOutAlbums() {
        CATransaction.begin()
        // Even though we are using explicit animations, we still need to disable implicit animations since we update the layer's model value before starting the animation
        CATransaction.setDisableActions(true)

        // Create 2 additional rows at the top
        // (Just having one row doesn't provide enough buffer, so you can sometimes see the new albums on the top row)
        for i in 0...1 {
            for c in 0..<self.numCols {
                let albumLayer = AlbumLayer(album: self.albumVendingMachine.getNextAlbum())
                albumLayer.frame = CGRect(origin: NSMakePoint(Double(self.albumSize) * Double(c), Double(self.numRows + i) * Double(self.albumSize)), size: NSMakeSize(CGFloat(self.albumSize), CGFloat(self.albumSize)))
                albumLayer.isDoubleSided = true
                self.layer!.addSublayer(albumLayer)
                self.albumWrapperLayers.append(albumLayer)
            }
        }

        self.numRows += 2

        assert(self.numRows * self.numCols == self.albumWrapperLayers.count, "expected grid size does not match number of album layers")

        for r in 0..<self.numRows {
            for c in 0..<self.numCols {
                let i = (r * self.numCols) + c

                let finalTransform = CATransform3DTranslate(CATransform3DIdentity, 0, 0, CGFloat(png.randomFloat(min: animationConfig.albumScaleMinimumScaleFactor, max: animationConfig.albumScaleMaximumScaleFactor)))
                self.albumWrapperLayers[i].transform = finalTransform

                let animation = CABasicAnimation()
                animation.keyPath = "transform"
                animation.fillMode = .backwards
                animation.isRemovedOnCompletion = true
                animation.fromValue = CATransform3DIdentity
                animation.toValue = finalTransform
                animation.timingFunction = CAMediaTimingFunction(name: .easeIn)
                animation.setValue("albumScaleOutAnimation", forKey: "animationType")

                // Only stagger the first 4 rows, and all the remaining rows start at the same time
                var beginTimeOffset: Double = 0.0
                if r == 0 {
                    beginTimeOffset = 0.4
                } else if r == 1 {
                    beginTimeOffset = 0.5
                } else if r == 2 {
                    beginTimeOffset = 0.8
                } else if r == 3 {
                    beginTimeOffset = 1.0
                } else {
                    beginTimeOffset = 1.2
                }
                animation.beginTime = CACurrentMediaTime() + beginTimeOffset

                animation.duration = self.animationConfig.albumScaleOutDuration

                self.albumWrapperLayers[i].add(animation, forKey: nil)
            }
        }

        for r in 0..<self.numRows {
            for c in 0..<self.numCols {
                let i = (r * self.numCols) + c
                let layer = self.albumWrapperLayers[i]

                let animation = _verticalScrollAnimationForLayer(layer: layer, velocity: animationConfig.verticalScrollVelocity)

                var beginTimeOffset: Double = 0.0
                if r == 0 {
                    beginTimeOffset = 0.0
                } else if r == 1 {
                    beginTimeOffset = 0.3
                } else {
                    beginTimeOffset = 0.75
                }
                animation.beginTime = CACurrentMediaTime() + beginTimeOffset

                if c == 0 {
                    animation.setValue(true, forKey: "firstInRow")
                }

                layer.add(animation, forKey: nil)
            }
        }

        CATransaction.commit()
    }

    func startVerticalScroll() {
        // Change all the album layers to double-sided (since the entire scene can be rotated)
        for layer in self.albumWrapperLayers {
            layer.isDoubleSided = true
        }

        // Kickoff the initial animations (all subsequent animations will be initiated from the completion block)
        for row in 0..<(self.numRows+2) {
            // For each album in the row, create the animation
            for col in 0..<self.numCols {
                let album = self.albumWrapperLayers[(row*self.numCols)+col]
                let animation = _verticalScrollAnimationForLayer(layer: album, velocity: animationConfig.verticalScrollVelocity)
                if col == 0 {
                    animation.setValue(true, forKey: "firstInRow")
                }
                album.add(animation, forKey: nil)
            }
        }
    }

    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        guard let animationType = (anim.value(forKey: "animationType") as? String) else {
            assertionFailure("animation has no animationType")
            return
        }

        if animationType == "mouseRotationAnimation" {
            self.numInflightMouseRotationAnimations -= 1
        } else if animationType == "verticalScrollAnimation" {
            guard let albumLayer = (anim.value(forKey: "layer") as? AlbumLayer) else {
                assertionFailure("animation object of type verticalScroll has no layer attached to it")
                return
            }

            albumLayer.removeFromSuperlayer()

            if let firstInRow = (anim.value(forKey: "firstInRow") as? Bool) {
                if firstInRow {
                    for c in 0..<self.numCols {
                        let albumLayer = AlbumLayer(album: self.albumVendingMachine.getNextAlbum())
                        albumLayer.frame = CGRect(origin: NSMakePoint(Double(self.albumSize) * Double(c), Double(self.numRows - 1) * Double(self.albumSize)), size: NSMakeSize(CGFloat(self.albumSize), CGFloat(self.albumSize)))
                        albumLayer.isDoubleSided = true
                        albumLayer.transform = CATransform3DTranslate(CATransform3DIdentity, 0, 0, CGFloat(png.randomFloat(min: animationConfig.albumScaleMinimumScaleFactor, max: animationConfig.albumScaleMaximumScaleFactor)))
                        self.layer!.addSublayer(albumLayer)
                        self.albumWrapperLayers.append(albumLayer)

                        let newAnimation = _verticalScrollAnimationForLayer(layer: albumLayer, velocity: animationConfig.verticalScrollVelocity)
                        if c == 0 {
                            newAnimation.setValue(true, forKey: "firstInRow")
                        }
                        albumLayer.add(newAnimation, forKey: nil)
                    }
                }
            }
        }
    }

    func _verticalScrollAnimationForLayer(layer: CALayer, velocity: Float) -> CABasicAnimation {
        let animation = CABasicAnimation()
        animation.delegate = self
        animation.keyPath = "position"
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false // doesn't really matter if we keep the animation since the layer will get removed once the scroll animation is complete

        let destY = -self.albumSize * 2.0
        let rowDistance = Float(layer.frame.origin.y) - destY
        let rowDuration = rowDistance / velocity
        animation.toValue = CGPoint(x: layer.position.x, y: CGFloat(destY))
        animation.duration = Double(rowDuration)

        // Use KVC to attach metadata to the animation object that we later use in the animation completion block
        animation.setValue(layer, forKey: "layer")
        animation.setValue("verticalScrollAnimation", forKey: "animationType")

        return animation
    }

    func resetScale() {
        for i in 0..<self.albumWrapperLayers.count {
            var t = CATransform3DIdentity
            // We don't need to set t.m34 because we already set the m34 on the parent layer sublayerTransforms
            t = CATransform3DTranslate(t, 0, 0, 0)
            self.albumWrapperLayers[i].transform = t
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard self.currentStage == .stage2 && self.numInflightMouseRotationAnimations < 2 else {
            return
        }

        let absDelta = abs(Int(event.deltaX))

        var minimumDelta = 0
        // We want to have a very small delta required to initiate the initial rotation, but then subsequent rotations should require more "drag"
        if self.numInflightMouseRotationAnimations == 0 {
            minimumDelta = 5
        } else if self.numInflightMouseRotationAnimations == 1 {
            minimumDelta = 30
        }
        if absDelta < minimumDelta {
            return
        }

        var direction = 1.0
        if event.deltaX.sign == .minus {
            direction = -1.0
        }

        // Note that to animate `sublayerTransform`, we *must* use an explicit animation
        let animation = CABasicAnimation()
        animation.keyPath = "sublayerTransform.rotation.y"
        // For now, just make sure the angle is a multiple of 360deg so we don't have to worry about snapping back at the end of the animation
        // Lol actually all good, the actual wwdc2006 animation also just goes back to 0 y rotation at the end of the animation
        animation.byValue = deg2rad(Float(direction) * Float(180+180))
        animation.duration = animationConfig.mouseRotationAnimationDuration
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = true
        animation.delegate = self
        animation.setValue("mouseRotationAnimation", forKey: "animationType")
        self.layer!.add(animation, forKey: nil)
        self.numInflightMouseRotationAnimations += 1
    }
}
