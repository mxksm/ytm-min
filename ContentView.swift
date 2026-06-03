import SwiftUI
import WebKit

struct WebViewWrapper: NSViewRepresentable {
    var webView: WKWebView
    func makeNSView(context: Context) -> WKWebView { return webView }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

struct ContentView: View {
    @ObservedObject var bridge: YTMusicBridge
    var isExpanded: Bool
    var isTransparent: Bool
    var smallWidth: CGFloat
    
    // Tracks if the app currently has window focus
    @State private var isAppFocused: Bool = true
    
    var body: some View {
        Group {
            if isExpanded {
                WebViewWrapper(webView: bridge.webView)
            } else {
                ZStack(alignment: .bottomLeading) {
                    Rectangle()
                        .fill(Color(red: 26/255, green: 27/255, blue: 38/255).opacity(isTransparent ? 0.0 : 1.0))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(bridge.trackTitle)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(bridge.isPlaying ? Color(red: 187/255, green: 154/255, blue: 247/255) : .primary)
                            .lineLimit(1)
                        
                        Text(bridge.artistName)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 6)
                    .frame(width: smallWidth, height: 44, alignment: .bottomLeading)
                    
                    // The Volume Bar - now fades out when app loses focus
                    Rectangle()
                        .fill(Color(red: 187/255, green: 154/255, blue: 247/255))
                        .frame(width: smallWidth * bridge.volume, height: 3)
                        .opacity(isAppFocused ? 1.0 : 0.0)
                        .animation(.easeInOut(duration: 0.2), value: isAppFocused)
                }
            }
        }
        .onAppear { 
            NSApp.mainWindow?.isMovableByWindowBackground = true
            isAppFocused = NSApplication.shared.isActive
        }
        // Listen for macOS focus events
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            isAppFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            isAppFocused = false
        }
    }
}
