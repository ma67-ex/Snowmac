import AppKit
import QuartzCore

/// The snowplough. It can be picked up with the mouse and dropped anywhere:
///  - on the snow pile (or the bare screen bottom) it clears the pile as it drives along,
///  - on the top edge of a window, tab bar or widget it clears that snow cap instead,
///  - when it reaches the end of a window it drives off, tumbles, lands below and drives home along the screen bottom.
/// It lives in the overlay's front layer, so it is never hidden behind a window.
final class Truck {
    enum Mode { case hidden, driving, carried, falling }
    private(set) var mode = Mode.hidden {
        didSet { if mode != oldValue, ProcessInfo.processInfo.environment["FLURRY_DEBUG"] != nil { FileHandle.standardError.write(Data("truck \(oldValue) -> \(mode) at x=\(Int(x)) y=\(Int(y)) surface=\(surface)\n".utf8)) } }
    }
    private enum Surface { case pile, window(Int) }
    private let size = CGSize(width: 140, height: 64), bladeX: CGFloat = 137, speedMax: CGFloat = 200
    private let layer = CALayer(), ball = CALayer(), beacon = CALayer()
    private weak var ov: Overlay?
    private var surface = Surface.pile
    private var x: CGFloat = 0, y: CGFloat = 0                 // left edge and wheel line, overlay-local points
    private var vx: CGFloat = 0, vy: CGFloat = 0, rot: CGFloat = 0, spin: CGFloat = 0
    private var passTime: CGFloat = 0, collected: CGFloat = 0, ballAngle: CGFloat = 0, sprayCarry: CGFloat = 0
    private var fellFrom: Int?
    private var tipAngle: CGFloat = 0, tipV: CGFloat = 0, tipPivotX: CGFloat = 0   // nose-down lean once the front wheel is past an edge
    /// A rider rolls along the TOP of the snow, up and down its humps. A plower works low and pushes the snow away.
    private(set) var rides = true
    private var keepFactor: CGFloat = 0.5                       // share of the snow left behind after the blade passes
    var span: ClosedRange<CGFloat> { x...(x + size.width) }     // where it is, left to right (overlay coordinates)
    private var grab = CGPoint.zero
    private var dragV = CGVector.zero, lastDrag = CACurrentMediaTime()   // how fast the pointer is carrying it
    private struct Spark { let layer: CALayer; var x: CGFloat; var y: CGFloat; var vx: CGFloat; var vy: CGFloat; var age: CGFloat; let life: CGFloat }
    private var sparks: [Spark] = [], pool: [CALayer] = []

    init(overlay: Overlay) {
        ov = overlay
        layer.bounds = CGRect(origin: .zero, size: size); layer.anchorPoint = CGPoint(x: 0.5, y: 0.25)
        layer.contents = truckImage(); layer.contentsScale = 4; layer.minificationFilter = .trilinear; layer.isHidden = true
        ball.contents = snowballImage(); ball.contentsScale = 2; ball.isHidden = true
        ball.shadowColor = NSColor(calibratedRed: 0.3, green: 0.4, blue: 0.6, alpha: 1).cgColor; ball.shadowOpacity = 0.35; ball.shadowRadius = 2; ball.shadowOffset = CGSize(width: 0, height: -1)
        // Yellow safety light on the cab roof, like a road-works truck: a dome with a soft flash (no sound).
        beacon.bounds = CGRect(x: 0, y: 0, width: 9, height: 6); beacon.position = CGPoint(x: 89, y: 48.5)
        beacon.backgroundColor = NSColor(calibratedRed: 1, green: 0.82, blue: 0.05, alpha: 1).cgColor; beacon.cornerRadius = 3
        beacon.shadowColor = NSColor(calibratedRed: 1, green: 0.85, blue: 0.1, alpha: 1).cgColor; beacon.shadowOpacity = 1; beacon.shadowRadius = 7; beacon.shadowOffset = .zero
        let blink = CAKeyframeAnimation(keyPath: "opacity"); blink.values = [1, 1, 0.12, 0.12, 1]; blink.keyTimes = [0, 0.45, 0.55, 0.9, 1]
        blink.duration = 0.9; blink.repeatCount = .infinity
        beacon.add(blink, forKey: "blink")
        layer.addSublayer(beacon); layer.addSublayer(ball)
        overlay.fly.addSublayer(layer)
    }

    var visible: Bool { mode != .hidden }

    /// Scheduled run: enters from the left edge and clears the pile.
    func startPileRun(rides r: Bool = true, keep: CGFloat = 0.5, startX: CGFloat = -140) {
        guard mode == .hidden, let ov = ov else { return }
        rides = r; keepFactor = keep
        surface = .pile; x = startX; y = ov.ground.baseY - 1; rot = 0
        resetPass(); mode = .driving; layer.isHidden = false; ball.isHidden = false
    }

    private func resetPass() { tipAngle = 0; tipV = 0; passTime = 0; collected = 0; ballAngle = 0; sprayCarry = 0; vx = 0; vy = 0; spin = 0; fellFrom = nil }

    // MARK: mouse

    /// Is this global screen point over the truck (with a little slack)?
    func hit(_ p: CGPoint) -> Bool {
        guard mode != .hidden, let ov = ov, ov.frame.contains(p) else { return false }
        let l = CGPoint(x: p.x - ov.frame.minX, y: p.y - ov.frame.minY)
        return CGRect(x: x - 4, y: y - 4, width: size.width + 8, height: size.height + 8).contains(l)
    }

    func beginDrag(at l: CGPoint) {
        guard mode != .hidden else { return }
        grab = CGPoint(x: l.x - x, y: l.y - y); mode = .carried; rot = 0.12; vx = 0; vy = 0; spin = 0; dragV = .zero; lastDrag = CACurrentMediaTime(); ball.isHidden = true
        NSCursor.closedHand.set()
    }
    /// Dev only: pick up, carry and drop the truck without a mouse.
    func scriptedDrop(at l: CGPoint) { beginDrag(at: CGPoint(x: x + 60, y: y + 20)); drag(to: l); dragV = .zero; endDrag() }

    func drag(to l: CGPoint) {
        guard mode == .carried else { return }
        let nx = l.x - grab.x, ny = l.y - grab.y, now = CACurrentMediaTime(), dt = CGFloat(max(0.004, now - lastDrag)); lastDrag = now
        dragV = CGVector(dx: dragV.dx * 0.5 + (nx - x) / dt * 0.5, dy: dragV.dy * 0.5 + (ny - y) / dt * 0.5)
        x = nx; y = ny; rot = max(-0.3, min(0.3, 0.12 - dragV.dx * 0.0002))        // swings a little as it is carried
    }
    func endDrag() {
        guard mode == .carried else { return }
        mode = .falling; fellFrom = nil                                                  // let go: it keeps the speed of the throw
        vx = max(-900, min(900, dragV.dx * 0.8)); vy = max(-300, min(900, dragV.dy * 0.8)); spin = -rot * 3; dragV = .zero
        NSCursor.arrow.set()
    }

    // MARK: per frame

    func step(_ dt: CGFloat) {
        guard let ov = ov else { return }
        stepSparks(dt)
        switch mode {
        case .hidden: return
        case .carried: break
        case .falling: fall(dt, ov)
        case .driving: drive(dt, ov)
        }
        draw()
    }

    private func fall(_ dt: CGFloat, _ ov: Overlay) {
        vy -= 1700 * dt; x += vx * dt; y += vy * dt; rot += spin * dt
        let cx = x + size.width / 2
        let below = driveFloors(ov).filter { $0.id != fellFrom && cx >= $0.x0 && cx <= $0.x1 && y <= $0.top && ($0.top - y) < 60 + abs(vy) * dt }
        if vy < 0, let land = below.max(by: { $0.top < $1.top }) {                   // touch down on the highest thing under it
            y = land.top; rot = 0; spin = 0
            if abs(vy) > 400 { burst(at: CGPoint(x: x + 70, y: y), amount: 14) }
            vx = 0; vy = 0
            surface = land.id.map { .window($0) } ?? .pile
            passTime = 1.2; mode = .driving; ball.isHidden = false; collected = 0; fellFrom = nil
        }
        if y < -size.height * 2 { hide() }
    }

    private func drive(_ dt: CGFloat, _ ov: Overlay) {
        passTime += dt
        let e = min(1, passTime / 2.2), ease = e * e * (3 - 2 * e)
        let speed = 40 + (speedMax - 40) * ease                          // starts slowly, then gets up to speed
        let old = x + bladeX; x += (tipAngle > 0 ? speed * 0.35 : speed) * dt; let front = x + bladeX      // it slows as it tips

        var depth: CGFloat = 0
        switch surface {
        case .pile:
            let base = ov.ground.baseY - 1
            if rides {                                                       // sit on top of the snow: front and rear wheel follow its surface
                let hr = (ov.ground.surface(atX: x + 30) ?? ov.ground.baseY) - ov.ground.baseY
                let hf = (ov.ground.surface(atX: x + 106) ?? ov.ground.baseY) - ov.ground.baseY
                let k = min(1, dt * 14)
                y += (base + (hr + hf) / 2 - y) * k
                rot += (atan2(hf - hr, 76) - rot) * k
            } else { y = base; rot = 0 }
            let r = ov.ground.plow(from: old, to: front, keep: keepFactor); depth = r.depth; collected += r.mass
            if x > ov.frame.width + 60 { hide(); ov.ground.passFinished(); return }
        case .window(let id):
            guard let s = liveCaps.surfaces.first(where: { $0.id == id }) else { startFall(from: nil, speed: speed); return }
            let top = s.rect.maxY - ov.frame.minY, x0 = s.rect.minX - ov.frame.minX, x1 = s.rect.maxX - ov.frame.minX
            y = top
            let r = liveCaps.clear(id: id, from: old - x0, to: front - x0); depth = r.depth; collected += r.mass
            // As soon as the FRONT wheel is past the edge it pivots on the edge and leans nose-down, getting faster as more of it
            // overhangs. When the rear wheels are over too, or it has leant far enough, it topples off nose-first.
            if x + 106 > x1 || tipAngle > 0 {
                if tipAngle == 0 { tipPivotX = x1 }
                tipV += 9 * (1 + 2 * tipAngle) * dt; tipAngle += tipV * dt; rot = -tipAngle
                if x + 40 > x1 || tipAngle > 0.5 { startFall(from: id, speed: speed) }
            }
        }
        let r = 3 + 19 * (1 - exp(-collected / 2500))                     // the ball grows as more snow comes in
        ballAngle -= speed * dt / r
        ball.bounds = CGRect(x: 0, y: 0, width: 2 * r, height: 2 * r)
        ball.position = CGPoint(x: bladeX + r * 0.7, y: r)
        ball.setValue(ballAngle, forKeyPath: "transform.rotation.z")
        sprayCarry += 150 * (0.2 + 0.8 * min(1, depth / 8)) * dt          // snow thrown off the blade
        while sprayCarry >= 1 { sprayCarry -= 1; spark(atX: x + bladeX, y: y + .random(in: 3...14), speed: speed) }
    }

    /// Past the end of a window: it drives off the edge, flips, and falls.
    /// Where the truck's centre is while it pivots on the edge (rotated about the edge point it rests on).
    private func tipCentre() -> CGPoint {
        let vx0 = x + size.width / 2 - tipPivotX, vy0 = size.height * 0.25, c = cos(rot), s = sin(rot)
        return CGPoint(x: tipPivotX + vx0 * c - vy0 * s, y: y + vx0 * s + vy0 * c)
    }

    /// Past the end of a window: it drives off the edge, flips, and falls.
    private func startFall(from id: Int?, speed: CGFloat) {
        if tipAngle > 0 {                                            // already leaning: carry on tumbling nose-first from where it is
            let c = tipCentre(); x = c.x - size.width / 2; y = c.y - size.height * 0.25
            rot = -tipAngle; spin = -max(2, tipV * 1.2); vx = max(60, speed * 0.4); vy = 0; tipAngle = 0; tipV = 0
        } else { vx = max(90, speed * 0.7); vy = 220; spin = -5.2 }
        mode = .falling; fellFrom = id
        burst(at: CGPoint(x: x + bladeX, y: y + 8), amount: 16); ball.isHidden = true
    }

    private func hide() { mode = .hidden; layer.isHidden = true; ball.isHidden = true; rot = 0 }

    private func draw() {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        layer.isHidden = (mode == .hidden)
        layer.position = (mode == .driving && tipAngle > 0) ? tipCentre() : CGPoint(x: x + size.width / 2, y: y + size.height * 0.25)
        layer.transform = CATransform3DMakeRotation(rot, 0, 0, 1)
        CATransaction.commit()
    }

    // MARK: blown snow

    private func spark(atX px: CGFloat, y py: CGFloat, speed: CGFloat) {
        let sz = CGFloat.random(in: 2...5)
        let l = pool.popLast() ?? { let n = CALayer(); n.backgroundColor = NSColor.white.cgColor; return n }()
        CATransaction.begin(); CATransaction.setDisableActions(true)
        l.bounds = CGRect(x: 0, y: 0, width: sz, height: sz); l.cornerRadius = sz / 2; l.opacity = 1
        ov?.fly.addSublayer(l); CATransaction.commit()
        sparks.append(Spark(layer: l, x: px + .random(in: -2...8), y: py, vx: speed * 0.5 + .random(in: 40...170), vy: .random(in: 60...240), age: 0, life: .random(in: 0.5...1.1)))
    }

    private func burst(at p: CGPoint, amount: Int) {
        for _ in 0..<amount {
            let sz = CGFloat.random(in: 2...5)
            let l = pool.popLast() ?? { let n = CALayer(); n.backgroundColor = NSColor.white.cgColor; return n }()
            CATransaction.begin(); CATransaction.setDisableActions(true)
            l.bounds = CGRect(x: 0, y: 0, width: sz, height: sz); l.cornerRadius = sz / 2; l.opacity = 1
            ov?.fly.addSublayer(l); CATransaction.commit()
            sparks.append(Spark(layer: l, x: p.x, y: p.y, vx: .random(in: -180...180), vy: .random(in: 40...260), age: 0, life: .random(in: 0.5...1.0)))
        }
    }

    private func stepSparks(_ dt: CGFloat) {
        guard !sparks.isEmpty else { return }
        CATransaction.begin(); CATransaction.setDisableActions(true)
        var i = 0
        while i < sparks.count {
            var p = sparks[i]
            p.age += dt; p.vy -= 520 * dt; p.x += p.vx * dt; p.y += p.vy * dt
            if p.age >= p.life || p.y < -4 { p.layer.removeFromSuperlayer(); pool.append(p.layer); sparks.remove(at: i); continue }
            p.layer.position = CGPoint(x: p.x, y: p.y); p.layer.opacity = Float(1 - p.age / p.life)
            sparks[i] = p; i += 1
        }
        CATransaction.commit()
    }
}

/// Everything a vehicle can stand on, in overlay coordinates: the pile (or screen bottom) and the top edge of each window/widget.
func driveFloors(_ ov: Overlay) -> [(top: CGFloat, id: Int?, x0: CGFloat, x1: CGFloat)] {
    var out: [(CGFloat, Int?, CGFloat, CGFloat)] = [(ov.ground.baseY - 1, nil, -1e6, 1e6)]
    for s in liveCaps.surfaces where ov.frame.intersects(s.rect) {
        out.append((s.rect.maxY - ov.frame.minY, s.id, s.rect.minX - ov.frame.minX, s.rect.maxX - ov.frame.minX))
    }
    return out
}
