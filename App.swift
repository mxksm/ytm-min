import SwiftUI
import WebKit

@main
struct CustomMiniPlayerApp: App {
    @StateObject private var bridge = YTMusicBridge()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings { EmptyView() }
    }
}

// Custom window class to force borderless windows to accept keyboard shortcuts
class CustomWindow: NSWindow {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: CustomWindow!
    var bridge = YTMusicBridge()
    
    let smallWidth: CGFloat = 220
    let smallHeight: CGFloat = 36
    
    let largeWidth: CGFloat = 800
    let largeHeight: CGFloat = 600
    
    let screenPadding: CGFloat = 10
    
    var isExpanded = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = CustomWindow(
            contentRect: NSRect(x: 0, y: 0, width: smallWidth, height: smallHeight),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating 
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        updateView()
        snapToCorner()
        window.makeKeyAndOrderFront(nil)
        
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            if event.modifierFlags.contains(.command) {
                if event.characters == "1" {
                    self.resizePlayer(expand: false)
                    return nil
                } else if event.characters == "2" {
                    self.resizePlayer(expand: true)
                    return nil
                }
            }
            return event
        }
    }
    
    private func updateView() {
        let contentView = ContentView(bridge: bridge, isExpanded: isExpanded, smallWidth: smallWidth)
        window.contentView = NSHostingView(rootView: contentView)
    }
    
    private func resizePlayer(expand: Bool) {
        guard isExpanded != expand else { return }
        isExpanded = expand
        updateView()
        snapToCorner()
    }
    
    private func snapToCorner() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        
        let targetWidth = isExpanded ? largeWidth : smallWidth
        let targetHeight = isExpanded ? largeHeight : smallHeight
        
        // This math ensures the bottom right corner of the app always stays pinned 
        // to the bottom right corner of your screen, even when it grows to 800x600
        let newX = screenFrame.maxX - targetWidth - screenPadding
        let newY = screenFrame.minY + screenPadding
        
        let newFrame = NSRect(x: newX, y: newY, width: targetWidth, height: targetHeight)
        
        // Changing animate to true gives it a smooth expanding effect
        window.setFrame(newFrame, display: true, animate: true)
    }
}
