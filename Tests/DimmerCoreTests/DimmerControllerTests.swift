import Testing
@testable import DimmerCore

/// Stands in for the MacBook screen: remembers what was set, like the real one.
@MainActor
final class FakeScreen: ScreenControlling {
    var backlight: Double? = 0.5
    var imageLevel: Double = 1.0
    var imageLevelWrites = 0

    func readBacklight() -> Double? { backlight }
    func setBacklight(_ value: Double) { backlight = value }
    func setImageLevel(_ value: Double) {
        imageLevel = value
        imageLevelWrites += 1
    }
}

@MainActor
final class MemoryStore: PositionStoring {
    var savedPosition: Double?
    init(_ saved: Double? = nil) { savedPosition = saved }
}

private func close(_ a: Double?, _ b: Double) -> Bool {
    guard let a else { return false }
    return abs(a - b) < 1e-6
}

@MainActor
@Suite struct DimmerControllerTests {
    // MARK: Starting up

    @Test func startsAtCurrentBacklightWhenNothingSaved() {
        let screen = FakeScreen()
        screen.backlight = 0.5
        let c = DimmerController(screen: screen, store: MemoryStore())
        #expect(close(c.sliderPosition, BrightnessMapping.sliderPosition(forBacklight: 0.5)))
        #expect(close(screen.backlight, 0.5))
        #expect(close(screen.imageLevel, 1.0))
    }

    @Test func restoresSavedExtraDarkPosition() {
        let screen = FakeScreen()
        screen.backlight = 0.8
        let c = DimmerController(screen: screen, store: MemoryStore(0.125))
        #expect(close(c.sliderPosition, 0.125))
        #expect(close(screen.backlight, BrightnessMapping.lowestLitBacklight))
        #expect(close(screen.imageLevel, 0.55))
    }

    @Test func savedPositionAboveApplesLowestDoesNotOverrideCurrentBacklight() {
        let screen = FakeScreen()
        screen.backlight = 0.2
        let c = DimmerController(screen: screen, store: MemoryStore(0.9))
        #expect(close(c.sliderPosition, BrightnessMapping.sliderPosition(forBacklight: 0.2)))
        #expect(close(screen.backlight, 0.2))
    }

    // MARK: Moving the slider

    @Test func movingSliderInUpperZoneSetsBacklight() {
        let screen = FakeScreen()
        let c = DimmerController(screen: screen, store: MemoryStore())
        c.setSlider(1.0)
        #expect(close(screen.backlight, 1.0))
        #expect(close(screen.imageLevel, 1.0))
    }

    @Test func movingSliderIntoExtraDarkDimsImageAtLowestBacklight() {
        let screen = FakeScreen()
        let c = DimmerController(screen: screen, store: MemoryStore())
        c.setSlider(0.0)
        #expect(close(screen.backlight, BrightnessMapping.lowestLitBacklight))
        #expect(close(screen.imageLevel, 0.10))
        #expect(c.isExtraDark)
    }

    @Test func sliderPositionIsSaved() {
        let store = MemoryStore()
        let c = DimmerController(screen: FakeScreen(), store: store)
        c.setSlider(0.1)
        #expect(close(store.savedPosition, 0.1))
    }

    @Test func percentShowsSliderPosition() {
        let c = DimmerController(screen: FakeScreen(), store: MemoryStore())
        c.setSlider(0.14)
        #expect(c.percent == 14)
    }

    @Test func changeHandlerFiresWhenSliderMoves() {
        let c = DimmerController(screen: FakeScreen(), store: MemoryStore())
        var calls = 0
        c.onChange = { calls += 1 }
        c.setSlider(0.3)
        #expect(calls == 1)
    }

    // MARK: Following the brightness keys / Control Center

    @Test func brightnessKeyChangeMovesSlider() {
        let screen = FakeScreen()
        let c = DimmerController(screen: screen, store: MemoryStore())
        c.setSlider(1.0)
        screen.backlight = 0.5 // user pressed brightness-down
        c.syncWithSystem()
        #expect(close(c.sliderPosition, BrightnessMapping.sliderPosition(forBacklight: 0.5)))
    }

    @Test func brightnessUpWhileExtraDarkEndsExtraDarkness() {
        let screen = FakeScreen()
        let store = MemoryStore()
        let c = DimmerController(screen: screen, store: store)
        c.setSlider(0.05)
        screen.backlight = 0.125 // one key press up from the lowest lit level
        c.syncWithSystem()
        #expect(!c.isExtraDark)
        #expect(close(screen.imageLevel, 1.0))
        #expect(close(store.savedPosition, c.sliderPosition))
    }

    @Test func extraDarkStaysWhenBacklightUnchanged() {
        let screen = FakeScreen()
        let c = DimmerController(screen: screen, store: MemoryStore())
        c.setSlider(0.05)
        c.syncWithSystem()
        #expect(close(c.sliderPosition, 0.05))
        #expect(c.isExtraDark)
    }

    @Test func tinyReadbackDifferencesAreIgnored() {
        let screen = FakeScreen()
        let c = DimmerController(screen: screen, store: MemoryStore())
        c.setSlider(0.625)
        screen.backlight = BrightnessMapping.output(forSlider: 0.625).backlight + 0.005
        c.syncWithSystem()
        #expect(close(c.sliderPosition, 0.625))
    }

    @Test func unreadableBacklightChangesNothing() {
        let screen = FakeScreen()
        let c = DimmerController(screen: screen, store: MemoryStore())
        c.setSlider(0.05)
        screen.backlight = nil
        c.syncWithSystem()
        #expect(close(c.sliderPosition, 0.05))
    }

    @Test func changeHandlerFiresWhenKeysMoveSlider() {
        let screen = FakeScreen()
        let c = DimmerController(screen: screen, store: MemoryStore())
        var calls = 0
        c.onChange = { calls += 1 }
        screen.backlight = 0.9
        c.syncWithSystem()
        #expect(calls == 1)
    }

    @Test func brightnessDownToOffWhileExtraDarkEndsExtraDarkAtApplesLowest() {
        let screen = FakeScreen()
        let c = DimmerController(screen: screen, store: MemoryStore())
        c.setSlider(0.05)
        screen.backlight = 0 // user pressed brightness-down past the lowest lit level: screen off
        c.syncWithSystem()
        #expect(!c.isExtraDark)
        #expect(close(c.sliderPosition, BrightnessMapping.applesLowest))
        #expect(close(screen.imageLevel, 1.0))
    }

    @Test func screenSwitchedOffDoesNotKeepFiringChanges() {
        let screen = FakeScreen()
        let c = DimmerController(screen: screen, store: MemoryStore())
        screen.backlight = 0
        c.syncWithSystem()
        var calls = 0
        c.onChange = { calls += 1 }
        c.syncWithSystem()
        c.syncWithSystem()
        #expect(calls == 0)
    }

    // MARK: Wake, quit

    @Test func reapplyResendsCurrentDimming() {
        let screen = FakeScreen()
        let c = DimmerController(screen: screen, store: MemoryStore())
        c.setSlider(0.05)
        screen.imageLevel = 1.0 // macOS wiped it, e.g. after wake
        c.reapplyDimming()
        #expect(close(screen.imageLevel, BrightnessMapping.output(forSlider: 0.05).imageLevel))
    }

    @Test func shutdownRemovesDimmingButKeepsBacklight() {
        let screen = FakeScreen()
        let store = MemoryStore()
        let c = DimmerController(screen: screen, store: store)
        c.setSlider(0.05)
        c.shutdown()
        #expect(close(screen.imageLevel, 1.0))
        #expect(close(screen.backlight, BrightnessMapping.lowestLitBacklight))
        #expect(close(store.savedPosition, 0.05)) // reopening starts where you left it
    }
}
