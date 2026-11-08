import AppKit
import QuartzCore

/// A snowball fight for heavy snow. 3 or 4 kids pop out of the pile and throw snowballs at each other; whoever is aimed at
/// tries to dodge. A kid that gets hit falls over, lies there asleep, sinks into the snow and is gone. After 8 to 10 s the
/// dodging stops and they finish each other off; the last kid runs away, slips on its own, and vanishes too.
final class Fight {
    let container = CALayer()
    weak var ground: Ground?
    var isIdle: Bool { phase == .idle }

    private enum Phase { case idle, play, finish }
    private enum State { case pop, idle, windup, throwing, dodge, hit, lie, sink, run, carried, fall }
    private final class Brawler {
        let layer = CALayer(); let poses: [CGImage]
        var x: CGFloat, dir: CGFloat = 1, state = State.pop, t: CGFloat = 0, nextThrow: CGFloat
        weak var target: Brawler?
        var dodgeIn: CGFloat?, dodgeDX: CGFloat = 0, dodgeFrom: CGFloat = 0, hasThrown = false
        var angle: CGFloat = 0, dx: CGFloat = 0
        var floorID: Int?                                   // nil = standing on the pile; otherwise on top of this window/widget
        var yPos: CGFloat = 0, vx: CGFloat = 0, vy: CGFloat = 0, grab = CGPoint.zero, dragV = CGVector.zero, lastDrag = CACurrentMediaTime()
        init(x: CGFloat, variant: Int) {
            self.x = x; poses = kidImages(variant: variant); nextThrow = .random(in: 0.5...1.4)
            layer.bounds = CGRect(x: 0, y: 0, width: 52, height: 58); layer.anchorPoint = CGPoint(x: 0.5, y: 0.08)
            layer.contentsScale = 4; layer.minificationFilter = .trilinear
        }
        var alive: Bool { state != .hit && state != .lie && state != .sink }
    }
    private struct Ball { let layer: CALayer; var x: CGFloat, y: CGFloat, vx: CGFloat, vy: CGFloat; weak var thrower: Brawler?; var age: CGFloat; var ignore: Set<Int> }

    private var phase = Phase.idle, t: CGFloat = 0, playTime: CGFloat = 9
    private var kids: [Brawler] = [], balls: [Ball] = []
    private let gravity: CGFloat = 1500

    private func debug(_ s: String) { if ProcessInfo.processInfo.environment["FLURRY_DEBUG"] != nil { FileHandle.standardError.write(Data("fight \(s)\n".utf8)) } }

    // MARK: where a kid stands

    /// Top of whatever the kid stands on, or nil if its window has gone.
    private func floorTop(_ k: Brawler, _ g: Ground) -> CGFloat? {
        if let id = k.floorID { guard let s = liveCaps.surfaces.first(where: { $0.id == id }) else { return nil }; return s.rect.maxY - g.screenFrame.minY }
        return g.surface(atX: k.x) ?? g.baseY
    }
    private func xBounds(_ k: Brawler, _ g: Ground) -> (CGFloat, CGFloat) {
        if let id = k.floorID, let s = liveCaps.surfaces.first(where: { $0.id == id }) { return (s.rect.minX - g.screenFrame.minX + 22, s.rect.maxX - g.screenFrame.minX - 22) }
        return (g.originX + 40, g.originX + g.regionWidth - 40)
    }
    private func floorsAt(_ x: CGFloat, _ g: Ground) -> [(top: CGFloat, id: Int?)] {
        var out: [(CGFloat, Int?)] = [(g.surface(atX: x) ?? g.baseY, nil)]
        for s in liveCaps.surfaces {
            let x0 = s.rect.minX - g.screenFrame.minX, x1 = s.rect.maxX - g.screenFrame.minX
            if x >= x0 && x <= x1 { out.append((s.rect.maxY - g.screenFrame.minY, s.id)) }
        }
        return out
    }

    // MARK: picking a kid up

    private weak var held: Brawler?
    /// Is a kid under this global screen point?
    func hit(_ p: CGPoint) -> Bool { held != nil || kid(at: p) != nil }
    private func kid(at p: CGPoint) -> Brawler? {
        guard let g = ground else { return nil }
        let l = CGPoint(x: p.x - g.screenFrame.minX, y: p.y - g.screenFrame.minY)
        return kids.first { $0.alive && CGRect(x: $0.x + $0.dx - 22, y: $0.yPos - 6, width: 44, height: 64).contains(l) }
    }
    func beginDrag(at l: CGPoint) {
        guard let g = ground, let k = kid(at: CGPoint(x: l.x + g.screenFrame.minX, y: l.y + g.screenFrame.minY)) else { return }
        held = k; k.state = .carried; k.grab = CGPoint(x: l.x - k.x, y: l.y - k.yPos); k.dragV = .zero; k.lastDrag = CACurrentMediaTime(); k.dodgeIn = nil
        NSCursor.closedHand.set()
    }
    func drag(to l: CGPoint) {
        guard let k = held, k.state == .carried else { return }
        let nx = l.x - k.grab.x, ny = l.y - k.grab.y, now = CACurrentMediaTime(), dt = CGFloat(max(0.004, now - k.lastDrag)); k.lastDrag = now
        k.dragV = CGVector(dx: k.dragV.dx * 0.5 + (nx - k.x) / dt * 0.5, dy: k.dragV.dy * 0.5 + (ny - k.yPos) / dt * 0.5)
        k.x = nx; k.yPos = ny
    }
    func endDrag() {
        guard let k = held else { return }
        held = nil; NSCursor.arrow.set()
        guard k.state == .carried else { return }
        k.state = .fall; k.floorID = nil; k.t = 0
        k.vx = max(-700, min(700, k.dragV.dx * 0.7)); k.vy = max(-300, min(700, k.dragV.dy * 0.7)); k.dragV = .zero
    }
    /// Dev only: pick up and drop a kid without a mouse.
    func scriptedDrop(at l: CGPoint) {
        guard let k = kids.first(where: { $0.alive }), let g = ground else { return }
        beginDrag(at: CGPoint(x: k.x, y: k.yPos + 20)); _ = g; drag(to: l); held?.dragV = .zero; endDrag()
    }

    func start() {
        guard phase == .idle, let g = ground else { return }
        let n = Int.random(in: 3...4)
        var xs: [CGFloat] = []
        for _ in 0..<80 where xs.count < n {                                   // spread out, at least 130 pt apart
            let x = g.originX + CGFloat.random(in: 90...(max(100, g.regionWidth - 90)))
            if xs.allSatisfy({ abs($0 - x) > 130 }) { xs.append(x) }
        }
        guard xs.count >= 3 else { return }
        container.frame = CGRect(origin: .zero, size: g.screenFrame.size)
        let variants = [0, 1, 2, 3].shuffled()
        kids = xs.enumerated().map { Brawler(x: $0.element, variant: variants[$0.offset]) }
        for k in kids { container.addSublayer(k.layer) }
        phase = .play; t = 0; playTime = .random(in: 8...10)
        debug("start kids=\(kids.count) playTime=\(playTime)")
    }

    private func ease(_ p: CGFloat) -> CGFloat { p * p * (3 - 2 * p) }
    private func outBack(_ p: CGFloat) -> CGFloat { let c: CGFloat = 1.9, q = p - 1; return 1 + (c + 1) * q * q * q + c * q * q }

    func step(_ dt: CGFloat) {
        guard phase != .idle, let g = ground else { return }
        t += dt
        if phase == .play, t >= playTime { phase = .finish; debug("finish phase: no more dodging") }
        let living = kids.filter { $0.alive }
        for k in kids { stepKid(k, dt, g, living) }
        stepBalls(dt, g)
        if kids.isEmpty && balls.isEmpty { phase = .idle; debug("over") }
    }

    private func stepKid(_ k: Brawler, _ dt: CGFloat, _ g: Ground, _ living: [Brawler]) {
        k.t += dt
        if k.state == .carried { place(k, k.poses[3], 0.1 + max(-0.3, min(0.3, -k.dragV.dx * 0.0004)), k.yPos, 0, 1); return }      // swings in the air while held
        if k.state == .fall {                                                      // let go: falls under gravity, keeping the throw
            k.vy -= 1700 * dt; k.x += k.vx * dt; k.yPos += k.vy * dt
            if let land = floorsAt(k.x, g).filter({ k.yPos <= $0.top && ($0.top - k.yPos) < 50 + abs(k.vy) * dt }).max(by: { $0.top < $1.top }), k.vy < 0 {
                k.floorID = land.id; k.yPos = land.top; k.vx = 0; k.vy = 0; k.state = .idle; k.t = 0; k.nextThrow = CGFloat.random(in: 0.5...1.0)   // it plays on from wherever it landed
                debug("a kid landed on \(land.id.map { "window \($0)" } ?? "the pile")")
            } else if k.yPos < -80 { k.floorID = nil; k.yPos = g.surface(atX: k.x) ?? g.baseY; k.vx = 0; k.vy = 0; k.state = .idle; k.t = 0 }
            place(k, k.poses[3], 0.3 + k.t * 3, k.yPos, 0, 1); return
        }
        guard let surface = floorTop(k, g) else { k.state = .fall; k.floorID = nil; k.vx = 0; k.vy = 0; return }     // its window went away
        let (lo, hi) = xBounds(k, g)
        var y = surface, img = k.poses[0], angle: CGFloat = 0, dx: CGFloat = 0, fade: Float = 1
        // the last kid standing runs away
        if living.count == 1, k.alive, k.state != .run, k.state != .pop { k.state = .run; k.t = 0; debug("last kid runs away") }
        // face the target (or whoever is nearest)
        if k.alive, k.state != .run {
            // Throws go down, across, or up at an angle from the side. Never straight up at someone standing right above.
            if let t = k.target, !canThrow(k, t) { k.target = nil }
            if k.target == nil { k.target = living.filter { $0 !== k && canThrow(k, $0) }.randomElement() }
            if let tg = k.target { k.dir = tg.x >= k.x ? 1 : -1 }
        }
        switch k.state {
        case .pop:
            let p = min(1, k.t / 0.55); y = surface - 40 + 40 * outBack(p)
            if k.t >= 0.55 { k.state = .idle; k.t = 0 }
        case .idle:
            k.nextThrow -= dt
            if let d = k.dodgeIn { k.dodgeIn = d - dt; if d - dt <= 0 { k.dodgeIn = nil; k.state = .dodge; k.t = 0; k.dodgeFrom = k.x } }
            else if k.nextThrow <= 0, k.target != nil { k.state = .windup; k.t = 0; k.hasThrown = false }
        case .windup:
            img = k.poses[1]; angle = 0.14 * ease(min(1, k.t / 0.3))
            if let d = k.dodgeIn { k.dodgeIn = d - dt; if d - dt <= 0 { k.dodgeIn = nil; k.state = .dodge; k.t = 0; k.dodgeFrom = k.x } }
            if k.t >= 0.34 { k.state = .throwing; k.t = 0 }
        case .throwing:
            img = k.poses[2]; angle = 0.14 - 0.34 * ease(min(1, k.t / 0.2))
            if !k.hasThrown, k.t >= 0.08 { k.hasThrown = true; launch(from: k, g, surface) }
            if k.t >= 0.28 { k.state = .idle; k.t = 0; k.nextThrow = phase == .play ? .random(in: 1.2...2.2) : .random(in: 0.45...0.9) }
        case .dodge:                                                              // sidestep with a little hop
            let p = min(1, k.t / 0.4)
            k.x = max(lo, min(hi, k.dodgeFrom + k.dodgeDX * ease(p))); y = (k.floorID == nil ? (g.surface(atX: k.x) ?? surface) : surface) + 14 * sin(.pi * p); img = k.poses[0]
            if k.t >= 0.4 { k.state = .idle; k.t = 0 }
        case .run:                                                                // runs for the edge...
            let away: CGFloat = (k.x - g.originX) < g.regionWidth / 2 ? -1 : 1
            k.dir = away; k.x = max(k.floorID == nil ? lo - 30 : lo, min(k.floorID == nil ? hi + 30 : hi, k.x + away * 170 * dt))
            y = (k.floorID == nil ? (g.surface(atX: k.x) ?? surface) : surface) + 2.5 * abs(sin(k.t * 16)); angle = 0.12; img = k.poses[(Int(k.t * 10) % 2 == 0) ? 0 : 2]
            if k.t >= 1.7 { k.state = .hit; k.t = 0; debug("last kid slips on its own") }     // ...and trips over its own feet
        case .hit:
            img = k.poses[3]; let p = min(1, k.t / 0.55)
            angle = -0.2 + 1.75 * p * p; dx = -k.dir * 20 * ease(p); y = surface + 9 * sin(.pi * min(1, p * 1.15))
            if k.t >= 0.55 { k.state = .lie; k.t = 0 }
        case .lie:
            img = k.poses[3]; angle = 1.55 + 0.04 * sin(k.t * 14); dx = -k.dir * 20; y = surface + 4
            if k.t >= 0.9 { k.state = .sink; k.t = 0 }
        case .carried, .fall: break                                              // handled above
        case .sink:
            img = k.poses[3]; angle = 1.55; dx = -k.dir * 20
            if k.floorID == nil { y = surface + 4 - (surface + 66) * ease(min(1, k.t / 0.8)) } else { y = surface + 4; fade = Float(1 - min(1, k.t / 0.8)) }
            if k.t >= 0.8 { puff(at: CGPoint(x: k.x - k.dir * 20, y: surface)); k.layer.removeFromSuperlayer(); kids.removeAll { $0 === k }; debug("a kid is gone, \(kids.count) left"); return }
        }
        place(k, img, angle, y, dx, fade)
    }

    /// Put a kid's layer where it belongs this frame, and remember where it is.
    private func place(_ k: Brawler, _ img: CGImage, _ angle: CGFloat, _ y: CGFloat, _ dx: CGFloat, _ fade: Float) {
        k.angle = angle; k.dx = dx
        if k.state != .carried && k.state != .fall { k.yPos = y }
        CATransaction.begin(); CATransaction.setDisableActions(true)
        k.layer.contents = img; k.layer.opacity = fade; k.layer.position = CGPoint(x: k.x + dx, y: y)
        var tf = CATransform3DMakeRotation(angle * k.dir, 0, 0, 1); tf = CATransform3DScale(tf, k.dir, 1, 1)
        k.layer.transform = tf
        CATransaction.commit()
    }

    /// Throw a snowball at the target's head, solved so it arrives on time. In the play phase the target may see it coming
    /// and sidestep out of the way; once the fight is in its last phase nobody dodges.
    /// Anyone can throw at anyone, however high, so the game stays fair. The only rule: not straight up, so the thrower must stand off to the side.
    private func canThrow(_ k: Brawler, _ t: Brawler) -> Bool {
        guard t.alive, t !== k else { return false }
        let rise = t.yPos - k.yPos
        return rise <= 40 || abs(t.x - k.x) >= 70
    }

    private func launch(from k: Brawler, _ g: Ground, _ surface: CGFloat) {
        guard let tg = k.target, tg.alive, canThrow(k, tg) else { return }
        let tsurf = tg.yPos
        let hx = k.x + k.dir * 20, hy = surface + 50
        let tx = tg.x, ty = tsurf + 36
        let dist = abs(tx - hx), rise = max(0, tg.yPos - k.yPos)
        let T = rise > 40 ? min(2.2, max(0.8, 0.55 + rise / 400)) : max(0.5, min(1.05, dist / 650))   // up throws take longer: a higher arc clears the building's edge
        let vx = (tx - hx) / T, vy = (ty - hy + 0.5 * gravity * T * T) / T      // always an arc that lands on the target's head
        debug(rise > 40 ? "throw: arc up from the side" : tg.yPos < k.yPos - 40 ? "throw: arc down to a lower level" : "throw: arc on the same level")
        let l = CALayer(); l.bounds = CGRect(x: 0, y: 0, width: 14, height: 14); l.cornerRadius = 7
        l.contents = snowballImage(px: 56); l.contentsScale = 4
        container.addSublayer(l)
        var inside = Set<Int>()                                   // buildings the throw starts inside (a window over the ground strip)
        for s in liveCaps.surfaces where s.rect.offsetBy(dx: -g.screenFrame.minX, dy: -g.screenFrame.minY).contains(CGPoint(x: hx, y: hy)) { inside.insert(s.id) }
        balls.append(Ball(layer: l, x: hx, y: hy, vx: vx, vy: vy, thrower: k, age: 0, ignore: inside))
        if phase == .play, tg.dodgeIn == nil, tg.alive, Float.random(in: 0...1) < (kids.filter { $0.alive }.count <= 2 ? 1.0 : 0.82) {   // it saw that coming (always, once only two are left, so they keep playing)
            tg.dodgeIn = max(0.05, T - 0.4); tg.dodgeDX = (tx >= hx ? 1 : -1) * CGFloat.random(in: 50...70)
            let (blo, bhi) = xBounds(tg, g)
            if tg.x + tg.dodgeDX < blo || tg.x + tg.dodgeDX > bhi { tg.dodgeDX = -tg.dodgeDX }
        }
    }

    private func stepBalls(_ dt: CGFloat, _ g: Ground) {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        var i = 0
        while i < balls.count {
            var b = balls[i]
            b.age += dt; b.vy -= gravity * dt; b.x += b.vx * dt; b.y += b.vy * dt
            var done = false
            for k in kids where (k.alive && k !== b.thrower || (k === b.thrower && b.age > 0.35 && k.alive)) && k.state != .carried && k.state != .fall {
                let ks = k.yPos
                if phase == .play && kids.filter({ $0.alive }).count <= 2 { continue }       // still playing: the last two cannot be hit yet
                if hypot(b.x - (k.x + k.dx), b.y - (ks + 34)) < 15 {                    // a hit!
                    k.state = .hit; k.t = 0; k.dir = (b.vx >= 0) ? -1 : 1; k.dodgeIn = nil
                    puff(at: CGPoint(x: b.x, y: b.y), small: true); done = true; debug("hit! \(kids.filter { $0.alive }.count) kids still up"); break
                }
            }
            if !done {                                                                       // a ball cannot go through a building: it splats on the wall
                for s in liveCaps.surfaces where !b.ignore.contains(s.id) && s.rect.offsetBy(dx: -g.screenFrame.minX, dy: -g.screenFrame.minY).insetBy(dx: -2, dy: 0).contains(CGPoint(x: b.x, y: b.y)) {
                    puff(at: CGPoint(x: b.x, y: b.y), small: true); done = true; break
                }
            }
            if !done, let top = g.surface(atX: b.x), b.vy < 0, b.y <= top + 2 {                  // missed: it lands in the snow
                g.add(atX: b.x, amount: 6); puff(at: CGPoint(x: b.x, y: top + 2), small: true); done = true
            }
            if b.y < -10 || b.x < -20 || b.x > g.screenFrame.width + 20 { done = true }
            if done { b.layer.removeFromSuperlayer(); balls.remove(at: i); continue }
            b.layer.position = CGPoint(x: b.x, y: b.y); balls[i] = b; i += 1
        }
        CATransaction.commit()
    }

    /// A little puff of snow.
    private func puff(at p: CGPoint, small: Bool = false) {
        for _ in 0..<(small ? 7 : 12) {
            let d = CALayer(); let r = CGFloat.random(in: 1.5...(small ? 3 : 5))
            d.bounds = CGRect(x: 0, y: 0, width: 2 * r, height: 2 * r); d.cornerRadius = r; d.backgroundColor = NSColor.white.cgColor
            let from = CGPoint(x: p.x + .random(in: -6...6), y: p.y + 2); d.position = from; container.addSublayer(d)
            let ang = CGFloat.random(in: 0.3...(.pi - 0.3)), dist = CGFloat.random(in: 12...(small ? 26 : 40))
            let m = CABasicAnimation(keyPath: "position"); m.toValue = CGPoint(x: from.x + cos(ang) * dist, y: from.y + sin(ang) * dist + 8)
            let f = CABasicAnimation(keyPath: "opacity"); f.fromValue = 1; f.toValue = 0
            let gr = CAAnimationGroup(); gr.animations = [m, f]; gr.duration = 0.55; gr.timingFunction = CAMediaTimingFunction(name: .easeOut)
            gr.isRemovedOnCompletion = false; gr.fillMode = .forwards; d.add(gr, forKey: "puff")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { d.removeFromSuperlayer() }
        }
    }
}
