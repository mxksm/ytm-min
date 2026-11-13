import SwiftUI
import WebKit

@main
struct CustomMiniPlayerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene { Settings { EmptyView() } }
}

class CustomWindow: NSWindow {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}

final class PlayerWindowState: ObservableObject {
    @Published var isExpanded = false
    @Published var isTransparent = true
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: CustomWindow!
    var bridge = YTMusicBridge()
    let smallWidth: CGFloat = 150
    let smallHeight: CGFloat = 34
    let largeWidth: CGFloat = 800
    let largeHeight: CGFloat = 600
    
    // Separate padding for X and Y axis
    let paddingX: CGFloat = 10 + 100
    let paddingY: CGFloat = 10
    
    private let viewState = PlayerWindowState()
    private var isExpanded: Bool { viewState.isExpanded }
    var isAutoHideEnabled = true
    
    private var lastSmallPlayerPosition: NSRect?
    private var screenObserver: NSObjectProtocol?
    private var keyMonitor: Any?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Removed .fullSizeContentView to strip insets
        window = CustomWindow(contentRect: NSRect(x: 0, y: 0, width: smallWidth, height: smallHeight),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        
        // hasShadow = false removes the black rim/bezel effect
        window.isOpaque = false; window.backgroundColor = .clear; window.hasShadow = false; window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        window.contentView = NSHostingView(rootView: ContentView(bridge: bridge, state: viewState, smallWidth: smallWidth, smallHeight: smallHeight))
        window.isMovableByWindowBackground = true
        bridge.onShortcut = { [weak self] action in self?.perform(action) }
        snapToCorner()
        window.makeKeyAndOrderFront(nil)

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.lastSmallPlayerPosition = nil
            self.snapToCorner()
        }
        
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.window else { return event }
            if let action = KeyboardShortcuts.action(keyCode: event.keyCode,
                                                     characters: event.charactersIgnoringModifiers,
                                                     modifiers: event.modifierFlags, expanded: self.isExpanded) {
                if !event.isARepeat || action.allowsRepeat { self.perform(action) }
                return nil
            }
            // Leave standard modified shortcuts (copy/paste, etc.) to the responder.
            let modified = !event.modifierFlags.intersection([.command, .control, .option]).isEmpty
            return self.isExpanded || modified ? event : nil
        }
    }

    private func perform(_ action: PlayerAction) {
        switch action {
        case .toggleSize: togglePlayerSize()
        case .toggleAutoHide: toggleAutoHide()
        case .toggleTransparency: viewState.isTransparent.toggle()
        case .snap: snapToCorner()
        case .quit: NSApplication.shared.terminate(nil)
        case .reload: bridge.reload()
        default: bridge.perform(action)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        bridge.shutdown()
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        updateVisibility()
    }
    
    func applicationDidResignActive(_ notification: Notification) {
        updateVisibility()
    }
    
    private func updateVisibility() {
        guard let window else { return }
        let shouldHide = isAutoHideEnabled && !NSApplication.shared.isActive
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            window.animator().alphaValue = shouldHide ? 0.0 : 1.0
        }
        window.ignoresMouseEvents = shouldHide
    }
    
    private func toggleAutoHide() {
        isAutoHideEnabled.toggle()
        updateVisibility()
    }
    
    private func togglePlayerSize() {
        if !isExpanded { lastSmallPlayerPosition = window.frame }
        viewState.isExpanded.toggle()
        window.isMovableByWindowBackground = !isExpanded
        window.makeFirstResponder(isExpanded ? bridge.webView : window)
        
        if isExpanded {
            resizeInPlace()
        } else if let lastPos = lastSmallPlayerPosition {
            window.setFrame(clamped(lastPos), display: true, animate: true)
            lastSmallPlayerPosition = nil
        } else {
            // A display change may invalidate the saved compact frame.
            snapToCorner()
        }
    }
    
    private func resizeInPlace() {
        guard let screen = window.screen ?? NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let currentFrame = window.frame
        
        let targetWidth = isExpanded ? largeWidth : smallWidth
        let targetHeight = isExpanded ? largeHeight : smallHeight
        
        var newX = currentFrame.origin.x
        var newY = currentFrame.origin.y
        
        if currentFrame.midX > screenFrame.midX { newX = currentFrame.maxX - targetWidth } else { newX = currentFrame.minX }
        if currentFrame.midY > screenFrame.midY { newY = currentFrame.maxY - targetHeight } else { newY = currentFrame.minY }
        
        // Applied paddingX and paddingY
        newX = max(screenFrame.minX + paddingX, min(newX, screenFrame.maxX - targetWidth - paddingX))
        newY = max(screenFrame.minY + paddingY, min(newY, screenFrame.maxY - targetHeight - paddingY))
        
        window.setFrame(clamped(NSRect(x: newX, y: newY, width: targetWidth, height: targetHeight)), display: true, animate: true)
    }
    
    private func snapToCorner() {
        guard let screen = window.screen ?? NSScreen.main else { return }

        if !isExpanded, let shoulder = screen.auxiliaryTopLeftArea {
            let height = min(smallHeight, shoulder.height)
            let width = min(smallWidth, max(0, shoulder.width - 12))
            let frame = NSRect(
                x: shoulder.minX + 6,
                y: shoulder.maxY - height,
                width: width,
                height: height
            )
            window.setFrame(frame, display: true, animate: true)
            return
        }

        let screenFrame = screen.visibleFrame
        let targetWidth = isExpanded ? largeWidth : smallWidth
        let targetHeight = isExpanded ? largeHeight : smallHeight
        
        // Applied paddingX and paddingY
        window.setFrame(clamped(NSRect(x: screenFrame.maxX - targetWidth - paddingX, y: screenFrame.minY + paddingY, width: targetWidth, height: targetHeight)), display: true, animate: true)
    }
    private func clamped(_ frame: NSRect) -> NSRect {
        let screen = NSScreen.screens.first { $0.frame.intersects(frame) } ?? window.screen ?? NSScreen.main
        guard let screen else { return frame }
        // A saved mini player may live in the menu-bar shoulder beside the notch.
        let bounds = !isExpanded && frame.maxY > screen.visibleFrame.maxY ? screen.frame : screen.visibleFrame
        let width = min(frame.width, bounds.width)
        let height = min(frame.height, bounds.height)
        return NSRect(x: min(max(frame.minX, bounds.minX), bounds.maxX - width),
                      y: min(max(frame.minY, bounds.minY), bounds.maxY - height), width: width, height: height)
    }

}
