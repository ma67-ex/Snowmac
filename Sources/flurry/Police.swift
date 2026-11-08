import AppKit
import QuartzCore

/// Anything on the road that the kid has to keep clear of.
protocol Vehicle: AnyObject {
    var visible: Bool { get }
    var span: ClosedRange<CGFloat> { get }
}
extension Truck: Vehicle {}

/// A white police SUV with a blue stripe and a flashing red and blue light bar, facing right (side view, wheels on y = 0).
/// Drawn in code to match a reference picture of a police SUV.
func policeImage() -> CGImage? {
    let sc: CGFloat = 4, W: CGFloat = 96, H: CGFloat = 44
    guard let ctx = CGContext(data: nil, width: Int(W * sc), height: Int(H * sc), bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    ctx.scaleBy(x: sc, y: sc); ctx.setLineCap(.round); ctx.setLineJoin(.round)
    func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor { NSColor(calibratedRed: r, green: g, blue: b, alpha: a).cgColor }
    func poly(_ pts: [CGPoint], _ c: CGColor) { ctx.setFillColor(c); ctx.move(to: pts[0]); for q in pts.dropFirst() { ctx.addLine(to: q) }; ctx.closePath(); ctx.fillPath() }
    func box(_ r: CGRect, _ rad: CGFloat, _ c: CGColor) { ctx.setFillColor(c); ctx.addPath(CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil)); ctx.fillPath() }
    func disc(_ c: CGPoint, _ r: CGFloat, _ col: CGColor) { ctx.setFillColor(col); ctx.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)) }
    let white = rgb(0.97, 0.97, 0.98), shade = rgb(0.80, 0.82, 0.86), blue = rgb(0.10, 0.25, 0.55), black = rgb(0.08, 0.08, 0.09)
    disc(CGPoint(x: 5.5, y: 25), 5.5, black); disc(CGPoint(x: 5.5, y: 25), 3, rgb(0.2, 0.2, 0.22))        // spare tire on the back door
    poly([CGPoint(x: 6, y: 13), CGPoint(x: 6, y: 25), CGPoint(x: 14, y: 27), CGPoint(x: 21, y: 35), CGPoint(x: 65, y: 35), CGPoint(x: 78, y: 27),
          CGPoint(x: 93, y: 25), CGPoint(x: 95, y: 20), CGPoint(x: 95, y: 13)], white)                      // body
    poly([CGPoint(x: 6, y: 13), CGPoint(x: 95, y: 13), CGPoint(x: 95, y: 16), CGPoint(x: 6, y: 16)], shade) // lower sill
    poly([CGPoint(x: 24, y: 28), CGPoint(x: 29, y: 33.5), CGPoint(x: 47, y: 33.5), CGPoint(x: 47, y: 28)], rgb(0.16, 0.18, 0.22))   // windows
    poly([CGPoint(x: 49.5, y: 28), CGPoint(x: 49.5, y: 33.5), CGPoint(x: 64, y: 33.5), CGPoint(x: 73, y: 28)], rgb(0.16, 0.18, 0.22))
    poly([CGPoint(x: 25, y: 28), CGPoint(x: 29, y: 32.5), CGPoint(x: 34, y: 32.5), CGPoint(x: 30, y: 28)], rgb(0.30, 0.34, 0.42, 0.9))  // glass glint
    box(CGRect(x: 9, y: 19, width: 82, height: 3.6), 1.2, blue)                                              // blue stripe
    box(CGRect(x: 9, y: 22.6, width: 82, height: 0.9), 0.4, rgb(0.55, 0.65, 0.85))
    ctx.setStrokeColor(rgb(0.62, 0.64, 0.70)); ctx.setLineWidth(0.5)                                         // door seams and handles
    for dx in [CGFloat(47.5), 31] { ctx.move(to: CGPoint(x: dx, y: 15)); ctx.addLine(to: CGPoint(x: dx, y: 28)); ctx.strokePath() }
    box(CGRect(x: 40, y: 25, width: 4, height: 1.2), 0.5, rgb(0.3, 0.3, 0.33))
    disc(CGPoint(x: 58, y: 22), 1.7, rgb(0.78, 0.8, 0.86))                                                   // badge
    box(CGRect(x: 36, y: 35, width: 30, height: 2.4), 1, rgb(0.12, 0.12, 0.14))                              // light bar base
    box(CGRect(x: 37, y: 36.4, width: 13, height: 3.4), 1.4, rgb(0.20, 0.35, 0.95))                          // blue lens
    box(CGRect(x: 52, y: 36.4, width: 13, height: 3.4), 1.4, rgb(0.95, 0.20, 0.20))                          // red lens
    box(CGRect(x: 93, y: 12, width: 3.4, height: 12), 1.2, black)                                            // push bar
    box(CGRect(x: 92.2, y: 19.5, width: 3.2, height: 2.6), 1, rgb(1, 0.95, 0.7))                             // headlight
    box(CGRect(x: 6, y: 20, width: 2.2, height: 5), 0.8, rgb(0.9, 0.15, 0.15))                               // tail light
    for cx in [CGFloat(22), 71] {                                                                            // wheels with arches
        disc(CGPoint(x: cx, y: 10), 11.4, black)
        disc(CGPoint(x: cx, y: 9), 9.6, rgb(0.07, 0.07, 0.08)); disc(CGPoint(x: cx, y: 9), 6.2, rgb(0.62, 0.64, 0.68))
        disc(CGPoint(x: cx, y: 9), 3.4, rgb(0.22, 0.23, 0.26)); disc(CGPoint(x: cx, y: 9), 1.2, rgb(0.7, 0.72, 0.76))
    }
    return ctx.makeImage()
}

/// A police SUV that escorts a truck: same speed, a set gap behind it, red and blue lights flashing. It rides the top of the
/// snow (front and rear wheel on the surface) like the lead truck does.
final class Police: Vehicle {
    private let size = CGSize(width: 96, height: 44)
    private let layer = CALayer(), blueGlow = CALayer(), redGlow = CALayer(), frontBlue = CALayer()
    private weak var ov: Overlay?
    enum Mode { case hidden, driving, carried, falling }
    private(set) var mode = Mode.hidden {
        didSet { if mode != oldValue, ProcessInfo.processInfo.environment["FLURRY_DEBUG"] != nil { FileHandle.standardError.write(Data("police \(oldValue) -> \(mode) at x=\(Int(x)) y=\(Int(y)) surface=\(surface)\n".utf8)) } }
    }
    private enum Surface { case pile, window(Int) }
    private var surface = Surface.pile
    private var x: CGFloat = 0, y: CGFloat = 0, rot: CGFloat = 0, passTime: CGFloat = 0
    private var vx: CGFloat = 0, vy: CGFloat = 0, spin: CGFloat = 0, fellFrom: Int?
    private var tipAngle: CGFloat = 0, tipV: CGFloat = 0, tipPivotX: CGFloat = 0
    private var grab = CGPoint.zero, dragV = CGVector.zero, lastDrag = CACurrentMediaTime()
    var visible: Bool { mode != .hidden }
    var span: ClosedRange<CGFloat> { x...(x + size.width) }
    var length: CGFloat { size.width }

    init(overlay: Overlay) {
        ov = overlay
        layer.bounds = CGRect(origin: .zero, size: size); layer.anchorPoint = CGPoint(x: 0.5, y: 0.2)
        layer.contents = policeImage(); layer.contentsScale = 4; layer.minificationFilter = .trilinear; layer.isHidden = true
        func glow(_ l: CALayer, at p: CGPoint, color: NSColor, w: CGFloat, h: CGFloat, phase: Bool) {
            l.bounds = CGRect(x: 0, y: 0, width: w, height: h); l.position = p; l.cornerRadius = h / 2
            l.backgroundColor = color.cgColor
            l.shadowColor = color.cgColor; l.shadowOpacity = 1; l.shadowRadius = 9; l.shadowOffset = .zero
            let a = CAKeyframeAnimation(keyPath: "opacity")        // two quick flashes, then a pause; red and blue take turns
            a.values = phase ? [1, 0.05, 1, 0.05, 0.05, 0.05] : [0.05, 1, 0.05, 1, 0.05, 0.05]
            a.keyTimes = [0, 0.2, 0.4, 0.6, 0.8, 1]; a.calculationMode = .discrete; a.duration = 0.7; a.repeatCount = .infinity
            l.add(a, forKey: "flash"); layer.addSublayer(l)
        }
        glow(blueGlow, at: CGPoint(x: 43.5, y: 39), color: NSColor(calibratedRed: 0.25, green: 0.45, blue: 1, alpha: 1), w: 15, h: 5, phase: true)
        glow(redGlow, at: CGPoint(x: 58.5, y: 39), color: NSColor(calibratedRed: 1, green: 0.2, blue: 0.2, alpha: 1), w: 15, h: 5, phase: false)
        glow(frontBlue, at: CGPoint(x: 94, y: 21), color: NSColor(calibratedRed: 0.25, green: 0.45, blue: 1, alpha: 1), w: 3, h: 3, phase: true)
        overlay.fly.addSublayer(layer)
    }

    func start(atX sx: CGFloat) {
        guard let ov = ov else { return }
        x = sx; y = ov.ground.baseY - 1; rot = 0; passTime = 0; surface = .pile; vx = 0; vy = 0; spin = 0; tipAngle = 0; tipV = 0
        mode = .driving; layer.isHidden = false
    }

    // MARK: mouse (same as the truck: pick it up, carry it, drop it)

    func hit(_ p: CGPoint) -> Bool {
        guard mode != .hidden, let ov = ov, ov.frame.contains(p) else { return false }
        return CGRect(x: x - 4, y: y - 4, width: size.width + 8, height: size.height + 8).contains(CGPoint(x: p.x - ov.frame.minX, y: p.y - ov.frame.minY))
    }
    func beginDrag(at l: CGPoint) {
        guard mode != .hidden else { return }
        grab = CGPoint(x: l.x - x, y: l.y - y); mode = .carried; rot = 0.1; vx = 0; vy = 0; spin = 0; dragV = .zero; lastDrag = CACurrentMediaTime()
        NSCursor.closedHand.set()
    }
    /// Dev only: pick up, carry and drop without a mouse.
    func scriptedDrop(at l: CGPoint) { beginDrag(at: CGPoint(x: x + 40, y: y + 15)); drag(to: l); dragV = .zero; endDrag() }

    func drag(to l: CGPoint) {
        guard mode == .carried else { return }
        let nx = l.x - grab.x, ny = l.y - grab.y, now = CACurrentMediaTime(), dt = CGFloat(max(0.004, now - lastDrag)); lastDrag = now
        dragV = CGVector(dx: dragV.dx * 0.5 + (nx - x) / dt * 0.5, dy: dragV.dy * 0.5 + (ny - y) / dt * 0.5)
        x = nx; y = ny; rot = max(-0.3, min(0.3, 0.1 - dragV.dx * 0.0002))
    }
    func endDrag() {                                                      // let go: it falls, keeping the speed of the throw
        guard mode == .carried else { return }
        mode = .falling; fellFrom = nil
        vx = max(-900, min(900, dragV.dx * 0.8)); vy = max(-300, min(900, dragV.dy * 0.8)); spin = -rot * 3; dragV = .zero
        NSCursor.arrow.set()
    }

    private func tipCentre() -> CGPoint {
        let vx0 = x + size.width / 2 - tipPivotX, vy0 = size.height * 0.2, c = cos(rot), s = sin(rot)
        return CGPoint(x: tipPivotX + vx0 * c - vy0 * s, y: y + vx0 * s + vy0 * c)
    }

    // MARK: per frame

    func step(_ dt: CGFloat) {
        guard mode != .hidden, let ov = ov else { return }
        switch mode {
        case .hidden: return
        case .carried: break
        case .falling:
            vy -= 1700 * dt; x += vx * dt; y += vy * dt; rot += spin * dt
            let cx = x + size.width / 2
            let below = driveFloors(ov).filter { $0.id != fellFrom && cx >= $0.x0 && cx <= $0.x1 && y <= $0.top && ($0.top - y) < 60 + abs(vy) * dt }
            if vy < 0, let land = below.max(by: { $0.top < $1.top }) {
                y = land.top; rot = 0; spin = 0; vx = 0; vy = 0; fellFrom = nil
                surface = land.id.map { .window($0) } ?? .pile
                passTime = 1.2; mode = .driving
            }
            if y < -size.height * 2 { mode = .hidden; layer.isHidden = true }
        case .driving:
            passTime += dt
            let e = min(1, passTime / 2.2), ease = e * e * (3 - 2 * e)
            let speed = 40 + 160 * ease                                  // the same speed curve as the trucks, so the gaps stay put
            x += (tipAngle > 0 ? speed * 0.35 : speed) * dt
            let g = ov.ground, k = min(1, dt * 14)
            switch surface {
            case .pile:                                                  // ride the top of the snow, front and rear wheel on its surface
                let hr = (g.surface(atX: x + 22) ?? g.baseY) - g.baseY, hf = (g.surface(atX: x + 71) ?? g.baseY) - g.baseY
                y += (g.baseY - 1 + (hr + hf) / 2 - y) * k; rot += (atan2(hf - hr, 49) - rot) * k
                if x > ov.frame.width + 60 { mode = .hidden; layer.isHidden = true; return }
            case .window(let id):
                guard let s = liveCaps.surfaces.first(where: { $0.id == id }) else { mode = .falling; vx = speed * 0.6; vy = 100; spin = -3; fellFrom = id; break }
                y = s.rect.maxY - ov.frame.minY
                let x1 = s.rect.maxX - ov.frame.minX
                if x + 71 > x1 || tipAngle > 0 {                       // front wheel over the edge: pivot on the edge and lean nose-down
                    if tipAngle == 0 { tipPivotX = x1 }
                    tipV += 10 * (1 + 2 * tipAngle) * dt; tipAngle += tipV * dt; rot = -tipAngle
                    if x + 22 > x1 || tipAngle > 0.5 {                   // rear wheels over too, or leant far enough: topple off
                        let c = tipCentre(); x = c.x - size.width / 2; y = c.y - size.height * 0.2
                        rot = -tipAngle; spin = -max(2, tipV * 1.2); vx = max(60, speed * 0.4); vy = 0; fellFrom = id
                        tipAngle = 0; tipV = 0; mode = .falling
                    }
                }
            }
        }
        CATransaction.begin(); CATransaction.setDisableActions(true)
        layer.isHidden = false
        layer.position = (mode == .driving && tipAngle > 0) ? tipCentre() : CGPoint(x: x + size.width / 2, y: y + size.height * 0.2)
        layer.transform = CATransform3DMakeRotation(rot, 0, 0, 1)
        CATransaction.commit()
    }
}
