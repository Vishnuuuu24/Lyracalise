import Foundation
import AuthenticationServices

class SpotifyManager: NSObject, ObservableObject {
    static let shared = SpotifyManager()
    
    // MARK: - Spotify Credentials
    private let clientID = "762027f15f014f2ba92a054f7954235e"
    private let clientSecret = "62c7b4c2af894cb7bd25e9b9d4a179f1"
    private let redirectURI = "lyracalise://callback"
    private let tokenURL = "https://accounts.spotify.com/api/token"
    private let authURL = "https://accounts.spotify.com/authorize"
    private let scope = "user-read-playback-state user-read-currently-playing"
    
    // MARK: - Token Storage
    @Published var accessToken: String? {
        didSet { saveTokens() }
    }
    private var refreshToken: String? {
        didSet { saveTokens() }
    }
    @Published var isLoggedIn: Bool = false {
        didSet {
            print("[Spotify] isLoggedIn changed to", isLoggedIn)
            NotificationCenter.default.post(name: .spotifyLoginStateChanged, object: nil)
        }
    }
    @Published var currentTrack: SpotifyTrack?
    private var authSession: ASWebAuthenticationSession?
    
    private override init() {
        super.init()
        loadTokens()
    }
    
    // MARK: - OAuth Login
    func login(completion: (() -> Void)? = nil) {
        let state = UUID().uuidString
        let urlString = "\(authURL)?client_id=\(clientID)&response_type=code&redirect_uri=\(redirectURI)&scope=\(scope)&state=\(state)&show_dialog=true"
        guard let url = URL(string: urlString) else { return }
        authSession = ASWebAuthenticationSession(url: url, callbackURLScheme: "lyracalise") { callbackURL, error in
            guard let callbackURL = callbackURL, error == nil else { return }
            guard let code = self.getQueryStringParameter(url: callbackURL.absoluteString, param: "code") else { return }
            self.exchangeCodeForToken(code: code, completion: completion)
        }
        authSession?.presentationContextProvider = self
        authSession?.start()
    }
    
    func logout() {
        accessToken = nil
        refreshToken = nil
        isLoggedIn = false
        currentTrack = nil
        saveTokens()
    }
    
    // MARK: - Token Exchange
    private func exchangeCodeForToken(code: String, completion: (() -> Void)? = nil) {
        guard let url = URL(string: tokenURL) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let bodyParams = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI,
            "client_id": clientID,
            "client_secret": clientSecret
        ]
        request.httpBody = bodyParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        print("[Spotify] Exchanging code for token...")
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("[Spotify] Token exchange error: \(error.localizedDescription)")
            }
            if let response = response as? HTTPURLResponse {
                print("[Spotify] Token exchange HTTP status: \(response.statusCode)")
            }
            guard let data = data else { print("[Spotify] No data received"); return }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("[Spotify] Token exchange response: \(json)")
                DispatchQueue.main.async {
                    self.accessToken = json["access_token"] as? String
                    self.refreshToken = json["refresh_token"] as? String
                    self.isLoggedIn = self.accessToken != nil
                    completion?()
                }
            } else {
                print("[Spotify] Failed to parse token exchange response: \(String(data: data, encoding: .utf8) ?? "nil")")
            }
        }.resume()
    }
    
    // MARK: - Fetch Current Track
    func fetchCurrentTrack(completion: ((SpotifyTrack?) -> Void)? = nil) {
        guard let accessToken = accessToken else {
            completion?(nil)
            return
        }
        var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/player/currently-playing")!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("[Spotify] Fetch track error: \(error.localizedDescription)")
            }
            if let response = response as? HTTPURLResponse {
                print("[Spotify] Fetch track HTTP status: \(response.statusCode)")
            }
            guard let data = data else { print("[Spotify] No data received"); completion?(nil); return }
            if let jsonString = String(data: data, encoding: .utf8) {
                print("[Spotify] Fetch track raw response: \(jsonString)")
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let item = json["item"] as? [String: Any] {
                let isPlaying = json["is_playing"] as? Bool
                let progressMs = json["progress_ms"] as? Int
                let track = SpotifyTrack(json: item, progressMs: progressMs, isPlaying: isPlaying)
                DispatchQueue.main.async {
                    self.currentTrack = track
                    completion?(track)
                }
            } else {
                DispatchQueue.main.async {
                    self.currentTrack = nil
                    completion?(nil)
                }
            }
        }.resume()
    }
    
    // MARK: - Helpers
    private func getQueryStringParameter(url: String, param: String) -> String? {
        guard let url = URLComponents(string: url) else { return nil }
        return url.queryItems?.first(where: { $0.name == param })?.value
    }
    
    private func saveTokens() {
        let defaults = UserDefaults(suiteName: "group.com.vishnu.lyracalise")!
        defaults.set(accessToken, forKey: "spotify_access_token")
        defaults.set(refreshToken, forKey: "spotify_refresh_token")
        defaults.set(isLoggedIn, forKey: "spotify_logged_in")
        defaults.synchronize()
        print("[Spotify] Saved tokens (App Group): accessToken=\(String(describing: accessToken)), refreshToken=\(String(describing: refreshToken)), isLoggedIn=\(isLoggedIn)")
    }
    private func loadTokens() {
        let defaults = UserDefaults(suiteName: "group.com.vishnu.lyracalise")!
        accessToken = defaults.string(forKey: "spotify_access_token")
        refreshToken = defaults.string(forKey: "spotify_refresh_token")
        isLoggedIn = defaults.bool(forKey: "spotify_logged_in")
        print("[Spotify] Loaded tokens (App Group): accessToken=\(String(describing: accessToken)), refreshToken=\(String(describing: refreshToken)), isLoggedIn=\(isLoggedIn)")
    }
}

extension SpotifyManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return UIApplication.shared.windows.first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

struct SpotifyTrack {
    let name: String
    let artist: String
    let album: String
    let id: String
    let progressMs: Int?
    let isPlaying: Bool?
    init?(json: [String: Any], progressMs: Int? = nil, isPlaying: Bool? = nil) {
        guard let name = json["name"] as? String,
              let album = json["album"] as? [String: Any],
              let albumName = album["name"] as? String,
              let artists = json["artists"] as? [[String: Any]],
              let artistName = artists.first?["name"] as? String,
              let id = json["id"] as? String else { return nil }
        self.name = name
        self.artist = artistName
        self.album = albumName
        self.id = id
        self.progressMs = progressMs
        self.isPlaying = isPlaying
    }
}

extension Notification.Name {
    static let spotifyLoginStateChanged = Notification.Name("SpotifyLoginStateChanged")
} 
