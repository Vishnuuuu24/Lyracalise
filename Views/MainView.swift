import SwiftUI

struct MainView: View {
    @StateObject private var lyricSyncManager = LyricSyncManager()
    @State private var input = ""

    var body: some View {
        ZStack {
            LinearGradient(colors: [.black, .blue.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 30) {

                // 🎵 App Title with Glass
                Text("Lyracalise")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .padding()

                // 📝 Input Field
                TextField("Type lyrics or command...", text: $input)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

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

                // 🎶 Lyrics Card
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.regularMaterial)
                        .frame(height: 180)

                    VStack(spacing: 10) {
                        Text("🎶 Live Lyrics")
                            .font(.title2)
                            .bold()

                        Text(lyricSyncManager.currentLine)
                            .font(.body)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding()
        }
        .onAppear {
            lyricSyncManager.loadLyrics()
        }
    }
}
