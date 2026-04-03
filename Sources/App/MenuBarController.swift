import AppKit
import SwiftUI
import Combine

/// MenuBarController manages the menu bar status item and popover lifecycle.
/// It tracks the open/closed state of the popover and handles global hotkeys.
@MainActor
final class MenuBarController: NSObject, ObservableObject {
    // MARK: - Published State

    @Published private(set) var isPopoverOpen = false
    @Published private(set) var isClaudeThinking = false
    @Published private(set) var currentProject: String?

    // MARK: - UI Components

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private nonisolated(unsafe) var eventMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Configuration

    struct Config {
        var showBadgeWhenThinking = true
        var globalHotkey: String = "command+space"
        var defaultPopoverSize = NSSize(width: 480, height: 640)
    }

    var config = Config()

    // MARK: - Init

    override init() {
        super.init()
        setupStatusItem()
        setupPopover()
        setupGlobalHotkey()
        setupEventMonitor()
    }

    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // MARK: - Public API

    /// Toggles the popover open/closed.
    func togglePopover() {
        if isPopoverOpen {
            closePopover()
        } else {
            openPopover()
        }
    }

    /// Opens the popover.
    func openPopover() {
        guard let button = statusItem?.button else { return }

        popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        isPopoverOpen = true
    }

    /// Closes the popover.
    func closePopover() {
        popover?.performClose(nil)
        isPopoverOpen = false
    }

    /// Sets the thinking indicator.
    func setThinking(_ thinking: Bool) {
        isClaudeThinking = thinking
        updateStatusItemBadge()
    }

    /// Sets the current project name.
    func setProject(_ name: String?) {
        currentProject = name
        updateStatusItemTitle()
    }

    /// Shows a notification via the status item.
    func showNotification(title: String, body: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = body
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }

    // MARK: - Private Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem?.button else { return }

        // Set up the brain icon using SF Symbols
        if let image = NSImage(systemSymbolName: "brain.head.profile", accessibilityDescription: "Axis") {
            image.isTemplate = true
            button.image = image
        } else {
            // Fallback to text
            button.title = "AX"
        }

        button.action = #selector(statusItemClicked)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        updateStatusItemTitle()
    }

    private func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = config.defaultPopoverSize
        popover?.behavior = .transient
        popover?.animates = true

        // Set the content view controller
        // In R2, this would be the main Axis content
        let contentView = PopoverContentView()
        popover?.contentViewController = NSHostingController(rootView: contentView)
    }

    private func setupGlobalHotkey() {
        // Register global hotkey (Cmd+Space) using Carbon API
        // Note: This may conflict with Spotlight - user should be warned
        installGlobalHotkey()
    }

    private func setupEventMonitor() {
        // Monitor for clicks outside the popover to close it
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            // Only close if clicking outside the popover
            guard let self = self, self.isPopoverOpen else { return }

            if let popoverFrame = self.popover?.contentViewController?.view.window?.frame {
                let clickLocation = event.locationInWindow
                let screenLocation = NSEvent.mouseLocation

                if !popoverFrame.contains(screenLocation) {
                    self.closePopover()
                }
            }
        }
    }

    // MARK: - Actions

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent

        if event?.type == .rightMouseUp {
            // Right-click shows menu
            showStatusMenu()
        } else {
            // Left-click toggles popover
            togglePopover()
        }
    }

    private func showStatusMenu() {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "Open Axis", action: #selector(openAxis), keyEquivalent: "o"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "New Chat", action: #selector(newChat), keyEquivalent: "n"))
        menu.addItem(NSMenuItem(title: "Skills...", action: #selector(showSkills), keyEquivalent: "k"))
        menu.addItem(NSMenuItem.separator())

        let projectsItem = NSMenuItem(title: "Recent Projects", action: nil, keyEquivalent: "")
        let projectsMenu = NSMenu()
        // In R2, populate with recent projects
        projectsItem.submenu = projectsMenu
        menu.addItem(projectsItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Axis", action: #selector(quitAxis), keyEquivalent: "q"))

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func openAxis() {
        openPopover()
    }

    @objc private func newChat() {
        openPopover()
        // In R2, trigger new chat action
    }

    @objc private func showSkills() {
        openPopover()
        // In R2, switch to Skills tab
    }

    @objc private func showSettings() {
        openPopover()
        // In R2, open settings
    }

    @objc private func quitAxis() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Status Item Updates

    private func updateStatusItemTitle() {
        // In R2, show project name or generic title
        guard let button = statusItem?.button else { return }

        if let project = currentProject {
            button.title = " \(project.prefix(8))"
            button.imagePosition = .imageLeading
        } else {
            button.title = ""
            button.imagePosition = .imageOnly
        }
    }

    private func updateStatusItemBadge() {
        guard let button = statusItem?.button else { return }

        if isClaudeThinking && config.showBadgeWhenThinking {
            // Show a small indicator dot
            if let image = NSImage(systemSymbolName: "brain.head.profile", accessibilityDescription: "Axis") {
                let config = NSImage.SymbolConfiguration(paletteColors: [.systemBlue])
                button.image = image.withSymbolConfiguration(config)

                // Add a badge overlay
                let badge = NSView(frame: NSRect(x: 14, y: 14, width: 8, height: 8))
                badge.wantsLayer = true
                badge.layer?.backgroundColor = NSColor.systemGreen.cgColor
                badge.layer?.cornerRadius = 4

                // This is a simplified approach; in production use NSStatusBarButton overlay
            }
        } else {
            if let image = NSImage(systemSymbolName: "brain.head.profile", accessibilityDescription: "Axis") {
                image.isTemplate = true
                button.image = image
            }
        }
    }

    // MARK: - Global Hotkey (Carbon API)

    private var globalHotkeyRef: Any? = nil

    private func installGlobalHotkey() {
        // Using Carbon API for global hotkey registration
        // Note: This is a simplified version; production would need proper Carbon hotkey handling
        //
        // In production, you would use:
        // - RegisterEventHotKey from Carbon API
        // Or use a library like HotKey (Swift package)
        //
        // For now, we rely on the system's Spotlight conflict or let users configure
        print("[MenuBarController] Global hotkey registration would use Carbon API here")
    }
}

