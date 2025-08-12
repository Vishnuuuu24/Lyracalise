import SwiftUI

struct MainView: View {
    @Environment(\.scenePhase) private var scenePhase
    // The single source of truth for all lyric and playback state.
    @StateObject private var lyricSyncManager = LyricSyncManager()
    @State private var manualInput: String = "" // State for the manual search text field

    var body: some View {
        ZStack {
            // A subtle, dark gradient background.
            LinearGradient(
                colors: [.black, Color(red: 0.1, green: 0.1, blue: 0.25)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
                .ignoresSafeArea()

            VStack(spacing: 15) {
                // MARK: - Header
                Text("Lyracalise")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .background(.white.opacity(0.1))
                    .cornerRadius(20)

                // MARK: - Now Playing Info
                VStack {
                    Text(lyricSyncManager.nowPlayingTitle.isEmpty ? "No Song Detected" : lyricSyncManager.nowPlayingTitle)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Text(lyricSyncManager.nowPlayingArtist.isEmpty ? "Play a song in your music app" : lyricSyncManager.nowPlayingArtist)
                        .font(.headline)
                        .fontWeight(.light)
                        .foregroundColor(.white.opacity(0.7))
                }
                    .padding(.horizontal)

                // MARK: - Manual Search UI
                if lyricSyncManager.manualSearchEnabled {
                    HStack {
                        TextField("Artist - Title", text: $manualInput)
                            .textFieldStyle(.roundedBorder)
                            .padding(.leading)
                        
                        Button("Find Lyrics") {
                            lyricSyncManager.manualSearch(for: manualInput)
                }
                        .buttonStyle(.borderedProminent)
                        .padding(.trailing)
                    }
                    .transition(.opacity.combined(with: .scale))
                }
                
                // MARK: - Status Message
                Text(lyricSyncManager.statusMessage)
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .padding(.bottom, 5)

                // MARK: - Interactive Lyrics View
                if !lyricSyncManager.loadedLyrics.isEmpty {
                    ZStack(alignment: .topLeading) {
                        ScrollViewReader { proxy in
                            ScrollView {
                                VStack(alignment: .center, spacing: 18) {
                                    Color.clear.frame(height: 150)
                                    ForEach(Array(lyricSyncManager.loadedLyrics.enumerated()), id: \.offset) { index, entry in
                                        Text(entry.line)
                                            .font(.title2)
                                            .fontWeight(lyricSyncManager.currentLineIndex == index ? .bold : .medium)
                                            .foregroundColor(lyricSyncManager.currentLineIndex == index ? .white : .gray)
                                            .multilineTextAlignment(.center)
                                            .id(index)
                                            .onTapGesture {
                                                lyricSyncManager.resync(to: entry.time, at: index)
                                            }
                                    }
                                    Color.clear.frame(height: 150)
                                }
                                .padding(.horizontal)
                            }
                            .onChange(of: lyricSyncManager.currentLineIndex) { newIndex in
                                if let newIndex = newIndex {
                                    withAnimation(.easeInOut(duration: 0.5)) {
                                        proxy.scrollTo(newIndex, anchor: .center)
                                    }
                                }
                            }
                        }
                        // Add the manual override button if auto-selected
                        if lyricSyncManager.autoSelectedFirstResult {
                            Button(action: {
                                lyricSyncManager.isShowingSearchResults = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.bubble")
                                        .foregroundColor(.yellow)
                                    Text("Wrong lyrics?")
                                        .font(.caption)
                                        .foregroundColor(.yellow)
                                }
                                .padding(8)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(12)
                            }
                            .padding([.top, .leading], 12)
                            .transition(.opacity)
                        }
                    }
                } else if let staticText = lyricSyncManager.staticLyrics {
                    // Fallback for plain, unsynced lyrics.
                    ScrollView {
                        Text(staticText)
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.medium)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 30)
                            .frame(maxWidth: .infinity)
                        }
                    .mask(
                        VStack(spacing: 0) {
                            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                                .frame(height: 30)
                            Rectangle().fill(.black)
                            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                                .frame(height: 30)
                        }
                    )
                } else {
                    // Placeholder when no lyrics are loaded.
                    VStack {
                        Spacer()
                        Text("No lyrics found for this track.")
                            .foregroundColor(.gray)
                        Text("Make sure a correctly named .lrc file is in the 'Lyrics' folder.")
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.7))
                            .multilineTextAlignment(.center)
                    .padding(.horizontal)
                        Spacer()
                    }
                }

                // MARK: - Controls
                if lyricSyncManager.manualSyncOffset != nil {
                    Button("Resume Auto-Sync") {
                        lyricSyncManager.resumeAutoSync()
                    }
                    .buttonStyle(.bordered)
                    .tint(.accentColor)
                    .transition(.opacity)
                }

                Spacer()
                Button(action: {
                    lyricSyncManager.stopAll()
                }) {
                    Text("Stop")
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
            }
            .padding(.vertical)
        }
        .onAppear {
            lyricSyncManager.startNowPlayingObservation()
            NotificationCenter.default.addObserver(
                forName: UIApplication.willTerminateNotification,
                object: nil,
                queue: .main
            ) { _ in
                lyricSyncManager.stopAll()
            }
        }
        .sheet(isPresented: $lyricSyncManager.isShowingSearchResults) {
            SearchResultView(lyricSyncManager: lyricSyncManager)
        }
    }
}

/// A new view to display the list of search results in a pop-up sheet.
struct SearchResultView: View {
    @ObservedObject var lyricSyncManager: LyricSyncManager
    
    var body: some View {
        NavigationView {
            List(lyricSyncManager.searchResults) { result in
                Button(action: {
                    lyricSyncManager.selectSearchResult(result)
                }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(result.artistName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        HStack {
                            Text(result.albumName)
                                .font(.caption)
                                .foregroundColor(.gray)
                            Spacer()
                            Text(String(format: "%.0f:%02.0f", (result.duration / 60).rounded(.down), result.duration.truncatingRemainder(dividingBy: 60)))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .navigationTitle("Search Results")
            .navigationBarItems(trailing: Button("Cancel") {
                lyricSyncManager.isShowingSearchResults = false
            })
        }
    }
}
