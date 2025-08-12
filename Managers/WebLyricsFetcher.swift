import Foundation

/// The result of an online lyric search, which can either be a perfectly synced LRC file
/// or plain, unsynced text that needs its timings generated.
enum OnlineLyricResult {
    case synced([LyricEntry])
    case plain(String)
}

/// A utility class for fetching lyrics from various web sources.
/// This combines multi-source LRC searching with a Genius API fallback.
class WebLyricsFetcher {

    /// The primary public method. It orchestrates a multi-step search for lyrics online.
    /// - Returns: An `OnlineLyricResult` enum case, or `nil` if nothing is found.
    static func findLyricsOnline(artist: String, title: String) async -> OnlineLyricResult? {
        // Step 1: Try to find a pre-synced .lrc file from multiple web sources.
        if let syncedLyrics = await findSyncedLRC(artist: artist, title: title) {
            return .synced(syncedLyrics)
        }
        
        // Step 2: If no .lrc file is found, fall back to fetching plain text from Genius.
        if let plainLyrics = await fetchPlainLyricsFromGenius(artist: artist, title: title) {
            return .plain(plainLyrics)
        }
        
        // If all sources fail, return nil.
        return nil
    }

    // MARK: - Private Helper Methods

    /// Searches multiple online databases for a downloadable .lrc file.
    private static func findSyncedLRC(artist: String, title: String) async -> [LyricEntry]? {
        let searchArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        let searchTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Tier 1: LRCLIB.NET API - High quality source
        if let lyrics = await searchLrclibNet(artist: searchArtist, title: searchTitle) {
            return lyrics
        }
        
        // Tier 2 & 3: Unofficial APIs for NetEase and QQMusic
        if let lyrics = await searchNetEase(title: searchTitle) {
            return lyrics
        }
        if let lyrics = await searchQQMusic(title: searchTitle) {
            return lyrics
        }
        
        // Tier 4: The other file-based sources.
        // This logic is now smarter and avoids creating malformed patterns.
        var patterns: [String] = [searchTitle] // Always search by title alone.
        if !searchArtist.isEmpty {
            // Only create artist-based patterns if an artist is present.
            patterns.insert("\(searchArtist) - \(searchTitle)", at: 0)
            patterns.insert("\(searchTitle) - \(searchArtist)", at: 1)
        }

        let sources: [(String) -> String] = [
            { name in "https://raw.githubusercontent.com/lyricfind/lrc/master/\(name).lrc" },
            { name in "https://lrc-service.g-core.com/lrc/\(name)" }
        ]

        for pattern in patterns {
            guard let safePattern = pattern.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { continue }
            for urlBuilder in sources {
                if let lyrics = await fetchAndParseLRC(from: urlBuilder(safePattern)) {
                    return lyrics
                }
            }
        }
        
        return nil // No LRC found from any source.
    }
    
    // Helper to fetch and parse from a single URL
    private static func fetchAndParseLRC(from urlString: String) async -> [LyricEntry]? {
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
               let lrcText = String(data: data, encoding: .utf8) {
                let parsed = parseLRC(lrcText)
                if !parsed.isEmpty {
                    print("Successfully fetched LRC from: \(url)")
                    return parsed
                }
            }
        } catch { }
        return nil
    }

    // MARK: - API-Specific Search Functions
    
    private static func searchLrclibNet(artist: String, title: String) async -> [LyricEntry]? {
        var components = URLComponents(string: "https://lrclib.net/api/get")!
        components.queryItems = [
            URLQueryItem(name: "artist_name", value: artist),
            URLQueryItem(name: "track_name", value: title)
        ]
        guard let url = components.url else { return nil }
        
        if let lrcText = await fetchContent(from: url) {
            // lrclib.net returns JSON, we need to decode it and get the syncedLyrics field
            struct LrcLibResponse: Decodable {
                let syncedLyrics: String?
            }
            if let jsonData = lrcText.data(using: .utf8),
               let response = try? JSONDecoder().decode(LrcLibResponse.self, from: jsonData),
               let synced = response.syncedLyrics {
                return parseLRC(synced)
            }
        }
        return nil
    }
    
    private static func searchNetEase(title: String) async -> [LyricEntry]? {
        let urlString = "https://music.163.com/api/search/pc?s=\(title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&type=1"
        guard let searchURL = URL(string: urlString) else { return nil }
        
        // This is a simplified search; a more robust client would handle multiple results.
        // For now, we take the first result's ID.
        if let searchData = await fetchContent(from: searchURL)?.data(using: .utf8) {
            if let json = try? JSONSerialization.jsonObject(with: searchData) as? [String: Any],
               let result = json["result"] as? [String: Any],
               let songs = result["songs"] as? [[String: Any]],
               let firstSongID = songs.first?["id"] as? Int {
                
                let lyricURL = URL(string: "https://music.163.com/api/song/lyric?id=\(firstSongID)&lv=1&kv=1&tv=-1")!
                if let lyricData = await fetchContent(from: lyricURL)?.data(using: .utf8) {
                    if let lyricJson = try? JSONSerialization.jsonObject(with: lyricData) as? [String: Any],
                       let lrc = lyricJson["lrc"] as? [String: Any],
                       let lyricString = lrc["lyric"] as? String {
                        return parseLRC(lyricString)
                    }
                }
            }
        }
        return nil
    }
    
    private static func searchQQMusic(title: String) async -> [LyricEntry]? {
        // QQ Music API is often more complex and may require keys. This is a placeholder for a common endpoint structure.
        // A full implementation would require more research into the latest working, unauthenticated endpoints.
        return nil // Placeholder
    }
    
    private static func fetchContent(from url: URL) async -> String? {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                return String(data: data, encoding: .utf8)
            }
        } catch { }
        return nil
    }

    /// Fetches plain (unsynced) lyrics for a given song from the Genius API.
    private static func fetchPlainLyricsFromGenius(artist: String, title: String) async -> String? {
        let query = "\(artist) \(title)"
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.genius.com/search?q=\(encodedQuery)") else {
            return nil
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer c_Bq0bOcwTovw7vuYcDecpIkwcpOz9bu1_8PqSsj6-QHGyJh07uYVgGUQ1tTd8yn", forHTTPHeaderField: "Authorization")
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let responseDict = json["response"] as? [String: Any],
                  let hits = responseDict["hits"] as? [[String: Any]],
                  let firstHit = hits.first,
                  let result = firstHit["result"] as? [String: Any],
                  let songURLString = result["url"] as? String else {
                return nil
            }
            return await scrapeLyricsFromGeniusPage(urlString: songURLString)
        } catch {
            return nil
        }
    }

    /// Scrapes the song lyrics from a Genius.com HTML page.
    private static func scrapeLyricsFromGeniusPage(urlString: String) async -> String? {
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else { return nil }
            let pattern = #"<div[^>]*data-lyrics-container=\"true\"[^>]*>([\s\S]*?)<\/div>"#
            let regex = try NSRegularExpression(pattern: pattern)
            let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
            let matches = regex.matches(in: html, options: [], range: nsRange)
            let htmlSnippets = matches.compactMap { Range($0.range(at: 1), in: html) }.map { String(html[$0]) }
            guard !htmlSnippets.isEmpty else { return nil }
            if let decodedLyrics = decodeHTMLEntities(from: htmlSnippets.joined()) {
                let finalLyrics = decodedLyrics
                    .components(separatedBy: .newlines)
                    .filter { line in
                        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                        return !trimmedLine.isEmpty && !trimmedLine.hasPrefix("[") && !trimmedLine.hasSuffix("]")
                    }
                    .joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return finalLyrics.isEmpty ? nil : finalLyrics
            }
            return nil
        } catch {
            return nil
        }
    }

    /// Decodes HTML entities (e.g., &#39;) into their proper characters (e.g., ').
    private static func decodeHTMLEntities(from html: String) -> String? {
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
    
    /// Parses LRC formatted text into an array of timed lyric entries.
    private static func parseLRC(_ lrc: String) -> [LyricEntry] {
        var result: [LyricEntry] = []
        let lines = lrc.components(separatedBy: .newlines)
        let timeRegex = try! NSRegularExpression(pattern: #"\[(\d{2}):(\d{2})\.(\d{2,3})\]"#)
        for line in lines {
            let matches = timeRegex.matches(in: line, range: NSRange(line.startIndex..., in: line))
            guard !matches.isEmpty else { continue }
            
            let nsLine = line as NSString
            let lyricText = nsLine.substring(from: matches.last!.range.upperBound).trimmingCharacters(in: .whitespaces)
            guard !lyricText.isEmpty else { continue }

            for match in matches {
                let min = Double(nsLine.substring(with: match.range(at: 1))) ?? 0
                let sec = Double(nsLine.substring(with: match.range(at: 2))) ?? 0
                let ms = Double(nsLine.substring(with: match.range(at: 3))) ?? 0
                let timestamp = min * 60 + sec + ms / (pow(10, Double(nsLine.substring(with: match.range(at: 3)).count)))
                result.append((time: timestamp, line: lyricText))
            }
        }
        return result.sorted { $0.time < $1.time }
    }
} 