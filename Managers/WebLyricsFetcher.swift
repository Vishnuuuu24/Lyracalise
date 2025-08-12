import Foundation

/// The result of an LRCLIB lyric search.
enum LrclibResult {
    case synced([LyricEntry])
    case instrumental
    case notFound
}

/// A Codable struct to decode the JSON response from the lrclib.net API.
private struct LrclibResponse: Decodable {
    let plainLyrics: String?
    let syncedLyrics: String?
    let instrumental: Bool
}

// Represents a single song result from an LRCLIB search.
// We make it Codable to directly parse the JSON response.
struct LrclibSearchResult: Codable, Identifiable, Hashable {
    var id: Int
    var name: String // Track Name
    var artistName: String
    var albumName: String
    var duration: Double
    var instrumental: Bool
    
    // Conformance to Identifiable
    var anId: Int { id }
}

/// A utility class for fetching lyrics from the lrclib.net JSON API.
class WebLyricsFetcher {

    /// Searches the LRCLIB API for a given query.
    /// - Parameter query: The search term (e.g., "heartless madison beer").
    /// - Returns: An array of `LrclibSearchResult` objects.
    static func search(for query: String) async -> [LrclibSearchResult] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://lrclib.net/api/search?q=\(encodedQuery)") else {
            print("Failed to create a valid search URL.")
            return []
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            // The API returns a JSON array directly, so we decode it as such.
            let results = try JSONDecoder().decode([LrclibSearchResult].self, from: data)
            return results
        } catch {
            print("Failed to search or decode API response: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Fetches the raw LRC text for a specific search result ID.
    /// - Parameter id: The ID of the song from the search result.
    /// - Returns: The raw, synced `.lrc` string, or `nil` if not found.
    static func fetchLrcContent(for id: Int) async -> String? {
        guard let url = URL(string: "https://lrclib.net/api/get/\(id)") else { return nil }
        
        do {
            // This endpoint returns a JSON object that contains the lyrics.
            struct LrcContentResponse: Decodable {
                let syncedLyrics: String?
            }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(LrcContentResponse.self, from: data)
            return response.syncedLyrics
            
        } catch {
            print("Failed to fetch or parse LRC content: \(error.localizedDescription)")
            return nil
        }
    }

    /// A robust parser for LRC formatted text.
    static func parseLRC(_ lrc: String) -> [LyricEntry] {
        var result: [LyricEntry] = []
        let lines = lrc.components(separatedBy: .newlines)
        
        let timeTagRegex = try! NSRegularExpression(pattern: #"\[(.*?)\]"#)
        
        for line in lines {
            let lineRange = NSRange(line.startIndex..<line.endIndex, in: line)
            let matches = timeTagRegex.matches(in: line, options: [], range: lineRange)
            
            let lyricText = matches.last.map {
                let endOfTag = $0.range.upperBound
                if endOfTag < line.utf16.count {
                    return String(line[line.index(line.startIndex, offsetBy: endOfTag)...])
                }
                return ""
            } ?? line

            var hasTimestamp = false
            for match in matches {
                if let tagContentRange = Range(match.range(at: 1), in: line) {
                    let tagContent = String(line[tagContentRange])
                    
                    let timeParts = tagContent.components(separatedBy: CharacterSet(charactersIn: ":."))
                    if timeParts.count >= 2, let minutes = Double(timeParts[0]), let seconds = Double(timeParts[1]) {
                        let ms = timeParts.count > 2 ? (Double(timeParts[2]) ?? 0) : 0
                        let normalizedMs = ms / pow(10.0, Double(timeParts.count > 2 ? timeParts[2].count : 0))
                        let timestamp = (minutes * 60) + seconds + normalizedMs
                        
                        hasTimestamp = true
                        result.append((time: timestamp, line: lyricText.trimmingCharacters(in: .whitespacesAndNewlines)))
                    }
                }
            }
            if !hasTimestamp { continue }
        }
        return result.sorted { $0.time < $1.time }
    }
} 