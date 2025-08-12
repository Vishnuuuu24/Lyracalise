//
//  LyricEntry.swift
//  Lyracalise
//
//  Created by Vishnu Vardhan on 27/6/25.
//


import WidgetKit
import SwiftUI

struct LyricEntry: TimelineEntry {
    let date: Date
    let lyric: String
    let songTitle: String
    let artist: String
}

struct LyricProvider: TimelineProvider {
    func placeholder(in context: Context) -> LyricEntry {
        LyricEntry(date: Date(), lyric: "Sample lyric line", songTitle: "Sample Song", artist: "Sample Artist")
    }
    func getSnapshot(in context: Context, completion: @escaping (LyricEntry) -> ()) {
        completion(placeholder(in: context))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<LyricEntry>) -> ()) {
        let sharedDefaults = UserDefaults(suiteName: "group.com.vishnu.lyracalise")
        let lyric = sharedDefaults?.string(forKey: "currentLyric") ?? "No lyric"
        let songTitle = sharedDefaults?.string(forKey: "songTitle") ?? "No song"
        let artist = sharedDefaults?.string(forKey: "artist") ?? "No artist"
        let entry = LyricEntry(date: Date(), lyric: lyric, songTitle: songTitle, artist: artist)
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

struct LyricWidgetView: View {
    var entry: LyricEntry
    var body: some View {
        ZStack {
            VStack {
                Spacer(minLength: 0)
                Text(entry.lyric)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.3)
                    .allowsTightening(true)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
                HStack {
                    Text(entry.songTitle)
                        .font(.footnote)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.4), radius: 1, x: 0, y: 1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.3)
                        .allowsTightening(true)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(entry.artist)
                        .font(.footnote)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.4), radius: 1, x: 0, y: 1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.3)
                        .allowsTightening(true)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding([.horizontal, .bottom], 4)
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}

@main
struct LyracaliseLyricWidget: Widget {
    let kind: String = "lyric_widget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LyricProvider()) { entry in
            LyricWidgetView(entry: entry)
        }
        .supportedFamilies([.systemMedium, .systemLarge])
        .configurationDisplayName("Current Lyric")
        .description("Shows the current lyric line for the playing song.")
    }
}