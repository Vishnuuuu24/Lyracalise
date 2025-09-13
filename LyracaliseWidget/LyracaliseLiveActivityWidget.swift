import WidgetKit
import SwiftUI
import ActivityKit



// MARK: - Main Widget
@main
struct LyracaliseLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        // Live Activity
        ActivityConfiguration(for: LyricAttributes.self) { context in
            let showAppName = (context.state.currentLyric.isEmpty || context.state.currentLyric == "No lyric") && (context.state.songTitle.isEmpty || context.state.songTitle == "No song") && (context.state.artist.isEmpty || context.state.artist == "No artist")
            VStack {
                Spacer(minLength: 0)
                if showAppName {
                    Text("Lyracalise")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else if !context.state.currentLyric.isEmpty && context.state.currentLyric != "No lyric" {
                Text(context.state.currentLyric)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.3)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    // Show nothing during lyric gaps
                    Text("")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                Spacer(minLength: 0)
            }
            .frame(height: 110)
            .containerBackground(for: .widget) { Color.clear }
            .activityBackgroundTint(Color.clear)
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 4) {
                        Text(context.state.songTitle)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(context.state.artist)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                    .padding(.vertical, 4)
                }
            } compactLeading: {
                Image(systemName: "music.mic")
                    .foregroundColor(.white)
            } compactTrailing: {
                Image(systemName: "music.note")
                    .foregroundColor(.white)
            } minimal: {
                Image(systemName: "music.mic")
                    .foregroundColor(.white)
            }
            .widgetURL(nil)
            .keylineTint(Color.white)
        }
    }
} 
