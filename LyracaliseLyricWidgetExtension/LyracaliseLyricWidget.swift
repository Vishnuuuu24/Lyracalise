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
        let lyric = sharedDefaults?.string(forKey: "currentLyric") ?? ""
        let songTitle = sharedDefaults?.string(forKey: "songTitle") ?? ""
        let artist = sharedDefaults?.string(forKey: "artist") ?? ""
        let lastUpdateTime = sharedDefaults?.object(forKey: "lastUpdateTime") as? Date
        let isActive = sharedDefaults?.bool(forKey: "isActive") ?? false
        let isPaused = sharedDefaults?.bool(forKey: "isPaused") ?? false
        let hasNewData = sharedDefaults?.bool(forKey: "hasNewData") ?? false
        let appIsActive = sharedDefaults?.bool(forKey: "appIsActive") ?? false
        let appTerminationTime = sharedDefaults?.object(forKey: "appTerminationTime") as? Date
        let terminationReason = sharedDefaults?.string(forKey: "terminationReason")
        
        var displayLyric = lyric
        var displayTitle = songTitle
        var displayArtist = artist
        
        print("[Widget] 📱 Timeline update - Active: \(isActive), Lyric: '\(lyric)', Title: '\(songTitle)', Artist: '\(artist)'")
        
        // Clear the fresh data flag immediately after reading
        if hasNewData {
            sharedDefaults?.set(false, forKey: "hasNewData")
        }
        
        // Check for app termination first
        if let terminationTime = appTerminationTime {
            let timeSinceTermination = Date().timeIntervalSince(terminationTime)
            // Only show termination message for a limited time (5 minutes)
            if timeSinceTermination < 300 && timeSinceTermination > 5 { // After 5 seconds but before 5 minutes
                displayLyric = "App was closed"
                displayTitle = "Open Lyracalise"
                displayArtist = "To resume lyrics"
                print("[Widget] 💀 Showing termination message")
            } else if timeSinceTermination >= 300 {
                // Auto-clear old termination flags
                sharedDefaults?.removeObject(forKey: "appTerminationTime")
                sharedDefaults?.removeObject(forKey: "terminationReason")
            }
        }
        // Enhanced stale data detection for suspended apps
        else if let lastUpdate = lastUpdateTime {
            let timeSinceUpdate = Date().timeIntervalSince(lastUpdate)
            
            // More aggressive stale detection when app was backgrounded
            let staleThreshold: TimeInterval = appIsActive ? 60 : 30 // Shorter threshold for backgrounded apps
            
            if timeSinceUpdate > staleThreshold && isActive {
                displayLyric = "App terminated"
                displayTitle = "Open Lyracalise" 
                displayArtist = "To resume sync"
                print("[Widget] ⏰ Showing stale data message")
            }
        } else {
            // No update time means app was force closed or never started
            if isActive {
                displayLyric = "App not running"
                displayTitle = "Open Lyracalise"
                displayArtist = "To start sync"
                print("[Widget] ❌ No update time, showing app not running")
            }
        }
        
        // Show better status when no music is playing or app is inactive
        if !isActive || (songTitle.isEmpty && lyric.isEmpty) || 
           (songTitle == "No song" && lyric == "No lyric") {
            displayLyric = "Start Lyracalise"
            displayTitle = "No music playing"
            displayArtist = "Open app to begin"
            print("[Widget] 🎵 No active music, showing default message")
        }
        
        // If we have valid data, use it directly
        if isActive && !lyric.isEmpty && !songTitle.isEmpty && lyric != "No lyric" && songTitle != "No song" {
            displayLyric = lyric
            displayTitle = songTitle  
            displayArtist = artist.isEmpty ? "Unknown Artist" : artist
            print("[Widget] ✅ Using valid lyric data: '\(displayLyric)'")
        }
        
        let entry = LyricEntry(date: Date(), lyric: displayLyric, songTitle: displayTitle, artist: displayArtist)
        
        // SMART refresh strategy optimized for app termination detection
        // More frequent refreshes to quickly detect when app is force-closed
        let nextRefresh = Date().addingTimeInterval(15) // Check every 15 seconds
        let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
        completion(timeline)
    }
}

struct LyricWidgetView: View {
    var entry: LyricEntry
    var body: some View {
        // Determine if we're in a default state
        let isDefaultState = entry.lyric.isEmpty || 
                           entry.lyric == "No lyric" || 
                           entry.lyric == "Start Lyracalise" ||
                           entry.songTitle.isEmpty || 
                           entry.songTitle == "No song" ||
                           entry.songTitle == "No music playing"
        
        ZStack {
            if isDefaultState {
                VStack(spacing: 8) {
                    Image(systemName: "music.note")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("Lyracalise")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                    
                    if !entry.lyric.isEmpty && entry.lyric != "No lyric" {
                        Text(entry.lyric)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
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
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .systemExtraLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
        .configurationDisplayName("Current Lyric")
        .description("Shows the current lyric line for the playing song.")
    }
}