import CoreGraphics
import Darwin
import DimmerCore

/// Apple's private DisplayServices framework — the same calls the brightness keys use.
/// Not public API, so a future macOS update could break it.
private enum DisplayServices {
    typealias GetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    typealias SetBrightness = @convention(c) (CGDirectDisplayID, Float) -> Int32

    nonisolated(unsafe) private static let handle = dlopen(
        "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY)

    static let getBrightness: GetBrightness? = symbol("DisplayServicesGetBrightness")
    static let setBrightness: SetBrightness? = symbol("DisplayServicesSetBrightness")

    private static func symbol<T>(_ name: String) -> T? {
        guard let handle, let sym = dlsym(handle, name) else { return nil }
        return unsafeBitCast(sym, to: T.self)
    }
}

/// The MacBook's own screen. Real backlight via DisplayServices; extra darkness by
/// scaling the display's color output (its gamma table). If this process dies,
/// macOS puts the gamma table back by itself, so the screen can't get stuck dark.
@MainActor
final class BuiltInScreen: ScreenControlling {
    typealias Table = (red: [CGGammaValue], green: [CGGammaValue], blue: [CGGammaValue])

    let displayID: CGDirectDisplayID
    private let original: Table
    private var imageLevel: Double = 1

    init?() {
        guard let id = Self.findBuiltInDisplay() else { return nil }
        displayID = id
        original = Self.readTable(id) ?? Self.identityTable()
    }

    func readBacklight() -> Double? {
        guard let get = DisplayServices.getBrightness else { return nil }
        var value: Float = 0
        guard get(displayID, &value) == 0 else { return nil }
        return Double(value)
    }

    func setBacklight(_ value: Double) {
        _ = DisplayServices.setBrightness?(displayID, Float(min(max(value, 0), 1)))
    }

    func setImageLevel(_ value: Double) {
        imageLevel = min(max(value, 0), 1)
        writeTable(for: imageLevel)
    }

    /// Puts the dimming back if something (wake, a color profile change) wiped it.
    func ensureApplied() {
        guard imageLevel < 1,
              let current = Self.readTable(displayID),
              let actualTop = current.red.last,
              let originalTop = original.red.last else { return }
        if abs(Double(actualTop) - Double(originalTop) * imageLevel) > 0.002 {
            writeTable(for: imageLevel)
        }
    }

    private func writeTable(for level: Double) {
        let scale = CGGammaValue(level)
        let r = original.red.map { $0 * scale }
        let g = original.green.map { $0 * scale }
        let b = original.blue.map { $0 * scale }
        CGSetDisplayTransferByTable(displayID, UInt32(r.count), r, g, b)
    }

    private static func findBuiltInDisplay() -> CGDirectDisplayID? {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return nil }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &ids, &count) == .success else { return nil }
        return ids.prefix(Int(count)).first { CGDisplayIsBuiltin($0) != 0 }
    }

    private static func readTable(_ id: CGDirectDisplayID) -> Table? {
        let capacity = CGDisplayGammaTableCapacity(id)
        guard capacity > 0 else { return nil }
        var r = [CGGammaValue](repeating: 0, count: Int(capacity))
        var g = r, b = r
        var count: UInt32 = 0
        guard CGGetDisplayTransferByTable(id, capacity, &r, &g, &b, &count) == .success,
              count > 0 else { return nil }
        let n = Int(count)
        return (Array(r.prefix(n)), Array(g.prefix(n)), Array(b.prefix(n)))
    }

    private static func identityTable() -> Table {
        let ramp = (0..<256).map { CGGammaValue($0) / 255 }
        return (ramp, ramp, ramp)
    }
}
