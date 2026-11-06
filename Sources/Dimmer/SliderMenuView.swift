import AppKit
import DimmerCore

/// A slider whose track shows the extra-dark zone as stripes, with a tick
/// where Apple's own slider stops.
final class ZonedSlider: NSView {
    var value: Double = 0.5 { didSet { needsDisplay = true } }
    var onChange: ((Double) -> Void)?

    private let knobDiameter: CGFloat = 16
    private let trackHeight: CGFloat = 6

    override var isFlipped: Bool { true }

    /// Horizontal position of the knob's center for a given value.
    func x(for value: Double) -> CGFloat {
        let minX = bounds.minX + knobDiameter / 2
        let maxX = bounds.maxX - knobDiameter / 2
        return minX + (maxX - minX) * CGFloat(min(max(value, 0), 1))
    }

    private func value(at x: CGFloat) -> Double {
        let minX = bounds.minX + knobDiameter / 2
        let maxX = bounds.maxX - knobDiameter / 2
        return Double(min(max((x - minX) / (maxX - minX), 0), 1))
    }

    override func draw(_ dirtyRect: NSRect) {
        let midY = bounds.midY
        let track = NSRect(x: bounds.minX + knobDiameter / 2 - trackHeight / 2,
                           y: midY - trackHeight / 2,
                           width: bounds.width - knobDiameter + trackHeight,
                           height: trackHeight)
        let trackPath = NSBezierPath(roundedRect: track, xRadius: trackHeight / 2, yRadius: trackHeight / 2)
        NSColor.labelColor.withAlphaComponent(0.15).setFill()
        trackPath.fill()

        let markX = x(for: BrightnessMapping.applesLowest)
        let knobX = x(for: value)

        // Striped extra-dark zone.
        NSGraphicsContext.saveGraphicsState()
        trackPath.addClip()
        NSRect(x: track.minX, y: track.minY, width: markX - track.minX, height: track.height).clip()
        let stripes = NSBezierPath()
        var sx = track.minX - track.height
        while sx < markX + track.height {
            stripes.move(to: NSPoint(x: sx, y: track.maxY))
            stripes.line(to: NSPoint(x: sx + track.height, y: track.minY))
            sx += 4
        }
        stripes.lineWidth = 1.5
        NSColor.systemIndigo.withAlphaComponent(0.75).setStroke()
        stripes.stroke()
        NSGraphicsContext.restoreGraphicsState()

        // Filled part, up to the knob.
        NSGraphicsContext.saveGraphicsState()
        trackPath.addClip()
        NSColor.controlAccentColor.setFill()
        NSRect(x: track.minX, y: track.minY, width: knobX - track.minX, height: track.height).fill()
        NSGraphicsContext.restoreGraphicsState()

        // Tick at Apple's lowest.
        NSColor.secondaryLabelColor.setFill()
        NSRect(x: markX - 0.75, y: midY - 7, width: 1.5, height: 14).fill()

        // Knob.
        let knob = NSRect(x: knobX - knobDiameter / 2, y: midY - knobDiameter / 2,
                          width: knobDiameter, height: knobDiameter)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
        shadow.shadowBlurRadius = 2
        shadow.shadowOffset = NSSize(width: 0, height: -0.5)
        shadow.set()
        NSColor.white.setFill()
        NSBezierPath(ovalIn: knob).fill()
        NSGraphicsContext.restoreGraphicsState()
        NSColor.black.withAlphaComponent(0.12).setStroke()
        NSBezierPath(ovalIn: knob.insetBy(dx: 0.25, dy: 0.25)).stroke()
    }

    override func mouseDown(with event: NSEvent) { track(event) }
    override func mouseDragged(with event: NSEvent) { track(event) }

    private func track(_ event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        value = value(at: point.x)
        onChange?(value)
    }

    // Accessibility: present as a real slider.
    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .slider }
    override func accessibilityLabel() -> String? { "Brightness" }
    override func accessibilityValue() -> Any? { NSNumber(value: Int((value * 100).rounded())) }
    override func accessibilityPerformIncrement() -> Bool { nudge(0.05) }
    override func accessibilityPerformDecrement() -> Bool { nudge(-0.05) }

    private func nudge(_ delta: Double) -> Bool {
        value = min(max(value + delta, 0), 1)
        onChange?(value)
        return true
    }
}

/// The top of the menu: "Brightness — 14%" and the slider.
final class SliderMenuView: NSView {
    let title = NSTextField(labelWithString: "")
    let slider = ZonedSlider()

    override var isFlipped: Bool { true }

    init(width: CGFloat = 260) {
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 52))
        title.font = .systemFont(ofSize: 12)
        title.textColor = .secondaryLabelColor
        title.frame = NSRect(x: 14, y: 6, width: width - 28, height: 16)
        slider.frame = NSRect(x: 14, y: 24, width: width - 28, height: 22)
        addSubview(title)
        addSubview(slider)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func show(position: Double, percent: Int) {
        title.stringValue = "Brightness — \(percent)%"
        slider.value = position
        needsDisplay = true
    }

}
