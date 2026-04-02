import AppKit
import SwiftUI
import Carbon

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var eventMonitor: Any?
    private var globalHotkeyMonitor: Any?

    // CGEvent tap for global hotkey
    private var eventTap: CFMachPort?

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request notification authorization
        NotificationService.shared.requestAuthorization()

        setupStatusItem()
        setupPopover()
        setupEventMonitor()
        registerGlobalHotkey()
    }

    func applicationWillTerminate(_ notification: Notification) {
        unregisterGlobalHotkey()
    }

    // MARK: - Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
            let image = NSImage(systemSymbolName: "brain.head.profile", accessibilityDescription: "Axis")
            image?.isTemplate = true
            button.image = image?.withSymbolConfiguration(config)
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 480, height: 640)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: PopoverContentView())
    }

    private func setupEventMonitor() {
        // Close popover when clicking outside
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if self?.popover.isShown == true {
                self?.popover.performClose(nil)
            }
        }
    }

    // MARK: - Popover Toggle

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            if let button = statusItem.button {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }

    // MARK: - Global Hotkey (⌘+Space) using CGEvent Tap

    private func registerGlobalHotkey() {
        // Create event tap for key down events
        // We need to monitor maskKeyDown to catch Cmd+Space
        let eventMask = (1 << CGEventType.keyDown.rawValue)

        // Callback for CGEvent tap
        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon = refcon else { return Unmanaged.passRetained(event) }

            let appDelegate = Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue()

            if type == .keyDown {
                let flags = event.flags
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

                // Check for Cmd+Space: keycode 49 (Space), modifiers include Command
                if keyCode == 49 && flags.contains(.maskCommand) && !flags.contains(.maskControl) && !flags.contains(.maskAlternate) {
                    DispatchQueue.main.async {
                        appDelegate.togglePopover()
                    }
                    // Consume the event
                    return nil
                }
            }

            return Unmanaged.passRetained(event)
        }

        // Create the event tap
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("[Axis] Failed to create event tap. Check Accessibility permissions.")
            // Fallback to less privileged monitoring
            registerFallbackHotkey()
            return
        }

        eventTap = tap

        // Create run loop source and add to current run loop
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        print("[Axis] Global hotkey registered (Cmd+Space)")
    }

    private func registerFallbackHotkey() {
        // Fallback using NSEvent.addGlobalMonitorForEvents
        // Note: This doesn't work when app is not active, but as a menu bar app
        // the user expects Cmd+Space to work globally
        globalHotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Check for Cmd+Space
            if event.modifierFlags.contains(.command) &&
               !event.modifierFlags.contains(.control) &&
               !event.modifierFlags.contains(.option) &&
               event.keyCode == 49 {
                DispatchQueue.main.async {
                    self?.togglePopover()
                }
            }
        }
    }

    private func unregisterGlobalHotkey() {
        // Disable and remove event tap
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            eventTap = nil
        }

        // Remove fallback monitor
        if let monitor = globalHotkeyMonitor {
            NSEvent.removeMonitor(monitor)
            globalHotkeyMonitor = nil
        }
    }
}
