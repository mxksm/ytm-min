import SwiftUI
import WebKit

struct WebViewWrapper: NSViewRepresentable {
    var webView: WKWebView
    func makeNSView(context: Context) -> WKWebView { return webView }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

struct ContentView: View {
    @ObservedObject var bridge: YTMusicBridge
    @ObservedObject var state: PlayerWindowState
    var smallWidth: CGFloat
    var smallHeight: CGFloat
    
    // Tracks if the app currently has window focus
    @State private var isAppFocused: Bool = true
    
    var body: some View {
        ZStack {
            // Keep the same WebKit view mounted across mode changes.
            WebViewWrapper(webView: bridge.webView)
                .opacity(state.isExpanded ? 1 : 0)
                .allowsHitTesting(state.isExpanded)
                .accessibilityHidden(!state.isExpanded)
            if !state.isExpanded {
                ZStack(alignment: .bottomLeading) {
                    Rectangle()
                        .fill(Color(red: 26/255, green: 27/255, blue: 38/255).opacity(state.isTransparent ? 0.0 : 1.0))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(bridge.trackTitle)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                        
                        Text(bridge.artistName)
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                        .padding(.bottom, 4)
                        .frame(width: smallWidth, height: smallHeight, alignment: .bottomLeading)
                    
                    // The Volume Bar - stays as your accent color
                    Rectangle()
                        .fill(Color(red: 187/255, green: 154/255, blue: 247/255))
                        .frame(width: smallWidth * bridge.volume, height: 3)
                        .opacity(isAppFocused ? 1.0 : 0.0)
                        .animation(.easeInOut(duration: 0.2), value: isAppFocused)
                }
            }
        }
        .overlay(alignment: .top) {
            if state.isExpanded, let error = bridge.errorMessage {
                HStack {
                    Text(error).font(.caption).lineLimit(3)
                    Button("Retry") { bridge.reload() }
                }.padding(8).background(.regularMaterial)
            }
        }
        .onAppear { 
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
