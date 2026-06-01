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

        NSEvent.addLocalMonitorForEvents(matching: .systemDefined) { [weak self] event in
            guard let self = self else { return event }
            
            // Subtype 8 is the macOS hardware identifier for media keys
            if event.subtype.rawValue == 8 {
                let keyCode = (event.data1 & 0xFFFF0000) >> 16
                let keyFlags = (event.data1 & 0x0000FFFF)
                
                // 0xA signifies the key is being pressed down (not released)
                let isKeyDown = (((keyFlags & 0xFF00) >> 8)) == 0xA
                
                if isKeyDown {
                    switch keyCode {
                    case 16: // Play/Pause physical button (F8)
                        self.bridge.togglePlayPause()
                        return nil // Consumes the input, blocking Firefox from seeing it
                    case 17: // Next Track physical button (F9)
                        self.bridge.nextTrack()
                        return nil
                    case 18: // Previous Track physical button (F7)
                        self.bridge.previousTrack()
                        return nil
                    default:
                        break
                    }
                }
            }
            return event
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // Forcefully re-assert Now Playing state to steal media keys back from Firefox
        bridge.updateNowPlayingCenter()
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
