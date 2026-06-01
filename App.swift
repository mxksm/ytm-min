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
    var isTransparent = false 
    
    private var lastSmallPlayerPosition: NSRect?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = CustomWindow(contentRect: NSRect(x: 0, y: 0, width: smallWidth, height: smallHeight),
                              styleMask: [.borderless, .fullSizeContentView], backing: .buffered, defer: false)
        window.isOpaque = false; window.backgroundColor = .clear; window.hasShadow = true; window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        updateView(); snapToCorner(); window.makeKeyAndOrderFront(nil)
        
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            
            if let char = event.charactersIgnoringModifiers?.lowercased() {
                
                // Global Binds (Active whether expanded or small)
                if char == "e" { self.togglePlayerSize(); return nil }
                if char == "s" { self.snapToCorner(); return nil }
                if char == "t" { self.toggleTransparency(); return nil }
                
                // Widget-Local Vim Binds (Active only when small)
                if !self.isExpanded {
                    if event.keyCode == 36 { self.bridge.togglePlayPause(); return nil } // Enter
                    if event.keyCode == 124 { self.bridge.nextTrack(); return nil }      // Right Arrow
                    if event.keyCode == 123 { self.bridge.previousTrack(); return nil }  // Left Arrow
                    
                    switch char {
                    case "p": self.bridge.togglePlayPause(); return nil
                    case "l": self.bridge.nextTrack(); return nil
                    case "h": self.bridge.previousTrack(); return nil
                    case "k", "=": self.bridge.increaseVolume(); return nil
                    case "j", "-": self.bridge.decreaseVolume(); return nil
                    default: break
                    }
                }
            }
            return event
        }
    }
    
    private func updateView() { 
        window.contentView = NSHostingView(rootView: ContentView(bridge: bridge, isExpanded: isExpanded, isTransparent: isTransparent, smallWidth: smallWidth)) 
    }
    
    private func togglePlayerSize() {
        if !isExpanded {
            // About to expand: remember the current small position
            lastSmallPlayerPosition = window.frame
        }
        
        isExpanded.toggle()
        updateView()
        
        if isExpanded {
            // Dynamic expansion based on screen space
            resizeInPlace()
        } else if let lastPos = lastSmallPlayerPosition {
            // Restore the exact last small position when collapsing
            window.setFrame(lastPos, display: true, animate: true)
            lastSmallPlayerPosition = nil // Clear after restoring
        }
    }
    
    private func toggleTransparency() {
        isTransparent.toggle()
        updateView()
    }
    
    // Calculates which quadrant the window is in, and expands away from the nearest edges
    private func resizeInPlace() {
        guard let screen = window.screen ?? NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let currentFrame = window.frame
        
        let targetWidth = isExpanded ? largeWidth : smallWidth
        let targetHeight = isExpanded ? largeHeight : smallHeight
        
        var newX = currentFrame.origin.x
        var newY = currentFrame.origin.y
        
        if currentFrame.midX > screenFrame.midX {
            newX = currentFrame.maxX - targetWidth
        } else {
            newX = currentFrame.minX
        }
        
        if currentFrame.midY > screenFrame.midY {
            newY = currentFrame.maxY - targetHeight
        } else {
            newY = currentFrame.minY
        }
        
        newX = max(screenFrame.minX + screenPadding, min(newX, screenFrame.maxX - targetWidth - screenPadding))
        newY = max(screenFrame.minY + screenPadding, min(newY, screenFrame.maxY - targetHeight - screenPadding))
        
        window.setFrame(NSRect(x: newX, y: newY, width: targetWidth, height: targetHeight), display: true, animate: true)
    }
    
    private func snapToCorner() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let targetWidth = isExpanded ? largeWidth : smallWidth
        let targetHeight = isExpanded ? largeHeight : smallHeight
        window.setFrame(NSRect(x: screenFrame.maxX - targetWidth - screenPadding, y: screenFrame.minY + screenPadding, width: targetWidth, height: targetHeight), display: true, animate: true)
    }
}
