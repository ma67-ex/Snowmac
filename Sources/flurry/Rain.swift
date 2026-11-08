import AppKit

/// A thin rain streak, drawn as vector art at its exact pixel size (bright head, fading tail), leaning with the wind.
func rainStreak(px: Int, lean: CGFloat = 0.105) -> CGImage? {
    let w = max(6, px / 4 + 4), h = px
    guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    ctx.setLineCap(.round)
    let tail = CGPoint(x: 2, y: CGFloat(h) - 2), head = CGPoint(x: min(CGFloat(w) - 2, 2 + (CGFloat(h) - 4) * lean), y: 2)
    let steps = 18
    for i in 0..<steps {                                        // fade from the tail (top) to the head (bottom)
        let a = CGFloat(i) / CGFloat(steps), b = CGFloat(i + 1) / CGFloat(steps)
        ctx.setStrokeColor(NSColor(calibratedRed: 0.82, green: 0.92, blue: 1, alpha: 0.08 + 0.82 * a * a).cgColor)
        ctx.setLineWidth(max(1.2, CGFloat(px) / 34))
        ctx.move(to: CGPoint(x: tail.x + (head.x - tail.x) * a, y: tail.y + (head.y - tail.y) * a))
        ctx.addLine(to: CGPoint(x: tail.x + (head.x - tail.x) * b, y: tail.y + (head.y - tail.y) * b)); ctx.strokePath()
    }
    return ctx.makeImage()
}

/// Falling rain, moved by hand like the flakes. Density and speed come from the menu sliders. Each drop falls until it
/// reaches the ground (or the Dock) and splashes there, so none can vanish half-way down.
final class RainField {
    private struct D { let layer: CALayer; var x: CGFloat; var y: CGFloat; let vy: CGFloat; let h: CGFloat }
    let container = CALayer()
    private var drops: [D] = [], pool: [CALayer] = []
    private let sprites: [CGImage]
    private let scale: CGFloat, size: CGSize
    private var carry: CGFloat = 0
    private let lean: CGFloat = 0.105                                     // sideways travel per unit of fall

    init(size: CGSize, scale: CGFloat) {
        self.size = size; self.scale = scale
        container.frame = CGRect(origin: .zero, size: size)
        sprites = [34, 50, 68].compactMap { rainStreak(px: Int(CGFloat($0) * scale / 2) / 2 * 2) }
    }

    func step(_ dt: CGFloat, ground: Ground) {
        let density = Settings.f("rainDensity"), speed = Settings.f("rainSpeed")
        carry += 150 * (size.width / 1512) * density * dt
        CATransaction.begin(); CATransaction.setDisableActions(true)
        while carry >= 1 {
            carry -= 1
            let img = sprites.randomElement()!, h = CGFloat(img.height) / scale, w = CGFloat(img.width) / scale
            let l = pool.popLast() ?? CALayer()
            l.contentsScale = scale; l.contents = img; l.bounds = CGRect(x: 0, y: 0, width: w, height: h)
            l.minificationFilter = .linear; l.magnificationFilter = .linear; l.opacity = Float(0.45 + 0.55 * h / 40)
            container.addSublayer(l)
            drops.append(D(layer: l, x: .random(in: -120...(size.width + 40)), y: size.height + h,
                           vy: (650 + h * 9 + .random(in: 0...250)) * speed, h: h))
        }
        var i = 0
        while i < drops.count {
            var d = drops[i]
            d.y -= d.vy * dt; d.x += d.vy * lean * dt
            var land = d.y < -d.h
            if let top = ground.surface(atX: d.x), d.y - d.h * 0.5 <= top { land = true; if Int.random(in: 0..<3) == 0 { splash(at: CGPoint(x: d.x, y: top)) } }
            if land { d.layer.removeFromSuperlayer(); pool.append(d.layer); drops.remove(at: i); continue }
            d.layer.position = CGPoint(x: d.x, y: d.y)
            drops[i] = d; i += 1
        }
        CATransaction.commit()
    }

    /// A tiny ring where a drop lands.
    private func splash(at p: CGPoint) {
        let r = CALayer(); r.bounds = CGRect(x: 0, y: 0, width: 8, height: 3); r.cornerRadius = 1.5
        r.borderColor = NSColor(calibratedRed: 0.85, green: 0.94, blue: 1, alpha: 0.8).cgColor; r.borderWidth = 0.8
        r.position = p; container.addSublayer(r)
        let s = CABasicAnimation(keyPath: "transform.scale.x"); s.fromValue = 0.4; s.toValue = 2.2
        let f = CABasicAnimation(keyPath: "opacity"); f.fromValue = 0.9; f.toValue = 0
        let g = CAAnimationGroup(); g.animations = [s, f]; g.duration = 0.3; g.isRemovedOnCompletion = false; g.fillMode = .forwards
        r.add(g, forKey: "splash")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) { r.removeFromSuperlayer() }
    }
}
