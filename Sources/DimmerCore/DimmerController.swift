/// The real screen, as far as the controller is concerned.
@MainActor
public protocol ScreenControlling: AnyObject {
    /// Current backlight 0...1, or nil if it can't be read.
    func readBacklight() -> Double?
    func setBacklight(_ value: Double)
    /// 1 = normal image, lower = darker image.
    func setImageLevel(_ value: Double)
}

@MainActor
public protocol PositionStoring: AnyObject {
    var savedPosition: Double? { get set }
}

/// Owns the slider position and keeps the screen, the saved setting,
/// and the system's own brightness controls in agreement.
@MainActor
public final class DimmerController {
    /// Backlight differences smaller than this are read-back noise, not the user.
    static let changeTolerance = 0.01

    public private(set) var sliderPosition: Double
    public var onChange: (() -> Void)?

    private let screen: ScreenControlling
    private let store: PositionStoring

    public var isExtraDark: Bool { BrightnessMapping.isExtraDark(sliderPosition) }
    public var percent: Int { Int((sliderPosition * 100).rounded()) }

    public init(screen: ScreenControlling, store: PositionStoring) {
        self.screen = screen
        self.store = store
        let current = screen.readBacklight() ?? 1
        sliderPosition = BrightnessMapping.sliderPosition(forBacklight: current)
        // Only an extra-dark setting is restored; above Apple's lowest,
        // the real backlight is the truth and we don't yank it around.
        if let saved = store.savedPosition, BrightnessMapping.isExtraDark(saved) {
            apply(saved)
        }
    }

    public func setSlider(_ position: Double) {
        apply(position)
    }

    /// Call periodically: follows brightness keys / Control Center.
    public func syncWithSystem() {
        guard let actual = screen.readBacklight() else { return }
        let expected = BrightnessMapping.output(forSlider: sliderPosition).backlight
        guard abs(actual - expected) > Self.changeTolerance else { return }
        let wasExtraDark = isExtraDark
        let newPosition = BrightnessMapping.sliderPosition(forBacklight: actual)
        // Screen switched off with the slider already at Apple's lowest: nothing new to show.
        if !wasExtraDark && abs(newPosition - sliderPosition) < 1e-9 { return }
        sliderPosition = newPosition
        if wasExtraDark { screen.setImageLevel(1) }
        store.savedPosition = sliderPosition
        onChange?()
    }

    /// Call after wake / display changes, when macOS may have wiped the dimming.
    public func reapplyDimming() {
        screen.setImageLevel(BrightnessMapping.output(forSlider: sliderPosition).imageLevel)
    }

    /// Call on quit: removes extra darkness, leaves the backlight and saved position alone.
    public func shutdown() {
        screen.setImageLevel(1)
    }

    private func apply(_ position: Double) {
        sliderPosition = min(max(position, 0), 1)
        let out = BrightnessMapping.output(forSlider: sliderPosition)
        screen.setBacklight(out.backlight)
        screen.setImageLevel(out.imageLevel)
        store.savedPosition = sliderPosition
        onChange?()
    }
}
