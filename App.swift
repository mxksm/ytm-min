import SwiftUI
import WebKit
import MediaPlayer

@main
struct CustomMiniPlayerApp: App {
    @StateObject private var bridge = YTMusicBridge()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings { EmptyView() }
    }
}

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
        
        // Hooks up the F7/F8/F9 physical media keys
        setupMediaKeys()
        
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            
            // Intercept Spacebar (keycode 49) ONLY when in the mini widget mode
            if event.keyCode == 49 && !self.isExpanded {
                self.bridge.togglePlayPause()
                return nil // Consumes the input so macOS doesn't play an error "beep"
            }
            
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
    
    // Explicitly registers the app with macOS's media control center
    private func setupMediaKeys() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.bridge.togglePlayPause()
            return .success
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.bridge.togglePlayPause()
            return .success
        }
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.bridge.togglePlayPause()
            return .success
        }
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.bridge.nextTrack()
            return .success
        }
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.bridge.previousTrack()
            return .success
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
        
        let newX = screenFrame.maxX - targetWidth - screenPadding
        let newY = screenFrame.minY + screenPadding
        
        let newFrame = NSRect(x: newX, y: newY, width: targetWidth, height: targetHeight)
        
        window.setFrame(newFrame, display: true, animate: true)
    }
}
