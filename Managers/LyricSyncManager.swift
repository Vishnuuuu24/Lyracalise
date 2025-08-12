import Foundation
import Combine
import ActivityKit
import MediaPlayer

class LyricSyncManager: ObservableObject {
    @Published var currentLine: String = "Lyrics will appear here..."
    @Published var nowPlayingTitle: String = ""
    @Published var nowPlayingArtist: String = ""
    @Published var statusMessage: String = ""
    private var timer: Timer?
    private var startTime: Date?
    private var lyrics: [LyricLine] = []
    private var index = 0
    private var activity: Activity<LyricAttributes>?
    private var nowPlayingTimer: Timer?
    private var lastNowPlayingTitle: String = ""
    private var lastNowPlayingArtist: String = ""
    @Published var manualSearchEnabled: Bool = false
    private var nowPlayingTimeoutTimer: Timer?

    var lyricsCount: Int {
        return lyrics.count
    }

    var fullLyricsText: String {
        return lyrics.map { $0.text }.joined(separator: "\n")
    }

    func loadLyrics() {
        // Placeholder lyrics
        lyrics = [
            LyricLine(timestamp: 0, text: "Just a small town girl"),
            LyricLine(timestamp: 5, text: "Living in a lonely world"),
            LyricLine(timestamp: 10, text: "She took the midnight train going anywhere")
        ]
    }

    func start() {
        index = 0
        startTime = Date()
        currentLine = lyrics.first?.text ?? ""
        updateLiveActivity(lyric: currentLine)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.updateLine()
        }
        startLiveActivity()
    }

    private func updateLine() {
        guard index < lyrics.count, let startTime = startTime else { return }
        let elapsed = Date().timeIntervalSince(startTime)
        if index + 1 < lyrics.count && elapsed >= lyrics[index + 1].timestamp {
            index += 1
            let newLine = lyrics[index].text
            if currentLine != newLine {
            currentLine = newLine
            updateLiveActivity(lyric: newLine)
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        stopLiveActivity()
        activity = nil
    }

    private func startLiveActivity() {
        // End any existing activity before starting a new one
        if let existingActivity = activity {
            Task {
                await existingActivity.end(nil, dismissalPolicy: .immediate)
            }
            activity = nil
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = LyricAttributes(songTitle: "Don't Stop Believin'", artist: "Journey")
        let initialState = LyricAttributes.ContentState(currentLyric: lyrics.first?.text ?? "", timestamp: Date())
        let initialContent = ActivityContent(state: initialState, staleDate: nil)

        activity = try? Activity<LyricAttributes>.request(
                attributes: attributes,
            content: initialContent,
                pushType: nil
            )
    }

    private func updateLiveActivity(lyric: String) {
        let state = LyricAttributes.ContentState(currentLyric: lyric, timestamp: Date())
        let content = ActivityContent(state: state, staleDate: nil)
        Task {
            await activity?.update(content)
        }
    }

    private func stopLiveActivity() {
        Task {
            await activity?.end(nil, dismissalPolicy: .immediate)
        }
    }

    func startNowPlayingObservation(timeout: TimeInterval = 8.0) {
        statusMessage = "Detecting current song..."
        manualSearchEnabled = false
        nowPlayingTimer?.invalidate()
        nowPlayingTimeoutTimer?.invalidate()
        nowPlayingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateNowPlayingInfo()
        }
        nowPlayingTimeoutTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if self.nowPlayingTitle.isEmpty {
                self.statusMessage = "Couldn't detect song. Please enter song and artist."
                self.manualSearchEnabled = true
            }
        }
        updateNowPlayingInfo()
    }

    private func updateNowPlayingInfo() {
        let info = MPNowPlayingInfoCenter.default().nowPlayingInfo
        print("NowPlayingInfo: \(info ?? [:])")
        let title = info?[MPMediaItemPropertyTitle] as? String ?? ""
        let artist = info?[MPMediaItemPropertyArtist] as? String ?? ""
        if title != lastNowPlayingTitle || artist != lastNowPlayingArtist {
            nowPlayingTitle = title
            nowPlayingArtist = artist
            lastNowPlayingTitle = title
            lastNowPlayingArtist = artist
            if !title.isEmpty {
                statusMessage = "Now playing: \(title) - \(artist)"
            } else {
                statusMessage = "No song detected."
            }
        }
    }

    /// Genius API fallback: fetch plain lyrics if no LRC is found
    func fetchPlainLyricsFromGenius(artist: String?, title: String) async {
        await MainActor.run { self.statusMessage = "Searching Genius for lyrics..." }
        let query = (artist != nil && !artist!.isEmpty) ? "\(artist!) \(title)" : title
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://api.genius.com/search?q=\(encodedQuery)"
        guard let url = URL(string: urlString) else {
            await MainActor.run { self.statusMessage = "Invalid Genius search URL." }
            return
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer c_Bq0bOcwTovw7vuYcDecpIkwcpOz9bu1_8PqSsj6-QHGyJh07uYVgGUQ1tTd8yn", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                await MainActor.run { self.statusMessage = "Genius API error." }
                return
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let response = json["response"] as? [String: Any],
                  let hits = response["hits"] as? [[String: Any]],
                  let firstHit = hits.first,
                  let result = firstHit["result"] as? [String: Any],
                  let songURL = result["url"] as? String else {
                await MainActor.run { self.statusMessage = "No Genius results found." }
                return
            }
            await MainActor.run { self.statusMessage = "Fetching lyrics from Genius page..." }
            if let lyrics = await Self.scrapeLyricsFromGeniusPage(urlString: songURL) {
                await MainActor.run {
                    self.statusMessage = "Plain lyrics loaded from Genius."
                    self.lyrics = [LyricLine(timestamp: 0, text: lyrics)]
                    self.start() // Start after loading plain lyrics
                }
            } else {
                await MainActor.run { self.statusMessage = "Failed to extract lyrics from Genius." }
            }
        } catch {
            await MainActor.run { self.statusMessage = "Genius API error: \(error.localizedDescription)" }
        }
    }

    /// Scrape lyrics from Genius song page (improved: only main lyrics, decode HTML entities, remove contributors)
    static func scrapeLyricsFromGeniusPage(urlString: String) async -> String? {
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else { return nil }

            // Genius lyrics are inside <div data-lyrics-container="true"> ... </div>
            // This regex finds all such containers and combines their content.
            let pattern = #"<div[^>]*data-lyrics-container=\"true\"[^>]*>([\s\S]*?)<\/div>"#
            let regex = try NSRegularExpression(pattern: pattern)
            let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
            let matches = regex.matches(in: html, options: [], range: nsRange)

            let htmlSnippets = matches.compactMap { match -> String? in
                if let range = Range(match.range(at: 1), in: html) {
                    return String(html[range])
                }
                return nil
            }
            
            guard !htmlSnippets.isEmpty else { return nil }
            
            let combinedHtml = htmlSnippets.joined()

            // Use the new robust decoding method
            if let decodedLyrics = Self.decodeHTMLEntities(from: combinedHtml) {
                // Filter out unwanted lines like [Chorus], [Verse], etc. and contributor info
                let finalLyrics = decodedLyrics
                    .components(separatedBy: .newlines)
                    .filter { line in
                        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                        // Remove section headers and contributor text
                        return !trimmedLine.hasPrefix("[") && !trimmedLine.hasSuffix("]") && !trimmedLine.lowercased().contains("contributors") && !trimmedLine.isEmpty
                    }
                    .joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                return finalLyrics.isEmpty ? nil : finalLyrics
            }

            return nil
        } catch {
            print("Error scraping lyrics: \(error)")
            return nil
        }
    }

    /// Decode HTML entities using NSAttributedString for robustness and simplicity.
    static func decodeHTMLEntities(from html: String) -> String? {
        guard let data = html.data(using: .utf8) else { return nil }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        if let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
            return attributedString.string
        }
        return nil
    }

    /// Improved: Try multiple LRC sources and filename patterns, flexible input
    func fetchAndParseLRCFromInput(_ input: String) async {
        let cleanedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        var artist: String? = nil
        var title: String = cleanedInput
        // Try to split input as "Artist - Title"
        let parts = cleanedInput.components(separatedBy: "-").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        if parts.count >= 2 {
            artist = parts[0]
            title = parts[1]
        }
        // Try different filename patterns
        var patterns: [String] = []
        if let artist = artist, !artist.isEmpty {
            patterns.append("\(artist) - \(title)")
            patterns.append("\(title) - \(artist)")
        }
        patterns.append(title) // Just the title
        // Try multiple sources
        let sources: [(String, (String) -> String)] = [
            ("GitHub LyricFind", { name in "https://raw.githubusercontent.com/lyricfind/lrc/master/\(name).lrc" }),
            ("lrcgc.com", { name in "https://lrcgc.com/download/\(name).lrc" }),
            ("lrc123.com", { name in "https://lrc123.com/lrc/\(name).lrc" })
        ]
        for pattern in patterns {
            let safePattern = pattern.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: " ", with: "%20")
            for (sourceName, urlBuilder) in sources {
                let urlString = urlBuilder(safePattern)
                await MainActor.run { self.statusMessage = "Trying \(sourceName): \(pattern)..." }
                guard let url = URL(string: urlString) else { continue }
                do {
                    let (data, response) = try await URLSession.shared.data(from: url)
                    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { continue }
                    guard let lrcText = String(data: data, encoding: .utf8) else { continue }
                    let parsed = Self.parseLRC(lrcText)
                    await MainActor.run {
                        if parsed.isEmpty {
                            self.statusMessage = "LRC found at \(sourceName) but no lyrics parsed." }
                        else {
                            self.statusMessage = "LRC loaded from \(sourceName)!"
                            self.lyrics = parsed
                            self.start() // Start after loading LRC
                        }
                    }
                    return // Stop after first successful fetch
                } catch {
                    // Try next source
                    continue
                }
            }
        }
        // If no LRC found, fallback to Genius
        await fetchPlainLyricsFromGenius(artist: artist, title: title)
    }

    /// Parse LRC text into [LyricLine]
    static func parseLRC(_ lrc: String) -> [LyricLine] {
        var result: [LyricLine] = []
        let lines = lrc.components(separatedBy: .newlines)
        let timeRegex = try! NSRegularExpression(pattern: "\\[(\\d{2}):(\\d{2})\\.(\\d{2,3})]", options: [])
        for line in lines {
            guard let match = timeRegex.firstMatch(in: line, options: [], range: NSRange(location: 0, length: line.utf16.count)) else { continue }
            let nsLine = line as NSString
            let min = Double(nsLine.substring(with: match.range(at: 1))) ?? 0
            let sec = Double(nsLine.substring(with: match.range(at: 2))) ?? 0
            let ms  = Double(nsLine.substring(with: match.range(at: 3))) ?? 0
            let timestamp = min * 60 + sec + ms / (ms > 99 ? 1000 : 100)
            let lyricText = nsLine.substring(from: match.range(at: 0).upperBound).trimmingCharacters(in: .whitespaces)
            if !lyricText.isEmpty {
                result.append(LyricLine(timestamp: timestamp, text: lyricText))
            }
        }
        return result.sorted { $0.timestamp < $1.timestamp }
    }

    // MARK: - Public helpers for UI
}
