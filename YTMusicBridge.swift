import SwiftUI
import WebKit

class YTMusicBridge: NSObject, ObservableObject, WKScriptMessageHandler {
    @Published var trackTitle: String = "Not Playing"
    @Published var artistName: String = "Unknown Artist"
    @Published var isPlaying: Bool = false
    @Published var volume: Double = 1.0
    
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
            const video = document.querySelector('video');
            const titleEl = document.querySelector('.title.ytmusic-player-bar');
            const artistEl = document.querySelector('.byline.ytmusic-player-bar a');
            
            let linearVolume = 1.0;
            if (video) {
                // Read YouTube's actual UI slider value (0-100) instead of the exponential audio gain
                const slider = document.querySelector('#volume-slider');
                if (slider && slider.value !== undefined) {
                    linearVolume = Number(slider.value) / 100.0;
                } else {
                    // Fallback: Reverse the exponential curve if the DOM changes
                    linearVolume = Math.sqrt(video.volume);
                }
            }
            
            if (video && titleEl && artistEl) {
                window.webkit.messageHandlers.trackChanged.postMessage({
                    title: titleEl.innerText,
                    artist: artistEl.innerText,
                    isPlaying: !video.paused,
                    volume: linearVolume
                });
            }
        };

        const observer = new MutationObserver(updateState);
        observer.observe(document.body, { childList: true, subtree: true, attributes: true });
        document.addEventListener('play', updateState, true);
        document.addEventListener('pause', updateState, true);
        document.addEventListener('volumechange', updateState, true);
        """
        
        let userScript = WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        configuration.userContentController.addUserScript(userScript)
        configuration.userContentController.add(self, name: "trackChanged")
        
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        webView.load(URLRequest(url: URL(string: "https://music.youtube.com")!))
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let dict = message.body as? [String: Any] else { return }
        DispatchQueue.main.async {
            self.trackTitle = dict["title"] as? String ?? "Unknown"
            self.artistName = dict["artist"] as? String ?? "Unknown"
            self.isPlaying = (dict["isPlaying"] as? Bool ?? false)
            self.volume = dict["volume"] as? Double ?? 1.0
        }
    }
    
    func togglePlayPause() { webView.evaluateJavaScript("document.querySelector('#play-pause-button')?.click()") }
    func nextTrack() { webView.evaluateJavaScript("document.querySelector('.next-button')?.click()") }
    func previousTrack() { webView.evaluateJavaScript("document.querySelector('.previous-button')?.click()") }
    
    func increaseVolume() {
        let js = "document.dispatchEvent(new KeyboardEvent('keydown', { key: '=', code: 'Equal', keyCode: 187, bubbles: true }));"
        webView.evaluateJavaScript(js)
    }
    
    func decreaseVolume() {
        let js = "document.dispatchEvent(new KeyboardEvent('keydown', { key: '-', code: 'Minus', keyCode: 189, bubbles: true }));"
        webView.evaluateJavaScript(js)
    }
}
