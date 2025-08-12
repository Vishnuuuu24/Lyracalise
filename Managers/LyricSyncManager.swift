import Foundation
import Combine
import ActivityKit
import MediaPlayer

// A type alias for a lyric line, making the code cleaner.
typealias LyricEntry = (time: TimeInterval, line: String)

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

    // Tracks the user's manual time override.
    @Published var manualSyncOffset: TimeInterval? = nil

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
    }

    func stopSyncing() {
        syncTimer?.invalidate()
        syncTimer = nil
    }

    private func updateLyricForCurrentTime() {
        guard !loadedLyrics.isEmpty else { return }

        // Determine the current playback time, prioritizing manual offset.
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
        if let manualOffset = manualSyncOffset, let startTime = manualSyncStartTime {
            // If user tapped a line, calculate time from that point.
            return manualOffset + Date().timeIntervalSince(startTime)
        } else if let info = MPNowPlayingInfoCenter.default().nowPlayingInfo,
                  let elapsed = info[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? TimeInterval {
            // Otherwise, use the official playback time.
            return elapsed
        }
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
        let title = info?[MPMediaItemPropertyTitle] as? String ?? ""
        let artist = info?[MPMediaItemPropertyArtist] as? String ?? ""

        if title != lastNowPlayingTitle || artist != lastNowPlayingArtist {
            // A song was detected, so cancel the timeout timer.
            self.nowPlayingTimeoutTimer?.invalidate()
            
            lastNowPlayingTitle = title
            lastNowPlayingArtist = artist

            DispatchQueue.main.async {
                self.nowPlayingTitle = title
                self.nowPlayingArtist = artist
                self.loadLyricsForCurrentSong()
            }
        }
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
            self.nowPlayingArtist = artist
            self.nowPlayingTitle = title
            self.staticLyrics = nil // Clear previous static lyrics
            self.loadedLyrics = [] // Clear previous synced lyrics
            self.loadLyricsForCurrentSong()
        }
    }

    // MARK: - Local LRC File Handling
    
    /// Looks for a local .lrc file matching the current song and loads it.
    func loadLyricsForCurrentSong() {
        let filename = filenameFor(title: nowPlayingTitle, artist: nowPlayingArtist)
        
        // Look for the file in the main app bundle.
        // Assumes a "Lyrics" folder exists.
        if let path = Bundle.main.path(forResource: filename, ofType: "lrc", inDirectory: "Lyrics") {
            let parsedLyrics = Self.parseLRC(from: path)
            DispatchQueue.main.async {
                self.loadedLyrics = parsedLyrics
                self.statusMessage = parsedLyrics.isEmpty ? "Found LRC file, but it's empty." : "Lyrics loaded from local file."
                self.startSyncing()
                self.startLiveActivity()
            }
        } else {
            // No local file found, so try our powerful online search.
            Task {
                await MainActor.run { self.statusMessage = "No local file found. Searching online..." }
                
                if let result = await WebLyricsFetcher.findLyricsOnline(artist: nowPlayingArtist, title: nowPlayingTitle) {
                    switch result {
                    case .synced(let syncedLyrics):
                        // We found a perfect, pre-synced .lrc file online.
                        await MainActor.run {
                            self.loadedLyrics = syncedLyrics
                            self.statusMessage = "Synced lyrics found online!"
                            self.startSyncing()
                            self.startLiveActivity()
                        }
                    case .plain(let plainLyrics):
                        // We found plain text. Check if we can auto-sync it.
                        if let duration = MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyPlaybackDuration] as? TimeInterval, duration > 0 {
                            // Duration is available, so generate sync.
                            await MainActor.run { self.statusMessage = "Found plain lyrics. Generating sync..." }
                            let generatedLyrics = self.generateSyncedLyrics(from: plainLyrics, duration: duration)
                            
                            await MainActor.run {
                                self.loadedLyrics = generatedLyrics
                                self.staticLyrics = nil
                                self.statusMessage = "Auto-sync enabled for this track."
                                self.startSyncing()
                                self.startLiveActivity()
                            }
                        } else {
                            // No duration available, so just display the static text.
                            await MainActor.run {
                                self.loadedLyrics = []
                                self.staticLyrics = plainLyrics
                                self.statusMessage = "Displaying unsynced lyrics."
                                self.stopSyncing()
                                self.stopLiveActivity()
                            }
                        }
                    }
                } else {
                    // All online sources failed.
                    await MainActor.run {
                        self.statusMessage = "Could not find any lyrics online for this song."
                        self.loadedLyrics = []
                        self.stopSyncing()
                        self.stopLiveActivity()
                    }
                }
            }
        }
    }

    /// Generates timed lyrics from plain text using a word-count weighted distribution.
    func generateSyncedLyrics(from plainText: String, duration: TimeInterval) -> [LyricEntry] {
        let lines = plainText.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard !lines.isEmpty else { return [] }

        // Calculate the total number of words across all lines.
        let totalWords = lines.map { $0.split(separator: " ").count }.reduce(0, +)
        guard totalWords > 0 else { return [] }
        
        var cumulativeTime: TimeInterval = 0
        var syncedLyrics: [LyricEntry] = []

        for line in lines {
            let wordCount = line.split(separator: " ").count
            // The time allocated to this line is proportional to its word count.
            let timeSlice = (duration * Double(wordCount)) / Double(totalWords)
            
            // Add a small buffer at the beginning of the song.
            let timestamp = syncedLyrics.isEmpty ? 1.5 : cumulativeTime
            
            syncedLyrics.append((time: timestamp, line: line))
            
            cumulativeTime += timeSlice
        }
        
        return syncedLyrics
    }

    /// Parses an LRC file from a given file path.
    static func parseLRC(from path: String) -> [LyricEntry] {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }
        var result: [LyricEntry] = []
        let lines = content.components(separatedBy: .newlines)
        
        // Regex to capture [mm:ss.xx] timestamps.
        let pattern = #"\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)"#
        let regex = try! NSRegularExpression(pattern: pattern)

        for line in lines {
            let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
            if let match = regex.firstMatch(in: line, options: [], range: nsRange) {
                let nsLine = line as NSString
                let minutes = Double(nsLine.substring(with: match.range(at: 1))) ?? 0
                let seconds = Double(nsLine.substring(with: match.range(at: 2))) ?? 0
                let milliseconds = Double(nsLine.substring(with: match.range(at: 3))) ?? 0
                let time = (minutes * 60) + seconds + (milliseconds / 100.0)
                
                let textRange = match.range(at: 4)
                let text = nsLine.substring(with: textRange).trimmingCharacters(in: .whitespaces)

                if !text.isEmpty {
                    result.append((time: time, line: text))
                }
            }
        }
        return result.sorted { $0.time < $1.time }
    }

    // MARK: - Live Activity

    private func startLiveActivity() {
        // End any existing activity first.
        Task { await activity?.end(nil, dismissalPolicy: .immediate) }
        activity = nil
        
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

    private func updateLiveActivity(lyric: String) {
        let state = LyricAttributes.ContentState(currentLyric: lyric, timestamp: Date())
        Task {
            await activity?.update(.init(state: state, staleDate: nil))
        }
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
}
