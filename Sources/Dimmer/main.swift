import AppKit

let app = NSApplication.shared

// Developer aid: `Dimmer --render-menu-preview out.png` draws the slider panel
// in light and dark mode to an image, without touching the screen.
let args = CommandLine.arguments
if let i = args.firstIndex(of: "--render-menu-preview"), i + 1 < args.count {
    MainActor.assumeIsolated { MenuPreview.render(to: args[i + 1]) }
    exit(0)
}

let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
