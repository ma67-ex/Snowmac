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
        let c = cell(sprite(24, color: .white), rate: 40, life: 14, vy: 60, scale: 0.5, scaleRange: 0.3, alpha: 0.9)
        c.emissionLongitude = -.pi / 2; c.xAcceleration = 4; c.spin = 0.3; c.spinRange = 0.6
        l.emitterCells = [c]
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
    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        ignoresMouseEvents = true
        isOpaque = false; backgroundColor = .clear; hasShadow = false
        contentView = NSView(frame: CGRect(origin: .zero, size: screen.frame.size))
        contentView?.wantsLayer = true
    }
    func show(_ e: Effect) {
        contentView?.layer?.sublayers?.forEach { $0.removeFromSuperlayer() }
        if let l = layer(for: e, size: frame.size) { contentView?.layer?.addSublayer(l) }
    }
}

final class App: NSObject, NSApplicationDelegate {
    var item: NSStatusItem!
    var overlays: [Overlay] = []
    var current: Effect = Effect(rawValue: UserDefaults.standard.string(forKey: "effect") ?? "") ?? .snow

    func applicationDidFinishLaunching(_ n: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "snowflake", accessibilityDescription: "Flurry")
        let menu = NSMenu()
        for e in Effect.allCases {
            let mi = NSMenuItem(title: e.rawValue, action: #selector(pick(_:)), keyEquivalent: "")
            mi.target = self; mi.representedObject = e.rawValue; menu.addItem(mi)
        }
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        NotificationCenter.default.addObserver(self, selector: #selector(rebuild),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        rebuild()
    }

    @objc func rebuild() {
        overlays.forEach { $0.orderOut(nil) }
        overlays = NSScreen.screens.map { Overlay(screen: $0) }
        apply()
    }

    @objc func pick(_ s: NSMenuItem) {
        current = Effect(rawValue: s.representedObject as! String) ?? .none
        UserDefaults.standard.set(current.rawValue, forKey: "effect")
        apply()
    }

    func apply() {
        // Respect "Reduce motion": show nothing.
        let e = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? Effect.none : current
        for o in overlays { o.show(e); e == .none ? o.orderOut(nil) : o.orderFrontRegardless() }
        for m in item.menu?.items ?? [] { m.state = (m.representedObject as? String) == current.rawValue ? .on : .off }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // menu-bar only, no Dock icon
let delegate = App()
app.delegate = delegate
app.run()
