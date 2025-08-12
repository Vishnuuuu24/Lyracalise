import Foundation
import Combine
import ActivityKit
import MediaPlayer
import WidgetKit

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

class LyricSyncManager: ObservableObject {
    // MARK: - Published Properties for UI
    @Published var nowPlayingTitle: String = ""
    @Published var nowPlayingArtist: String = ""
    @Published var statusMessage: String = "Waiting for a song to play..."
    @Published var manualSearchEnabled: Bool = false
    
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
    
    // MARK: - Private Properties
    private var syncTimer: Timer?
    private var nowPlayingTimer: Timer?
    private var nowPlayingTimeoutTimer: Timer?
    private var lastNowPlayingTitle: String = ""
    private var lastNowPlayingArtist: String = ""
    private var activity: Activity<LyricAttributes>?

    init() {
        startNowPlayingObservation()
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
        guard !loadedLyrics.isEmpty else { return }

        // Determine the current playback time, prioritizing manual offset,
        // then real player time, then our simulated time.
        let currentPlaybackTime = getCurrentPlaybackTime()

        // Find the most recent lyric line that should be active.
        let newIndex = loadedLyrics.lastIndex(where: { $0.time <= currentPlaybackTime })

        if newIndex != self.currentLineIndex {
            DispatchQueue.main.async {
                self.currentLineIndex = newIndex
                if let newIndex = newIndex {
                    let newLine = self.loadedLyrics[newIndex].line
                    if self.currentLine != newLine {
                        self.currentLine = newLine
                        self.updateLiveActivity(lyric: newLine)
                    }
                }
            }
        }
    }
    
    private func getCurrentPlaybackTime() -> TimeInterval {
        // 1. Manual sync override is the top priority.
        if let manualOffset = manualSyncOffset, let startTime = manualSyncStartTime {
            return manualOffset + Date().timeIntervalSince(startTime)
        }
        
        // 2. Check for a valid, progressing playback time from the system.
        if let info = MPNowPlayingInfoCenter.default().nowPlayingInfo,
           let elapsed = info[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? TimeInterval,
           elapsed > 0 {
            // Real time is working, so ensure we are not in simulated mode.
            if self.simulatedPlaybackStartTime != nil {
                DispatchQueue.main.async { self.simulatedPlaybackStartTime = nil }
            }
            return elapsed
        }
        
        // 3. If system time fails, use our internal simulated timer if it's active.
        if let simulatedStart = simulatedPlaybackStartTime {
            return Date().timeIntervalSince(simulatedStart)
        }
        
        // 4. Default to 0 if no time source is available.
        return 0
    }
    
    private var manualSyncStartTime: Date?
    func resync(to time: TimeInterval, at index: Int) {
        DispatchQueue.main.async {
            self.manualSyncOffset = time
            self.manualSyncStartTime = Date() // Record the moment of the tap
            self.currentLineIndex = index
            self.currentLine = self.loadedLyrics[index].line
            self.updateLiveActivity(lyric: self.currentLine)
        }
    }

    func resumeAutoSync() {
        manualSyncOffset = nil
        manualSyncStartTime = nil
        // Also disable simulated playback when resuming auto-sync.
        // The app will now try to use the real player time again.
        simulatedPlaybackStartTime = nil
    }

    // MARK: - Now Playing Observation
    
    func startNowPlayingObservation(timeout: TimeInterval = 8.0) {
        nowPlayingTimer?.invalidate()
        nowPlayingTimeoutTimer?.invalidate()
        
        nowPlayingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateNowPlayingInfo()
        }
        
        // If no song is detected after the timeout, enable manual search.
        nowPlayingTimeoutTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if self.nowPlayingTitle.isEmpty {
                DispatchQueue.main.async {
                    self.statusMessage = "Automatic detection failed. Please search manually."
                    self.manualSearchEnabled = true
                }
            }
        }
    }

    private func updateNowPlayingInfo() {
        let info = MPNowPlayingInfoCenter.default().nowPlayingInfo
        let title = info?[MPNowPlayingInfoPropertyTitle] as? String ?? ""
        let artist = info?[MPNowPlayingInfoPropertyArtist] as? String ?? ""

        if title != lastNowPlayingTitle || artist != lastNowPlayingArtist {
            // A song was detected, so cancel the timeout timer.
            self.nowPlayingTimeoutTimer?.invalidate()
            
            lastNowPlayingTitle = title
            lastNowPlayingArtist = artist

            DispatchQueue.main.async {
                self.resetStateForNewSong()
                self.nowPlayingTitle = title
                self.nowPlayingArtist = artist
                self.loadLyricsForCurrentSong()
            }
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
        stopLiveActivity() // Ensure any previous live activity is ended
    }

    /// Allows the user to manually trigger a lyric search, with improved parsing.
    func manualSearch(for query: String) {
        let cleanedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = cleanedQuery.components(separatedBy: "-").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        let artist = parts.count > 1 ? parts[0] : ""
        let title = parts.count > 1 ? parts.dropFirst().joined(separator: "-").trimmingCharacters(in: .whitespacesAndNewlines) : cleanedQuery
        
        // Prevent empty searches
        guard !title.isEmpty else {
            self.statusMessage = "Please enter a song title."
            return
        }
        
        DispatchQueue.main.async {
            self.resetStateForNewSong()
            self.nowPlayingArtist = artist
            self.nowPlayingTitle = title
            self.loadLyricsForCurrentSong()
        }
    }

    // MARK: - Local LRC File Handling
    
    /// Looks for a local .lrc file matching the current song and loads it.
    func loadLyricsForCurrentSong() {
        let filename = filenameFor(title: nowPlayingTitle, artist: nowPlayingArtist)

        // Priority 1: Check the user's Documents directory for a saved file.
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let lyricsFolderURL = documentsURL.appendingPathComponent("Lyrics")
            let fileURL = lyricsFolderURL.appendingPathComponent("\(filename).lrc")

            if FileManager.default.fileExists(atPath: fileURL.path),
               let lrcContent = try? String(contentsOf: fileURL) {
                let parsedLyrics = WebLyricsFetcher.parseLRC(lrcContent)
                DispatchQueue.main.async {
                    self.loadedLyrics = parsedLyrics
                    self.statusMessage = "Lyrics loaded from local file."
                    self.startSyncing()
                    self.startLiveActivity()
                }
                return // Found it, so we're done.
            }
        }

        // Priority 2: If no local file, perform a web search.
        let query = "\(nowPlayingArtist) \(nowPlayingTitle)"
        Task {
            await MainActor.run { self.statusMessage = "No local file found. Searching online..." }
            let results = await WebLyricsFetcher.search(for: query)
            await MainActor.run {
                if results.isEmpty {
                    self.statusMessage = "No results found for '\(query)'."
                    self.autoSelectedFirstResult = false
                } else if results.count == 1 {
                    self.autoSelectedFirstResult = false
                    self.selectSearchResult(results.first!)
                } else {
                    // If there are multiple results, auto-select the first one
                    self.autoSelectedFirstResult = true
                    self.tryAutoSelectFirstResult(results: results)
                }
            }
        }
    }
    
    /// Called when a user selects a specific version from the search results list.
    func selectSearchResult(_ result: LrclibSearchResult) {
        self.isShowingSearchResults = false
        self.statusMessage = "Fetching lyrics..."
        
        Task {
            if let lrcContent = await WebLyricsFetcher.fetchLrcContent(for: result.id) {
                let parsedLyrics = WebLyricsFetcher.parseLRC(lrcContent)
                
                await MainActor.run {
                    // Update the main properties with the canonical data from the user's choice.
                    self.nowPlayingTitle = result.name
                    self.nowPlayingArtist = result.artistName
                    
                    self.loadedLyrics = parsedLyrics
                    self.statusMessage = "Lyrics loaded!"
                    
                    if MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? TimeInterval ?? 0 <= 0 {
                        self.simulatedPlaybackStartTime = Date()
                        self.statusMessage = "Starting from beginning. Tap a line to sync."
                    }
                    
                    self.startSyncing()
                    self.startLiveActivity()
                    
                    // Now, this save will use the same canonical name that will be used for future lookups.
                    self.saveLyricsToFile(lyrics: parsedLyrics, for: result.name, artist: result.artistName)
        }
            } else {
                await MainActor.run {
                    self.statusMessage = "Failed to fetch lyric content."
                }
            }
        }
    }

    // Try to auto-select the first result, fallback to manual selection if it fails
    private func tryAutoSelectFirstResult(results: [LrclibSearchResult]) {
        self.isShowingSearchResults = false
        self.statusMessage = "Fetching lyrics..."
        let firstResult = results.first!
        Task {
            if let lrcContent = await WebLyricsFetcher.fetchLrcContent(for: firstResult.id) {
                let parsedLyrics = WebLyricsFetcher.parseLRC(lrcContent)
                await MainActor.run {
                    self.nowPlayingTitle = firstResult.name
                    self.nowPlayingArtist = firstResult.artistName
                    self.loadedLyrics = parsedLyrics
                    self.statusMessage = "Lyrics loaded!"
                    if MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? TimeInterval ?? 0 <= 0 {
                        self.simulatedPlaybackStartTime = Date()
                        self.statusMessage = "Starting from beginning. Tap a line to sync."
                    }
                    self.startSyncing()
                    self.startLiveActivity()
                    self.saveLyricsToFile(lyrics: parsedLyrics, for: firstResult.name, artist: firstResult.artistName)
                }
            } else {
                // If fetching/parsing fails, show the search results for manual selection
                await MainActor.run {
                    self.searchResults = results
                    self.isShowingSearchResults = true
                    self.statusMessage = "Auto-selection failed. Please select the correct version."
                    self.autoSelectedFirstResult = false
                }
            }
        }
    }

    private func saveLyricsToFile(lyrics: [LyricEntry], for title: String, artist: String) {
        let fileName = filenameFor(title: title, artist: artist)
        // Use the app's documents directory, which is the correct place for user-generated content.
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Could not access the documents directory.")
            return
        }
        
        let lyricsDirectory = documentsDirectory.appendingPathComponent("Lyrics", isDirectory: true)
        
        // Ensure the "Lyrics" subdirectory exists.
        if !FileManager.default.fileExists(atPath: lyricsDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: lyricsDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Failed to create Lyrics directory: \(error)")
                return
            }
        }
        
        let fileURL = lyricsDirectory.appendingPathComponent("\(fileName).lrc")
        
        // Prevent overwriting existing files.
        if FileManager.default.fileExists(atPath: fileURL.path) {
            print("Lyric file already exists for '\(fileName)'. Skipping save.")
            return
        }
        
        // Convert the structured lyric data back into a standard LRC string.
        let lrcContent = lyrics.map { entry in
            let minutes = Int(entry.time) / 60
            let seconds = Int(entry.time) % 60
            let milliseconds = Int((entry.time.truncatingRemainder(dividingBy: 1)) * 100)
            return String(format: "[%02d:%02d.%02d]%@", minutes, seconds, milliseconds, entry.line)
        }.joined(separator: "\n")
        
        // Write the content to the specified file.
        do {
            try lrcContent.write(to: fileURL, atomically: true, encoding: .utf8)
            print("Successfully saved lyrics to: \(fileURL.path)")
        } catch {
            print("Failed to write lyrics file: \(error)")
        }
    }

    /// Parses an LRC file from a given file path.
    static func parseLRC(from path: String) -> [LyricEntry] {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }
        // We can reuse the robust parser from the web fetcher.
        return WebLyricsFetcher.parseLRC(content)
    }

    // MARK: - Live Activity

    private func startLiveActivity() {
        // End any existing activity first.
        Task {
            if let currentActivity = activity {
                await currentActivity.end(nil, dismissalPolicy: .immediate)
                activity = nil // Only set to nil after ending
            }
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

            let attributes = LyricAttributes(songTitle: nowPlayingTitle, artist: nowPlayingArtist)
            let initialState = LyricAttributes.ContentState(currentLyric: currentLine, timestamp: Date())

            do {
                activity = try Activity<LyricAttributes>.request(
                    attributes: attributes,
                    content: .init(state: initialState, staleDate: nil)
                )
            } catch {
                print("Error requesting Live Activity: \(error.localizedDescription)")
            }
        }
    }

    private func updateLiveActivity(lyric: String) {
        let state = LyricAttributes.ContentState(currentLyric: lyric, timestamp: Date())
        Task {
            await activity?.update(.init(state: state, staleDate: nil))
        }
        // Also update widget data
        updateWidgetSharedData()
    }

    private func stopLiveActivity() {
        Task {
            await activity?.end(nil, dismissalPolicy: .immediate)
        }
    }

    /// Generates a clean filename from song metadata.
    private func filenameFor(title: String?, artist: String?) -> String {
        let cleanTitle = title?.replacingOccurrences(of: "[^a-zA-Z0-9 ]", with: "", options: .regularExpression) ?? ""
        let cleanArtist = artist?.replacingOccurrences(of: "[^a-zA-Z0-9 ]", with: "", options: .regularExpression) ?? ""
        // Return only the base filename, not the extension.
        return "\(cleanArtist) - \(cleanTitle)"
    }

    // Helper to write current lyric info to App Group UserDefaults
    private func updateWidgetSharedData() {
        if let sharedDefaults = UserDefaults(suiteName: "group.com.vishnu.lyracalise") {
            sharedDefaults.set(currentLine, forKey: "currentLyric")
            sharedDefaults.set(nowPlayingTitle, forKey: "songTitle")
            sharedDefaults.set(nowPlayingArtist, forKey: "artist")
            sharedDefaults.synchronize()
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
