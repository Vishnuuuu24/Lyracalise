import Foundation
import Combine
import ActivityKit
import MediaPlayer
import WidgetKit
import AuthenticationServices
import UIKit
import CoreLocation
import CoreHaptics

// A type alias for a lyric line, making the code cleaner.
typealias LyricEntry = (time: TimeInterval, line: String)

// MARK: - Xcode Build Workaround
// These constants are being defined locally to work around a persistent
// Xcode project corruption issue where the MediaPlayer framework is not linking correctly.
private let MPNowPlayingInfoPropertyElapsedPlaybackTime = "elapsedPlaybackTime"
private let MPNowPlayingInfoPropertyPlaybackDuration = "playbackDuration"
private let MPNowPlayingInfoPropertyTitle = "title"
private let MPNowPlayingInfoPropertyArtist = "artist"
private let MPNowPlayingInfoPropertyAlbumTitle = "albumTitle"

@MainActor
class LyricSyncManager: ObservableObject {
    // MARK: - Published Properties for UI
    @Published var nowPlayingTitle: String = ""
    @Published var nowPlayingArtist: String = ""
    @Published var statusMessage: String = "Waiting..."
    @Published var manualSearchEnabled: Bool = false
    
    // MARK: - Privacy-Safe Background Execution
    @Published var showPrivacyEducation: Bool = false
    private let locationManager = PrivacyLocationManager()
    
    // The full list of lyrics for the current song.
    @Published var loadedLyrics: [LyricEntry] = []
    // A fallback for plain text when auto-syncing isn't possible.
    @Published var staticLyrics: String? = nil
    // The currently active lyric line.
    @Published var currentLine: String = ""
    // The current line index, useful for UI highlighting.
    @Published var currentLineIndex: Int?

    // Our new properties for handling search results
    @Published var searchResults: [LrclibSearchResult] = []
    @Published var isShowingSearchResults = false
    
    // Tracks the user's manual time override.
    @Published var manualSyncOffset: TimeInterval? = nil
    
    // A new property to hold the raw LRC content before saving
    private var lastFetchedLrcContent: String? = nil

    // Tracks the start time for our internal, simulated playback.
    private var simulatedPlaybackStartTime: Date? = nil
    
    // Add a property to track if lyrics were auto-selected
    @Published var autoSelectedFirstResult: Bool = false
    
    // MARK: - Background Task Management
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var lastSuccessfulUpdate: Date = Date()
    
    private func startBackgroundTask() {
        endBackgroundTask()
        
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "LyricSync") { [weak self] in
            print("[LyricSyncManager] Background task expired, ending gracefully")
            self?.endBackgroundTask()
        }
        
        if backgroundTask == .invalid {
            print("[LyricSyncManager] Failed to start background task")
        } else {
            print("[LyricSyncManager] Background task started successfully")
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            print("[LyricSyncManager] Ending background task")
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    private func checkForStaleData() {
        let timeSinceLastUpdate = Date().timeIntervalSince(lastSuccessfulUpdate)
        if timeSinceLastUpdate > 30 { // No updates for 30 seconds
            print("[LyricSyncManager] Detected stale data, refreshing...")
            // Try to refresh Spotify state
            if SpotifyManager.shared.isLoggedIn {
                SpotifyManager.shared.fetchCurrentTrack { [weak self] track in
                    if let track = track {
                        self?.handleSpotifyState(track: track)
                    }
                }
            }
        }
    }
    
    // Lyric sync state machine
    enum LyricSyncState: String {
        case waiting = "waiting"
        case playing = "playing"
        case paused = "paused"
        case seeking = "seeking"
        case stopped = "stopped"
    }
    private var syncState: LyricSyncState = .waiting
    private var debounceWorkItem: DispatchWorkItem?
    private let debounceInterval: TimeInterval = 0.3
    
    // MARK: - Private Properties
    private var syncTimer: Timer?
    private var nowPlayingTimer: Timer?
    private var nowPlayingTimeoutTimer: Timer?
    private var lastNowPlayingTitle: String = ""
    private var lastNowPlayingArtist: String = ""
    private var activity: Activity<LyricAttributes>?
    private var spotifyTimer: Timer?
    private var nowPlayingTrackID: String? = nil
    private var lastProgressMs: Int? = nil
    @Published public var currentTrack: SpotifyTrack? = nil
    private var isStopped: Bool = false
    private var manualSyncStartTime: Date?

    init() {
        stopAll(showStopped: false)
        
        // Clean up expired cache files
        cleanExpiredCache()
        
        // Check if this is first launch for privacy education
        let hasSeenPrivacyEducation = UserDefaults.standard.bool(forKey: "hasSeenPrivacyEducation")
        if !hasSeenPrivacyEducation {
            DispatchQueue.main.async {
                self.showPrivacyEducation = true
            }
        }
        
        // IMMEDIATE SYNC BOOST: Force sync on app startup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("[Startup] 🚀 Performing startup sync boost")
            self.performStartupSyncBoost()
        }
        
        if SpotifyManager.shared.isLoggedIn {
            print("[LyricSyncManager] Spotify is logged in on launch, starting observation.")
            startSpotifyObservation()
        }
        // Listen for Spotify login state changes
        NotificationCenter.default.addObserver(forName: .spotifyLoginStateChanged, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            if SpotifyManager.shared.isLoggedIn {
                print("[LyricSyncManager] Spotify login detected, starting observation.")
                self.startSpotifyObservation()
            } else {
                self.stopAll()
                self.startNowPlayingObservation()
            }
        }
        
        // Listen for app state changes to adjust polling frequency
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.adjustPollingForBackground()
        }
        
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.adjustPollingForForeground()
        }
        
        // Listen for app termination to clean up widget data
        NotificationCenter.default.addObserver(forName: UIApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            self?.handleAppTermination()
        }
    }
    
    /// Startup sync boost - immediately update all widgets/Live Activities on app launch
    private func performStartupSyncBoost() {
        print("[Startup] 🚀 App launched - checking for termination recovery")
        
        // ALWAYS clear termination flags on app startup
        if let sharedDefaults = UserDefaults(suiteName: "group.com.vishnu.lyracalise") {
            // Clear termination flags immediately
            sharedDefaults.removeObject(forKey: "appTerminationTime")
            sharedDefaults.removeObject(forKey: "terminationReason")
            
            // Check if this is a recovery from app termination
            if let lastUpdateTime = sharedDefaults.object(forKey: "lastUpdateTime") as? Date {
                let timeSinceLastUpdate = Date().timeIntervalSince(lastUpdateTime)
                if timeSinceLastUpdate > 60 {
                    print("[Startup] 📱 Detected app termination recovery - clearing stale widget data")
                    // Clear potentially stale data
                    sharedDefaults.removeObject(forKey: "currentLyric")
                    sharedDefaults.removeObject(forKey: "songTitle") 
                    sharedDefaults.removeObject(forKey: "artist")
                    sharedDefaults.set(false, forKey: "isActive")
                }
            }
        }
        
        if SpotifyManager.shared.isLoggedIn {
            SpotifyManager.shared.fetchCurrentTrack { [weak self] track in
                guard let self = self else { return }
                
                if let track = track {
                    print("[Startup] 🎵 Startup track detected: \(track.name)")
                    
                    // Update our state immediately
                    self.nowPlayingTitle = track.name
                    self.nowPlayingArtist = track.artist
                    self.nowPlayingTrackID = track.id
                    self.syncState = (track.isPlaying ?? true) ? .playing : .paused
                    self.isStopped = false // Ensure we're not in stopped state
                    
                    // If we have lyrics loaded, sync to current position
                    if !self.loadedLyrics.isEmpty {
                        if let progressMs = track.progressMs {
                            self.setLyricSyncOffset(milliseconds: progressMs)
                            self.startSyncing()
                        }
                    } else {
                        // Load lyrics for this track
                        self.loadLyricsForCurrentSong()
                    }
                    
                    // Start Live Activity if needed
                    Task { await self.smartLiveActivityUpdate() }
                } else {
                    print("[Startup] ❌ No track found on startup")
                    // Clear stale data if no track is playing
                    self.nowPlayingTitle = ""
                    self.nowPlayingArtist = ""
                    self.statusMessage = "Waiting..."
                }
                
                // ALWAYS force widget update after startup, regardless of track status
                self.updateWidgetSharedData()
            }
        } else {
            // For Apple Music, update Now Playing info
            self.updateNowPlayingInfo()
            self.updateWidgetSharedData()
        }
    }
    
    private func adjustPollingForBackground() {
        guard SpotifyManager.shared.isLoggedIn else { return }
        print("[LyricSyncManager] App entering background, starting background task")
        startBackgroundTask()
        startSpotifyObservation() // This will use background interval
    }
    
    private func adjustPollingForForeground() {
        guard SpotifyManager.shared.isLoggedIn else { return }
        print("[LyricSyncManager] App entering foreground, ending background task")
        endBackgroundTask()
        
        // IMMEDIATE SYNC: Force refresh current state when app resumes
        print("[Resume] 🔄 App resumed - forcing immediate sync update")
        SpotifyManager.shared.fetchCurrentTrack { [weak self] track in
            guard let self = self, let track = track else { return }
            print("[Resume] 📱 Syncing resumed state: \(track.name)")
            self.handleSpotifyState(track: track)
            
            // Force immediate widget and Live Activity updates
            self.updateWidgetSharedData()
            if !self.currentLine.isEmpty {
                self.updateLiveActivity(lyric: self.currentLine)
            }
        }
        
        startSpotifyObservation() // This will use foreground interval
        
        // Check if we need to create a Live Activity now that we're in foreground
        if activity == nil && !nowPlayingTitle.isEmpty && !nowPlayingArtist.isEmpty && !isStopped {
            print("[LyricSyncManager] 🆕 Creating missing Live Activity now that app is in foreground")
            Task { await startLiveActivity() }
        }
    }

    // MARK: - Core Syncing Logic
    
    /// Starts the main timer that syncs lyrics with the music player's elapsed time.
    func startSyncing() {
        stopSyncing() // Ensure no previous timer is running
        syncTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateLyricForCurrentTime()
        }
        updateWidgetSharedData()
    }

    func stopSyncing() {
        syncTimer?.invalidate()
        syncTimer = nil
    }

    private func updateLyricForCurrentTime() {
        guard !isStopped else { return }
        guard !loadedLyrics.isEmpty else { return }
        
        // Don't update lyrics when paused
        guard syncState != .paused else { 
            print("[LyricSync] ⏸️ Skipping lyric update - music is paused")
            return 
        }

        let currentPlaybackTime = getCurrentPlaybackTime()
        let newIndex = loadedLyrics.lastIndex(where: { $0.time <= currentPlaybackTime })

        if newIndex != self.currentLineIndex {
            self.currentLineIndex = newIndex
            if let newIndex = newIndex {
                let newLine = self.loadedLyrics[newIndex].line
                if self.currentLine != newLine {
                    self.currentLine = newLine
                    
                    // Premium haptic feedback for lyric changes
                    HapticManager.shared.lyricChanged()
                    
                    self.updateLiveActivity(lyric: newLine)
                    // IMPORTANT: Update widget when lyrics change!
                    self.updateWidgetSharedData()
                }
            }
        }
    }
    
    private func getCurrentPlaybackTime() -> TimeInterval {
        if let manualOffset = manualSyncOffset, let startTime = manualSyncStartTime {
            return manualOffset + Date().timeIntervalSince(startTime)
        }
        
        if let info = MPNowPlayingInfoCenter.default().nowPlayingInfo,
           let elapsed = info[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? TimeInterval,
           elapsed > 0 {
            if self.simulatedPlaybackStartTime != nil {
                self.simulatedPlaybackStartTime = nil
            }
            return elapsed
        }
        
        if let simulatedStart = simulatedPlaybackStartTime {
            return Date().timeIntervalSince(simulatedStart)
        }
        
        return 0
    }
    
    func resync(to time: TimeInterval, at index: Int) {
        // Premium haptic feedback for manual sync correction
        HapticManager.shared.userCorrectedSync()
        
        self.manualSyncOffset = time
        self.manualSyncStartTime = Date() // Record the moment of the tap
        self.currentLineIndex = index
        self.currentLine = self.loadedLyrics[index].line
        self.updateLiveActivity(lyric: self.currentLine)
    }

    func resumeOrStartLyricSync() {
        print("[Resume] 🔄 Checking if we should auto-resume or start fresh")
        
        // Clear any termination flags
        if let sharedDefaults = UserDefaults(suiteName: "group.com.vishnu.lyracalise") {
            sharedDefaults.removeObject(forKey: "appTerminationTime")
            sharedDefaults.removeObject(forKey: "terminationReason")
            sharedDefaults.set(true, forKey: "appIsActive")
        }
        
        self.isStopped = false
        
        if SpotifyManager.shared.isLoggedIn {
            SpotifyManager.shared.fetchCurrentTrack { [weak self] track in
                guard let self = self else { return }
                if let track = track {
                    print("[Resume] 🎵 Current track: \(track.name)")
                    
                    // Update track info immediately
                    self.nowPlayingTitle = track.name
                    self.nowPlayingArtist = track.artist
                    self.nowPlayingTrackID = track.id
                    self.lastProgressMs = track.progressMs
                    self.syncState = (track.isPlaying ?? true) ? .playing : .paused
                    
                    // Check if we have lyrics loaded for this track
                    if !self.loadedLyrics.isEmpty {
                        print("[Resume] ✅ Found existing lyrics - auto-syncing to current position")
                        // Auto-sync to current position without resetting everything
                        if let progressMs = track.progressMs {
                            self.setLyricSyncOffset(milliseconds: progressMs)
                        }
                        self.startSyncing() // Start timer immediately
                        self.statusMessage = "Auto-synced"
                    } else {
                        print("[Resume] 🔍 No lyrics loaded - starting fresh sync")
                        // No lyrics yet, load them
                        self.loadLyricsForCurrentSong()
                        self.statusMessage = "Loading..."
                    }
                    
                    // Start or update Live Activity
                    Task { await self.smartLiveActivityUpdate() }
                } else {
                    print("[Resume] ❌ No current track found")
                    self.statusMessage = "No music"
                }
                // Always update widgets
                self.updateWidgetSharedData()
            }
            startSpotifyObservation()
        } else {
            // For Apple Music
            startNowPlayingObservation()
            
            if !nowPlayingTitle.isEmpty && !nowPlayingArtist.isEmpty {
                if !loadedLyrics.isEmpty {
                    print("[Resume] ✅ Found existing lyrics for Apple Music - starting sync")
                    startSyncing()
                    statusMessage = "Auto-synced"
                } else {
                    loadLyricsForCurrentSong()
                    statusMessage = "Loading..."
                }
                Task { await self.smartLiveActivityUpdate() }
            } else {
                statusMessage = "Waiting..."
            }
            updateWidgetSharedData()
        }
    }

    func startLyricSync() {
        print("[Start] 🚀 Starting lyric sync")
        
        // Premium haptic feedback for session start
        HapticManager.shared.sessionStarted()
        
        self.isStopped = false
        
        // Clear any termination flags when starting manually
        if let sharedDefaults = UserDefaults(suiteName: "group.com.vishnu.lyracalise") {
            sharedDefaults.removeObject(forKey: "appTerminationTime")
            sharedDefaults.removeObject(forKey: "terminationReason")
            sharedDefaults.set(true, forKey: "isActive")
            sharedDefaults.set(true, forKey: "appIsActive")
            print("[Start] ✅ Cleared termination flags")
        }
        
        // Reset state completely before starting
        self.syncState = .waiting
        self.currentLine = ""
        self.currentLineIndex = nil
        self.manualSyncOffset = nil
        self.manualSyncStartTime = nil
        self.simulatedPlaybackStartTime = nil
        
        if SpotifyManager.shared.isLoggedIn {
             SpotifyManager.shared.fetchCurrentTrack { [weak self] track in
                guard let self = self else { return }
                if let track = track {
                    print("[Start] 🎵 Current track: \(track.name)")
                    
                    // Update track info immediately
                    self.nowPlayingTitle = track.name
                    self.nowPlayingArtist = track.artist
                    self.nowPlayingTrackID = track.id
                    self.lastProgressMs = track.progressMs
                    self.syncState = (track.isPlaying ?? true) ? .playing : .paused
                    
                    // Load lyrics if we don't have them
                    if self.loadedLyrics.isEmpty {
                        self.loadLyricsForCurrentSong()
                    } else {
                        // If we have lyrics, start syncing immediately
                        if let progressMs = track.progressMs {
                            self.setLyricSyncOffset(milliseconds: progressMs)
                        }
                        self.startSyncing()
                    }
                    
                    // Start or update Live Activity
                    Task { await self.smartLiveActivityUpdate() }
                    
                    self.statusMessage = "Syncing..."
                } else {
                    print("[Start] ❌ No current track found")
                    self.statusMessage = "No music. Start a song and try again."
                }
                // Always update widgets after start attempt
                self.updateWidgetSharedData()
             }
            startSpotifyObservation()
        } else {
            // For Apple Music
            startNowPlayingObservation()
            
            // If we already have track info, start syncing
            if !nowPlayingTitle.isEmpty && !nowPlayingArtist.isEmpty {
                if loadedLyrics.isEmpty {
                    loadLyricsForCurrentSong()
                } else {
                    startSyncing()
                }
                Task { await self.smartLiveActivityUpdate() }
                statusMessage = "Syncing..."
            } else {
                statusMessage = "Waiting..."
            }
            updateWidgetSharedData()
        }
    }

    // MARK: - Now Playing Observation
    
    func startNowPlayingObservation(timeout: TimeInterval = 8.0) {
        guard !SpotifyManager.shared.isLoggedIn else { return }
        nowPlayingTimer?.invalidate()
        nowPlayingTimeoutTimer?.invalidate()
        nowPlayingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateNowPlayingInfo()
        }
        nowPlayingTimeoutTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if self.nowPlayingTitle.isEmpty {
                self.statusMessage = "Auto-detection failed. Search manually."
                self.manualSearchEnabled = true
            }
        }
    }

    private func updateNowPlayingInfo() {
        let info = MPNowPlayingInfoCenter.default().nowPlayingInfo
        let title = info?[MPNowPlayingInfoPropertyTitle] as? String ?? ""
        let artist = info?[MPNowPlayingInfoPropertyArtist] as? String ?? ""
        if title != lastNowPlayingTitle || artist != lastNowPlayingArtist {
            self.nowPlayingTimeoutTimer?.invalidate()
            lastNowPlayingTitle = title
            lastNowPlayingArtist = artist
            self.resetStateForNewSong()
            self.nowPlayingTitle = title
            self.nowPlayingArtist = artist
            self.loadLyricsForCurrentSong()
        }
    }

    private func resetStateForNewSong() {
        self.loadedLyrics = []
        self.staticLyrics = nil
        self.currentLine = ""
        self.currentLineIndex = nil
        self.manualSyncOffset = nil
        self.manualSyncStartTime = nil
        self.simulatedPlaybackStartTime = nil
        self.isShowingSearchResults = false
        self.searchResults = []
        stopSyncing()
        // NOTE: We DON'T stop Live Activity here anymore - we update it instead!
    }

    func manualSearch(for query: String) {
        let cleanedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = cleanedQuery.components(separatedBy: "-").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        let artist = parts.count > 1 ? parts[0] : ""
        let title = parts.count > 1 ? parts.dropFirst().joined(separator: "-").trimmingCharacters(in: .whitespacesAndNewlines) : cleanedQuery
        
        guard !title.isEmpty else {
            self.statusMessage = "Enter a song title."
            return
        }
        
        self.resetStateForNewSong()
        self.nowPlayingArtist = artist
        self.nowPlayingTitle = title
        self.loadLyricsForCurrentSong()
    }

    // MARK: - Local & Web Lyric Fetching
    
    func loadLyricsForCurrentSong() {
        let filename = filenameFor(title: nowPlayingTitle, artist: nowPlayingArtist)
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let lyricsFolderURL = documentsURL.appendingPathComponent("Lyrics")
            let fileURL = lyricsFolderURL.appendingPathComponent("\(filename).lrc")

            // Check if cached file exists and is within 30-day limit
            if FileManager.default.fileExists(atPath: fileURL.path) {
                do {
                    let fileAttributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                    if let modificationDate = fileAttributes[FileAttributeKey.modificationDate] as? Date {
                        let daysSinceLastAccess = Calendar.current.dateComponents([.day], from: modificationDate, to: Date()).day ?? 0
                        
                        if daysSinceLastAccess <= 30 {
                            // File is fresh, load from cache
                            if let lrcContent = try? String(contentsOf: fileURL) {
                                let parsedLyrics = WebLyricsFetcher.parseLRC(lrcContent)
                                self.loadedLyrics = parsedLyrics
                                
                                // Update access time by touching the file's modification date
                                try? FileManager.default.setAttributes([FileAttributeKey.modificationDate: Date()], ofItemAtPath: fileURL.path)
                                
                                self.statusMessage = "Cached"
                                self.startSyncing()
                                Task { await self.smartLiveActivityUpdate() }
                                return
                            }
                        } else {
                            // File hasn't been accessed in 30+ days, remove it
                            try? FileManager.default.removeItem(at: fileURL)
                            self.statusMessage = "Cache expired"
                        }
                    }
                } catch {
                    print("Error checking file attributes: \(error)")
                }
            }
        }

        // BACKGROUND-OPTIMIZED: Quick lyrics fetching with extended background time
        let query = "\(nowPlayingArtist) \(nowPlayingTitle)"
        let appState = UIApplication.shared.applicationState
        
        Task {
            // Request extended background time for lyrics fetching
            var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
            if appState != .active {
                backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "LyricsFetch") {
                    print("[Background] ⏰ Background lyrics fetch task expired")
                    UIApplication.shared.endBackgroundTask(backgroundTaskID)
                }
                print("[Background] 🎵 Started background lyrics fetch task")
            }
            
            self.statusMessage = "Searching..."
            let results = await WebLyricsFetcher.search(for: query)
            
            if results.isEmpty {
                self.statusMessage = "Not found"
                self.autoSelectedFirstResult = false
            } else if results.count == 1 {
                self.autoSelectedFirstResult = false
                self.selectSearchResult(results.first!)
            } else {
                self.autoSelectedFirstResult = true
                self.tryAutoSelectFirstResult(results: results)
            }
            
            // End background task if it was started
            if backgroundTaskID != .invalid {
                print("[Background] ✅ Ending background lyrics fetch task")
                UIApplication.shared.endBackgroundTask(backgroundTaskID)
            }
        }
    }
    
    func selectSearchResult(_ result: LrclibSearchResult) {
        self.isShowingSearchResults = false
        self.statusMessage = "Fetching..."
        
        Task {
            if let lrcContent = await WebLyricsFetcher.fetchLrcContent(for: result.id) {
                let parsedLyrics = WebLyricsFetcher.parseLRC(lrcContent)
                
                await MainActor.run {
                    self.nowPlayingTitle = result.name
                    self.nowPlayingArtist = result.artistName
                    self.loadedLyrics = parsedLyrics
                    self.statusMessage = "Loaded!"
                    
                    // Premium haptic feedback for successful lyrics loading
                    HapticManager.shared.lyricsLoaded()
                    
                    if MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? TimeInterval ?? 0 <= 0 {
                        self.simulatedPlaybackStartTime = Date()
                        self.statusMessage = "Tap a line to sync."
                    }
                    
                    self.startSyncing()
                }
                
                // SMART: Use update logic instead of creating new Live Activity
                await self.smartLiveActivityUpdate()
                self.saveLyricsToFile(lrcContent: lrcContent, for: result.name, artist: result.artistName)
            } else {
                await MainActor.run {
                    self.statusMessage = "Failed to fetch lyrics. Please try another selection."
                    self.isShowingSearchResults = true  // Show search results again
                }
            }
        }
    }

    private func tryAutoSelectFirstResult(results: [LrclibSearchResult]) {
        guard let firstResult = results.first else { return }
        self.isShowingSearchResults = false
        self.statusMessage = "Fetching lyrics..."
        Task {
            if let lrcContent = await WebLyricsFetcher.fetchLrcContent(for: firstResult.id) {
                let parsedLyrics = WebLyricsFetcher.parseLRC(lrcContent)
                self.nowPlayingTitle = firstResult.name
                self.nowPlayingArtist = firstResult.artistName
                self.loadedLyrics = parsedLyrics
                self.statusMessage = "Lyrics loaded!"
                if MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? TimeInterval ?? 0 <= 0 {
                    self.simulatedPlaybackStartTime = Date()
                    self.statusMessage = "Starting from beginning. Tap a line to sync."
                }
                self.startSyncing()
                // SMART: Use update logic instead of creating new Live Activity
                await self.smartLiveActivityUpdate()
                self.saveLyricsToFile(lrcContent: lrcContent, for: firstResult.name, artist: firstResult.artistName)
            } else {
                self.searchResults = results
                self.isShowingSearchResults = true
                self.statusMessage = "Auto-selection failed. Please select the correct version."
                self.autoSelectedFirstResult = false
            }
        }
    }

    private func saveLyricsToFile(lrcContent: String, for title: String, artist: String) {
        let fileName = filenameFor(title: title, artist: artist)
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Could not access the documents directory.")
            return
        }
        
        let lyricsDirectory = documentsDirectory.appendingPathComponent("Lyrics", isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: lyricsDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: lyricsDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Failed to create Lyrics directory: \(error)")
                return
            }
        }
        
        let fileURL = lyricsDirectory.appendingPathComponent("\(fileName).lrc")
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            print("Lyric file already exists for '\(fileName)'. Skipping save.")
            return
        }

        do {
            try lrcContent.write(to: fileURL, atomically: true, encoding: .utf8)
            print("Successfully saved lyrics to: \(fileURL.path)")
        } catch {
            print("Failed to write lyrics file: \(error)")
        }
    }

    // MARK: - NEW Live Activity System (Prevents Stacking)
    private func startFreshLiveActivityForSongChange() async {
        let appState = UIApplication.shared.applicationState
        print("[NewLiveActivity] 🚀 Starting fresh Live Activity for song change [App: \(appState == .active ? "foreground" : "background")]")
        
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { 
            print("[NewLiveActivity] ❌ Live Activities not enabled")
            return 
        }
        
        guard !nowPlayingTitle.isEmpty && !nowPlayingArtist.isEmpty else {
            print("[NewLiveActivity] ❌ Missing song info: title='\(nowPlayingTitle)', artist='\(nowPlayingArtist)'")
            return
        }

        // Create NEW Live Activity with unique ID (prevents stacking)
        let uniqueID = UUID().uuidString
        print("[NewLiveActivity] 🔑 Generated unique ID: \(uniqueID)")
        let newAttributes = LyricAttributes(
            appName: "Lyracalise",
            uniqueID: uniqueID
        )
        let initialState = LyricAttributes.ContentState(
            currentLyric: currentLine.isEmpty ? "♪ \(nowPlayingTitle)" : currentLine,
            songTitle: nowPlayingTitle,
            artist: nowPlayingArtist,
            timestamp: Date()
        )

        do {
            print("[NewLiveActivity] 🔄 Creating NEW Live Activity with ID: \(uniqueID)")
            
            // FIRST: Stop ALL existing Live Activities immediately to prevent stacking
            if let oldActivity = self.activity {
                print("[NewLiveActivity] 🛑 IMMEDIATELY stopping old Live Activity to prevent stacking")
                await oldActivity.end(nil, dismissalPolicy: .immediate)
                self.activity = nil
            }
            
            // Also end any other potential activities that might be running
            for activity in Activity<LyricAttributes>.activities {
                print("[NewLiveActivity] 🧹 Cleaning up existing activity")
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            
            // Small delay to ensure cleanup
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            
            // THEN: Create new activity
            let newActivity = try Activity<LyricAttributes>.request(
                attributes: newAttributes,
                content: .init(state: initialState, staleDate: nil)
            )
            
            self.activity = newActivity
            print("[NewLiveActivity] ✅ NEW Live Activity created successfully with ID: \(uniqueID)")
            
        } catch {
            print("[NewLiveActivity] ❌ Error creating new Live Activity: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Smart Live Activity Updates (No Recreation Needed!)
    private func updateLiveActivityForNewSong() async {
        print("[SmartUpdate] 🎵 Updating Live Activity with new song: '\(nowPlayingTitle)' by '\(nowPlayingArtist)'")
        
        guard let activity = self.activity else {
            print("[SmartUpdate] ❌ No existing Live Activity to update")
            return
        }
        
        // Create new content state with updated song info and current lyric
        let newState = LyricAttributes.ContentState(
            currentLyric: currentLine.isEmpty ? "♪ \(nowPlayingTitle)" : currentLine,
            songTitle: nowPlayingTitle,
            artist: nowPlayingArtist,
            timestamp: Date()
        )
        
        do {
            // Update the existing Live Activity - this works even in background!
            await activity.update(.init(state: newState, staleDate: nil))
            print("[SmartUpdate] ✅ Live Activity updated successfully with new song!")
        } catch {
            print("[SmartUpdate] ❌ Error updating Live Activity: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Live Activity & Widget
    private func forceStartLiveActivityForNewSong() async {
        print("[LiveActivity] Force starting Live Activity for new song")
        
        // Always stop any existing activity first
        await stopLiveActivity()
        
        // Wait a moment to ensure cleanup
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { 
            print("[LiveActivity] Live Activities not enabled")
            return 
        }
        
        guard !nowPlayingTitle.isEmpty && !nowPlayingArtist.isEmpty else {
            print("[LiveActivity] Missing song info: title='\(nowPlayingTitle)', artist='\(nowPlayingArtist)'")
            return
        }

        let attributes = LyricAttributes(
            appName: "Lyracalise",
            uniqueID: UUID().uuidString
        )
        let initialState = LyricAttributes.ContentState(
            currentLyric: currentLine.isEmpty ? "♪ \(nowPlayingTitle)" : currentLine,
            songTitle: nowPlayingTitle,
            artist: nowPlayingArtist,
            timestamp: Date()
        )

        do {
            activity = try Activity<LyricAttributes>.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil)
            )
            print("[LiveActivity] ✅ Successfully started Live Activity for: '\(nowPlayingTitle)' by '\(nowPlayingArtist)'")
        } catch {
            print("[LiveActivity] ❌ Error starting Live Activity: \(error.localizedDescription)")
            // Try again after a short delay
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            do {
                activity = try Activity<LyricAttributes>.request(
                    attributes: attributes,
                    content: .init(state: initialState, staleDate: nil)
                )
                print("[LiveActivity] ✅ Retry successful for: '\(nowPlayingTitle)'")
            } catch {
                print("[LiveActivity] ❌ Retry failed: \(error.localizedDescription)")
            }
        }
    }
    
    /// Smart Live Activity management - either updates existing or creates new one
    private func smartLiveActivityUpdate() async {
        print("[SmartLiveActivity] 🧠 Smart update called - existing activity: \(activity != nil)")
        
        // FIRST: Clean up any orphaned Live Activities to prevent stacking
        await cleanupAllLiveActivities()
        
        if let existingActivity = activity {
            // Check if the activity is still valid
            if existingActivity.activityState == .active {
                print("[SmartLiveActivity] ✅ Updating existing valid Live Activity")
                await updateLiveActivityForNewSong()
            } else {
                print("[SmartLiveActivity] 🔄 Existing activity is stale, creating new one")
                self.activity = nil
                await startLiveActivity()
            }
        } else {
            print("[SmartLiveActivity] 🆕 No existing activity, creating new one")
            await startLiveActivity()
        }
    }
    
    /// Cleanup all Live Activities to prevent stacking
    private func cleanupAllLiveActivities() async {
        print("[Cleanup] 🧹 Cleaning up all Live Activities to prevent stacking")
        
        // End our tracked activity first
        if let currentActivity = self.activity {
            await currentActivity.end(nil, dismissalPolicy: .immediate)
            self.activity = nil
        }
        
        // End any other activities that might be running
        let allActivities = Activity<LyricAttributes>.activities
        for activity in allActivities {
            print("[Cleanup] 🗑️ Ending orphaned activity: \(activity.id)")
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        
        print("[Cleanup] ✅ All Live Activities cleaned up")
    }
    
    /// Handle app termination - clean up widget data
    private func handleAppTermination() {
        print("[Termination] 💀 App terminating - cleaning up widget data")
        
        if let sharedDefaults = UserDefaults(suiteName: "group.com.vishnu.lyracalise") {
            // Set termination flag so widgets know app was closed
            sharedDefaults.set(Date(), forKey: "appTerminationTime")
            sharedDefaults.set(false, forKey: "isActive")
            sharedDefaults.set(false, forKey: "appIsActive")
            
            // Don't clear lyric data completely, but mark as stale
            sharedDefaults.set("App terminated", forKey: "terminationReason")
        }
        
        // End Live Activities gracefully 
        Task {
            await stopLiveActivity()
        }
    }
    
    private func startLiveActivity() async {
        print("[LiveActivity] startLiveActivity called - isStopped: \(isStopped), title: '\(nowPlayingTitle)', artist: '\(nowPlayingArtist)'")
        
        // SMART: If we have an existing activity, just update it instead of recreating
        if let existingActivity = activity {
            print("[LiveActivity] 🔄 Existing activity found, updating instead of recreating")
            await updateLiveActivityForNewSong()
            return
        }
        
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { 
            print("[LiveActivity] ❌ Live Activities not enabled")
            return 
        }
        
        guard !nowPlayingTitle.isEmpty && !nowPlayingArtist.isEmpty else {
            print("[LiveActivity] ❌ Missing song info for Live Activity: title='\(nowPlayingTitle)', artist='\(nowPlayingArtist)'")
            return
        }

        let attributes = LyricAttributes(
            appName: "Lyracalise",
            uniqueID: UUID().uuidString
        )
        let initialState = LyricAttributes.ContentState(
            currentLyric: currentLine.isEmpty ? "♪ Loading lyrics..." : currentLine,
            songTitle: nowPlayingTitle,
            artist: nowPlayingArtist,
            timestamp: Date()
        )

        do {
            print("[LiveActivity] 🔄 Requesting Live Activity for: '\(nowPlayingTitle)' by '\(nowPlayingArtist)'")
            activity = try Activity<LyricAttributes>.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil)
            )
            print("[LiveActivity] ✅ Live Activity started successfully!")
        } catch {
            print("[LiveActivity] ❌ Error requesting Live Activity: \(error.localizedDescription)")
        }
    }

    private func updateLiveActivity(lyric: String) {
        let displayLyric: String
        if syncState == .paused && !lyric.hasPrefix("⏸️") {
            displayLyric = "⏸️ \(lyric)"
        } else {
            displayLyric = lyric
        }
        
        let state = LyricAttributes.ContentState(
            currentLyric: displayLyric,
            songTitle: nowPlayingTitle,
            artist: nowPlayingArtist,
            timestamp: Date()
        )
        Task {
            await activity?.update(.init(state: state, staleDate: nil))
        }
        updateWidgetSharedData()
    }

    private func stopLiveActivity() async {
        await activity?.end(nil, dismissalPolicy: .immediate)
        activity = nil
    }

    private func updateWidgetSharedData() {
        if let sharedDefaults = UserDefaults(suiteName: "group.com.vishnu.lyracalise") {
            let timestamp = Date()
            
            // Include pause state in the lyric display
            let displayLyric: String
            if syncState == .paused {
                displayLyric = currentLine.isEmpty ? "⏸️ Paused" : "⏸️ \(currentLine)"
            } else {
                displayLyric = currentLine.isEmpty ? "" : currentLine
            }
            
            // Ensure we always have valid data
            let finalLyric = displayLyric.isEmpty ? (isStopped ? "" : "♪ Loading lyrics...") : displayLyric
            let finalTitle = nowPlayingTitle.isEmpty ? "" : nowPlayingTitle
            let finalArtist = nowPlayingArtist.isEmpty ? "" : nowPlayingArtist
            
            sharedDefaults.set(finalLyric, forKey: "currentLyric")
            sharedDefaults.set(finalTitle, forKey: "songTitle")
            sharedDefaults.set(finalArtist, forKey: "artist")
            sharedDefaults.set(timestamp, forKey: "lastUpdateTime")
            sharedDefaults.set(syncState.rawValue, forKey: "syncState") // Track sync state
            sharedDefaults.set(!isStopped, forKey: "isActive") // Track if app is active
            sharedDefaults.set(syncState == .paused, forKey: "isPaused") // Explicit pause state
            
            // AGGRESSIVE: Set flags to help widgets detect fresh data
            sharedDefaults.set(true, forKey: "hasNewData") // Signal fresh update
            sharedDefaults.set(UIApplication.shared.applicationState == .active, forKey: "appIsActive") // App state
            
            // Track successful update
            lastSuccessfulUpdate = timestamp
            
            // TRIPLE force widget updates for maximum compatibility
            WidgetCenter.shared.reloadAllTimelines()
            
            // Force reload specific widget kinds if needed
            WidgetCenter.shared.reloadTimelines(ofKind: "lyric_widget")
            
            print("[LyricSyncManager] 🔄 Widget update - Active: \(!isStopped), Lyric: '\(finalLyric)', Title: '\(finalTitle)', Artist: '\(finalArtist)', State: \(syncState.rawValue)")
        }
    }

    func stopAll(showStopped: Bool = true) {
        print("[Stop] 🛑 Stopping all lyric sync")
        
        // Premium haptic feedback for session end
        HapticManager.shared.sessionEnded()
        
        isStopped = true
        
        // Stop all timers
        spotifyTimer?.invalidate()
        spotifyTimer = nil
        nowPlayingTimer?.invalidate()
        nowPlayingTimer = nil
        nowPlayingTimeoutTimer?.invalidate()
        nowPlayingTimeoutTimer = nil
        stopSyncing()
        
        // Stop Live Activity
        Task { await stopLiveActivity() }

        // Clear widget data
        if let sharedDefaults = UserDefaults(suiteName: "group.com.vishnu.lyracalise") {
            sharedDefaults.removeObject(forKey: "currentLyric")
            sharedDefaults.removeObject(forKey: "songTitle")
            sharedDefaults.removeObject(forKey: "artist")
            sharedDefaults.set(false, forKey: "isActive")
            sharedDefaults.set(false, forKey: "appIsActive")
            sharedDefaults.removeObject(forKey: "appTerminationTime")
            sharedDefaults.removeObject(forKey: "terminationReason")
            WidgetCenter.shared.reloadAllTimelines()
        }

        // Reset sync state
        self.syncState = .stopped
        self.currentLine = ""
        self.currentLineIndex = nil
        self.manualSyncOffset = nil
        self.manualSyncStartTime = nil
        self.simulatedPlaybackStartTime = nil
        self.nowPlayingTrackID = nil
        self.lastProgressMs = nil
        
        if showStopped {
            self.statusMessage = "Stopped. Press Start to resume."
        }
    }
    
    func stopAllLyricSync() {
        stopAll()
    }

    // MARK: - Spotify Observation
    private func startSpotifyObservation() {
        spotifyTimer?.invalidate()
        
        // More aggressive intervals - faster background detection
        let interval: TimeInterval = UIApplication.shared.applicationState == .active ? 0.5 : 2.0 // Changed from 1.0 to 2.0 for background
        
        print("[SpotifyObservation] 🔄 Starting observation with \(interval)s interval [App: \(UIApplication.shared.applicationState == .active ? "foreground" : "background")]")
        
        spotifyTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self, !self.isStopped else { return }
            
            // Check for stale data periodically
            self.checkForStaleData()
            
            // Always renew background task to stay alive longer
            if UIApplication.shared.applicationState != .active {
                self.startBackgroundTask()
            }
            
            // Use background session when app is not active
            if UIApplication.shared.applicationState != .active {
                print("[Background] 🌙 App in background, using background session")
                BackgroundSessionManager.shared.fetchCurrentTrackInBackground { track in
                    if let track = track {
                        print("[Background] 🎵 Background track detected: \(track.name)")
                        self.debounceWorkItem?.cancel()
                        let workItem = DispatchWorkItem { 
                            print("[Background] 🔄 Processing background track change")
                            self.handleSpotifyState(track: track) 
                        }
                        self.debounceWorkItem = workItem
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem) // Faster debounce
                    } else {
                        print("[Background] ❌ No background track detected")
                        self.syncState = .waiting
                        self.statusMessage = "Waiting for Spotify..."
                    }
                }
            } else {
                // Use regular session when app is active
                SpotifyManager.shared.fetchCurrentTrack { track in
                    if let track = track {
                        self.debounceWorkItem?.cancel()
                        let workItem = DispatchWorkItem { self.handleSpotifyState(track: track) }
                        self.debounceWorkItem = workItem
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem) // Faster debounce
                    } else {
                        self.syncState = .waiting
                        self.statusMessage = "Waiting for Spotify..."
                    }
                }
            }
        }
    }

    private func handleSpotifyState(track: SpotifyTrack) {
        let appState = UIApplication.shared.applicationState
        print("[HandleState] 📱 App state: \(appState == .active ? "active" : appState == .background ? "background" : "inactive")")
        
        self.currentTrack = track
        let trackIDChanged = self.nowPlayingTrackID != track.id
        let isPlaying = track.isPlaying ?? true
        let currentProgress = track.progressMs ?? 0
        
        if trackIDChanged {
            print("[LyricSyncManager] Song changed: \(track.name) by \(track.artist) [App: \(appState == .active ? "foreground" : "background")]")
            
            // Auto-restart on song change (same as pressing Start button)
            self.isStopped = false
            
            // First update the song info
            self.nowPlayingTitle = track.name
            self.nowPlayingArtist = track.artist
            self.nowPlayingTrackID = track.id
            self.lastProgressMs = currentProgress
            self.syncState = isPlaying ? .playing : .paused
            
            // Reset state and stop old Live Activity
            self.resetStateForNewSong()
            
            // Load lyrics and start syncing
            self.loadLyricsForCurrentSong()
            self.setLyricSyncOffset(milliseconds: currentProgress)
            self.statusMessage = ""
            
            // SMART APPROACH: Update existing Live Activity instead of creating new ones
            Task { 
                let appState = UIApplication.shared.applicationState
                print("[LyricSyncManager] Song changed - App state: \(appState == .active ? "foreground" : "background")")
                
                if self.activity != nil {
                    // We have an existing Live Activity - just update it with new song info!
                    print("[LyricSyncManager] 🔄 Updating existing Live Activity with new song")
                    await self.updateLiveActivityForNewSong()
                } else {
                    // No Live Activity exists - create one (but only if in foreground)
                    if appState == .active {
                        print("[LyricSyncManager] 🆕 Creating new Live Activity (foreground)")
                        await self.startLiveActivity()
                    } else {
                        print("[LyricSyncManager] ⏳ Cannot create Live Activity in background - will create when app returns to foreground")
                    }
                }
            }
            return
        }
        
        if let last = self.lastProgressMs, abs(currentProgress - last) > 2000 {
            self.syncState = .seeking
            self.setLyricSyncOffset(milliseconds: currentProgress)
        }
        self.lastProgressMs = currentProgress
        
        switch (self.syncState, isPlaying) {
        case (.playing, false):
            print("[LyricSync] 🎵➡️⏸️ Music paused - pausing lyrics")
            HapticManager.shared.musicPaused()
            self.syncState = .paused
            self.pauseLyricTimer(at: currentProgress)
        case (.paused, true), (.seeking, true), (.waiting, true), (.stopped, true):
            print("[LyricSync] ⏸️➡️🎵 Music resumed - resuming lyrics")
            HapticManager.shared.musicResumed()
            self.syncState = .playing
            self.setLyricSyncOffset(milliseconds: currentProgress)
            self.startSyncing()
        case (.paused, false):
            print("[LyricSync] ⏸️ Music still paused - keeping lyrics paused")
            // Keep paused, no action needed
        case (.playing, true):
            // Already playing, just update offset if needed
            if abs(currentProgress - (lastProgressMs ?? 0)) > 1000 {
                print("[LyricSync] 🎵 Music playing - updating sync offset")
                self.setLyricSyncOffset(milliseconds: currentProgress)
            }
        default:
            break
        }
        
        if currentProgress == 0 && !isPlaying {
            stopAll()
        }
    }

    private func pauseLyricTimer(at progressMs: Int) {
        print("[LyricSync] ⏸️ Pausing lyrics at \(progressMs)ms")
        stopSyncing()
        self.manualSyncOffset = Double(progressMs) / 1000.0
        self.manualSyncStartTime = nil
        
        // Update widgets and Live Activity to show paused state
        updateWidgetSharedData()
        let pausedLyric = currentLine.isEmpty ? "⏸️ Paused" : "⏸️ \(currentLine)"
        updateLiveActivity(lyric: pausedLyric)
    }

    private func setLyricSyncOffset(milliseconds: Int) {
        self.manualSyncOffset = Double(milliseconds) / 1000.0
        self.manualSyncStartTime = Date()
    }
    
    private func filenameFor(title: String?, artist: String?) -> String {
        let cleanTitle = title?.replacingOccurrences(of: "[^a-zA-Z0-9 ]", with: "", options: .regularExpression) ?? ""
        let cleanArtist = artist?.replacingOccurrences(of: "[^a-zA-Z0-9 ]", with: "", options: .regularExpression) ?? ""
        return "\(cleanArtist) - \(cleanTitle)"
    }
    
    // MARK: - Privacy Education & Background Location
    
    func dismissPrivacyEducation() {
        UserDefaults.standard.set(true, forKey: "hasSeenPrivacyEducation")
        showPrivacyEducation = false
        
        // Check if location permission was granted for background execution
        if locationManager.hasBackgroundLocationPermission {
            print("[Privacy] ✅ Background location enabled - app can sync lyrics for hours")
        } else {
            print("[Privacy] ⚠️ Background location not enabled - lyrics sync limited to ~30 seconds")
        }
    }
    
    var hasBackgroundLocationPermission: Bool {
        return locationManager.hasBackgroundLocationPermission
    }
    
    var locationPermissionStatus: String {
        return locationManager.permissionStatus
    }
    
    // MARK: - Cache Management
    
    /// Cleans up expired lyrics cache files (not accessed in 30 days)
    func cleanExpiredCache() {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let lyricsFolderURL = documentsURL.appendingPathComponent("Lyrics")
        
        guard FileManager.default.fileExists(atPath: lyricsFolderURL.path) else {
            return
        }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: lyricsFolderURL, includingPropertiesForKeys: [.contentModificationDateKey], options: [])
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            
            for fileURL in files {
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]),
                   let modificationDate = resourceValues.contentModificationDate,
                   modificationDate < cutoffDate {
                    try FileManager.default.removeItem(at: fileURL)
                    print("[Cache] 🗑️ Removed unused cache file (last accessed \(Calendar.current.dateComponents([.day], from: modificationDate, to: Date()).day ?? 0) days ago): \(fileURL.lastPathComponent)")
                }
            }
        } catch {
            print("[Cache] ⚠️ Error cleaning cache: \(error)")
        }
    }
}
