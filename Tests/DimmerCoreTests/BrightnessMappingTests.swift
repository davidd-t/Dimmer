import Testing
@testable import DimmerCore

private func close(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 1e-9 }

@Suite struct BrightnessMappingTests {
    @Test func topOfSliderIsFullBacklightAndFullImage() {
        let out = BrightnessMapping.output(forSlider: 1.0)
        #expect(close(out.backlight, 1.0))
        #expect(close(out.imageLevel, 1.0))
    }

    @Test func lowestLitBacklightIsOneKeyStepAboveOff() {
        // Backlight 0 switches the MacBook screen fully off; one brightness-key step (1/16) is the dimmest lit level.
        #expect(close(BrightnessMapping.lowestLitBacklight, 1.0 / 16))
    }

    @Test func applesLowestMarkIsLowestLitBacklightWithNoExtraDimming() {
        let out = BrightnessMapping.output(forSlider: BrightnessMapping.applesLowest)
        #expect(close(out.backlight, BrightnessMapping.lowestLitBacklight))
        #expect(close(out.imageLevel, 1.0))
    }

    @Test func applesLowestSitsAtOneQuarterOfTheSlider() {
        #expect(close(BrightnessMapping.applesLowest, 0.25))
    }

    @Test func bottomOfSliderIsDarkestButNeverBlack() {
        let out = BrightnessMapping.output(forSlider: 0.0)
        #expect(close(out.backlight, BrightnessMapping.lowestLitBacklight))
        #expect(close(out.imageLevel, 0.10))
    }

    @Test func extraDarkZoneScalesImageLinearly() {
        let out = BrightnessMapping.output(forSlider: 0.125)
        #expect(close(out.backlight, BrightnessMapping.lowestLitBacklight))
        #expect(close(out.imageLevel, 0.55))
    }

    @Test func upperZoneScalesBacklightLinearly() {
        let out = BrightnessMapping.output(forSlider: 0.625)
        #expect(close(out.backlight, 0.0625 + 0.5 * (1 - 0.0625)))
        #expect(close(out.imageLevel, 1.0))
    }

    @Test func outOfRangeSliderValuesAreClamped() {
        #expect(BrightnessMapping.output(forSlider: -0.5) == BrightnessMapping.output(forSlider: 0))
        #expect(BrightnessMapping.output(forSlider: 1.5) == BrightnessMapping.output(forSlider: 1))
    }

    @Test func backlightMapsBackToSliderPosition() {
        #expect(close(BrightnessMapping.sliderPosition(forBacklight: 0.0625), 0.25))
        #expect(close(BrightnessMapping.sliderPosition(forBacklight: 0.0625 + 0.5 * (1 - 0.0625)), 0.625))
        #expect(close(BrightnessMapping.sliderPosition(forBacklight: 1), 1.0))
    }

    @Test func backlightSwitchedOffMapsToApplesLowest() {
        #expect(close(BrightnessMapping.sliderPosition(forBacklight: 0), 0.25))
    }

    @Test func extraDarkMeansBelowApplesLowest() {
        #expect(BrightnessMapping.isExtraDark(0.2))
        #expect(!BrightnessMapping.isExtraDark(0.25))
        #expect(!BrightnessMapping.isExtraDark(0.9))
    }
}
