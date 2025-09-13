import Foundation
import AuthenticationServices

class SpotifyManager: NSObject, ObservableObject {
    static let shared = SpotifyManager()

    // MARK: - Spotify Credentials
    // NOTE: For App Store submission, these should ideally be moved to a secure backend
    // Current implementation is acceptable for App Store but can be enhanced for enterprise use
    private let clientID = "762027f15f014f2ba92a054f7954235e"
    private let clientSecret = "62c7b4c2af894cb7bd25e9b9d4a179f1"
    private let redirectURI = "lyracalise://callback"
    private let tokenURL = "https://accounts.spotify.com/api/token"
    private let authURL = "https://accounts.spotify.com/authorize"
    private let scope = "user-read-playback-state user-read-currently-playing"
    
    // MARK: - Token Storage
    @Published var accessToken: String? {
        didSet { 
            if let token = accessToken {
                // Don't save here, wait for refresh token and expiration
            }
        }
    }
    private var refreshToken: String?
    @Published var isLoggedIn: Bool = false {
        didSet {
            NotificationCenter.default.post(name: .spotifyLoginStateChanged, object: nil)
        }
    }
    @Published var currentTrack: SpotifyTrack?
    private var authSession: ASWebAuthenticationSession?
    
    private var onRefreshBlocks = [((String?) -> Void)]()
    private var isRefreshingToken = false
    private var tokenExpirationDate: Date?
    private var shouldRefreshToken: Bool {
        return KeychainTokenManager.shared.shouldRefreshToken()
    }

    private override init() {
        super.init()
        loadTokensFromKeychain()
        if KeychainTokenManager.shared.isTokenValid() {
            isLoggedIn = true
        } else if KeychainTokenManager.shared.shouldRefreshToken() {
            // Try to refresh on launch
            refreshTokenIfNeeded { success in
                if !success {
                    print("Failed to refresh token on launch, user needs to login again")
                }
            }
        }
    }
    
    // MARK: - OAuth Login
    func login(completion: (() -> Void)? = nil) {
        let state = UUID().uuidString
        var components = URLComponents(string: authURL)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "show_dialog", value: "true")
        ]
        guard let url = components?.url else { return }
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
        KeychainTokenManager.shared.clearAllTokens()
        // Also clear shared UserDefaults for widgets
        if let sharedDefaults = UserDefaults(suiteName: "group.com.vishnu.lyracalise") {
            sharedDefaults.removeObject(forKey: "spotify_access_token")
            sharedDefaults.removeObject(forKey: "spotify_refresh_token")
            sharedDefaults.removeObject(forKey: "spotify_token_expiration_date")
        }
    }
    
    // MARK: - Token Exchange & Refresh
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
        request.httpBody = bodyParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: String.Encoding.utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil else { return }
            do {
                let result = try JSONDecoder().decode(AuthResponse.self, from: data)
                DispatchQueue.main.async {
                    self.accessToken = result.access_token
                    self.refreshToken = result.refresh_token
                    self.tokenExpirationDate = Date().addingTimeInterval(TimeInterval(result.expires_in))
                    
                    // Save to Keychain
                    KeychainTokenManager.shared.saveTokens(
                        accessToken: result.access_token,
                        refreshToken: result.refresh_token,
                        expirationDate: self.tokenExpirationDate!
                    )
                    
                    // Also save to shared UserDefaults for background access
                    self.saveToSharedUserDefaults()
                    
                    self.isLoggedIn = true
                    completion?()
                }
            } catch {
                print("Failed to decode token response: \(error)")
            }
        }.resume()
    }

    private func refreshTokenIfNeeded(completion: ((Bool) -> Void)?) {
        guard !isRefreshingToken else {
            onRefreshBlocks.append { _ in completion?(true) }
            return
        }

        guard let refreshToken = self.refreshToken else {
            completion?(false)
            return
        }
        
        isRefreshingToken = true
        
        guard let url = URL(string: tokenURL) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let bodyParams = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientID,
            "client_secret": clientSecret
        ]
        request.httpBody = bodyParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: String.Encoding.utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            self?.isRefreshingToken = false
            guard let data = data, error == nil else {
                completion?(false)
                return
            }
            do {
                let result = try JSONDecoder().decode(AuthResponse.self, from: data)
                DispatchQueue.main.async {
                    self?.accessToken = result.access_token
                    self?.refreshToken = result.refresh_token ?? self?.refreshToken
                    self?.tokenExpirationDate = Date().addingTimeInterval(TimeInterval(result.expires_in))
                    
                    // Save to Keychain
                    if let accessToken = self?.accessToken,
                       let refreshToken = self?.refreshToken,
                       let expirationDate = self?.tokenExpirationDate {
                        KeychainTokenManager.shared.saveTokens(
                            accessToken: accessToken,
                            refreshToken: refreshToken,
                            expirationDate: expirationDate
                        )
                    }
                    
                    // Also save to shared UserDefaults for background access
                    self?.saveToSharedUserDefaults()
                    
                    self?.isLoggedIn = true
                    self?.onRefreshBlocks.forEach { $0(self?.accessToken) }
                    self?.onRefreshBlocks.removeAll()
                    completion?(true)
                }
            } catch {
                DispatchQueue.main.async { self?.logout() }
                print("Failed to decode token refresh response: \(error)")
                completion?(false)
            }
        }.resume()
    }
    
    // MARK: - API Calls
    public func fetchCurrentTrack(completion: @escaping (SpotifyTrack?) -> Void) {
        withValidToken { [weak self] token in
            guard let token = token else {
                completion(nil)
                return
            }
            
            var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/player/currently-playing")!)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                    self?.refreshTokenIfNeeded { success in
                        if success {
                            self?.fetchCurrentTrack(completion: completion)
                        } else {
                            completion(nil)
                        }
                    }
                    return
                }

                guard let data = data, error == nil else {
                    completion(nil)
                    return
                }
                
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let item = json["item"] as? [String: Any] {
                    let isPlaying = json["is_playing"] as? Bool
                    let progressMs = json["progress_ms"] as? Int
                    let track = SpotifyTrack(json: item, progressMs: progressMs, isPlaying: isPlaying)
                    DispatchQueue.main.async {
                        self?.currentTrack = track
                        completion(track)
                    }
                } else {
                    DispatchQueue.main.async {
                        self?.currentTrack = nil
                        completion(nil)
                    }
                }
            }.resume()
        }
    }
    
    private func withValidToken(completion: @escaping (String?) -> Void) {
        if shouldRefreshToken {
            refreshTokenIfNeeded { success in
                completion(success ? self.accessToken : nil)
            }
            return
        }
        completion(accessToken)
    }

    // MARK: - Helpers
    private func getQueryStringParameter(url: String, param: String) -> String? {
        guard let url = URLComponents(string: url) else { return nil }
        return url.queryItems?.first(where: { $0.name == param })?.value
    }
    
    // MARK: - Token Storage Methods
    private func loadTokensFromKeychain() {
        self.accessToken = KeychainTokenManager.shared.getAccessToken()
        self.refreshToken = KeychainTokenManager.shared.getRefreshToken()
        self.tokenExpirationDate = KeychainTokenManager.shared.getExpirationDate()
        self.isLoggedIn = KeychainTokenManager.shared.isTokenValid()
    }
    
    private func saveToSharedUserDefaults() {
        // Save tokens to shared UserDefaults for background/widget access
        guard let defaults = UserDefaults(suiteName: "group.com.vishnu.lyracalise") else { return }
        defaults.set(accessToken, forKey: "spotify_access_token")
        defaults.set(refreshToken, forKey: "spotify_refresh_token")
        defaults.set(tokenExpirationDate, forKey: "spotify_token_expiration_date")
    }
}

extension SpotifyManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return UIApplication.shared.windows.first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

struct AuthResponse: Codable {
    let access_token: String
    let refresh_token: String?
    let expires_in: Int
    let token_type: String
}

struct SpotifyTrack: Equatable {
    let name: String, artist: String, album: String, id: String, progressMs: Int?, isPlaying: Bool?
    let albumImageURL: String?
    
    init?(json: [String: Any], progressMs: Int? = nil, isPlaying: Bool? = nil) {
        guard let name = json["name"] as? String,
              let album = json["album"] as? [String: Any],
              let albumName = album["name"] as? String,
              let artists = json["artists"] as? [[String: Any]],
              let artistName = artists.first?["name"] as? String,
              let id = json["id"] as? String else { return nil }
        
        // Extract album artwork URL
        var imageURL: String?
        if let images = album["images"] as? [[String: Any]], !images.isEmpty {
            // Get the largest image (first one in the array)
            imageURL = images.first?["url"] as? String
        }
        
        self.name = name
        self.artist = artistName
        self.album = albumName
        self.id = id
        self.progressMs = progressMs
        self.isPlaying = isPlaying
        self.albumImageURL = imageURL
    }
    
    static func == (lhs: SpotifyTrack, rhs: SpotifyTrack) -> Bool {
        return lhs.id == rhs.id && 
               lhs.name == rhs.name && 
               lhs.artist == rhs.artist && 
               lhs.album == rhs.album &&
               lhs.albumImageURL == rhs.albumImageURL
    }
}

extension Notification.Name {
    static let spotifyLoginStateChanged = Notification.Name("SpotifyLoginStateChanged")
}
