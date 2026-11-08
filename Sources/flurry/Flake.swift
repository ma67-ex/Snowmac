import AppKit

/// Deterministic RNG so every flake shape is stable between launches.
struct SeededRNG: RandomNumberGenerator {
    var s: UInt64
    mutating func next() -> UInt64 {
        s &+= 0x9E3779B97F4A7C15
        var z = s
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// A real six-fold snow crystal: spine + branches + sub-branches, or a hexagonal plate. Drawn as vector art at the exact
/// pixel size and at a given rotation (so spinning never resamples a bitmap), with a hairline cool shadow for contrast.
func flakeSprite(seed: UInt64, px: Int = 192, angle: CGFloat = 0) -> CGImage? {
    var rng = SeededRNG(s: seed &* 7919 &+ 17)
    guard let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    let c = CGFloat(px) / 2, R = c * 0.9
    ctx.translateBy(x: c, y: c); ctx.rotate(by: angle)
    ctx.setAllowsAntialiasing(true); ctx.setShouldAntialias(true)
    ctx.setLineCap(.round); ctx.setLineJoin(.round)

    let w = max(1.4, CGFloat(px) / 30)                       // fine lines that stay sharp at small sizes
    let kind = Int(seed % 3)                                 // 0 dendrite, 1 stellar, 2 plate with ribs
    let branches = kind == 0 ? Int.random(in: 3...4, using: &rng) : Int.random(in: 1...2, using: &rng)
    let ang = CGFloat.random(in: 0.85...1.1, using: &rng)    // branch angle, ~50-63 degrees
    let blen = CGFloat.random(in: 0.26...0.36, using: &rng)
    let first = CGFloat.random(in: 0.28...0.4, using: &rng)

    func hexagon(_ r: CGFloat) -> CGPath {
        let p = CGMutablePath()
        for i in 0..<6 { let a = CGFloat(i) * .pi / 3
            let pt = CGPoint(x: cos(a) * r, y: sin(a) * r); i == 0 ? p.move(to: pt) : p.addLine(to: pt) }
        p.closeSubpath(); return p
    }
    /// One full pass of the crystal in a colour; `grow` thickens the lines (used for the shadow pass).
    func pass(_ color: CGColor, fill: CGColor, grow: CGFloat, dy: CGFloat) {
        ctx.saveGState(); ctx.translateBy(x: 0, y: dy)
        ctx.setStrokeColor(color); ctx.setFillColor(color)
        func line(_ a: CGPoint, _ b: CGPoint, _ lw: CGFloat) {
            ctx.setLineWidth(lw + grow); ctx.move(to: a); ctx.addLine(to: b); ctx.strokePath()
        }
        if kind == 2 {
            ctx.setFillColor(fill); ctx.addPath(hexagon(R * 0.6)); ctx.fillPath()
            ctx.setLineWidth(w + grow); ctx.addPath(hexagon(R * 0.6)); ctx.strokePath()
            ctx.addPath(hexagon(R * 0.3)); ctx.strokePath(); ctx.setFillColor(color)
        }
        for k in 0..<6 {                                     // the same arm six times = hexagonal symmetry
            ctx.saveGState(); ctx.rotate(by: CGFloat(k) * .pi / 3)
            line(.zero, CGPoint(x: R, y: 0), w * 1.2)
            for j in 0..<branches {
                let t = branches == 1 ? first + 0.2 : first + CGFloat(j) * (0.55 - first) / CGFloat(max(1, branches - 1)) + 0.05
                let base = CGPoint(x: R * t, y: 0), len = R * blen * (1.15 - t * 0.7)
                for sgn in [CGFloat(1), -1] {
                    let tip = CGPoint(x: base.x + cos(ang) * len, y: sgn * sin(ang) * len)
                    line(base, tip, w)
                    if kind == 0 {
                        let m = CGPoint(x: (base.x + tip.x) / 2, y: (base.y + tip.y) / 2)
                        line(m, CGPoint(x: m.x + len * 0.28, y: m.y + sgn * len * 0.1), w * 0.7)
                    }
                }
            }
            let tb = CGPoint(x: R * 0.86, y: 0)              // forked tip
            line(tb, CGPoint(x: R, y: R * 0.07), w * 0.9); line(tb, CGPoint(x: R, y: -R * 0.07), w * 0.9)
            ctx.restoreGState()
        }
        ctx.addPath(hexagon(R * 0.1 + grow * 0.5)); ctx.fillPath()   // core
        ctx.restoreGState()
    }
    let shadow = NSColor(calibratedRed: 0.10, green: 0.18, blue: 0.38, alpha: 0.38).cgColor
    pass(shadow, fill: shadow, grow: max(1.0, CGFloat(px) / 60), dy: -max(0.6, CGFloat(px) / 90))   // hairline cool shadow
    let white = NSColor.white.cgColor, plate = NSColor(white: 1, alpha: 0.30).cgColor
    pass(white, fill: plate, grow: 0, dy: 0)
    return ctx.makeImage()
}

func dumpFlakes(to dir: String) {
    if let p = policeImage() { try? NSBitmapImageRep(cgImage: p).representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: "\(dir)/police.png")) }
    if let big = flakeSprite(seed: 1, px: 1024) { try? NSBitmapImageRep(cgImage: big).representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: "\(dir)/flake_big.png")) }
    for (i, k) in kidImages().enumerated() { try? NSBitmapImageRep(cgImage: k).representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: "\(dir)/kid\(i).png")) }
    if let t = truckImage() { try? NSBitmapImageRep(cgImage: t).representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: "\(dir)/truck.png")) }
    for i in 1...10 {
        guard let img = flakeSprite(seed: UInt64(i)) else { continue }
        let rep = NSBitmapImageRep(cgImage: img)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: "\(dir)/flake\(i).png"))
    }
}
