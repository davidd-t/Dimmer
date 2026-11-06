import AppKit

/// Renders the slider panel to a PNG so its look can be checked without opening the menu.
@MainActor
enum MenuPreview {
    static func render(to path: String) {
        let cases: [(NSAppearance.Name, Double)] = [
            (.darkAqua, 0.14), (.darkAqua, 0.70), (.aqua, 0.14), (.aqua, 0.70),
        ]
        let cell = NSSize(width: 260, height: 52)
        let gap: CGFloat = 12
        let canvas = FlippedView(frame: NSRect(x: 0, y: 0, width: cell.width * 2 + gap * 3,
                                               height: cell.height * 2 + gap * 3))
        canvas.wantsLayer = true
        canvas.layer?.backgroundColor = NSColor.gray.cgColor

        for (index, (appearanceName, position)) in cases.enumerated() {
            let appearance = NSAppearance(named: appearanceName)!
            let frame = NSRect(x: gap + CGFloat(index % 2) * (cell.width + gap),
                               y: gap + CGFloat(index / 2) * (cell.height + gap),
                               width: cell.width, height: cell.height)
            let background = NSView(frame: frame)
            background.appearance = appearance
            background.wantsLayer = true
            appearance.performAsCurrentDrawingAppearance {
                background.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            }
            let view = SliderMenuView(width: cell.width)
            view.show(position: position, percent: Int((position * 100).rounded()))
            background.addSubview(view)
            canvas.addSubview(background)
        }

        guard let rep = canvas.bitmapImageRepForCachingDisplay(in: canvas.bounds) else { return }
        canvas.cacheDisplay(in: canvas.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }
}

private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}
