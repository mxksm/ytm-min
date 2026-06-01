import SwiftUI
import WebKit

struct WebViewWrapper: NSViewRepresentable {
    var webView: WKWebView
    
    func makeNSView(context: Context) -> WKWebView {
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

struct ContentView: View {
    @ObservedObject var bridge: YTMusicBridge
    var isExpanded: Bool
    var smallWidth: CGFloat
    
    var body: some View {
        Group {
            if isExpanded {
                WebViewWrapper(webView: bridge.webView)
            } else {
                ZStack {
                    Rectangle()
                        .fill(Color(red: 26/255, green: 27/255, blue: 38/255))                    

                    VStack(alignment: .leading, spacing: 2) {
                        // Stripped the emojis, added dynamic color for the title
                        Text(bridge.trackTitle)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(
                                bridge.isPlaying 
                                ? Color(red: 187/255, green: 154/255, blue: 247/255) 
                                : .primary
                            )
                            .lineLimit(1)
                        
                        Text(bridge.artistName)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .frame(width: smallWidth, alignment: .leading)
                }
            }
        }
        .onAppear {
            NSApp.mainWindow?.isMovableByWindowBackground = true
        }
    }
}
