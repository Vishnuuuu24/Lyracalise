//
//  BackgroundSessionManager.swift
//  Lyracalise
//
//  Created by Vishnu Vardhan on 12/9/25.
//

import Foundation
import WidgetKit

/// Handles background URLSession for API calls that work even when app is force-closed
/// Similar to how Uber/Swiggy maintains real-time updates
class BackgroundSessionManager: NSObject, ObservableObject {
    static let shared = BackgroundSessionManager()
    
    private var backgroundSession: URLSession!
    private let backgroundIdentifier = "com.vishnu.lyracalise.background"
    
    // Track current requests
    private var pendingRequests: [String: (SpotifyTrack?) -> Void] = [:]
    
    override init() {
        super.init()
        setupBackgroundSession()
    }
    
    private func setupBackgroundSession() {
        let config = URLSessionConfiguration.background(withIdentifier: backgroundIdentifier)
        config.sessionSendsLaunchEvents = true
        config.isDiscretionary = false
        config.shouldUseExtendedBackgroundIdleMode = true
        
        backgroundSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    /// Fetch current track using background session - works even when app is force-closed
    func fetchCurrentTrackInBackground(completion: @escaping (SpotifyTrack?) -> Void) {
        // First try to get token from shared UserDefaults (set by main app)
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.vishnu.lyracalise"),
              let token = sharedDefaults.string(forKey: "spotify_access_token") else {
            completion(nil)
            return
        }
        
        // Check if token is expired
        if let expirationDate = sharedDefaults.object(forKey: "spotify_token_expiration_date") as? Date,
           Date() >= expirationDate {
            // Token expired, try to refresh
            refreshTokenInBackground { success in
                if success {
                    self.fetchCurrentTrackInBackground(completion: completion)
                } else {
                    completion(nil)
                }
            }
            return
        }
        
        guard let url = URL(string: "https://api.spotify.com/v1/me/player/currently-playing") else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let taskIdentifier = UUID().uuidString
        pendingRequests[taskIdentifier] = completion
        
        let task = backgroundSession.dataTask(with: request)
        task.taskDescription = taskIdentifier
        task.resume()
    }
    
    private func refreshTokenInBackground(completion: @escaping (Bool) -> Void) {
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.vishnu.lyracalise"),
              let refreshToken = sharedDefaults.string(forKey: "spotify_refresh_token") else {
            completion(false)
            return
        }
        
        guard let url = URL(string: "https://accounts.spotify.com/api/token") else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyParams = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": "762027f15f014f2ba92a054f7954235e",
            "client_secret": "62c7b4c2af894cb7bd25e9b9d4a179f1"
        ]
        request.httpBody = bodyParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)
        
        let task = backgroundSession.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                completion(false)
                return
            }
            
            do {
                let result = try JSONDecoder().decode(AuthResponse.self, from: data)
                
                // Update shared UserDefaults
                sharedDefaults.set(result.access_token, forKey: "spotify_access_token")
                if let newRefreshToken = result.refresh_token {
                    sharedDefaults.set(newRefreshToken, forKey: "spotify_refresh_token")
                }
                let expirationDate = Date().addingTimeInterval(TimeInterval(result.expires_in))
                sharedDefaults.set(expirationDate, forKey: "spotify_token_expiration_date")
                
                // Also update Keychain for main app
                KeychainTokenManager.shared.saveTokens(
                    accessToken: result.access_token,
                    refreshToken: result.refresh_token ?? refreshToken,
                    expirationDate: expirationDate
                )
                
                completion(true)
            } catch {
                print("Failed to refresh token in background: \(error)")
                completion(false)
            }
        }
        task.resume()
    }
}

// MARK: - URLSessionDelegate
extension BackgroundSessionManager: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let taskIdentifier = dataTask.taskDescription,
              let completion = pendingRequests[taskIdentifier] else { return }
        
        // Parse Spotify response
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let item = json["item"] as? [String: Any] {
            let isPlaying = json["is_playing"] as? Bool
            let progressMs = json["progress_ms"] as? Int
            let track = SpotifyTrack(json: item, progressMs: progressMs, isPlaying: isPlaying)
            
            DispatchQueue.main.async {
                completion(track)
                self.pendingRequests.removeValue(forKey: taskIdentifier)
            }
        } else {
            DispatchQueue.main.async {
                completion(nil)
                self.pendingRequests.removeValue(forKey: taskIdentifier)
            }
        }
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didCompleteWithError error: Error?) {
        guard let taskIdentifier = dataTask.taskDescription,
              let completion = pendingRequests[taskIdentifier] else { return }
        
        if let error = error {
            print("Background request failed: \(error)")
        }
        
        DispatchQueue.main.async {
            completion(nil)
            self.pendingRequests.removeValue(forKey: taskIdentifier)
        }
    }
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            // Notify widgets to update
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
