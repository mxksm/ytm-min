import SwiftUI
import WebKit
import MediaPlayer

private final class WeakScriptHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ target: WKScriptMessageHandler) { self.target = target }
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(controller, didReceive: message)
    }
}

final class YTMusicBridge: NSObject, ObservableObject, WKScriptMessageHandler, WKNavigationDelegate {
    @Published private(set) var trackTitle = "Not Playing"
    @Published private(set) var artistName = "Unknown Artist"
    @Published private(set) var isPlaying = false
    @Published private(set) var volume = 1.0
    @Published private(set) var errorMessage: String?
    private(set) var webView: WKWebView!
    var onShortcut: ((PlayerAction) -> Void)?
    private var remoteTargets: [(MPRemoteCommand, Any)] = []
    private var hasTrack = false

    override init() {
        super.init()
        let configuration = WKWebViewConfiguration()
        configuration.mediaTypesRequiringUserActionForPlayback = []
        let controller = configuration.userContentController
        for name in ["playerState", "shortcut"] { controller.add(WeakScriptHandler(self), name: name) }
        if let url = Bundle.main.url(forResource: "player", withExtension: "js"),
           let source = try? String(contentsOf: url, encoding: .utf8) {
            controller.addUserScript(WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        } else {
            errorMessage = "Player controls are missing. Rebuild the app using build.sh."
        }
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        webView.load(URLRequest(url: URL(string: "https://music.youtube.com")!))
        configureMediaCommands()
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, message.frameInfo.securityOrigin.host == "music.youtube.com" else { return }
        if message.name == "shortcut", let name = message.body as? String, let action = PlayerAction(rawValue: name) {
            onShortcut?(action)
        } else if message.name == "playerState", let state = message.body as? [String: Any] {
            let title = state["title"] as? String ?? "Not Playing"
            let artist = state["artist"] as? String ?? "Unknown Artist"
            let playing = state["isPlaying"] as? Bool ?? false
            let track = state["hasTrack"] as? Bool ?? false
            let metadataChanged = title != trackTitle || artist != artistName || playing != isPlaying || track != hasTrack
            if title != trackTitle { trackTitle = title }
            if artist != artistName { artistName = artist }
            if playing != isPlaying { isPlaying = playing }
            hasTrack = track
            if let value = state["volume"] as? Double, value.isFinite {
                let bounded = min(1, max(0, value))
                if volume != bounded { volume = bounded }
            }
            if metadataChanged { updateNowPlaying() }
        }
    }

    func perform(_ action: PlayerAction) {
        webView.evaluateJavaScript("window.ytmMini?.perform('\(action.rawValue)')") { [weak self] _, error in
            if let error { self?.errorMessage = "Player control failed: \(error.localizedDescription)" }
        }
    }
    func reload() { errorMessage = nil; webView.reload() }

    private func configureMediaCommands() {
        let center = MPRemoteCommandCenter.shared()
        for (command, action) in [(center.previousTrackCommand, PlayerAction.previous),
                                  (center.nextTrackCommand, .next), (center.togglePlayPauseCommand, .togglePlayback),
                                  (center.playCommand, .play), (center.pauseCommand, .pause)] {
            command.isEnabled = true
            let token = command.addTarget { [weak self] _ in
                DispatchQueue.main.async { self?.perform(action) }
                return .success
            }
            remoteTargets.append((command, token))
        }
    }
    private func updateNowPlaying() {
        let center = MPNowPlayingInfoCenter.default()
        guard hasTrack else { center.nowPlayingInfo = nil; center.playbackState = .stopped; return }
        center.nowPlayingInfo = [MPMediaItemPropertyTitle: trackTitle, MPMediaItemPropertyArtist: artistName,
                                 MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0]
        center.playbackState = isPlaying ? .playing : .paused
    }
    func shutdown() {
        for (command, target) in remoteTargets { command.removeTarget(target) }
        remoteTargets.removeAll()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .stopped
        webView.stopLoading()
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { reload() }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { show(error) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { show(error) }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { errorMessage = nil }
    private func show(_ error: Error) {
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        errorMessage = error.localizedDescription
    }
}
