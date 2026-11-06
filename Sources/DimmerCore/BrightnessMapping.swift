/// Maps the single 0...1 slider onto the two things it controls:
/// the real backlight, and the extra image darkening below Apple's lowest.
///
///   0 ........ applesLowest ............................ 1
///   |  extra dark  |  real backlight lowestLit → 1         |
///   image 10%→100%            image stays 100%
public enum BrightnessMapping {
    public struct Output: Equatable, Sendable {
        public var backlight: Double
        public var imageLevel: Double
    }

    /// Slider position where Apple's own slider bottoms out.
    public static let applesLowest: Double = 0.25
    /// How much of the image is left at the very bottom of the slider. Never black.
    public static let darkestImageLevel: Double = 0.10
    /// Backlight 0 switches a MacBook screen fully off. One brightness-key step (1/16)
    /// is the dimmest level that's still lit, so that's as low as the backlight goes.
    public static let lowestLitBacklight: Double = 1.0 / 16

    public static func output(forSlider position: Double) -> Output {
        let p = min(max(position, 0), 1)
        if p >= applesLowest {
            let t = (p - applesLowest) / (1 - applesLowest)
            return Output(backlight: lowestLitBacklight + t * (1 - lowestLitBacklight), imageLevel: 1)
        }
        let t = p / applesLowest
        return Output(backlight: lowestLitBacklight,
                      imageLevel: darkestImageLevel + (1 - darkestImageLevel) * t)
    }

    /// Where the slider sits for a backlight level. Anything at or below the
    /// lowest lit level (including switched off) shows as Apple's lowest.
    public static func sliderPosition(forBacklight backlight: Double) -> Double {
        let b = min(max(backlight, lowestLitBacklight), 1)
        return applesLowest + (b - lowestLitBacklight) / (1 - lowestLitBacklight) * (1 - applesLowest)
    }

    public static func isExtraDark(_ position: Double) -> Bool {
        position < applesLowest
    }
}
