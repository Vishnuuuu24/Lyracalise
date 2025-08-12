import SwiftUI

struct MainView: View {
    @StateObject private var lyricSyncManager = LyricSyncManager()
    @State private var input = ""

    var body: some View {
        ZStack {
            LinearGradient(colors: [.black, .blue.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                // 🎵 App Title with Glass
                Text("Lyracalise")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .padding()

                // 📝 Input Field and Fetch Button (only show if manual search enabled)
                if lyricSyncManager.manualSearchEnabled {
                    HStack {
                        TextField("Artist - Song Title", text: $input)
                            .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                        Button("Fetch Lyrics") {
                            Task {
                                await lyricSyncManager.fetchAndParseLRCFromInput(input)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                // ▶️ Start/Stop Buttons
                HStack {
                Button("Start Lyrics") {
                        lyricSyncManager.start()
                }
                    .buttonStyle(.borderedProminent)
                .controlSize(.large)
                    
                    Button("Stop Lyrics") {
                        lyricSyncManager.stop()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                // Now Playing Info and Status Message (below buttons)
                VStack(spacing: 2) {
                    if !lyricSyncManager.nowPlayingTitle.isEmpty {
                        Text("Currently Playing:")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Text(lyricSyncManager.nowPlayingTitle)
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        if !lyricSyncManager.nowPlayingArtist.isEmpty {
                            Text(lyricSyncManager.nowPlayingArtist)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                    if !lyricSyncManager.statusMessage.isEmpty {
                        Text(lyricSyncManager.statusMessage)
                            .font(.footnote)
                            .foregroundColor(.blue)
                            .padding(.top, 2)
                    }
                }
                .padding(.bottom, 4)

                // 🎶 Lyrics Card
                if !lyricSyncManager.fullLyricsText.isEmpty {
                    VStack {
                        // Conditional Title for the Lyrics Card
                        Text(lyricSyncManager.lyricsCount > 1 ? "🎶 Live Lyrics" : "📜 Plain Lyrics")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.top)

                        ZStack {
                            // The main background card that extends
                            RoundedRectangle(cornerRadius: 25)
                                .fill(.regularMaterial)

                            // Logic for displaying either scrolling plain text or live synced lyrics
                            if lyricSyncManager.lyricsCount == 1 {
                                // Scrollable view for plain lyrics with a fade-out effect
                                ScrollView {
                                    Text(lyricSyncManager.fullLyricsText)
                                        .font(.system(.title3, design: .rounded))
                                        .fontWeight(.medium)
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(.white.opacity(0.85))
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 30) // Give space for the fade
                                }
                                .mask(
                                    // This VStack creates the fade-out effect at the top and bottom
                                    VStack(spacing: 0) {
                                        LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                                            .frame(height: 30)
                                        Rectangle().fill(.black)
                                        LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                                            .frame(height: 30)
                                    }
                                )
                            } else {
                                // View for synced, line-by-line lyrics
                                Text(lyricSyncManager.currentLine)
                                    .font(.system(.title2, design: .rounded))
                                    .fontWeight(.bold)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.white)
                                    .padding()
                            }
                        }
                    }
                    .padding(.horizontal)
                    .frame(maxHeight: .infinity) // Allow the card to take up available space
                }

                Spacer()
            }
            .padding()
        }
        .onAppear {
            lyricSyncManager.loadLyrics()
            lyricSyncManager.startNowPlayingObservation()
        }
    }
}
