import AppKit

/// 长按退出时的提示，默认贴在 Touch Bar 最右边（盖住右侧的按钮，反正只是个临时提示）；被按的图标在右半边时改贴最左边，两边互不遮挡。
/// 显示：“正在关闭 XX”、倒计时和进度条。手指按在图标上会挡住图标下方的进度条，这里给一个不会被挡住的地方。
/// 不接收触摸，不占用 Dock 的位置。
///
/// 文字是白色，一道高光循环扫过（类似系统“滑动来解锁”的文字流光）。背景是一幅像素画的季节小场景，像素游戏里常见的横版画面：
/// 最下面直接是地面，进度条是地面上的一条分段像素条，一个小角色（小狗、帆船、狐狸、雪橇）沿着它往前跑，倒计时走完就到了；
/// 背景是缓缓向后滚动的远景，天上飞过小动物，烟囱冒烟，花瓣、落叶、雪在空中飘。贴着 Touch Bar 边缘的一端最完整，往中间渐渐溶解成暗色。
/// 松手取消就淡出，倒计时走完则闪一下再消失。具体配色、场景和角色由 `QuitHintTheme`（春夏秋冬）决定，菜单里可以切换。
/// 长按要做的事，决定提示里的文字。
enum QuitHintAction {
    case quit, forceQuit, closeWindow, hide
}

final class QuitHintView: NSView {
    static let width: CGFloat = 440
    static let height: CGFloat = 30

    private static let side: CGFloat = 16
    private static let countdownWidth: CGFloat = 44
    private static let barWidth: CGFloat = 230
    /// 进度条坐在地面上（地面 3pt 厚）。
    private static let barY: CGFloat = 3
    private static let barHeight: CGFloat = 3
    private static let titleMaxWidth: CGFloat = 260
    /// 文字放大加粗，再配一层淡淡的投影，压在场景上也看得清。
    private static let textSize: CGFloat = 14
    private static let textHeight: CGFloat = 18
    private static let textY: CGFloat = 12
    /// 远景向后滚动的速度（pt/秒）。
    private static let farSpeed: CGFloat = 24
    /// 飞过背景的小动物从哪里飞到哪里（离边缘的距离）。
    private static let wandererRange: ClosedRange<CGFloat> = 24...260

    var theme = QuitHintTheme.spring {
        didSet {
            guard theme != oldValue else { return }
            stopAnimations()
            applyTheme()
            needsLayout = true
        }
    }
    private var look = QuitHintTheme.spring.look
    private var actors = QuitHintTheme.spring.actors
    private var flow: QuitHintFlow?

    // 背景：backdrop（贴左边时镜像）→ panel（入场时滑动）→ 暗色底 / 辉光 / 远景 / 地面和主角 / 海浪 / 烟 / 闪光。都是按“贴右边”画的。
    private let backdrop = CALayer()
    private let panel = CALayer()
    private let scrim = CAGradientLayer()
    private let glow = CAGradientLayer()
    private let farHost = CALayer()
    private let far = CALayer()
    private let scene = CALayer()
    private let flowHost = CALayer()
    private let flowRows = CAReplicatorLayer()
    private let flowTile = CALayer()
    private let smoke = CAEmitterLayer()
    private var fixedLayers: [CALayer] = []
    private let flash = CALayer()

    /// 角色身后扬起来的粒子，跟着角色走。
    private let trail = CAEmitterLayer()
    /// 飘在背景里的粒子（花瓣、落叶、雪）。
    private let rain = CAEmitterLayer()
    /// 贴着地面一闪一闪的光点。
    private let glints = CAEmitterLayer()
    /// 倒计时走完时的“收尾风暴”：放在最上面，一阵密集的漂浮物盖过整个画面，然后渐渐稀疏。
    private let finale = CAEmitterLayer()
    /// 收尾时场景先淡掉（content），文字稍晚一点淡掉（labels），只剩最上面的风暴。
    private let content = CALayer()
    private let labels = CALayer()
    private let wanderer = CALayer()
    private let runner = CALayer()

    private let titleLayer = CATextLayer()
    private let shimmerMask = CAGradientLayer()
    private let countdownLayer = CATextLayer()
    private let track = CALayer()
    private let bar = CALayer()
    private var timer: Timer?
    private var deadline = Date()
    private var appName = ""
    private var onLeft = false
    /// 长按要做什么（决定文字）；在 `show` 之前设置。
    var action = QuitHintAction.quit
    /// 只显示一句话的“说明”模式：没有进度条和倒计时（做不了的事、做完但没成功的事）。
    private var notice: String?
    /// 倒计时走完、正在等结果（App 有没有真的退出）。这期间手指抬起等触发的普通淡出不打断。
    private var isHolding = false
    /// 正在放收尾动画（约 1.8 秒）。这期间手指抬起等触发的普通淡出不打断它，下一次 show 才会重置。
    private var isFinishing = false
    /// 每次 show 加一；淡出结束后的清理只在这期间没有再次 show 时才做，免得清掉新一轮的动画。
    private var generation = 0

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        alphaValue = 0
        layer?.masksToBounds = true

        // 暗色底：靠边缘几乎不透明，往里越来越透明。
        scrim.locations = [0, 0.15, 0.38, 0.55, 1]
        scrim.startPoint = CGPoint(x: 0, y: 0.5)
        scrim.endPoint = CGPoint(x: 1, y: 0.5)
        glow.locations = [0.3, 0.7, 1]
        glow.startPoint = CGPoint(x: 0, y: 0.5)
        glow.endPoint = CGPoint(x: 1, y: 0.5)
        glow.opacity = 0.4
        flash.opacity = 0

        // 远景和海浪都是会滚动的，靠一张固定的溶解遮罩只露出靠边缘的一端。
        for (host, moving) in [(farHost, far), (flowHost, flowRows)] as [(CALayer, CALayer)] {
            let mask = CALayer()
            mask.contents = QuitHintTheme.makeFadeMask()
            mask.magnificationFilter = .nearest
            mask.contentsGravity = .resize
            host.mask = mask
            host.addSublayer(moving)
        }
        for pixelLayer in [far, scene, flowTile, runner, wanderer, bar] {
            pixelLayer.magnificationFilter = .nearest
            pixelLayer.minificationFilter = .nearest
            pixelLayer.contentsGravity = .resize
        }
        flowRows.addSublayer(flowTile)
        scene.contentsGravity = .resize
        bar.contentsGravity = .left
        bar.masksToBounds = true
        bar.anchorPoint = CGPoint(x: 0, y: 0.5)
        runner.anchorPoint = CGPoint(x: 0.5, y: 0)

        trail.emitterShape = .point
        trail.renderMode = .additive
        rain.emitterShape = .rectangle
        glints.emitterShape = .rectangle
        finale.emitterShape = .rectangle
        finale.birthRate = 0
        smoke.emitterShape = .point
        for emitter in [trail, rain, glints, smoke] { emitter.birthRate = 0 }

        for l in [scrim, glow, farHost, scene, flowHost, smoke, flash] as [CALayer] { panel.addSublayer(l) }
        backdrop.addSublayer(panel)

        titleLayer.font = NSFont.systemFont(ofSize: Self.textSize, weight: .bold)
        titleLayer.fontSize = Self.textSize
        titleLayer.foregroundColor = NSColor.white.cgColor
        titleLayer.alignmentMode = .right
        titleLayer.truncationMode = .end
        // 高光遮罩：中间最亮、两边稍暗的一条宽带，平移过文字就是流光。两边只暗一点点，平时也读得清。
        shimmerMask.colors = [NSColor(white: 1, alpha: 0.8).cgColor, NSColor(white: 1, alpha: 0.8).cgColor,
                              NSColor(white: 1, alpha: 1).cgColor,
                              NSColor(white: 1, alpha: 0.8).cgColor, NSColor(white: 1, alpha: 0.8).cgColor]
        shimmerMask.locations = [0, 0.38, 0.5, 0.62, 1]
        shimmerMask.startPoint = CGPoint(x: 0, y: 0.5)
        shimmerMask.endPoint = CGPoint(x: 1, y: 0.5)
        titleLayer.mask = shimmerMask

        countdownLayer.font = NSFont.monospacedDigitSystemFont(ofSize: Self.textSize, weight: .bold)
        countdownLayer.fontSize = Self.textSize
        countdownLayer.foregroundColor = NSColor.white.cgColor
        countdownLayer.alignmentMode = .right
        for text in [titleLayer, countdownLayer] {
            text.shadowColor = NSColor.black.cgColor
            text.shadowOpacity = 0.55
            text.shadowRadius = 2
            text.shadowOffset = CGSize(width: 0, height: -1)
        }

        track.backgroundColor = NSColor(red: 0.03, green: 0.04, blue: 0.06, alpha: 0.75).cgColor

        for l in [backdrop, glints, rain, wanderer, track, bar, runner, trail] as [CALayer] {
            l.contentsScale = 2
            content.addSublayer(l)
        }
        for l in [titleLayer, countdownLayer] {
            l.contentsScale = 2
            labels.addSublayer(l)
        }
        finale.contentsScale = 2
        for l in [content, labels, finale] as [CALayer] { layer?.addSublayer(l) }
        for l in [far, scene, flowTile, runner, wanderer, bar] { l.contentsScale = 2 }
        applyTheme()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    /// 把当前季节的颜色、场景、角色、粒子换到各个图层上；位置和大小由 `layout()` 管。
    private func applyTheme() {
        look = theme.look
        actors = theme.actors
        flow = theme.makeFlow()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let dark = look.scrim
        scrim.colors = [0, 0.45, 0.9, 0.97, 0.98].map { dark.withAlphaComponent($0).cgColor }
        glow.colors = [0, 0.1, 0.32].map { look.glow.withAlphaComponent($0).cgColor }
        flash.backgroundColor = look.flash.cgColor

        scene.contents = theme.makeScene()
        far.contents = theme.makeFar()
        flowTile.contents = flow?.image
        flowHost.isHidden = flow == nil
        bar.contents = theme.makeBarPattern(width: Int(Self.barWidth))
        runner.contents = actors.runner.frames.first
        wanderer.contents = actors.wanderer.frames.first

        fixedLayers.forEach { $0.removeFromSuperlayer() }
        fixedLayers = actors.fixed.map { fixed in
            let l = CALayer()
            l.contents = fixed.sprite.frames.first
            l.magnificationFilter = .nearest
            l.contentsScale = 2
            l.bounds = CGRect(origin: .zero, size: fixed.sprite.size)
            panel.insertSublayer(l, below: flash)
            return l
        }

        trail.emitterCells = theme.trailCells()
        rain.emitterCells = theme.ambientCells()
        glints.emitterCells = theme.glintCells()
        smoke.emitterCells = theme.smokeCells()
        CATransaction.commit()
    }

    /// 靠右时：[标题 倒计时]|边；靠左时镜像：边|[倒计时 标题]，文字左对齐。
    private var titleFrame: CGRect {
        if onLeft {
            let left = Self.side + Self.countdownWidth + 6
            return CGRect(x: left, y: Self.textY, width: min(bounds.width - left - 30, Self.titleMaxWidth), height: Self.textHeight)
        }
        let right = bounds.width - Self.side - Self.countdownWidth - 6
        let width = min(right - 30, Self.titleMaxWidth)
        return CGRect(x: right - width, y: Self.textY, width: width, height: Self.textHeight)
    }

    private var barFrame: CGRect {
        CGRect(x: onLeft ? Self.side : bounds.width - Self.side - Self.barWidth, y: Self.barY, width: Self.barWidth, height: Self.barHeight)
    }

    /// 角色的脚踩在进度条的上沿。
    private var runnerFeet: CGFloat { barFrame.maxY }

    /// 距离边缘 `distance` 处，在真实坐标里的 x。
    private func x(atDistance distance: CGFloat) -> CGFloat {
        onLeft ? distance : bounds.width - distance
    }

    /// 飞过背景的小动物的路线：在真实坐标里从左飞到右。
    private var wandererPath: (from: CGFloat, to: CGFloat) {
        let a = x(atDistance: Self.wandererRange.upperBound), b = x(atDistance: Self.wandererRange.lowerBound)
        return (min(a, b), max(a, b))
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let b = bounds
        let period = QuitHintTheme.farPeriod

        // 背景按“贴右边”画好，贴左边时整体镜像。
        content.frame = b
        labels.frame = b
        backdrop.frame = b
        backdrop.transform = onLeft ? CATransform3DMakeScale(-1, 1, 1) : CATransform3DIdentity
        panel.frame = CGRect(origin: .zero, size: b.size)
        for l in [scrim, glow, scene, flash, farHost, flowHost] as [CALayer] { l.frame = panel.bounds }
        farHost.mask?.frame = panel.bounds
        flowHost.mask?.frame = panel.bounds
        // 远景比面板多一个周期，滚动一个周期正好接上；滚动方向反过来时，多出来的那一段在另一边。
        far.frame = CGRect(x: onLeft ? -period : 0, y: 0, width: b.width + period, height: b.height)

        if let flow {
            flowRows.frame = CGRect(x: -flow.period, y: flow.y, width: b.width + flow.period * 2, height: flow.height)
            flowRows.instanceCount = Int(ceil(flowRows.bounds.width / flow.period))
            flowRows.instanceTransform = CATransform3DMakeTranslation(flow.period, 0, 0)
            flowTile.frame = CGRect(x: 0, y: 0, width: flow.period, height: flow.height)
        }
        smoke.frame = panel.bounds
        if let chimney = actors.chimney {
            smoke.emitterPosition = CGPoint(x: b.width - chimney.x, y: chimney.y)
        }
        for (layer, fixed) in zip(fixedLayers, actors.fixed) {
            layer.frame = CGRect(x: b.width - fixed.distance - fixed.sprite.size.width, y: fixed.y,
                                 width: fixed.sprite.size.width, height: fixed.sprite.size.height)
        }

        rain.frame = b
        let rainSpan = b.width * 0.6
        rain.emitterPosition = CGPoint(x: x(atDistance: rainSpan / 2), y: 20)
        rain.emitterSize = CGSize(width: rainSpan, height: 16)
        glints.frame = b
        finale.frame = b
        let finaleSpan = b.width * 0.85
        finale.emitterPosition = CGPoint(x: x(atDistance: finaleSpan / 2), y: b.height / 2)
        finale.emitterSize = CGSize(width: finaleSpan, height: b.height)
        glints.emitterPosition = CGPoint(x: x(atDistance: Self.side + b.width * 0.2), y: 2)
        glints.emitterSize = CGSize(width: b.width * 0.4, height: 2)

        titleLayer.frame = titleFrame
        titleLayer.alignmentMode = onLeft ? .left : .right
        countdownLayer.alignmentMode = onLeft ? .left : .right
        let w = titleFrame.width
        // 遮罩上下多留一截，免得把文字的投影裁掉。
        shimmerMask.frame = CGRect(x: -w, y: -4, width: w * 3, height: titleFrame.height + 8)
        countdownLayer.frame = CGRect(x: onLeft ? Self.side : bounds.width - Self.side - Self.countdownWidth, y: Self.textY,
                                      width: Self.countdownWidth, height: Self.textHeight)

        track.frame = barFrame
        bar.bounds = CGRect(x: 0, y: 0, width: Self.barWidth, height: Self.barHeight)
        bar.position = CGPoint(x: barFrame.minX, y: barFrame.midY)
        runner.bounds = CGRect(origin: .zero, size: actors.runner.size)
        runner.position = CGPoint(x: barFrame.minX, y: runnerFeet)
        wanderer.bounds = CGRect(origin: .zero, size: actors.wanderer.size)
        wanderer.position = CGPoint(x: wandererPath.from, y: actors.wandererY)
        trail.frame = b
        trail.emitterPosition = trailPosition(at: barFrame.minX)
        CATransaction.commit()
    }

    /// 尘土、浪花从角色的屁股后面扬起。
    private func trailPosition(at headX: CGFloat) -> CGPoint {
        CGPoint(x: headX - actors.runner.size.width * 0.4, y: runnerFeet + 1)
    }

    private func frameAnimation(_ frames: [CGImage], duration: TimeInterval) -> CAKeyframeAnimation {
        let a = CAKeyframeAnimation(keyPath: "contents")
        a.values = frames
        a.calculationMode = .discrete
        a.duration = duration * Double(frames.count)
        a.repeatCount = .infinity
        return a
    }

    func show(appName: String, duration: TimeInterval, onLeft: Bool) {
        generation += 1
        // 上一次的收尾动画可能还没放完：立刻收掉。
        isFinishing = false
        isHolding = false
        notice = nil
        setNoticeMode(false)
        finale.removeAllAnimations()
        finale.birthRate = 0
        resetVanish()
        trail.removeAnimation(forKey: "puff")
        runner.removeAnimation(forKey: "hop")
        self.appName = appName
        self.onLeft = onLeft
        needsLayout = true
        deadline = Date().addingTimeInterval(duration)
        layoutSubtreeIfNeeded()
        updateText()

        // 模型值先设成终点，动画从头跑到终点；动画被移除时画面也停在终点。
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        glow.opacity = 1
        runner.position = CGPoint(x: barFrame.maxX, y: runnerFeet)
        trail.emitterPosition = trailPosition(at: barFrame.maxX)
        for emitter in [trail, rain, glints, smoke] { emitter.birthRate = 1 }
        CATransaction.commit()

        func linear(_ keyPath: String, from: Any, to: Any) -> CABasicAnimation {
            let a = CABasicAnimation(keyPath: keyPath)
            a.fromValue = from
            a.toValue = to
            a.duration = duration
            return a
        }
        bar.add(linear("bounds.size.width", from: 0, to: Self.barWidth), forKey: "fill")
        glow.add(linear("opacity", from: 0.4, to: 1), forKey: "glow")
        runner.add(linear("position.x", from: barFrame.minX, to: barFrame.maxX), forKey: "run")
        trail.add(linear("emitterPosition", from: NSValue(point: trailPosition(at: barFrame.minX)),
                         to: NSValue(point: trailPosition(at: barFrame.maxX))), forKey: "head")
        if actors.runner.frames.count > 1 {
            runner.add(frameAnimation(actors.runner.frames, duration: actors.runnerFrameDuration), forKey: "frames")
        } else {
            // 只有一帧的（帆船、雪橇）靠上下颠簸来动。
            let bob = CABasicAnimation(keyPath: "transform.translation.y")
            bob.fromValue = 0
            bob.toValue = 1
            bob.duration = 0.22
            bob.autoreverses = true
            bob.repeatCount = .infinity
            runner.add(bob, forKey: "bob")
        }

        // 飞过背景的小动物：一边扑翅膀，一边沿着路线往前飞，上下起伏。
        let path = wandererPath
        let cross = CABasicAnimation(keyPath: "position.x")
        cross.fromValue = path.from
        cross.toValue = path.to
        cross.duration = 4.5
        cross.repeatCount = .infinity
        wanderer.add(cross, forKey: "cross")
        let waves = CAKeyframeAnimation(keyPath: "position.y")
        waves.values = [0, 3, 0, -3, 0].map { actors.wandererY + $0 }
        waves.duration = 1.4
        waves.repeatCount = .infinity
        wanderer.add(waves, forKey: "waves")
        wanderer.add(frameAnimation(actors.wanderer.frames, duration: actors.wandererFrameDuration), forKey: "frames")

        // 远景向后滚动（和角色跑的方向相反），海浪一层层涌，太阳的光芒一闪一闪。
        let sign: CGFloat = onLeft ? 1 : -1
        let scroll = CABasicAnimation(keyPath: "transform.translation.x")
        scroll.fromValue = 0
        scroll.toValue = sign * QuitHintTheme.farPeriod
        scroll.duration = Double(QuitHintTheme.farPeriod / Self.farSpeed)
        scroll.repeatCount = .infinity
        far.add(scroll, forKey: "scroll")
        if let flow {
            let surge = CABasicAnimation(keyPath: "transform.translation.x")
            surge.fromValue = 0
            surge.toValue = -flow.period
            surge.duration = flow.duration
            surge.repeatCount = .infinity
            flowRows.add(surge, forKey: "surge")
        }
        for (layer, fixed) in zip(fixedLayers, actors.fixed) {
            layer.add(frameAnimation(fixed.sprite.frames, duration: fixed.frameDuration), forKey: "frames")
        }

        // 面板从边上一格一格“蹦”进来，像像素游戏里的推入，不是平滑滑动。
        let slide = CAKeyframeAnimation(keyPath: "transform.translation.x")
        slide.values = [40, 24, 10, 0]
        slide.calculationMode = .discrete
        slide.duration = 0.2
        panel.add(slide, forKey: "slide")

        let w = titleFrame.width
        let sweep = CABasicAnimation(keyPath: "transform.translation.x")
        sweep.fromValue = -w * 0.8
        sweep.toValue = w * 0.8
        sweep.duration = 1.5
        sweep.repeatCount = .infinity
        sweep.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        shimmerMask.add(sweep, forKey: "sweep")

        NSAnimationContext.runAnimationGroup { $0.duration = 0.18; animator().alphaValue = 1 }
        timer?.invalidate()
        let t = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in self?.updateText() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// `completed` 为 true 表示倒计时走完、App 要退出了：放一段收尾动画（见 `finish()`）；
    /// 否则是中途松手取消，直接淡出。收尾放到一半时再来的普通 `hide()` 会被忽略。
    func hide(completed: Bool = false) {
        guard !isFinishing else { return }
        if isHolding && !completed { return }
        isHolding = false
        timer?.invalidate()
        timer = nil
        guard alphaValue > 0 else {
            for emitter in [trail, rain, glints, smoke] { emitter.birthRate = 0 }
            return
        }
        if completed {
            finish()
            return
        }
        for emitter in [trail, rain, glints, smoke] { emitter.birthRate = 0 }
        let token = generation
        NSAnimationContext.runAnimationGroup({ $0.duration = 0.18; animator().alphaValue = 0 }) { [weak self] in
            guard let self, self.generation == token else { return }
            self.stopAnimations()
        }
    }

    /// 收尾（趣味优先），像一场转场：小角色停下脚步、原地蹦一下，落地扬起一小团尘土；
    /// 一阵季节风暴（花瓣、落叶、雪、泡泡）涌到最前面，场景先淡掉，文字（已变成“已关闭 ✓”）稍晚一点淡掉，
    /// 最后只剩漂浮物自己，越来越少，直到没有。
    private func finish() {
        isFinishing = true
        let token = generation

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        titleLayer.string = doneTitle
        countdownLayer.string = "✓"
        CATransaction.commit()

        // 停下脚步，蹦一下。
        runner.removeAnimation(forKey: "frames")
        runner.removeAnimation(forKey: "bob")
        let hop = CAKeyframeAnimation(keyPath: "transform.translation.y")
        hop.values = [0, 7, 0, 3, 0]
        hop.keyTimes = [0, 0.3, 0.55, 0.78, 1]
        hop.duration = 0.5
        runner.add(hop, forKey: "hop")

        // 落地那一下扬起一小团尘土（浪花、雪）。
        let puff = CAKeyframeAnimation(keyPath: "birthRate")
        puff.values = [0, 0, 6, 0]
        puff.keyTimes = [0, 0.5, 0.55, 0.85]
        puff.duration = 0.6
        trail.birthRate = 0
        trail.add(puff, forKey: "puff")

        // 风暴在最上面：先猛地密起来，撑一会儿，再一点点稀疏下去，直到没有。
        finale.emitterCells = theme.finaleCells(gust: onLeft ? 0 : .pi)
        finale.birthRate = 0
        let storm = CAKeyframeAnimation(keyPath: "birthRate")
        storm.values = [0, 1, 1, 0.7, 0.35, 0.1, 0]
        storm.keyTimes = [0, 0.08, 0.3, 0.5, 0.7, 0.88, 1]
        storm.duration = 1.8
        finale.add(storm, forKey: "storm")

        // 场景先淡掉，文字晚一点。
        vanish(content, after: 0.25, duration: 0.9)
        vanish(labels, after: 0.75, duration: 0.8)

        // 风暴散尽（最后一批粒子的寿命约 1.3 秒）就收工。
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.1) { [weak self] in
            guard let self, self.generation == token else { return }
            self.alphaValue = 0
            self.stopAnimations()
        }
    }

    /// 让一层慢慢淡到全透明（先等 `delay` 秒）。
    private func vanish(_ layer: CALayer, after delay: CFTimeInterval, duration: CFTimeInterval) {
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.duration = duration
        fade.beginTime = layer.convertTime(CACurrentMediaTime(), from: nil) + delay
        fade.fillMode = .both
        fade.timingFunction = CAMediaTimingFunction(name: .easeIn)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.opacity = 0
        CATransaction.commit()
        layer.add(fade, forKey: "vanish")
    }

    private func resetVanish() {
        for l in [content, labels] { l.removeAnimation(forKey: "vanish") }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        content.opacity = 1
        labels.opacity = 1
        CATransaction.commit()
    }

    private var isOptionDown: Bool {
        NSEvent.modifierFlags.contains(.option)
    }

    /// 倒计时进行中：告诉用户现在该做什么（按住不放）、松手会发生什么。
    private var workingTitle: String {
        switch action {
        case .quit:
            if isOptionDown {
                return L10n.tr("按住不放，强制退出 \(appName)", "Hold to force quit \(appName)")
            }
            return L10n.tr("按住不放，关闭 \(appName)", "Hold to close \(appName)")
        case .forceQuit:
            return L10n.tr("按住不放，强制退出 \(appName)", "Hold to force quit \(appName)")
        case .closeWindow: return L10n.tr("按住不放，关闭 \(appName) 的窗口", "Hold to close \(appName)'s window")
        case .hide: return L10n.tr("按住不放，隐藏 \(appName)", "Hold to hide \(appName)")
        }
    }

    /// 倒计时走完、动作已经发出、等结果这段时间：不用再按着了，告诉用户可以松手，事情正在办。
    private var releasingTitle: String {
        switch action {
        case .quit:
            if isOptionDown {
                return L10n.tr("请松手，正在强制退出 \(appName)", "Let go — force quitting \(appName)")
            }
            return L10n.tr("请松手，正在关闭 \(appName)", "Let go — closing \(appName)")
        case .forceQuit:
            return L10n.tr("请松手，正在强制退出 \(appName)", "Let go — force quitting \(appName)")
        case .closeWindow: return L10n.tr("请松手，正在关闭 \(appName) 的窗口", "Let go — closing \(appName)'s window")
        case .hide: return L10n.tr("请松手，正在隐藏 \(appName)", "Let go — hiding \(appName)")
        }
    }

    /// 结果出来了，确实办成了。
    private var doneTitle: String {
        switch action {
        case .quit:
            if isOptionDown {
                return L10n.tr("已强制退出 \(appName)", "Force quit \(appName)")
            }
            return L10n.tr("已关闭 \(appName)", "Closed \(appName)")
        case .forceQuit:
            return L10n.tr("已强制退出 \(appName)", "Force quit \(appName)")
        case .closeWindow: return L10n.tr("已关闭 \(appName) 的窗口", "Closed \(appName)'s window")
        case .hide: return L10n.tr("已隐藏 \(appName)", "Hidden \(appName)")
        }
    }

    /// 倒计时走完了，动作已经发出，等结果：先别让提示消失。之后必须调用 `hide(completed:)` 或 `showResultNotice`。
    /// 文字立刻换成“请松手”，不用等下一次 0.1 秒的定时刷新。
    func holdForResult() {
        isHolding = true
        updateText()
    }

    /// 只显示一句话（没有进度条、倒计时和小角色），几秒后淡出。
    /// 用于做不了的事（一开始就说明），以及做完但没成功的事（比如 App 在等你确认）。
    func showNotice(_ message: String, appName: String, onLeft: Bool) {
        if alphaValue == 0 || timer == nil {
            show(appName: appName, duration: 3600, onLeft: onLeft)
        }
        showResultNotice(message)
    }

    /// 把正在显示的提示换成一句话，几秒后淡出。
    func showResultNotice(_ message: String) {
        isHolding = false
        notice = message
        setNoticeMode(true)
        updateText()
        for emitter in [trail, rain, glints, smoke] { emitter.birthRate = 0 }
        let token = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) { [weak self] in
            guard let self, self.generation == token, self.notice != nil else { return }
            self.hide()
        }
    }

    /// 说明模式下藏起进度条、轨道、小角色和倒计时。
    private func setNoticeMode(_ on: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for l in [bar, track, runner, trail, countdownLayer] as [CALayer] { l.isHidden = on }
        CATransaction.commit()
    }

    private func stopAnimations() {
        let layers: [CALayer] = [bar, glow, runner, trail, wanderer, far, flowRows, panel, flash, shimmerMask, finale] + fixedLayers
        layers.forEach { $0.removeAllAnimations() }
        for emitter in [finale, trail] { emitter.birthRate = 0 }
        resetVanish()
        isFinishing = false
        isHolding = false
        notice = nil
        setNoticeMode(false)
    }

    /// 给 tools/render-preview 出图用：不跑动画，把画面定格在倒计时走到 `progress`（0…1）的样子。
    func freeze(progress: CGFloat, appName: String, onLeft: Bool) {
        self.appName = appName
        self.onLeft = onLeft
        needsLayout = true
        layoutSubtreeIfNeeded()
        stopAnimations()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        glow.opacity = Float(0.4 + 0.6 * progress)
        bar.bounds = CGRect(x: 0, y: 0, width: Self.barWidth * progress, height: Self.barHeight)
        runner.position = CGPoint(x: barFrame.minX + Self.barWidth * progress, y: runnerFeet)
        let path = wandererPath
        wanderer.position = CGPoint(x: path.from + (path.to - path.from) * 0.55, y: actors.wandererY + 1)
        titleLayer.string = workingTitle
        countdownLayer.string = String(format: "%.1fs", 3 * (1 - progress))
        CATransaction.commit()
        alphaValue = 1
    }

    private func updateText() {
        let left = max(deadline.timeIntervalSinceNow, 0)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if let notice {
            titleLayer.string = notice
            countdownLayer.string = ""
        } else if isHolding {
            // 倒计时已经走完、动作发出去了，不用再倒数；数字留着反而像还要等这么久。
            titleLayer.string = releasingTitle
            countdownLayer.string = ""
        } else {
            titleLayer.string = workingTitle
            countdownLayer.string = String(format: "%.1fs", left)
        }
        CATransaction.commit()
    }
}
