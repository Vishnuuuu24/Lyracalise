import Foundation
import Combine
import ActivityKit

class LyricSyncManager: ObservableObject {
    @Published var currentLine: String = "Lyrics will appear here..."
    private var timer: Timer?
    private var startTime: Date?
    private var lyrics: [LyricLine] = []
    private var index = 0
    private var activity: Activity<LyricAttributes>?

    func loadLyrics() {
        // Placeholder lyrics
        lyrics = [
            LyricLine(timestamp: 0, text: "Just a small town girl"),
            LyricLine(timestamp: 5, text: "Living in a lonely world"),
            LyricLine(timestamp: 10, text: "She took the midnight train going anywhere")
        ]
        startLiveActivity()
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
                await existingActivity.end(dismissalPolicy: .immediate)
            }
            activity = nil
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = LyricAttributes(songTitle: "Don't Stop Believin'", artist: "Journey")
        let initialState = LyricAttributes.ContentState(currentLyric: lyrics.first?.text ?? "", timestamp: Date())

        do {
            activity = try Activity<LyricAttributes>.request(
                attributes: attributes,
                contentState: initialState,
                pushType: nil
            )
        } catch (let error) {
            print("Error requesting Live Activity: \(error.localizedDescription)")
        }
    }

    private func updateLiveActivity(lyric: String) {
        let state = LyricAttributes.ContentState(currentLyric: lyric, timestamp: Date())
        Task {
            await activity?.update(using: state)
        }
    }

    private func stopLiveActivity() {
        Task {
            await activity?.end(dismissalPolicy: .immediate)
        }
    }
}
