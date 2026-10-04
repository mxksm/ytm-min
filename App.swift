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

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
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
    
    var isExpanded = false
    var isTransparent = true
    var isAutoHideEnabled = true
    
    private var lastSmallPlayerPosition: NSRect?
    private var screenObserver: NSObjectProtocol?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Removed .fullSizeContentView to strip insets
        window = CustomWindow(contentRect: NSRect(x: 0, y: 0, width: smallWidth, height: smallHeight),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        
        // hasShadow = false removes the black rim/bezel effect
        window.isOpaque = false; window.backgroundColor = .clear; window.hasShadow = false; window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        updateView(); snapToCorner(); window.makeKeyAndOrderFront(nil)

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, !self.isExpanded else { return }
            self.snapToCorner()
        }
        
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            let isCmd = event.modifierFlags.contains(.command)
            let char = event.charactersIgnoringModifiers?.lowercased()
            
            // 1. ESCAPE KEY
            if event.keyCode == 53 && self.isExpanded {
                self.bridge.webView.evaluateJavaScript("if(document.activeElement){ document.activeElement.blur(); }")
                self.togglePlayerSize()
                return nil
            }
            
            // 2. CMD-MODIFIED BINDS
            if isCmd {
                if char == "e" { self.togglePlayerSize(); return nil }
                if char == "s" { self.snapToCorner(); return nil }
                if char == "t" { self.toggleTransparency(); return nil }
                if char == "q" { NSApplication.shared.terminate(nil); return nil }
            }
            
            // 3. SINGLE-LETTER VIM BINDS
            if let key = char {
                
                if self.isExpanded && self.bridge.isInputFocused {
                    return event
                }
                
                if key == "e" { self.togglePlayerSize(); return nil }
                if key == "f" { self.toggleAutoHide(); return nil }
                if key == "q" { NSApplication.shared.terminate(nil); return nil }
                if key == "p" { self.bridge.togglePlayPause(); return nil }
                if key == "l" { self.bridge.nextTrack(); return nil }
                if key == "h" { self.bridge.previousTrack(); return nil }
                
            if !self.isExpanded || key == "j" || key == "k" {
                    if event.keyCode == 36 { self.bridge.togglePlayPause(); return nil } 
                    if event.keyCode == 124 { self.bridge.nextTrack(); return nil }      
                    if event.keyCode == 123 { self.bridge.previousTrack(); return nil }  
                    
                    switch key {
                    case "s": self.snapToCorner(); return nil
                    case "t": self.toggleTransparency(); return nil
                    case "k", "=": self.bridge.increaseVolume(); return nil
                    case "j", "-": self.bridge.decreaseVolume(); return nil
                    default: break
                    }
                }
            }
            
            if !self.isExpanded { return nil }
            
            return event
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        updateVisibility()
    }
    
    func applicationDidResignActive(_ notification: Notification) {
        updateVisibility()
    }
    
    private func updateVisibility() {
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
    
    private func updateView() { 
        window.contentView = NSHostingView(rootView: ContentView(bridge: bridge, isExpanded: isExpanded, isTransparent: isTransparent, smallWidth: smallWidth, smallHeight: smallHeight))
    }
    
    private func togglePlayerSize() {
        if !isExpanded { lastSmallPlayerPosition = window.frame }
        isExpanded.toggle()
        updateView()
        
        if isExpanded {
            resizeInPlace()
        } else if let lastPos = lastSmallPlayerPosition {
            window.setFrame(lastPos, display: true, animate: true)
            lastSmallPlayerPosition = nil
        }
    }
    
    private func toggleTransparency() {
        isTransparent.toggle()
        updateView()
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
        
        window.setFrame(NSRect(x: newX, y: newY, width: targetWidth, height: targetHeight), display: true, animate: true)
    }
    
    private func snapToCorner() {
        guard let screen = NSScreen.main else { return }

        if !isExpanded, let shoulder = screen.auxiliaryTopLeftArea {
            let height = min(smallHeight, shoulder.height)
            let width = min(smallWidth, shoulder.width)
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
        window.setFrame(NSRect(x: screenFrame.maxX - targetWidth - paddingX, y: screenFrame.minY + paddingY, width: targetWidth, height: targetHeight), display: true, animate: true)
    }
}
