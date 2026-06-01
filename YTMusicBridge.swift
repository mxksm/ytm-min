import SwiftUI
import WebKit
import MediaPlayer // Needed to publish metadata to macOS

class YTMusicBridge: NSObject, ObservableObject, WKScriptMessageHandler {
    @Published var trackTitle: String = "Not Playing"
    @Published var artistName: String = "Unknown Artist"
    @Published var isPlaying: Bool = false
    
    var webView: WKWebView!
    
    override init() {
        super.init()
        setupWebView()
    }
    
    private func setupWebView() {
        let configuration = WKWebViewConfiguration()
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        let source = """
        const updateState = () => {
            const titleEl = document.querySelector('.title.ytmusic-player-bar');
            const artistEl = document.querySelector('.byline.ytmusic-player-bar a');
            const video = document.querySelector('video');
            const isPlaying = video ? !video.paused : false;
            
            if (titleEl && artistEl) {
                window.webkit.messageHandlers.trackChanged.postMessage({
                    title: titleEl.innerText,
                    artist: artistEl.innerText,
                    isPlaying: isPlaying ? "true" : "false"
                });
            }
        };

        const observer = new MutationObserver(updateState);
        observer.observe(document.body, { childList: true, subtree: true, attributes: true });
        
        document.addEventListener('play', updateState, true);
        document.addEventListener('pause', updateState, true);
        """
        
        let userScript = WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        configuration.userContentController.addUserScript(userScript)
        configuration.userContentController.add(self, name: "trackChanged")
        
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        
        if let url = URL(string: "https://music.youtube.com") {
            webView.load(URLRequest(url: url))
        }
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let dict = message.body as? [String: String] else { return }
        DispatchQueue.main.async {
            self.trackTitle = dict["title"] ?? "Unknown"
            self.artistName = dict["artist"] ?? "Unknown"
            self.isPlaying = (dict["isPlaying"] == "true")
            
            // Push the current state to the macOS Control Center
            self.updateNowPlayingCenter()
        }
    }
    
    // Explicitly tells macOS that this app is playing media
    func updateNowPlayingCenter() {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = self.trackTitle
        nowPlayingInfo[MPMediaItemPropertyArtist] = self.artistName
        
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = self.isPlaying ? 1.0 : 0.0
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        MPNowPlayingInfoCenter.default().playbackState = self.isPlaying ? .playing : .paused
    }
    
    private var lastToggleTime = Date.distantPast
    
    func togglePlayPause() {
        let now = Date()
        
        if now.timeIntervalSince(lastToggleTime) < 0.3 { 
            return 
        }
        
        lastToggleTime = now
        webView.evaluateJavaScript("document.querySelector('#play-pause-button')?.click()")
    }
    
    func nextTrack() {
        webView.evaluateJavaScript("document.querySelector('.next-button')?.click()")
    }
    
    func previousTrack() {
        webView.evaluateJavaScript("document.querySelector('.previous-button')?.click()")
    }
}
