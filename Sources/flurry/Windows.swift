import AppKit
import QuartzCore

/// Menu option: hide falling snow where an app window is (off by default, so snow reaches the ground over every window).
let hideBehindWindows = true   // snow stays behind open windows (and tabs): nothing is drawn over a window's contents

/// Snow that settles on the top edge of every visible app window as an uneven mound that slowly grows.
/// Also cuts falling snow out of window contents, so it lands on the cap instead of passing through.
/// Desktop widgets: Apple fixes their sizes, so their card shape is measured once from a widget's own pixels
/// (screencapture of the widget window) instead of guessed. The window is bigger than the visible card by an
/// invisible margin, and the card's corner is a smooth curve, not a circle.
/// Corner profile of a plain circular corner, in the same format as `Widget.profile` (edge inset per 0.5 pt below the top).
func circleProfile(_ r: CGFloat) -> [CGFloat] {
    (0...Int(r * 2)).map { i in let k = r - CGFloat(i) * 0.5; return r - sqrt(max(0, r * r - k * k)) }
}

/// Ordinary windows: corner radius measured from a VS Code window's own pixels (smooth curve, about 17 pt).
enum Window { static let corner: CGFloat = 17 }

enum Widget {
    static let insetX: CGFloat = 7.5, insetY: CGFloat = 8            // margin between window bounds and the card, in points
    /// How far the card edge sits in from the card's side, per 0.5 pt below the card's top (measured, 2x display).
    static let profile: [CGFloat] = [29.22, 23.52, 20.72, 18.77, 17.23, 15.96, 14.87, 13.9, 13.03, 12.27, 11.52, 10.85, 10.24, 9.64, 9.06, 8.51, 8.01, 7.53, 7.08, 6.66, 6.23, 5.81, 5.42, 5.1, 4.75, 4.39, 4.13, 3.82, 3.56, 3.3, 3.06, 2.83, 2.64, 2.39, 2.26, 2.06, 1.86, 1.78, 1.61, 1.42, 1.33, 1.27, 1.15, 0.98, 0.87, 0.83, 0.8, 0.75, 0.66, 0.55, 0.44, 0.38, 0.33, 0.31, 0.31, 0.3, 0.3, 0.28, 0.26, 0.24, 0.21, 0.18, 0.14, 0.1]
    static var corner: CGFloat { profile[0] }                         // the flat top edge starts this far in from each side
    /// Distance (pt) the card's top-left/right corner falls below its flat top edge, at distance `d` in from the side.
    static func drop(_ d: CGFloat) -> CGFloat {
        if d >= profile[0] { return 0 }
        for i in 1..<profile.count where profile[i] <= d {
            let t = (profile[i - 1] - d) / max(0.0001, profile[i - 1] - profile[i])
            return (CGFloat(i - 1) + t) * 0.5
        }
        return CGFloat(profile.count) * 0.5
    }
}

/// The one Caps instance, for code that needs the current window rectangles (the plough truck).
var liveCaps = Caps()

final class Caps {
    var enabled = false { didSet { if !enabled { clear() } } }
    private final class Cap {
        let box = CALayer(), fill = CAGradientLayer(), shape = CAShapeLayer(), rim = CAShapeLayer()
        var sparkles: [(layer: CALayer, fx: CGFloat)] = []
        let seed: CGFloat, since: CFTimeInterval
        var level: CGFloat = 0, shedCarry: CGFloat = 0     // how much snow is on the cap (0 bare, 1 deep)
        init(seed: CGFloat, since: CFTimeInterval) { self.seed = seed; self.since = since }
    }
    private var caps: [Int: Cap] = [:]
    /// Visible windows and widgets as of the last frame, in global screen coordinates (bottom-left origin). Things a truck can drive on.
    private(set) var surfaces: [(id: Int, rect: CGRect)] = []
    private var keep: [Int: [CGFloat]] = [:]                    // 1 = snow as normal, 0 = cleared by a truck; per 6 pt of width
    private let keepStep: CGFloat = 6

    /// A plough blade passed over x0...x1 (points from the window's left edge): clear the snow cap there.
    func clear(id: Int, from x0: CGFloat, to x1: CGFloat) -> (mass: CGFloat, depth: CGFloat) {
        guard var k = keep[id], let cap = caps[id] else { return (0, 0) }
        var mass: CGFloat = 0
        let i0 = max(0, Int(min(x0, x1) / keepStep)), i1 = min(k.count - 1, Int(max(x0, x1) / keepStep))
        if i0 <= i1 { for i in i0...i1 { mass += (k[i] - 0.08) * cap.level * 19 * keepStep * 0.5; k[i] = 0.08 } }
        keep[id] = k
        return (max(0, mass), cap.level * 19)
    }
    // snow that slid off a dragged window and is falling
    private struct Clump { let layer: CALayer; weak var ov: Overlay?; var x: CGFloat; var y: CGFloat; var vx: CGFloat; var vy: CGFloat; var age: CGFloat; let sway: CGFloat; let size: CGFloat }
    private var clumps: [Clump] = [], clumpPool: [CALayer] = []
    private var motion: [Int: (origin: CGPoint, size: CGSize, t: CFTimeInterval, v: CGVector)] = [:]
    private var lastTick = CACurrentMediaTime()
    private var fullRects: [CGRect] = []
    private var tickCount = 0, cachedAt = CACurrentMediaTime()
    private var cachedWins: [(id: Int, rect: CGRect, corner: CGFloat, widget: Bool)] = []
    private let growSeconds = flurryGrow
    #if DEBUG
    private let test = ProcessInfo.processInfo.environment["FLURRY_TEST"] != nil
    #else
    private let test = false
    #endif

    private var shedSprites: [[CGImage]] = []
    /// A real snowflake breaks off the top edge, thrown opposite to the drag. It then drifts down all the way to the ground.
    private func shed(from r: CGRect, ov: Overlay, host: CALayer, v: CGVector) {
        let scale = ov.screen?.backingScaleFactor ?? 2
        if shedSprites.isEmpty { shedSprites = [36, 50, 68].map { px in (1...10).compactMap { flakeSprite(seed: UInt64($0), px: Int(CGFloat(px) * scale / 2) / 2 * 2) } } }
        let img = shedSprites[Int.random(in: 0..<3)].randomElement()!
        let sz = CGFloat(img.width) / scale
        let l = clumpPool.popLast() ?? CALayer()
        l.contentsScale = scale; l.contents = img; l.bounds = CGRect(x: 0, y: 0, width: sz, height: sz)
        l.minificationFilter = .linear; l.magnificationFilter = .linear; l.opacity = 1
        ov.fly.addSublayer(l)
        clumps.append(Clump(layer: l, ov: ov, x: r.minX - ov.frame.minX + CGFloat.random(in: 0.04...0.96) * r.width,
                            y: r.maxY - ov.frame.minY + 2, vx: -v.dx * 0.35 + .random(in: -40...40),
                            vy: -v.dy * 0.3 + .random(in: 20...90), age: 0, sway: .random(in: 0...6.28), size: sz))
    }

    /// Thrown sideways at first, then air drag takes over and it floats down like any other flake. Lands on the pile
    /// (adding to it) or leaves the bottom of the screen. No time limit: it falls the whole way.
    func stepClumps(_ dt: CGFloat) {
        guard !clumps.isEmpty else { return }
        CATransaction.begin(); CATransaction.setDisableActions(true)
        var i = 0
        while i < clumps.count {
            var c = clumps[i]
            c.age += dt
            c.vx *= max(0, 1 - 2.2 * dt)                                         // the throw dies away
            c.vy += (-95 - c.vy) * min(1, 3.0 * dt)                              // settles to a flake's slow fall speed
            c.x += (c.vx + sin(c.age * 2.3 + c.sway) * 14) * dt; c.y += c.vy * dt
            var gone = c.y < -c.size || c.ov == nil || c.age > 60
            if let ov = c.ov, let top = ov.ground.surface(atX: c.x), c.y - c.size * 0.35 <= top, c.vy < 0 { ov.ground.deposit(atX: c.x); gone = true }
            if gone { c.layer.removeFromSuperlayer(); clumpPool.append(c.layer); clumps.remove(at: i); continue }
            let ox = ((c.x - c.size / 2) * 2).rounded() / 2, oy = ((c.y - c.size / 2) * 2).rounded() / 2   // whole pixels: stays sharp
            c.layer.position = CGPoint(x: ox + c.size / 2, y: oy + c.size / 2); clumps[i] = c; i += 1
        }
        CATransaction.commit()
    }

    func clear() {
        clumps.forEach { $0.layer.removeFromSuperlayer() }; clumps = []
        caps.values.forEach { $0.box.removeFromSuperlayer() }
        caps = [:]
        liveOverlays.forEach { $0.scene.mask = nil }
    }

    /// Visible windows, front to back, in AppKit global coordinates (bottom-left origin). Includes desktop widgets
    /// (windows of "Notification Center" at the special desktop-widget level), which get rounder corners.
    private func windows() -> [(id: Int, rect: CGRect, corner: CGFloat, widget: Bool)] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]],
              let primaryH = NSScreen.screens.first?.frame.height else { return [] }
        var fulls: [CGRect] = []                       // maximised, screen-sized windows: no cap of their own, but they still hide snow
        var out: [(id: Int, rect: CGRect, corner: CGFloat, widget: Bool)] = list.compactMap { w in
            let layer = w[kCGWindowLayer as String] as? Int ?? 0
            let widget = (w[kCGWindowOwnerName as String] as? String) == "Notification Center" && layer < -1_000_000_000
            guard layer == 0 || widget || (test && layer == 3),
                  (w[kCGWindowAlpha as String] as? Double ?? 1) > 0.1,
                  let id = w[kCGWindowNumber as String] as? Int,
                  let b = w[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = b["X"], let y = b["Y"], let width = b["Width"], let h = b["Height"],
                  width > 120, h > 80
            else { return nil }
            if !widget, NSScreen.screens.contains(where: { width >= $0.frame.width - 2 && h >= $0.frame.height - 40 }) {
                fulls.append(CGRect(x: x, y: primaryH - y - h, width: width, height: h)); return nil
            }
            var r = CGRect(x: x, y: primaryH - y - h, width: width, height: h)
            if widget { r = r.insetBy(dx: Widget.insetX, dy: Widget.insetY) }   // the reported bounds include an invisible margin around the card
            return (id, r, widget ? Widget.corner : Window.corner, widget)
        }
#if DEBUG   // development hooks: not in the release app
        if let f = ProcessInfo.processInfo.environment["FLURRY_FAKEWIDGET"] {   // dev only: stand-in widget "x,y,w,h" (top-left origin)
            let v = f.split(separator: ",").compactMap { Double($0) }
            if v.count == 4 { out.insert((999_001, CGRect(x: v[0], y: primaryH - v[1] - v[3], width: v[2], height: v[3]), Widget.corner, true), at: 0) }
        }
#endif
        fullRects = fulls
        return out
    }

    func tick(overlays: [Overlay]) {
        guard enabled else { return }
        let now = CACurrentMediaTime()
        let dtTick = CGFloat(min(0.1, now - lastTick)); lastTick = now
        // The system window list is slow, so read it every other frame and move windows by their speed in between.
        tickCount += 1
        if tickCount % 2 == 1 || cachedWins.isEmpty { cachedWins = windows(); cachedAt = now }
        let ahead = CGFloat(min(0.05, now - cachedAt))
        surfaces = cachedWins.map { ($0.id, $0.rect) }
        let wins = cachedWins.map { w -> (id: Int, rect: CGRect, corner: CGFloat, widget: Bool) in
            guard let m = motion[w.id] else { return w }
            return (w.id, w.rect.offsetBy(dx: m.v.dx * ahead, dy: m.v.dy * ahead), w.corner, w.widget)
        }
        CATransaction.begin(); CATransaction.setDisableActions(true)
        for id in Set(caps.keys).subtracting(wins.map { $0.id }) { caps[id]?.box.removeFromSuperlayer(); caps[id] = nil }

        for (i, w) in wins.enumerated() {
            guard let ov = overlays.first(where: { $0.frame.contains(CGPoint(x: w.rect.midX, y: w.rect.maxY)) })
                    ?? overlays.first(where: { $0.frame.intersects(w.rect) }),
                  let host = Optional(ov.scene) else { continue }
            if caps[w.id] == nil { caps[w.id] = makeCap(seed: CGFloat(w.id % 97), since: now) }
            let kn = Int(w.rect.width / keepStep) + 2
            if keep[w.id]?.count != kn { keep[w.id] = Array(repeating: 1, count: kn) }
            for i in 0..<kn where keep[w.id]![i] < 1 { keep[w.id]![i] = min(1, keep[w.id]![i] + dtTick / 90) }   // cleared snow slowly builds back
            let cap = caps[w.id]!
            if cap.box.superlayer !== host { host.addSublayer(cap.box) }

            // How fast is this window moving? Drag it and the snow on top cannot keep up: it slides off the other way.
            var v = motion[w.id]?.v ?? .zero
            if cachedAt == now, let raw = cachedWins.first(where: { $0.id == w.id })?.rect {      // fresh reading: update the speed
                if let m = motion[w.id], now > m.t, m.size == raw.size {
                    let dt = CGFloat(now - m.t)
                    v = CGVector(dx: m.v.dx * 0.4 + (raw.origin.x - m.origin.x) / dt * 0.6, dy: m.v.dy * 0.4 + (raw.origin.y - m.origin.y) / dt * 0.6)
                }
                motion[w.id] = (raw.origin, raw.size, now, v)
            }
            // The cap starts bare and slowly builds. Its final depth follows the snow-density slider, and it builds faster
            // when it snows harder. (After being shaken off by a drag it builds back the same way.)
            let dens = Settings.f("snowDensity"), capTarget = Settings.depthFraction(dens)
            if cap.level < capTarget { cap.level = min(capTarget, cap.level + 0.7 * dens / CGFloat(growSeconds) * dtTick) }   // builds in proportion to the snowfall
            else if cap.level > capTarget { cap.level = max(capTarget, cap.level - 0.7 * 1.5 / CGFloat(growSeconds) * dtTick) }   // lower density: melts back slowly
            let speed = hypot(v.dx, v.dy)
            if speed > 90, cap.level > 0 {
                let loss = min(cap.level, speed / 1000 * dtTick * 0.9); cap.level -= loss
                cap.shedCarry += loss * 22 * w.rect.width / 400
                while cap.shedCarry >= 1 { cap.shedCarry -= 1; shed(from: w.rect, ov: ov, host: host, v: v) }
            }
            let fast = min(1, max(0, (speed - 250) / 350))                                   // 0 slow ... 1 fast drag
            if fast > 0 { cap.level = max(0, cap.level - fast * 2.2 * dtTick) }                // fast drag shakes the cap clean
            let depth = (0.4 + 19 * cap.level) * (1 - fast)                                // 0 at first, up to about 19 pt at full density
            let front = wins[0..<i].map { $0.rect } + (w.widget ? fullRects : [])  // windows above this one (a maximised window covers widgets)
            let topY = w.rect.maxY, width = w.rect.width

            // 1. The card's own outline in cap-local points (y up, flat top edge at y = 0): down the left corner, along the
            //    top, down the right corner. Widgets use their measured corner curve; ordinary windows a plain rounded one.
            let prof = w.widget ? Widget.profile : circleProfile(w.corner)
            let reach = min(prof.count - 1, 36)                                     // snow wraps 18 pt down each corner
            var edge: [CGPoint] = []
            for k in stride(from: reach, through: 0, by: -1) { edge.append(CGPoint(x: prof[k], y: -CGFloat(k) * 0.5)) }
            var fx = prof[0] + 3
            while fx < width - prof[0] { edge.append(CGPoint(x: fx, y: 0)); fx += 3 }
            for k in 0...reach { edge.append(CGPoint(x: width - prof[k], y: -CGFloat(k) * 0.5)) }

            // 2. Arclength along the outline, outward normals, and the snow's thickness at every point.
            var arc: [CGFloat] = [0]
            for k in 1..<edge.count { arc.append(arc[k - 1] + hypot(edge[k].x - edge[k - 1].x, edge[k].y - edge[k - 1].y)) }
            let total = arc[edge.count - 1]
            struct P { var p: CGPoint; var n: CGVector; var h: CGFloat; var hidden: Bool }
            var pts: [P] = []
            for k in 0..<edge.count {
                let a = edge[max(0, k - 1)], b = edge[min(edge.count - 1, k + 1)]
                let l = max(0.0001, hypot(b.x - a.x, b.y - a.y))
                let n = CGVector(dx: -(b.y - a.y) / l, dy: (b.x - a.x) / l)         // outward normal
                let u = arc[k], e = min(1, min(u, total - u) / 9); let taper = e * e * (3 - 2 * e)   // thins to nothing at both ends
                let noise = 0.5 + 0.30 * sin(u * 0.037 + cap.seed) + 0.20 * sin(u * 0.11 + cap.seed * 2)
                          + 0.12 * sin(u * 0.29 + cap.seed * 3) + 0.07 * sin(u * 0.71 + cap.seed * 5)   // uneven: drifts, lumps, bumps
                let gx = w.rect.minX + edge[k].x + n.dx, gy = topY + edge[k].y + n.dy
                let hidden = front.contains { $0.minX <= gx && gx <= $0.maxX && $0.minY <= gy && gy <= $0.maxY }
                let kp = keep[w.id]![max(0, min(kn - 1, Int(edge[k].x / keepStep)))]
                pts.append(P(p: edge[k], n: n, h: hidden ? 0 : depth * max(0.12, noise) * taper * kp, hidden: hidden))
            }

            // 3. Snow band = outline pushed outward by the thickness. Covered stretches draw nothing at all.
            let fillPath = CGMutablePath(), rimPath = CGMutablePath()
            var run: [P] = []
            func flush() {
                if run.count > 1 {
                    fillPath.move(to: CGPoint(x: run[0].p.x + run[0].n.dx * run[0].h, y: run[0].p.y + run[0].n.dy * run[0].h))
                    for r in run.dropFirst() { fillPath.addLine(to: CGPoint(x: r.p.x + r.n.dx * r.h, y: r.p.y + r.n.dy * r.h)) }
                    for r in run.reversed() { fillPath.addLine(to: r.p) }               // the inner edge IS the card's edge
                    fillPath.closeSubpath()
                    var drawing = false                                                 // glow only where the snow has real thickness
                    for r in run {
                        let o = CGPoint(x: r.p.x + r.n.dx * r.h, y: r.p.y + r.n.dy * r.h)
                        if r.h < 1.6 { drawing = false; continue }
                        if drawing { rimPath.addLine(to: o) } else { rimPath.move(to: o); drawing = true }
                    }
                }
                run = []
            }
            for q in pts { if q.hidden { flush() } else { run.append(q) } }
            flush()

            // Layers are bigger than the card so the snow can wrap down the corners; paths are shifted by the padding.
            let pad: CGFloat = 40
            cap.box.frame = CGRect(x: w.rect.minX - ov.frame.minX, y: topY - ov.frame.minY, width: width, height: depth * 1.5)
            let big = CGRect(x: -pad, y: -pad, width: width + 2 * pad, height: depth * 1.5 + 2 * pad)
            cap.fill.frame = big; cap.rim.frame = big
            cap.shape.frame = CGRect(origin: .zero, size: big.size)      // a mask lives in the masked layer's own coordinates
            var shift = CGAffineTransform(translationX: pad, y: pad)
            cap.shape.path = fillPath.copy(using: &shift); cap.rim.path = rimPath.copy(using: &shift)
            for sp in cap.sparkles {                                                    // glints ride on the snow surface
                let q = pts[min(pts.count - 1, Int(sp.fx * CGFloat(pts.count)))]
                sp.layer.position = CGPoint(x: q.p.x + q.n.dx * q.h * 0.7, y: q.p.y + q.n.dy * q.h * 0.7 + 0.5)
                sp.layer.isHidden = q.h < 1.5
            }
        }

        for ov in overlays {   // everything snowy (flakes, pile, plough, kid, snowballs) stays behind open windows
            let em = ov.scene
            guard hideBehindWindows else { em.mask = nil; continue }
            // Cut out each window with its real rounded shape (a plain rectangle would also erase the snow that wraps the
            // empty corner patches). Union of all windows, then subtract from the whole screen.
            let shapes = CGMutablePath()
            for fr in fullRects {                                                   // maximised windows: plain rectangles
                let r = fr.intersection(ov.frame)
                if !r.isNull && r.width >= 2 { shapes.addRect(r.offsetBy(dx: -ov.frame.minX, dy: -ov.frame.minY)) }
            }
            for w in wins where !w.widget {
                let r = w.rect.intersection(ov.frame)
                if r.isNull || r.width < 2 { continue }
                shapes.addPath(CGPath(roundedRect: r.offsetBy(dx: -ov.frame.minX, dy: -ov.frame.minY),
                                      cornerWidth: Window.corner, cornerHeight: Window.corner, transform: nil))
            }
            let m = (em.mask as? CAShapeLayer) ?? CAShapeLayer()
            m.frame = em.bounds; m.fillColor = NSColor.black.cgColor
            let p = CGPath(rect: em.bounds, transform: nil).subtracting(shapes, using: .winding)
            m.path = p; em.mask = m
        }
        CATransaction.commit()
    }

    private func makeCap(seed: CGFloat, since: CFTimeInterval) -> Cap {
        let c = Cap(seed: seed, since: since)
        // Matte snow: soft off-white on top, cool blue-grey in the shade underneath. No glow, no sparkle.
        c.fill.colors = [NSColor(calibratedRed: 0.93, green: 0.95, blue: 0.98, alpha: 1).cgColor,
                         NSColor(calibratedRed: 0.74, green: 0.81, blue: 0.91, alpha: 1).cgColor]
        c.fill.startPoint = CGPoint(x: 0.5, y: 1); c.fill.endPoint = CGPoint(x: 0.5, y: 0)
        c.fill.mask = c.shape
        c.rim.fillColor = nil; c.rim.strokeColor = NSColor(calibratedRed: 0.97, green: 0.98, blue: 1, alpha: 0.85).cgColor
        c.rim.lineWidth = 0.9; c.rim.lineJoin = .round          // a thin lit edge, no halo
        c.box.addSublayer(c.fill); c.box.addSublayer(c.rim)
        return c
    }

}
