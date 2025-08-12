import Foundation

struct LyricLine: Identifiable {
    let id = UUID()
    let timestamp: TimeInterval // seconds from start
    let text: String
}
