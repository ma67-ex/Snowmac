// Flurry: weather on your desktop. Menu-bar app, click-through overlay per screen.
// Original code, MIT licensed. Not affiliated with any commercial app.
import AppKit
import QuartzCore

enum Effect: String, CaseIterable {
    case none = "Off", snow = "Snow", rain = "Rain", petals = "Petals", fireflies = "Fireflies"
}

/// Draws a soft round sprite so no image files are needed.
func sprite(_ size: CGFloat, color: NSColor, oval: Bool = false) -> CGImage? {
    let w = Int(size), h = Int(oval ? size * 0.6 : size)
    guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    let colors = [color.cgColor, color.withAlphaComponent(0).cgColor] as CFArray
    let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.3, 1])!
    ctx.translateBy(x: CGFloat(w) / 2, y: CGFloat(h) / 2)
    if oval { ctx.scaleBy(x: 1, y: 0.6) }
    ctx.drawRadialGradient(g, startCenter: .zero, startRadius: 0, endCenter: .zero,
                           endRadius: size / 2, options: [])
    return ctx.makeImage()
}

func cell(_ img: CGImage?, rate: Float, life: Float, vy: CGFloat, vx: CGFloat = 0,
          scale: CGFloat, scaleRange: CGFloat, spin: CGFloat = 0, alpha: Float = 1) -> CAEmitterCell {
    let c = CAEmitterCell()
    c.contents = img; c.birthRate = rate; c.lifetime = life
    c.velocity = vy; c.velocityRange = vy * 0.4
    c.emissionLongitude = -.pi / 2           // CA y is up in layer coords of a flipped host; set per layer
    c.emissionRange = .pi / 8
    c.xAcceleration = vx
    c.scale = scale; c.scaleRange = scaleRange
    c.spin = spin; c.spinRange = spin
    c.alphaSpeed = -alpha / life * 0.5
    c.color = NSColor.white.cgColor
    return c
}

func layer(for effect: Effect, size: CGSize) -> CAEmitterLayer? {
    guard effect != .none else { return nil }
    let l = CAEmitterLayer()
    l.frame = CGRect(origin: .zero, size: size)
    l.emitterShape = .line
    l.emitterPosition = CGPoint(x: size.width / 2, y: size.height + 10) // top edge
    l.emitterSize = CGSize(width: size.width, height: 1)
    let down = CGFloat.pi * 3 / 2 * -1 + .pi * 2 // emit toward -y (down) in non-flipped layer
    switch effect {
    case .snow:
        // Ten different crystal shapes, each its own emitter cell, so no two neighbours look alike.
        l.emitterCells = (1...10).map { i in
            let c = cell(flakeSprite(seed: UInt64(i)), rate: 4.5, life: Float(size.height / 36 + 2), vy: 60,
                         scale: 0.085, scaleRange: 0.05, spin: 0.5, alpha: 1)
            c.alphaSpeed = 0                       // stay solid until it lands
            c.emissionLongitude = -.pi / 2; c.xAcceleration = 4
            c.spinRange = 1.2                      // each flake tumbles at its own pace
            c.color = NSColor.white.cgColor
            return c
        }
        // Snowfall thickens slowly instead of starting at full strength.
        let ramp = CABasicAnimation(keyPath: "birthRate"); ramp.fromValue = 0.15; ramp.toValue = 1
        ramp.duration = flurryGrow; ramp.fillMode = .forwards; ramp.isRemovedOnCompletion = false
        l.add(ramp, forKey: "ramp")
    case .rain:
        let c = cell(sprite(10, color: NSColor(calibratedRed: 0.7, green: 0.8, blue: 1, alpha: 0.8), oval: true),
                     rate: 180, life: 3, vy: 700, scale: 0.7, scaleRange: 0.3, alpha: 0.8)
        c.emissionLongitude = -.pi / 2 - 0.1; c.emissionRange = 0.05
        l.emitterCells = [c]
    case .petals:
        let c = cell(sprite(22, color: NSColor(calibratedRed: 1, green: 0.72, blue: 0.82, alpha: 1), oval: true),
                     rate: 10, life: 18, vy: 45, scale: 0.6, scaleRange: 0.3, spin: 1.2)
        c.emissionLongitude = -.pi / 2; c.xAcceleration = 10
        l.emitterCells = [c]
    case .fireflies:
        l.emitterPosition = CGPoint(x: size.width / 2, y: size.height / 2)
        l.emitterShape = .rectangle; l.emitterSize = size
        let c = cell(sprite(18, color: NSColor(calibratedRed: 1, green: 0.95, blue: 0.5, alpha: 1)),
                     rate: 6, life: 9, vy: 14, scale: 0.4, scaleRange: 0.25)
        c.emissionRange = .pi * 2; c.alphaSpeed = 0; c.alphaRange = 0.5
        c.scaleSpeed = -0.03
        l.emitterCells = [c]
    case .none: return nil
    }
    _ = down
    return l
}

final class Overlay: NSPanel {
    let ground: Ground
    var emitter: CALayer?
    let scene = CALayer()    // everything that hides behind windows (masked)
    let fly = CALayer()      // snow shaken off a dragged window: always in front, falls all the way down
    var flakes: FlakeField?
    var rain: RainField?
    var truck: Truck!, truck2: Truck!, police1: Police!, police2: Police!
    init(screen: NSScreen) {
        ground = Ground(screen: screen)
        super.init(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        ignoresMouseEvents = true
        isOpaque = false; backgroundColor = .clear; hasShadow = false
        contentView = NSView(frame: CGRect(origin: .zero, size: screen.frame.size))
        contentView?.wantsLayer = true
        scene.frame = CGRect(origin: .zero, size: screen.frame.size); fly.frame = scene.frame
        contentView?.layer?.addSublayer(scene); contentView?.layer?.addSublayer(fly)
        ground.stage.addSublayer(ground.kid.layer); ground.stage.addSublayer(ground.fight.container); fly.addSublayer(ground.stage)
        truck = Truck(overlay: self); truck2 = Truck(overlay: self); ground.truck = truck; ground.truck2 = truck2
        police1 = Police(overlay: self); police2 = Police(overlay: self); ground.police1 = police1; ground.police2 = police2
    }
    /// Only the truck takes the mouse (to be picked up and dropped); everything else clicks straight through.
    override func sendEvent(_ e: NSEvent) {
        switch e.type {
        case .leftMouseDown:                                                    // pick up whichever vehicle is under the pointer
            let m = NSEvent.mouseLocation
            if let t = [truck!, truck2!].first(where: { $0.hit(m) }) { t.beginDrag(at: e.locationInWindow) }
            else if let c = [police1!, police2!].first(where: { $0.hit(m) }) { c.beginDrag(at: e.locationInWindow) }
            else if ground.fight.hit(m) { ground.fight.beginDrag(at: e.locationInWindow) }
        case .leftMouseDragged: for t in [truck!, truck2!] { t.drag(to: e.locationInWindow) }; for c in [police1!, police2!] { c.drag(to: e.locationInWindow) }; ground.fight.drag(to: e.locationInWindow)
        case .leftMouseUp: for t in [truck!, truck2!] { t.endDrag() }; for c in [police1!, police2!] { c.endDrag() }; ground.fight.endDrag()
        default: super.sendEvent(e)
        }
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func show(_ e: Effect) {
        scene.sublayers?.forEach { $0.removeFromSuperlayer() }
        let sc = screen?.backingScaleFactor ?? 2
        flakes = nil; rain = nil
        if e == .snow { let f = FlakeField(size: frame.size, scale: sc); flakes = f; emitter = f.container }
        else if e == .rain { let r = RainField(size: frame.size, scale: sc); rain = r; emitter = r.container }
        else { emitter = layer(for: e, size: frame.size) }
        if let l = emitter { scene.addSublayer(l) }
        if e == .snow { let host = scene; host.addSublayer(ground.layer); host.addSublayer(ground.host) }   // the kid sits below the pile layer so it can sink into the snow
    }
}

final class App: NSObject, NSApplicationDelegate {
    var item: NSStatusItem!
    var overlays: [Overlay] = []
    var current: Effect = { let e = Effect(rawValue: UserDefaults.standard.string(forKey: "effect") ?? "") ?? .snow; return e == .none ? .snow : e }()   // "Off" lasts only for this session
    var timer: Timer?

    func applicationDidFinishLaunching(_ n: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "snowflake", accessibilityDescription: "Flurry")
        let menu = NSMenu()
        for e in Effect.allCases {
            let mi = NSMenuItem(title: e.rawValue, action: #selector(pick(_:)), keyEquivalent: "")
            mi.target = self; mi.representedObject = e.rawValue; menu.addItem(mi)
        }
        menu.addItem(.separator())
        for s in Settings.sliders { menu.addItem(makeSliderItem(s)) }
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        NotificationCenter.default.addObserver(self, selector: #selector(rebuild),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
#if DEBUG   // development hooks: not in the release app
        if ProcessInfo.processInfo.environment["FLURRY_TEST"] != nil { // dev only: a plain window to land snow on
            let w = NSWindow(contentRect: CGRect(x: 500, y: 602, width: 520, height: 320), styleMask: [.titled], backing: .buffered, defer: false)
            w.title = "snow lands here"; w.level = .floating; w.makeKeyAndOrderFront(nil)
            if ProcessInfo.processInfo.environment["FLURRY_TESTDRAG"] != nil {   // dev only: drag this test window back and forth
                let start = CACurrentMediaTime()
                Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { _ in
                    let t = CACurrentMediaTime() - start
                    if t > 14, t < 19 { w.setFrameOrigin(NSPoint(x: 500 + 280 * sin((t - 14) * 2.4), y: 602)) }
                }
            }
        }
#endif
        startSnowPhysics()
        rebuild()
    }

    @objc func rebuild() {
        liveCaps.clear()
        overlays.forEach { $0.orderOut(nil) }
        overlays = NSScreen.screens.map { Overlay(screen: $0) }
        apply()
    }

    @objc func pick(_ s: NSMenuItem) {
        current = Effect(rawValue: s.representedObject as! String) ?? .none
        if current != .none { UserDefaults.standard.set(current.rawValue, forKey: "effect") }
        apply()
    }

    func apply() {
        // Respect "Reduce motion": show nothing.
        let e = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? Effect.none : current
        o_snowCaps(e)
        for o in overlays { o.show(e); e == .none ? o.orderOut(nil) : o.orderFrontRegardless() }
        for m in item.menu?.items ?? [] { m.state = (m.representedObject as? String) == current.rawValue ? .on : .off }
    }
}

extension App { func o_snowCaps(_ e: Effect) { liveCaps.enabled = (e == .snow) } }

if let d = ProcessInfo.processInfo.environment["FLURRY_DUMP"] { dumpFlakes(to: d); exit(0) }
let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // menu-bar only, no Dock icon
let delegate = App()
app.delegate = delegate
app.run()
