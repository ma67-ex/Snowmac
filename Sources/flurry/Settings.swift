import AppKit

/// User settings, saved between launches. Each one is a slider in the menu-bar menu.
enum Settings {
    struct Slider { let key: String, title: String, range: ClosedRange<Double>, def: Double, unit: String }
    static let sliders: [Slider] = [
        Slider(key: "snowDensity", title: "Snow density", range: 0.2...3.0, def: 1.0, unit: "×"),
        Slider(key: "rainDensity", title: "Rain density", range: 0.2...3.0, def: 1.0, unit: "×"),
        Slider(key: "rainSpeed",   title: "Rain speed",   range: 0.4...2.5, def: 1.0, unit: "×"),
    ]
    static func value(_ key: String) -> Double {
        let s = sliders.first { $0.key == key }!
        let v = UserDefaults.standard.object(forKey: key) as? Double ?? s.def
        return min(s.range.upperBound, max(s.range.lowerBound, v))
    }
    /// How deep the snow settles for a given density: strictly rising over the whole slider range, 0.26 at 0.2x,
    /// 0.70 at 1x, 1.0 (the hard limit) at 3x.
    static func depthFraction(_ d: CGFloat) -> CGFloat { d <= 1 ? 0.15 + 0.55 * d : min(1, 0.7 + 0.15 * (d - 1)) }
    static func set(_ key: String, _ v: Double) { UserDefaults.standard.set(v, forKey: key) }
    /// What the animation actually uses. It eases toward the slider value instead of jumping, like real weather changing:
    /// snow and rain density take about a minute to settle, rain speed a few seconds.
    private static var eased: [String: CGFloat] = [:]
    static func f(_ key: String) -> CGFloat { eased[key] ?? CGFloat(value(key)) }
    static func ease(_ dt: CGFloat) {
        for s in sliders {
            let target = CGFloat(value(s.key)), cur = eased[s.key] ?? target
            let tau: CGFloat = s.key == "rainSpeed" ? 4 : 40                      // time constant in seconds
            eased[s.key] = cur + (target - cur) * min(1, dt / tau)
        }
    }
}

private var sliderLabels: [String: NSTextField] = [:]

extension App {
    /// One menu row: a title with the current value, and a slider under it.
    func makeSliderItem(_ s: Settings.Slider) -> NSMenuItem {
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 250, height: 48))
        let label = NSTextField(labelWithString: "")
        label.frame = NSRect(x: 16, y: 28, width: 218, height: 16); label.font = .menuFont(ofSize: 13)
        let slider = NSSlider(value: Settings.value(s.key), minValue: s.range.lowerBound, maxValue: s.range.upperBound,
                              target: self, action: #selector(sliderMoved(_:)))
        slider.frame = NSRect(x: 14, y: 6, width: 222, height: 20); slider.isContinuous = true
        slider.identifier = NSUserInterfaceItemIdentifier(s.key)
        v.addSubview(label); v.addSubview(slider)
        sliderLabels[s.key] = label
        label.stringValue = "\(s.title)   \(String(format: "%.1f", Settings.value(s.key)))\(s.unit)"
        let item = NSMenuItem(); item.view = v
        return item
    }

    @objc func sliderMoved(_ sender: NSSlider) {
        guard let key = sender.identifier?.rawValue, let s = Settings.sliders.first(where: { $0.key == key }) else { return }
        Settings.set(key, sender.doubleValue)
        sliderLabels[key]?.stringValue = "\(s.title)   \(String(format: "%.1f", sender.doubleValue))\(s.unit)"
    }
}
