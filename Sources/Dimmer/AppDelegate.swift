import AppKit
import DimmerCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let sliderView = SliderMenuView()
    private var screen: BuiltInScreen?
    private var controller: DimmerController?
    private var timer: Timer?
    /// The backlight can lag a moment behind what we set; don't mistake that for the brightness keys.
    private var lastSliderChange = Date.distantPast

    func applicationDidFinishLaunching(_ notification: Notification) {
        let icon = NSImage(systemSymbolName: "sun.max", accessibilityDescription: "Dimmer")
        icon?.isTemplate = true
        statusItem.button?.image = icon

        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        statusItem.menu = menu

        guard let screen = BuiltInScreen() else {
            let item = NSMenuItem(title: "No built-in screen found", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            menu.addItem(.separator())
            menu.addItem(quitItem())
            return
        }
        self.screen = screen

        let controller = DimmerController(screen: screen, store: DefaultsStore())
        self.controller = controller
        controller.onChange = { [weak self] in self?.refresh() }
        sliderView.slider.onChange = { [weak self] value in
            self?.lastSliderChange = Date()
            self?.controller?.setSlider(value)
        }

        let sliderItem = NSMenuItem()
        sliderItem.view = sliderView
        menu.addItem(sliderItem)
        menu.addItem(.separator())
        menu.addItem(quitItem())
        refresh()

        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        let reapply: @Sendable (Notification) -> Void = { [weak self] _ in
            MainActor.assumeIsolated { self?.controller?.reapplyDimming() }
        }
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main, using: reapply)
        workspace.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main, using: reapply)
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main, using: reapply)
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.shutdown()
    }

    // MARK: Menu

    func menuWillOpen(_ menu: NSMenu) {
        syncIfSettled()
        refresh()
    }

    private func quitItem() -> NSMenuItem {
        NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    private func refresh() {
        guard let controller else { return }
        sliderView.show(position: controller.sliderPosition, percent: controller.percent)
    }

    // MARK: Background upkeep

    private func tick() {
        screen?.ensureApplied()
        syncIfSettled()
    }

    private func syncIfSettled() {
        guard Date().timeIntervalSince(lastSliderChange) > 1.5 else { return }
        controller?.syncWithSystem()
    }
}
