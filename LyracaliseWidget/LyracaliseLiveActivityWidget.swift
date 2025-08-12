import WidgetKit
import SwiftUI
import ActivityKit



// MARK: - Main Widget
@main
struct LyracaliseLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        // Live Activity
        ActivityConfiguration(for: LyricAttributes.self) { context in
            let showAppName = (context.state.currentLyric.isEmpty || context.state.currentLyric == "No lyric") && (context.attributes.songTitle.isEmpty || context.attributes.songTitle == "No song") && (context.attributes.artist.isEmpty || context.attributes.artist == "No artist")
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
                    Text(context.state.currentLyric)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .padding(.vertical, 4)
                }
            } compactLeading: {
                Image(systemName: "music.mic")
                    .foregroundColor(.white)
            } compactTrailing: {
                EmptyView()
            } minimal: {
                Image(systemName: "music.mic")
                    .foregroundColor(.white)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.white)
        }
    }
} 
