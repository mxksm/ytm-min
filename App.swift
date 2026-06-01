import SwiftUI
import WebKit

@main
struct CustomMiniPlayerApp: App {
    @StateObject private var bridge = YTMusicBridge()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene { Settings { EmptyView() } }
}

class CustomWindow: NSWindow {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: CustomWindow!
    var bridge = YTMusicBridge()
    let smallWidth: CGFloat = 220
    let smallHeight: CGFloat = 44
    let largeWidth: CGFloat = 800
    let largeHeight: CGFloat = 600
    let screenPadding: CGFloat = 10
    var isExpanded = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = CustomWindow(contentRect: NSRect(x: 0, y: 0, width: smallWidth, height: smallHeight),
                              styleMask: [.borderless, .fullSizeContentView], backing: .buffered, defer: false)
        window.isOpaque = false; window.backgroundColor = .clear; window.hasShadow = true; window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        updateView(); snapToCorner(); window.makeKeyAndOrderFront(nil)
        
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            
            // Global Resizing & Positioning Binds
            if event.modifierFlags.contains(.command) {
                if event.characters == "1" { self.resizePlayer(expand: false); return nil }
                if event.characters == "2" { self.resizePlayer(expand: true); return nil }
                if event.characters == "3" { self.snapToCorner(); return nil }
            }
            
            // Widget-Local Vim Binds
            if !self.isExpanded {
                if event.keyCode == 36 { self.bridge.togglePlayPause(); return nil } // Enter
                if event.keyCode == 124 { self.bridge.nextTrack(); return nil }      // Right Arrow
                if event.keyCode == 123 { self.bridge.previousTrack(); return nil }  // Left Arrow
                
                if let char = event.charactersIgnoringModifiers {
                    switch char {
                    case "p": self.bridge.togglePlayPause(); return nil
                    case "l": self.bridge.nextTrack(); return nil
                    case "h": self.bridge.previousTrack(); return nil
                    case "k": self.bridge.increaseVolume(); return nil // Volume Up
                    case "j": self.bridge.decreaseVolume(); return nil // Volume Down
                    default: break
                    }
                }
            }
            return event
        }
    }
    
    private func updateView() { window.contentView = NSHostingView(rootView: ContentView(bridge: bridge, isExpanded: isExpanded, smallWidth: smallWidth)) }
    private func resizePlayer(expand: Bool) { guard isExpanded != expand else { return }; isExpanded = expand; updateView(); snapToCorner() }
    private func snapToCorner() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let targetWidth = isExpanded ? largeWidth : smallWidth
        let targetHeight = isExpanded ? largeHeight : smallHeight
        window.setFrame(NSRect(x: screenFrame.maxX - targetWidth - screenPadding, y: screenFrame.minY + screenPadding, width: targetWidth, height: targetHeight), display: true, animate: true)
    }
}
