import WidgetKit
import SwiftUI
import ActivityKit

@main
struct LyracaliseLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LyricAttributes.self) { context in
            VStack {
                Spacer(minLength: 0)
                Text(context.state.currentLyric)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.3)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                Spacer(minLength: 0)
            }
            .frame(height: 110)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.8), Color.black.opacity(0.9)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 6)
            )
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
                Text(context.state.currentLyric)
                    .font(.caption)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.trailing, 2)
            } minimal: {
                Image(systemName: "music.mic")
                    .foregroundColor(.white)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.white)
        }
    }
} 
