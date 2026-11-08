import AppKit
import QuartzCore

private let env = ProcessInfo.processInfo.environment
let flakesPerSecond: CGFloat = 28     // flakes per second at full snowfall
/// Seconds for everything to build up (snowfall, pile, window caps). FLURRY_GROW overrides it for testing.
let flurryGrow = Double(env["FLURRY_GROW"] ?? "") ?? 300

/// The snowplough, drawn entirely in code (side view, facing right): grey salt load under a snow crest, orange dump bed with a
/// tilted hydraulic arm, silver exhaust stack, orange cab with dark glass, amber lights, tandem rear wheels, and a dark front
/// plough blade. Coordinates below are design units (680 x 336, y down); `X`/`Y` map them into the sprite (140 x 64 pt, y up,
/// wheels on y = 0).
func truckImage() -> CGImage? {
    let sc: CGFloat = 4, W: CGFloat = 140, H: CGFloat = 64, k: CGFloat = 0.21875
    guard let ctx = CGContext(data: nil, width: Int(W * sc), height: Int(H * sc), bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    ctx.scaleBy(x: sc, y: sc); ctx.setLineCap(.round); ctx.setLineJoin(.round)
    func X(_ x: CGFloat) -> CGFloat { (x - 20) * k }
    func Y(_ y: CGFloat) -> CGFloat { (290 - y) * k }
    func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: X(x), y: Y(y)) }
    func R(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect { CGRect(x: X(x), y: Y(y + h), width: w * k, height: h * k) }
    func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor { NSColor(calibratedRed: r, green: g, blue: b, alpha: a) }
    func box(_ r: CGRect, _ c: NSColor, _ rad: CGFloat = 0) {
        ctx.setFillColor(c.cgColor); ctx.addPath(CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil)); ctx.fillPath()
    }
    func poly(_ pts: [CGPoint], _ c: NSColor) {
        ctx.setFillColor(c.cgColor); ctx.move(to: pts[0]); for q in pts.dropFirst() { ctx.addLine(to: q) }; ctx.closePath(); ctx.fillPath()
    }
    func line(_ a: CGPoint, _ b: CGPoint, _ w: CGFloat, _ c: NSColor) {
        ctx.setStrokeColor(c.cgColor); ctx.setLineWidth(w); ctx.move(to: a); ctx.addLine(to: b); ctx.strokePath()
    }
    let orange = rgb(0.93, 0.40, 0.07), orangeDark = rgb(0.74, 0.29, 0.04), orangeLight = rgb(1.0, 0.52, 0.14)
    let black = rgb(0.07, 0.07, 0.08), steel = rgb(0.78, 0.80, 0.82), grey = rgb(0.52, 0.55, 0.58), amber = rgb(1, 0.78, 0.25)

    box(R(40, 212, 505, 26), black, 2)                                              // chassis rail
    box(R(60, 188, 290, 28), rgb(0.18, 0.19, 0.21), 2)                              // under-bed frame
    box(R(22, 62, 318, 34), grey, 3)                                                // salt/sand load
    box(R(26, 52, 296, 16), rgb(0.93, 0.95, 0.97), 7)                               // snow crest on the load
    box(R(35, 92, 320, 100), orange, 5)                                             // dump bed
    box(R(35, 92, 320, 9), orangeLight, 3)                                          // bed top rail
    box(R(35, 118, 320, 3), orangeDark); box(R(35, 150, 320, 3), orangeDark); box(R(35, 178, 320, 4), orangeDark)  // body ribs
    box(R(35, 95, 18, 98), orangeDark, 4)                                           // tailgate
    box(R(40, 166, 7, 10), rgb(0.9, 0.1, 0.1), 1)                                   // tail light
    line(P(205, 186), P(344, 44), 15 * k, rgb(0.36, 0.38, 0.41))                    // hydraulic lift arm
    line(P(205, 186), P(344, 44), 7 * k, steel)
    ctx.setFillColor(black.cgColor); ctx.fillEllipse(in: CGRect(x: X(350) - 3.2, y: Y(48) - 3.2, width: 6.4, height: 6.4))   // arm pivot

    // cab + hood
    poly([P(355, 88), P(468, 88), P(490, 125), P(500, 142), P(560, 148), P(582, 168), P(589, 222), P(580, 252), P(355, 252)], orange)
    poly([P(355, 88), P(468, 88), P(471, 96), P(355, 96)], orangeLight)             // roof highlight
    poly([P(405, 101), P(463, 101), P(480, 131), P(405, 136)], rgb(0.09, 0.12, 0.17)) // glass
    poly([P(409, 105), P(436, 105), P(424, 133), P(409, 134)], rgb(0.22, 0.28, 0.36)) // window glint
    box(R(461, 100, 11, 32), rgb(0.2, 0.2, 0.22), 2)                                // mirror
    line(P(399, 100), P(399, 236), 1.1, orangeDark)                                 // door seam
    box(R(407, 168, 16, 5), orangeDark, 1)                                          // door handle
    box(R(368, 78, 16, 116), steel, 4); box(R(373, 80, 4, 112), rgb(0.95, 0.96, 0.97), 1)  // exhaust stack
    box(R(366, 72, 20, 9), rgb(0.55, 0.57, 0.60), 3)
    box(R(508, 160, 22, 6), orangeDark, 1); box(R(508, 171, 22, 6), orangeDark, 1)  // hood vents
    box(R(560, 200, 22, 13), amber, 3)                                              // headlight
    box(R(574, 138, 11, 8), amber, 2)                                               // cab marker light
    box(R(415, 78, 24, 11), orangeDark, 2)                                          // beacon base (the beacon itself blinks)

    // front plough: frame, blade and its edge
    line(P(560, 226), P(600, 214), 4.2, rgb(0.15, 0.16, 0.18))
    poly([P(590, 176), P(646, 186), P(641, 263), P(597, 252)], rgb(0.13, 0.14, 0.16))
    poly([P(612, 182), P(646, 186), P(641, 263), P(618, 258)], rgb(0.30, 0.32, 0.35))
    line(P(597, 252), P(641, 263), 2.2, amber)
    box(R(540, 214, 52, 22), black, 2)                                              // front bumper

    // wheels: two tandem rear axles and the front wheel
    ctx.setFillColor(rgb(0.10, 0.10, 0.11).cgColor)                                 // wheel arch in the cab, behind the front wheel
    ctx.fillEllipse(in: CGRect(x: X(505 - 46), y: Y(256 + 46), width: 92 * k, height: 92 * k))
    for (cx, cy) in [(105, 252), (205, 252), (505, 256)] as [(CGFloat, CGFloat)] {
        ctx.setFillColor(black.cgColor); ctx.fillEllipse(in: CGRect(x: X(cx - 38), y: Y(cy + 38), width: 76 * k, height: 76 * k))
        ctx.setFillColor(rgb(0.16, 0.17, 0.19).cgColor); ctx.fillEllipse(in: CGRect(x: X(cx - 28), y: Y(cy + 28), width: 56 * k, height: 56 * k))
        ctx.setFillColor(steel.cgColor); ctx.fillEllipse(in: CGRect(x: X(cx - 19), y: Y(cy + 19), width: 38 * k, height: 38 * k))
        ctx.setFillColor(rgb(0.30, 0.31, 0.33).cgColor); ctx.fillEllipse(in: CGRect(x: X(cx - 8), y: Y(cy + 8), width: 16 * k, height: 16 * k))
    }
    if let flake = flakeSprite(seed: 1, px: 128) {                                  // the snowflake decal on the bed
        ctx.draw(flake, in: R(183, 122, 46, 46))
    }
    return ctx.makeImage()
}

/// A snowball: white with an icy rim and a few darker packed-snow arcs, so you can see it roll.
func snowballImage(px: Int = 160) -> CGImage? {
    guard let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    let c = CGFloat(px) / 2, r = c - 2
    ctx.addEllipse(in: CGRect(x: 2, y: 2, width: 2 * r, height: 2 * r)); ctx.clip()
    let colors = [NSColor.white.cgColor, NSColor(calibratedRed: 0.90, green: 0.95, blue: 1, alpha: 1).cgColor,
                  NSColor(calibratedRed: 0.66, green: 0.77, blue: 0.93, alpha: 1).cgColor] as CFArray
    let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.6, 1])!
    ctx.drawRadialGradient(g, startCenter: CGPoint(x: c * 0.8, y: c * 1.2), startRadius: 0, endCenter: CGPoint(x: c, y: c), endRadius: r, options: [])
    ctx.setStrokeColor(NSColor(calibratedRed: 0.45, green: 0.58, blue: 0.80, alpha: 0.35).cgColor)   // packed-snow rings (they turn as it rolls)
    ctx.setLineWidth(CGFloat(px) / 40); ctx.setLineCap(.round)
    for (a0, a1, rr) in [(0.2, 1.7, 0.62), (2.6, 4.1, 0.45), (4.4, 5.9, 0.78), (1.0, 2.0, 0.25)] as [(Double, Double, Double)] {
        ctx.addArc(center: CGPoint(x: c, y: c), radius: r * CGFloat(rr), startAngle: CGFloat(a0), endAngle: CGFloat(a1), clockwise: false); ctx.strokePath()
    }
    return ctx.makeImage()
}

/// The little kid: four poses drawn in code (stand, wind-up holding a snowball, throw, slipped), facing right.
/// Red beanie with a white pompom, striped scarf, rosy cheeks, big shiny eyes, blue mittens.
func kidImages(variant: Int = 0) -> [CGImage] {
    let sc: CGFloat = 4, W: CGFloat = 52, H: CGFloat = 58
    func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor { NSColor(calibratedRed: r, green: g, blue: b, alpha: a).cgColor }
    let palettes: [(coat: CGColor, dark: CGColor, hat: CGColor)] = [
        (rgb(0.90, 0.20, 0.25), rgb(0.72, 0.13, 0.19), rgb(0.93, 0.22, 0.27)),      // red
        (rgb(0.20, 0.50, 0.92), rgb(0.13, 0.38, 0.75), rgb(0.24, 0.55, 0.95)),      // blue
        (rgb(0.25, 0.72, 0.42), rgb(0.16, 0.55, 0.31), rgb(0.30, 0.78, 0.47)),      // green
        (rgb(0.98, 0.72, 0.15), rgb(0.82, 0.54, 0.08), rgb(1.00, 0.78, 0.22))]      // yellow
    let pal = palettes[variant % palettes.count]
    let coat = pal.coat, coatDark = pal.dark, skin = rgb(1, 0.85, 0.72), mitten = rgb(0.25, 0.52, 0.92)
    let ink = rgb(0.13, 0.10, 0.12), cream = rgb(1, 0.98, 0.94), boot = rgb(0.36, 0.24, 0.20)
    func pose(_ k: Int) -> CGImage? {
        guard let ctx = CGContext(data: nil, width: Int(W * sc), height: Int(H * sc), bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.scaleBy(x: sc, y: sc); ctx.translateBy(x: 3, y: 0); ctx.setLineCap(.round); ctx.setLineJoin(.round)   // 3 pt of room on the left for the throwing arm
        func disc(_ c: CGPoint, _ r: CGFloat, _ col: CGColor) { ctx.setFillColor(col); ctx.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)) }
        func rbox(_ r: CGRect, _ rad: CGFloat, _ col: CGColor) { ctx.setFillColor(col); ctx.addPath(CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil)); ctx.fillPath() }
        func arm(_ from: CGPoint, _ to: CGPoint) {
            ctx.setStrokeColor(coat); ctx.setLineWidth(5.2); ctx.move(to: from); ctx.addLine(to: to); ctx.strokePath()
            disc(to, 3.4, mitten); disc(CGPoint(x: to.x - 0.8, y: to.y + 0.9), 1.0, rgb(1, 1, 1, 0.55))
        }
        let shoulderBack = CGPoint(x: 15, y: 25), shoulderFront = CGPoint(x: 31, y: 25)
        // back arm (the one that stays down, or goes up when slipping)
        if k == 3 { arm(shoulderBack, CGPoint(x: 6, y: 41)) } else { arm(shoulderBack, CGPoint(x: 11, y: 14)) }
        // boots, coat, scarf
        rbox(CGRect(x: 12, y: 2, width: 9, height: 7), 3, boot); rbox(CGRect(x: 25, y: 2, width: 9, height: 7), 3, boot)
        rbox(CGRect(x: 9.5, y: 7, width: 27, height: 22), 9, coat)
        rbox(CGRect(x: 9.5, y: 7, width: 27, height: 6), 3, coatDark)
        ctx.setStrokeColor(coatDark); ctx.setLineWidth(0.9); ctx.move(to: CGPoint(x: 23, y: 8)); ctx.addLine(to: CGPoint(x: 23, y: 26)); ctx.strokePath()
        disc(CGPoint(x: 27, y: 20), 1.3, rgb(1, 0.85, 0.3)); disc(CGPoint(x: 27, y: 13.5), 1.3, rgb(1, 0.85, 0.3))
        rbox(CGRect(x: 8.5, y: 17, width: 6, height: 12), 2.5, rgb(0.45, 0.75, 0.95))                      // scarf tail
        rbox(CGRect(x: 11, y: 26, width: 24, height: 6), 3, rgb(0.55, 0.80, 0.97))
        for i in 0..<4 { rbox(CGRect(x: 13 + CGFloat(i) * 6, y: 26, width: 2.6, height: 6), 1, cream) }      // scarf stripes
        // head
        disc(CGPoint(x: 23, y: 38.5), 12, skin)
        disc(CGPoint(x: 15.5, y: 34.5), 2.6, rgb(1, 0.55, 0.60, 0.75)); disc(CGPoint(x: 31.5, y: 34.5), 2.6, rgb(1, 0.55, 0.60, 0.75))   // cheeks
        let surprised = (k == 3)
        let er: CGFloat = surprised ? 2.5 : 2.1
        disc(CGPoint(x: 19.5, y: 37.5), er, ink); disc(CGPoint(x: 28, y: 37.5), er, ink)                      // big eyes
        disc(CGPoint(x: 20.2, y: 38.4), 0.8, cream); disc(CGPoint(x: 28.7, y: 38.4), 0.8, cream)               // sparkle in each eye
        ctx.setStrokeColor(ink); ctx.setLineWidth(1.1)
        if surprised { disc(CGPoint(x: 24, y: 32.2), 1.6, ink) }                                              // little "oh!" mouth
        else { ctx.addArc(center: CGPoint(x: 24, y: 33.6), radius: 2.6, startAngle: .pi * 1.15, endAngle: .pi * 1.85, clockwise: false); ctx.strokePath() }  // smile
        // beanie with white cuff and pompom
        ctx.setFillColor(pal.hat); ctx.addArc(center: CGPoint(x: 23, y: 40), radius: 12.6, startAngle: .pi, endAngle: 0, clockwise: true); ctx.closePath(); ctx.fillPath()
        rbox(CGRect(x: 10, y: 40, width: 26, height: 5), 2.5, cream)
        disc(CGPoint(x: 23, y: 53.8), 3.6, cream); disc(CGPoint(x: 22.2, y: 54.6), 1.2, rgb(1, 1, 1))
        // front arm
        switch k {
        case 1:                                                                                              // wind-up: arm back and up, holding a snowball
            arm(shoulderFront, CGPoint(x: 38, y: 43)); disc(CGPoint(x: 39.5, y: 49.5), 4.6, cream); disc(CGPoint(x: 38.3, y: 50.7), 1.4, rgb(1, 1, 1))
        case 2: arm(shoulderFront, CGPoint(x: 43, y: 36))                                                   // throw: arm swung forward
        case 3: arm(shoulderFront, CGPoint(x: 40, y: 41))                                                   // slipped: both arms up
        default: arm(shoulderFront, CGPoint(x: 35, y: 14))
        }
        return ctx.makeImage()
    }
    return (0..<4).compactMap { pose($0) }
}

/// One kid at a time pops out of the snow at a random spot, winds up, throws a snowball across the screen, slips onto
/// its back, and sinks into the pile in a puff of snow. Then it waits a good while before the next one.
final class Kid {
    let layer = CALayer()
    weak var ground: Ground?
    private enum Phase { case waiting, pop, windup, throwing, slip, lie, sink }
    private var phase = Phase.waiting, t: CGFloat = 0
    private var wait = CGFloat(Double(env["FLURRY_KID"] ?? "") ?? 25)
    private var x: CGFloat = 0, dir: CGFloat = 1, thrown = false
    var isIdle: Bool { phase == .waiting }
    private let poses = kidImages()
    private let size = CGSize(width: 52, height: 58), every = CGFloat(Double(env["FLURRY_KID"] ?? "") ?? 25)

    init() {
        layer.bounds = CGRect(origin: .zero, size: size); layer.anchorPoint = CGPoint(x: 0.5, y: 0.08)
        layer.contentsScale = 4; layer.minificationFilter = .trilinear; layer.isHidden = true
    }

    private func ease(_ p: CGFloat) -> CGFloat { p * p * (3 - 2 * p) }
    private func outBack(_ p: CGFloat) -> CGFloat { let c: CGFloat = 1.9; let q = p - 1; return 1 + (c + 1) * q * q * q + c * q * q }

    func step(_ dt: CGFloat) {
        guard let g = ground, g.regionWidth > 260 else { return }
        t += dt
        switch phase {
        case .waiting:
            guard t >= wait, g.vehicles.allSatisfy({ !$0.visible }), g.fight.isIdle else { return }     // only when no truck is about
            if Settings.f("snowDensity") >= 2.5 {                                           // heavy snow: a whole snowball fight instead
                g.fight.start(); t = 0; wait = every * CGFloat.random(in: 0.8...1.5); return
            }
            x = g.originX + CGFloat.random(in: 70...(g.regionWidth - 70))                   // a different place every time
            dir = (x < g.originX + g.regionWidth / 2) ? 1 : -1                              // throws toward the wider side
            thrown = false; phase = .pop; t = 0; layer.isHidden = false
            if env["FLURRY_DEBUG"] != nil { FileHandle.standardError.write(Data("kid x=\(x) dir=\(dir)\n".utf8)) }
        case .pop:      go(.windup, after: 0.55)
        case .windup:   go(.throwing, after: 0.55)
        case .throwing: go(.slip, after: 0.30)
        case .slip:     go(.lie, after: 0.55)
        case .lie:      go(.sink, after: 0.70)
        case .sink:
            if t >= 0.80 { poof(); layer.isHidden = true; phase = .waiting; t = 0; wait = every * CGFloat.random(in: 0.8...1.5); return }
        }
        // A truck coming near ends the kid's turn: it dives into the snow so it never gets hurt.
        if phase != .waiting, phase != .sink, g.vehicles.contains(where: { $0.visible && ($0.span.lowerBound - 70)...($0.span.upperBound + 70) ~= x }) { phase = .sink; t = 0 }
        guard phase != .waiting, let surface = g.surface(atX: x) else { return }
        var y = surface, angle: CGFloat = 0, dx: CGFloat = 0, img = poses[0]
        switch phase {
        case .pop:                                                                           // bounces up out of the snow
            let p = min(1, t / 0.55); y = surface - 40 + 40 * outBack(p)
        case .windup:                                                                        // leans back with the snowball
            img = poses[1]; angle = 0.14 * ease(min(1, t / 0.45))
        case .throwing:                                                                      // swings forward and lets go
            img = poses[2]; angle = 0.14 - 0.34 * ease(min(1, t / 0.2))
            if !thrown, t >= 0.08 { thrown = true; launch(from: g, surface: surface) }
        case .slip:                                                                          // little hop, then falls onto its back
            img = poses[3]; let p = min(1, t / 0.55)
            angle = -0.2 + 1.75 * p * p; dx = -dir * 20 * ease(p); y = surface + 9 * sin(.pi * min(1, p * 1.15))
        case .lie:                                                                           // lies in the snow, dizzy
            img = poses[3]; angle = 1.55 + 0.04 * sin(t * 14); dx = -dir * 20; y = surface + 4
        case .sink:                                                                          // slides down into the pile
            img = poses[3]; angle = 1.55; dx = -dir * 20; y = surface + 4 - (surface + 66) * ease(min(1, t / 0.8))
        case .waiting: break
        }
        CATransaction.begin(); CATransaction.setDisableActions(true)
        layer.contents = img
        layer.position = CGPoint(x: x + dx, y: y)
        var tf = CATransform3DMakeRotation(angle * dir, 0, 0, 1); tf = CATransform3DScale(tf, dir, 1, 1)
        layer.transform = tf
        CATransaction.commit()
    }

    private func go(_ next: Phase, after: CGFloat) { if t >= after { phase = next; t = 0 } }

    /// The throw: a high arc across the screen, aimed so it lands on the snow far away.
    private func launch(from g: Ground, surface: CGFloat) {
        let hand = CGPoint(x: x + dir * 20 + g.screenFrame.minX, y: surface + 50 + g.screenFrame.minY)
        let room = dir > 0 ? (g.screenFrame.maxX - hand.x) : (hand.x - g.screenFrame.minX)
        let range = max(120, min(room - 40, CGFloat.random(in: 0.25...0.75) * g.screenFrame.width))
        let ang = CGFloat.random(in: 0.8...1.1), gravity: CGFloat = 1500
        let v = sqrt(gravity * range / sin(2 * ang))
        balls.throwBall(from: hand, v: CGVector(dx: dir * v * cos(ang), dy: v * sin(ang)))
    }

    /// A little puff of snow where the kid went under.
    private func poof() {
        guard let g = ground, let host = layer.superlayer, let surface = g.surface(atX: x) else { return }
        for _ in 0..<12 {
            let d = CALayer(); let r = CGFloat.random(in: 2...5)
            d.bounds = CGRect(x: 0, y: 0, width: 2 * r, height: 2 * r); d.cornerRadius = r; d.backgroundColor = NSColor.white.cgColor
            let from = CGPoint(x: x - dir * 20 + CGFloat.random(in: -8...8), y: surface + 2)
            d.position = from; host.addSublayer(d)
            let ang = CGFloat.random(in: 0.3...(.pi - 0.3)), dist = CGFloat.random(in: 14...40)
            let m = CABasicAnimation(keyPath: "position"); m.toValue = CGPoint(x: from.x + cos(ang) * dist, y: from.y + sin(ang) * dist + 10)
            let f = CABasicAnimation(keyPath: "opacity"); f.fromValue = 1; f.toValue = 0
            let gr = CAAnimationGroup(); gr.animations = [m, f]; gr.duration = 0.6; gr.timingFunction = CAMediaTimingFunction(name: .easeOut)
            gr.isRemovedOnCompletion = false; gr.fillMode = .forwards
            d.add(gr, forKey: "poof")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) { d.removeFromSuperlayer() }
        }
    }
}

/// A tiny tileable-looking speckle texture: fine light and dark crystals over the pile, so it is not a flat colour.
func snowGrain(w: Int = 512, h: Int = 128) -> CGImage? {
    guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    var rng = SeededRNG(s: 424242)
    for _ in 0..<2600 {
        let x = CGFloat.random(in: 0..<CGFloat(w), using: &rng), y = CGFloat.random(in: 0..<CGFloat(h), using: &rng)
        let r = CGFloat.random(in: 0.5...1.4, using: &rng), light = Bool.random(using: &rng)
        ctx.setFillColor(light ? NSColor(white: 1, alpha: 0.55).cgColor : NSColor(calibratedRed: 0.45, green: 0.55, blue: 0.75, alpha: 0.28).cgColor)
        ctx.fillEllipse(in: CGRect(x: x, y: y, width: r * 2, height: r * 2))
    }
    return ctx.makeImage()
}

/// Snow pile on top of the Dock (or along the screen bottom when the Dock is hidden), with a plough that clears it.
final class Ground {
    let layer = CAGradientLayer()              // the visible pile: shaded gradient, masked by `shape`
    private let shape = CAShapeLayer(), grain = CALayer()
    let host = CALayer()                       // clips the truck to the pile's span
    let kid = Kid()
    let fight = Fight()
    let stage = CALayer()                       // in the front layer, clipped at the pile line: the kids play here so windows never hide them
    weak var truck: Truck?, truck2: Truck?
    weak var police1: Police?, police2: Police?
    var trucks: [Truck] { [truck, truck2].compactMap { $0 } }
    var vehicles: [Vehicle] { trucks + [police1, police2].compactMap { $0 } }
    private(set) var maxDepth: CGFloat = 0
    private(set) var originX: CGFloat = 0      // left edge of the pile, in screen-local points
    var regionWidth: CGFloat { width }
    var screenFrame: CGRect { screen.frame }
    private(set) var baseY: CGFloat = 0        // y of the surface the snow sits on
    private let step: CGFloat = 6
    private var width: CGFloat = 0
    private var cols: [CGFloat] = []           // snow that has fallen, per column
    private var noise: [CGFloat] = []
    private let screen: NSScreen
    private var ppi: CGFloat = 110   // points per inch; fall back if the display does not report its size
    // plough
    private let plowEvery = CGFloat(Double(env["FLURRY_PLOW"] ?? "") ?? 10)   // seconds between passes
    private let keep: CGFloat = 0.5                                           // share of snow left after a pass
    private let truckSpeed: CGFloat = 200, bladeX: CGFloat = 137   // blade tip
    private var wait: CGFloat = 0, frame = 0

    init(screen: NSScreen) {
        self.screen = screen
        kid.ground = self; fight.ground = self
        if let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
            let mm = CGDisplayScreenSize(id)
            if mm.width > 0 { ppi = screen.frame.width / (mm.width / 25.4) }
        }
        wait = plowEvery
        // Matte snow: off-white where it is lit, cool blue-grey toward the base. No glow.
        layer.colors = [NSColor(calibratedRed: 0.94, green: 0.96, blue: 0.99, alpha: 1).cgColor,
                        NSColor(calibratedRed: 0.76, green: 0.83, blue: 0.93, alpha: 1).cgColor,
                        NSColor(calibratedRed: 0.62, green: 0.70, blue: 0.84, alpha: 1).cgColor]
        layer.locations = [0, 0.55, 1]
        layer.startPoint = CGPoint(x: 0.5, y: 1); layer.endPoint = CGPoint(x: 0.5, y: 0)
        shape.fillColor = NSColor.black.cgColor; layer.mask = shape
        grain.contents = snowGrain(); grain.contentsGravity = .resize; grain.opacity = 0.5; grain.mask = nil
        layer.addSublayer(grain)
        host.masksToBounds = true
        refresh()
    }

    /// The Dock's rectangle in screen-local points, if it is visible at the bottom of this screen.
    private func dockRect() -> CGRect? {
#if DEBUG   // development hook: not in the release app
        if let f = env["FLURRY_FAKEDOCK"] { let v = f.split(separator: ",").compactMap { Double($0) }
            if v.count == 3 { return CGRect(x: v[0], y: 0, width: v[1], height: v[2]) } }
#endif
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]],
              let primaryH = NSScreen.screens.first?.frame.height else { return nil }
        var best: CGRect?
        for w in list where (w[kCGWindowOwnerName as String] as? String) == "Dock" {
            guard let b = w[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = b["X"], let y = b["Y"], let wd = b["Width"], let h = b["Height"],
                  wd > 100, (wd < screen.frame.width - 4), h > 30, (h < 250) else { continue }
            let r = CGRect(x: x - screen.frame.minX, y: primaryH - y - h - screen.frame.minY, width: wd, height: h)
            if r.minY < 40, r.midX > 0, (r.midX < screen.frame.width), wd > (best?.width ?? 0) { best = r }  // bottom Dock only
        }
        return best
    }

    /// Re-aim the pile at the Dock (or the screen bottom). Call about once a second.
    func refresh() {
        let dock = dockRect()
        let newX = dock?.minX ?? 0, newW = dock?.width ?? screen.frame.width
        let newBase = dock?.maxY ?? 0
        let newMax = (0.5 / 2.54) * ppi   // hard limit: 0.5 cm of snow, on the Dock or on the bare screen bottom
        if newW != width || newX != originX || newBase != baseY {
            originX = newX; width = newW; baseY = newBase; maxDepth = newMax
            let n = Int(width / step) + 2
            cols = Array(repeating: 0, count: n)
            noise = (0..<n).map { i in let x = CGFloat(i)
                return 0.8 + 0.12 * sin(x * 0.11) + 0.06 * sin(x * 0.37 + 1) + 0.03 * sin(x * 0.9) }
            layer.frame = CGRect(x: originX, y: baseY, width: width, height: maxDepth * 1.6)
            shape.frame = CGRect(origin: .zero, size: layer.frame.size)
            grain.frame = CGRect(origin: .zero, size: layer.frame.size)
            host.frame = CGRect(x: originX, y: baseY, width: width, height: 90)
        }
        let sh = screen.frame.size                                              // keep the kids' stage on the pile line
        stage.masksToBounds = true
        stage.frame = CGRect(x: 0, y: baseY - 2, width: sh.width, height: sh.height - baseY + 2)
        stage.bounds = CGRect(x: 0, y: baseY - 2, width: sh.width, height: sh.height - baseY + 2)   // children keep screen coordinates
        if env["FLURRY_DEBUG"] != nil { FileHandle.standardError.write(Data("pile max=\(cols.max() ?? -1) mean=\((cols.reduce(0, +)) / CGFloat(max(1, cols.count))) limit=\(maxDepth)\n".utf8)) }
        update()
    }

    private func h(_ i: Int) -> CGFloat { cols[i] }

    /// Top of the snow at screen-local x, or nil when x is not over the pile.
    func surface(atX x: CGFloat) -> CGFloat? {
        let lx = x - originX
        guard lx >= 0, lx <= width, !cols.isEmpty else { return nil }
        return baseY + h(max(0, min(cols.count - 1, Int(lx / step))))
    }

    /// One flake landed at x. The pile only grows this way, so it cannot start before the first flake reaches the bottom.
    /// At the default density the pile averages 70% of its limit after about `flurryGrow` s.
    func deposit(atX x: CGFloat) {
        let n = cols.count, c = Int((x - originX) / step)
        guard n > 0, c >= 0, c < n else { return }
        // The pile settles at a depth that follows the snow-density slider (never above the hard limit). Each flake adds
        // a fixed bit, so a bigger target takes proportionally longer to reach: raising density raises the pile slowly.
        let target = maxDepth * Settings.depthFraction(Settings.f("snowDensity"))
        guard cols.reduce(0, +) / CGFloat(n) < target else { return }
        let unit = maxDepth * 0.7 * CGFloat(n) / (flakesPerSecond * 0.575 * CGFloat(flurryGrow))   // 0.575 = average of the ramp
        cols[c] = min(maxDepth, cols[c] + unit)
    }

    /// A snowball lands: its snow joins the pile and then settles like the rest.
    func add(atX x: CGFloat, amount: CGFloat) {
        let c = Int((x - originX) / step)
        guard c >= 0, c < cols.count else { return }
        for i in max(0, c - 6)...min(cols.count - 1, c + 6) {
            let d = CGFloat(i - c)
            cols[i] = min(maxDepth, cols[i] + amount * exp(-d * d / 10))
        }
    }

    /// Real-life logic: a pointer (or foot) pressing into snow presses it DOWN. The snow under it is compressed into a
    /// dent (its own shape, left behind as a footprint), and only a little is squeezed up into a low rim around it.
    /// It never throws snow outward or into the air. Falling snow slowly refills the dent.
    func interact(cursor c: CGPoint, velocity v: CGVector) {
        guard !cols.isEmpty else { return }
        let R: CGFloat = 8
        let cx = c.x - originX, cy = c.y - baseY - 2                // lowest point of the pointer, in pile coordinates
        guard cx > -R, cx < width + R else { return }
        let i0 = max(0, Int((cx - R) / step)), i1 = min(cols.count - 1, Int((cx + R) / step) + 1)
        guard i0 <= i1 else { return }
        for i in i0...i1 {
            let dx = CGFloat(i) * step - cx
            guard abs(dx) < R else { continue }
            let bottom = max(0, cy - sqrt(R * R - dx * dx) * 0.6)  // underside of the pointer over this column
            guard cols[i] > bottom else { continue }
            let squashed = cols[i] - bottom
            cols[i] = bottom
            let rimCol = max(0, min(cols.count - 1, i + (dx >= 0 ? 1 : -1) * (Int(R / step) + 1)))   // a little is pressed up at the edge
            cols[rimCol] = min(maxDepth, cols[rimCol] + squashed * 0.12)
        }
    }

    /// Advance time. The pile only grows from flakes that land (see `deposit`); here it settles and the plough runs.
    /// steep slopes slide down to a natural angle, and the plough makes its rounds. No column may exceed `maxDepth`.
    func step(_ dt: CGFloat, active: Bool) {
        guard !cols.isEmpty else { return }
        let n = cols.count
        if active {
            let target = maxDepth * Settings.depthFraction(Settings.f("snowDensity"))
            if cols.reduce(0, +) / CGFloat(n) > target * 1.03 {                // density was lowered: the pile slowly sinks and thins
                let melt = maxDepth * 0.7 / CGFloat(flurryGrow) * dt * 1.5
                for i in cols.indices { cols[i] = max(0, cols[i] - melt) }
            }
            settle()
            // The plough comes round on a timer, but never while the kid is out. In heavy snow (density 2.5 or more) two
            // trucks come together, 2 cm apart: the first rides over the top and does a quarter of the work, the second
            // works low and clears the rest.
            if let t = truck, vehicles.allSatisfy({ !$0.visible }), kid.isIdle, fight.isIdle {      // never while kids are playing
                wait = max(0, wait - dt)
                // Only worth sending out once the pile is properly built up: at least half the 0.5 cm limit on average.
                let deep = cols.reduce(0, +) / CGFloat(max(1, cols.count)) >= maxDepth * 0.5
                if wait <= 0, deep {
                    wait = plowEvery
                    // A convoy, every vehicle 2 cm apart. Left to right: truck, police, [second truck, police] ... all driving right.
                    let gap = 2 / 2.54 * ppi, truckW: CGFloat = 140, carW = police1?.length ?? 96
                    var x: CGFloat = -truckW
                    if Settings.f("snowDensity") >= 2.5, let t2 = truck2 {
                        t.startPileRun(rides: true, keep: 0.875, startX: x)                 // the rider leads and does a quarter of the work
                        x -= gap + carW; police1?.start(atX: x)                              // a police SUV right behind it
                        x -= gap + truckW; t2.startPileRun(rides: false, keep: 0.3, startX: x)   // the plower works low and clears the rest
                        x -= gap + carW; police2?.start(atX: x)                              // and a police SUV behind that
                    } else {
                        t.startPileRun(rides: true, keep: 0.5, startX: x)
                        x -= gap + carW; police1?.start(atX: x)
                    }
                }
            }
            kid.step(dt); fight.step(dt)
        }
        frame += 1
        if (truck?.visible ?? false) || frame % 6 == 0 { update() }
    }

    /// Angle of repose: where two neighbours differ by more than the snow can hold, the excess slides downhill.
    /// The pile's two ends fall off like a real heap, and nothing may stack above `maxDepth`.
    private func settle() {
        let hold: CGFloat = step * 0.55                 // max height difference between neighbours (about 29 degrees)
        for _ in 0..<2 {
            for i in 0..<(cols.count - 1) {
                let d = cols[i] - cols[i + 1]
                if abs(d) > hold { let m = (abs(d) - hold) * 0.4
                    if d > 0 { cols[i] -= m; cols[i + 1] += m } else { cols[i] += m; cols[i + 1] -= m } }
            }
            if let f = cols.first, f > hold { cols[0] -= (f - hold) * 0.4 }          // edges shed what cannot be held
            if let l = cols.last, l > hold { cols[cols.count - 1] -= (l - hold) * 0.4 }
            for i in cols.indices where cols[i] > maxDepth {                          // hard cap: spill sideways
                let x = cols[i] - maxDepth; cols[i] = maxDepth
                if i > 0 { cols[i - 1] += x / 2 }; if i < cols.count - 1 { cols[i + 1] += x / 2 }
            }
        }
    }

    /// The plough blade moved from x0 to x1 (overlay coordinates): the snow it passes over is taken off the pile.
    /// Returns how much it took (for the snowball) and how deep the snow was (for the spray).
    func plow(from x0: CGFloat, to x1: CGFloat, keep: CGFloat = 0.5) -> (mass: CGFloat, depth: CGFloat) {
        var mass: CGFloat = 0, depth: CGFloat = 0
        for i in cols.indices {
            let cx = originX + CGFloat(i) * step
            guard cx > x0, cx <= x1 else { continue }
            let before = cols[i]
            cols[i] *= keep; depth = max(depth, before); mass += (before - cols[i]) * step
        }
        if mass > 0 { update() }
        return (mass, depth)
    }

    /// A run along the pile has ended; the next scheduled run starts counting from now.
    func passFinished() { wait = plowEvery }

    func update() {
        guard !cols.isEmpty else { return }
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 0, y: -4))
        for i in 0..<cols.count { p.addLine(to: CGPoint(x: CGFloat(i) * step, y: h(i))) }
        p.addLine(to: CGPoint(x: CGFloat(cols.count) * step, y: -4))
        p.closeSubpath()
        CATransaction.begin(); CATransaction.setDisableActions(true)
        shape.path = p
        CATransaction.commit()
    }
}

/// Snowballs: hold Option, drag, release to throw. Lands on the pile and splats.
final class Balls {
    private struct Ball { let layer: CALayer; var p: CGPoint; var v: CGVector; var age: Double }
    private var balls: [Ball] = []
    private var press: CGPoint?
    private var samples: [(CGPoint, TimeInterval)] = []
    private let gravity: CGFloat = 1500

    func monitor() {
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [self] e in
            let loc = NSEvent.mouseLocation
            switch e.type {
            case .leftMouseDown where e.modifierFlags.contains(.option): press = loc; samples = [(loc, e.timestamp)]
            case .leftMouseDragged where press != nil: samples.append((loc, e.timestamp))
            case .leftMouseUp where press != nil:
                samples.append((loc, e.timestamp))
                let recent = samples.filter { e.timestamp - $0.1 < 0.12 }
                var v = CGVector(dx: CGFloat.random(in: -250...250), dy: 900)   // plain click: lob it up
                if let a = recent.first, let b = recent.last, b.1 - a.1 > 0.01 {
                    v = CGVector(dx: (b.0.x - a.0.x) / (b.1 - a.1), dy: (b.0.y - a.0.y) / (b.1 - a.1))
                    let s = hypot(v.dx, v.dy); if s > 2600 { v = CGVector(dx: v.dx * 2600 / s, dy: v.dy * 2600 / s) }
                }
                press = nil; samples = []
                throwBall(from: loc, v: v)
            default: break
            }
        }
    }

    func throwBall(from p: CGPoint, v: CGVector) {
        guard let ov = overlay(at: p), let host = Optional(ov.scene) else { return }
        let l = CALayer()
        l.bounds = CGRect(x: 0, y: 0, width: 22, height: 22); l.cornerRadius = 11
        l.backgroundColor = NSColor.white.cgColor
        l.shadowOpacity = 0.4; l.shadowRadius = 3; l.shadowOffset = .zero
        host.addSublayer(l)
        balls.append(Ball(layer: l, p: p, v: v, age: 0))
    }

    private func overlay(at p: CGPoint) -> Overlay? { liveOverlays.first { $0.frame.contains(p) } }

    func step(_ dt: CGFloat) {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        balls = balls.compactMap { var b = $0
            b.v.dy -= gravity * dt; b.p.x += b.v.dx * dt; b.p.y += b.v.dy * dt; b.age += Double(dt)
            guard let ov = overlay(at: b.p), b.age < 8 else { b.layer.removeFromSuperlayer(); return nil }
            let lx = b.p.x - ov.frame.minX, ly = b.p.y - ov.frame.minY
            if b.v.dy < 0, let top = ov.ground.surface(atX: lx), ly <= top + 6 {
                splatter(at: CGPoint(x: lx, y: ly), on: ov); ov.ground.add(atX: lx, amount: 14)
                b.layer.removeFromSuperlayer(); return nil
            }
            b.layer.position = CGPoint(x: lx, y: ly)
            return b
        }
        CATransaction.commit()
    }

    private func splatter(at p: CGPoint, on ov: Overlay) {
        guard let host = Optional(ov.scene) else { return }
        for _ in 0..<14 {
            let s = CALayer(); let r = CGFloat.random(in: 2...5)
            s.bounds = CGRect(x: 0, y: 0, width: r * 2, height: r * 2); s.cornerRadius = r
            s.backgroundColor = NSColor.white.cgColor; s.position = p
            host.addSublayer(s)
            let a = CGFloat.random(in: 0.2...(.pi - 0.2)), sp = CGFloat.random(in: 80...260)
            let end = CGPoint(x: p.x + cos(a) * sp * 0.45, y: p.y + sin(a) * sp * 0.45 - 10)
            let m = CABasicAnimation(keyPath: "position"); m.fromValue = p; m.toValue = end
            let f = CABasicAnimation(keyPath: "opacity"); f.fromValue = 1; f.toValue = 0
            let g = CAAnimationGroup(); g.animations = [m, f]; g.duration = 0.5
            g.timingFunction = CAMediaTimingFunction(name: .easeOut); g.isRemovedOnCompletion = false; g.fillMode = .forwards
            s.add(g, forKey: "splat")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { s.removeFromSuperlayer() }
        }
    }
}

let balls = Balls()
var liveOverlays: [Overlay] = []   // mirrors App.overlays, for code outside App

private let physicsStart = CACurrentMediaTime()
private var fightSeen: CFTimeInterval?
private var scriptedKid = false
private var scriptedStarted = false, scriptedDropped = false, scriptedCar = false
private var physicsTicks = 0, physicsLast = CACurrentMediaTime()
private var lastMouse = NSEvent.mouseLocation, mouseV = CGVector.zero

extension App {
    /// Runs the animation once per display refresh (60 or 120 Hz on a ProMotion screen) so motion never beats against the screen.
    func startSnowPhysics() {
        balls.monitor()
        physicsLast = CACurrentMediaTime()
        if #available(macOS 14.0, *), let screen = NSScreen.main {
            screen.displayLink(target: self, selector: #selector(physicsFrame(_:))).add(to: .main, forMode: .common)
        } else {
            Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [unowned self] _ in self.physicsFrame(nil) }
        }
    }

    @objc func physicsFrame(_ link: Any?) {
        let now = CACurrentMediaTime(); let dt = CGFloat(min(0.05, now - physicsLast)); physicsLast = now
        liveOverlays = overlays
        balls.step(dt)
        Settings.ease(dt)
#if DEBUG   // development hooks: not in the release app
        if let spec = env["FLURRY_TRUCKDROP"]?.split(separator: ",").compactMap({ Double($0) }), spec.count == 3, let ov = overlays.first {   // dev only
            let t = CACurrentMediaTime() - physicsStart
            if t > 3, !scriptedStarted { scriptedStarted = true; ov.truck.startPileRun() }
            if t > spec[0], !scriptedDropped, ov.truck.visible { scriptedDropped = true; ov.truck.scriptedDrop(at: CGPoint(x: spec[1], y: spec[2])) }
        }
#endif
#if DEBUG   // development hooks: not in the release app
        if let spec = env["FLURRY_CARDROP"]?.split(separator: ",").compactMap({ Double($0) }), spec.count == 3, let ov = overlays.first {   // dev only
            let t = CACurrentMediaTime() - physicsStart
            if t > spec[0], !scriptedCar, ov.police1.visible { scriptedCar = true; ov.police1.scriptedDrop(at: CGPoint(x: spec[1], y: spec[2])) }
        }
#endif
#if DEBUG   // development hooks: not in the release app
        if let spec = env["FLURRY_KIDDROP"]?.split(separator: ",").compactMap({ Double($0) }), spec.count == 3, let ov = overlays.first {   // dev only
            if !ov.ground.fight.isIdle { if fightSeen == nil { fightSeen = CACurrentMediaTime() } }
            if let s0 = fightSeen, CACurrentMediaTime() - s0 > spec[0], !scriptedKid { scriptedKid = true; ov.ground.fight.scriptedDrop(at: CGPoint(x: spec[1], y: spec[2])) }
        }
#endif
        for ov in overlays {                                    // the truck: runs, and takes the mouse only while the pointer is on it
            if self.current == .snow { ov.truck.step(dt); ov.truck2.step(dt); ov.police1.step(dt); ov.police2.step(dt) }
            let trucks = [ov.truck!, ov.truck2!]
            let cars = [ov.police1!, ov.police2!], mouse = NSEvent.mouseLocation
            let want = self.current == .snow && (trucks.contains { $0.mode == .carried || $0.hit(mouse) } || cars.contains { $0.mode == .carried || $0.hit(mouse) } || ov.ground.fight.hit(mouse))
            if ov.ignoresMouseEvents == want { ov.ignoresMouseEvents = !want }
        }
        liveCaps.tick(overlays: overlays)           // window caps and cut-outs update every frame, in step with the screen
        liveCaps.stepClumps(dt)
        var m = NSEvent.mouseLocation                           // the pointer's speed, smoothed
#if DEBUG   // development hooks: not in the release app
        if env["FLURRY_FAKECURSOR"] != nil, let f = self.overlays.first?.frame {   // dev only: a pointer that drags through the pile
            let t = CGFloat(CACurrentMediaTime()).truncatingRemainder(dividingBy: 1000)
            m = CGPoint(x: f.minX + 700 + 450 * sin(t * 0.9), y: f.minY + 7)
        }
#endif
        let raw = CGVector(dx: (m.x - lastMouse.x) / max(dt, 0.001), dy: (m.y - lastMouse.y) / max(dt, 0.001)); lastMouse = m
        mouseV = CGVector(dx: mouseV.dx * 0.6 + raw.dx * 0.4, dy: mouseV.dy * 0.6 + raw.dy * 0.4)
        if self.current == .snow {
            for ov in overlays where ov.frame.contains(m) {
                ov.ground.interact(cursor: CGPoint(x: m.x - ov.frame.minX, y: m.y - ov.frame.minY), velocity: mouseV)
            }
        }
        physicsTicks += 1
        if physicsTicks % 120 == 0 {                      // about every second or two
            self.overlays.forEach { $0.ground.refresh() }
            if self.current != .none { self.overlays.forEach { $0.orderFrontRegardless() } }   // stay on whichever Space/full-screen app is active
        }
        self.overlays.forEach { $0.ground.step(dt, active: self.current == .snow) }
        if self.current == .snow { self.overlays.forEach { $0.flakes?.step(dt, ground: $0.ground) } }
        if self.current == .rain { self.overlays.forEach { $0.rain?.step(dt, ground: $0.ground) } }
    }
}

/// Falling snowflakes, moved by hand (not by an emitter): each one falls until it lands on the pile or leaves the
/// bottom of the screen, so none can disappear half-way down.
/// Crisp by construction: sprites are drawn at their exact pixel size, pre-rotated (a flake looks the same every 60
/// degrees, so 15 frames cover a full turn) and always placed on whole screen pixels. Nothing is ever resampled.
final class FlakeField {
    private static let frames = 15
    private static let pxSizes: [Int] = [24, 32, 44, 60, 80]          // device pixels at scale 2
    private static var cache: [CGFloat: [[[CGImage]]]] = [:]          // [scale] -> [size class][shape][rotation frame]
    private struct F { let layer: CALayer; var x0: CGFloat; var y: CGFloat; var rot: CGFloat; var frame: Int
                       let cls: Int, shape: Int, vy: CGFloat, amp: CGFloat, freq: CGFloat, phase: CGFloat, spin: CGFloat, size: CGFloat }
    let container = CALayer()
    private var flakes: [F] = [], pool: [CALayer] = []
    private let weights: [Double] = [0.34, 0.30, 0.20, 0.11, 0.05]    // many small flakes, few big ones
    private let sprites: [[[CGImage]]]
    private let scale: CGFloat
    private let size: CGSize
    private let born = CACurrentMediaTime()
    private var carry: CGFloat = 0, time: CGFloat = 0

    init(size: CGSize, scale: CGFloat) {
        self.size = size; self.scale = scale
        container.frame = CGRect(origin: .zero, size: size)
        if let c = FlakeField.cache[scale] { sprites = c } else {
            let n = FlakeField.frames
            let built: [[[CGImage]]] = FlakeField.pxSizes.map { base in
                let px = max(8, Int(CGFloat(base) * scale / 2) / 2 * 2)                 // even pixel size
                return (1...10).map { seed in
                    (0..<n).compactMap { flakeSprite(seed: UInt64(seed), px: px, angle: CGFloat($0) * (.pi / 3) / CGFloat(n)) }
                }
            }
            FlakeField.cache[scale] = built; sprites = built
        }
    }

    private func spawn() {
        var r = Double.random(in: 0..<1), k = 0
        while k < weights.count - 1, r >= weights[k] { r -= weights[k]; k += 1 }
        let shape = Int.random(in: 0..<10), frame = Int.random(in: 0..<FlakeField.frames)
        let img = sprites[k][shape][frame]
        let s = CGFloat(img.width) / scale                              // size in points = image pixels / scale
        let l = pool.popLast() ?? CALayer()
        l.contentsScale = scale; l.contents = img; l.bounds = CGRect(x: 0, y: 0, width: s, height: s)
        l.magnificationFilter = .nearest; l.minificationFilter = .nearest      // 1:1 pixels, no smoothing
        l.opacity = Float(0.85 + 0.15 * Double(k) / Double(weights.count - 1)) // small = far away = a touch fainter
        container.addSublayer(l)
        flakes.append(F(layer: l, x0: .random(in: -20...(size.width + 20)), y: size.height + s, rot: CGFloat(frame) * (.pi / 3) / CGFloat(FlakeField.frames),
                        frame: frame, cls: k, shape: shape,
                        vy: 26 + s * 2.4 + .random(in: 0...16), amp: .random(in: 4...16), freq: .random(in: 0.4...1.2),
                        phase: .random(in: 0...6.28), spin: .random(in: -1.0...1.0), size: s))
    }

    func step(_ dt: CGFloat, ground: Ground) {
        time += dt
        let ramp = 0.15 + 0.85 * min(1, (CACurrentMediaTime() - born) / flurryGrow)   // snowfall thickens over time
        carry += CGFloat(ramp) * flakesPerSecond * Settings.f("snowDensity") * dt
        let turn = CGFloat.pi / 3, n = FlakeField.frames
        CATransaction.begin(); CATransaction.setDisableActions(true)   // no implicit animations: a recycled layer must not cross-fade or slide
        while carry >= 1 { carry -= 1; spawn() }
        var i = 0
        while i < flakes.count {
            var f = flakes[i]
            f.y -= f.vy * dt; f.rot += f.spin * dt; f.x0 += 5 * dt                    // gentle wind to the right
            let x = f.x0 + sin(time * f.freq + f.phase) * f.amp                       // sway
            var done = f.y < -f.size                                                  // fell past the bottom of the screen
            if let top = ground.surface(atX: x), f.y - f.size * 0.35 <= top {         // landed: it becomes part of the pile
                done = true; ground.deposit(atX: x)
            }
            if done { f.layer.removeFromSuperlayer(); pool.append(f.layer); flakes.remove(at: i); continue }
            var a = f.rot.truncatingRemainder(dividingBy: turn); if a < 0 { a += turn }   // 60-degree symmetry
            let fr = min(n - 1, Int(a / turn * CGFloat(n)))
            if fr != f.frame { f.frame = fr; f.layer.contents = sprites[f.cls][f.shape][fr] }
            let ox = ((x - f.size / 2) * scale).rounded() / scale                     // snap to whole device pixels
            let oy = ((f.y - f.size / 2) * scale).rounded() / scale
            f.layer.position = CGPoint(x: ox + f.size / 2, y: oy + f.size / 2)
            flakes[i] = f; i += 1
        }
        CATransaction.commit()
    }
}
