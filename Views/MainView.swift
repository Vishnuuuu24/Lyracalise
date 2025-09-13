import SwiftUI

/// Premium iOS 18 Liquid Glass Design Language Implementation
struct MainView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var lyricSyncManager = LyricSyncManager()
    @StateObject private var colorExtractor = ColorExtractor()
    @State private var manualInput: String = ""
    @ObservedObject private var spotifyManager = SpotifyManager.shared
    @State private var showSettings = false
    @Namespace private var buttonNamespace
    
    // Premium iOS 18 Liquid Glass Animation States
    @State private var liquidGlassIntensity: Double = 0.8
    @State private var refractionOffset: CGFloat = 0
    @State private var contentOpacity: Double = 0
    @State private var headerOffset: CGFloat = -50
    @State private var cardsOffset: CGFloat = 30
    @State private var controlsOffset: CGFloat = 50
    @State private var morphingScale: CGFloat = 1.0
    @State private var fluidAnimationPhase: Double = 0
    @State private var backgroundFlow: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Dynamic Album Artwork Background with edge-to-edge extension
            DynamicAlbumBackground(colorExtractor: colorExtractor)
                .ignoresSafeArea()
                .backgroundExtensionEffect()
            
            // Premium Glass Background Container
            LiquidGlassContainer {
                // Multi-layer fluid background with transparency
                ZStack {
                    // Base layer using iOS 18 materials with transparency
                    Color.clear
                        .background(.ultraThinMaterial.opacity(0.3))
                    
                    // Dynamic refraction layer with album colors
                    LinearGradient(
                        colors: [
                            colorExtractor.primaryColor.opacity(0.15),
                            colorExtractor.accentColor.opacity(0.08),
                            colorExtractor.primaryColor.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .opacity(liquidGlassIntensity)
                    .offset(x: refractionOffset, y: refractionOffset * 0.5)
                    .scaleEffect(morphingScale)
                    
                    // Fluid animation overlay
                    FluidAnimationOverlay(phase: fluidAnimationPhase)
                        .opacity(0.2)
                }
            }
            .ignoresSafeArea()
            .onAppear {
                startLiquidGlassAnimations()
            }
            
            // Main content with full-screen lyrics like Apple Music
            VStack(spacing: 0) {
                // Prominent Lyracalise title like Apple Music - positioned higher
                Text("Lyracalise")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                colorExtractor.primaryColor.readableTextColor,
                                colorExtractor.accentColor.readableTextColor.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    .padding(.top, 20) // Reduced from 60 to push higher
                    .padding(.bottom, 16) // Slightly reduced bottom padding
                    .offset(y: headerOffset)
                    .opacity(contentOpacity)
                
                // Compact Now Playing info
                if !lyricSyncManager.nowPlayingTitle.isEmpty {
                    VStack(spacing: 4) {
                        Text(lyricSyncManager.nowPlayingTitle)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(colorExtractor.primaryColor.readableTextColor.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                        
                        if !lyricSyncManager.nowPlayingArtist.isEmpty {
                            Text(lyricSyncManager.nowPlayingArtist)
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(colorExtractor.primaryColor.readableTextColor.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                        }
                    }
                    .padding(.bottom, 24)
                    .offset(y: cardsOffset)
                    .opacity(contentOpacity)
                }
                
                // Full-width lyrics like Apple Music - takes up most of the screen
                LyricCanvas(
                    lyrics: lyricSyncManager.loadedLyrics,
                    currentLineIndex: lyricSyncManager.currentLineIndex,
                    currentLine: lyricSyncManager.currentLine,
                    colorExtractor: colorExtractor,
                    onLyricTap: { index, entry in
                        lyricSyncManager.resync(to: entry.time, at: index)
                    }
                )
                .layoutPriority(3)
                .frame(maxWidth: .infinity)
                .offset(y: cardsOffset)
                .opacity(contentOpacity)
                
                Spacer()
                
                // Bottom Start/Stop buttons like Apple Music
                HStack(spacing: 24) {
                    Button("Start") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            lyricSyncManager.startLyricSync()
                        }
                    }
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 100, height: 44)
                    .background(.ultraThinMaterial.opacity(0.8))
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    Button("Stop") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            lyricSyncManager.stopAllLyricSync()
                        }
                    }
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 100, height: 44)
                    .background(.blue.opacity(0.8))
                    .clipShape(Capsule())
                    .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .padding(.bottom, 50) // Apple Music spacing from bottom
                .offset(y: controlsOffset)
                .opacity(contentOpacity)
            }
            
            // Settings button
            VStack {
                HStack {
                    Spacer()
                    settingsButton
                        .opacity(contentOpacity)
                }
                Spacer()
            }
            .padding(.top, 60)
            .padding(.trailing, 20)
        }
        .onAppear {
            startLiquidGlassAnimations()
            lyricSyncManager.startLyricSync()
        }
        .onChange(of: spotifyManager.currentTrack) { _, newTrack in
            // Update album artwork colors when track changes
            colorExtractor.extractColors(from: newTrack?.albumImageURL)
        }
        .sheet(isPresented: $lyricSyncManager.isShowingSearchResults) {
            PremiumSearchResultView(lyricSyncManager: lyricSyncManager)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $lyricSyncManager.showPrivacyEducation) {
            PrivacyEducationView(isPresented: $lyricSyncManager.showPrivacyEducation)
                .onDisappear {
                    lyricSyncManager.dismissPrivacyEducation()
                }
        }
        .sheet(isPresented: $showSettings) {
            PremiumSpotifySettingsView(spotifyManager: spotifyManager)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
    
    // MARK: - UI Components
    
    private var dynamicBackground: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.systemBackground).opacity(0.95),
                    Color(.secondarySystemBackground).opacity(0.8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Flowing accent overlay
            LinearGradient(
                colors: [
                    Color(.systemBlue).opacity(0.03),
                    Color(.systemPurple).opacity(0.02),
                    Color(.systemTeal).opacity(0.03),
                    Color(.systemBlue).opacity(0.02)
                ],
                startPoint: UnitPoint(x: backgroundFlow, y: 0),
                endPoint: UnitPoint(x: backgroundFlow + 0.8, y: 1)
            )
            .ignoresSafeArea()
            .onAppear {
                withAnimation(Animation.linear(duration: 15.0).repeatForever(autoreverses: false)) {
                    backgroundFlow = 1.2
                }
            }
        }
    }
    
    // MARK: - Premium iOS 18 Liquid Glass Components
    
    private var liquidGlassManualSearchCard: some View {
        LiquidGlassContainer {
            VStack(spacing: 16) {
                Text("Manual Search")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    TextField("Artist - Song Title", text: $manualInput)
                        .textFieldStyle(LiquidGlassTextFieldStyle())
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                    
                    Button("Search") {
                        HapticManager.shared.buttonTapped()
                        lyricSyncManager.manualSearch(for: manualInput)
                    }
                    .buttonStyle(LiquidGlassPrimaryButtonStyle())
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
            }
            .padding(24)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(0.1), lineWidth: 0.5)
            )
        }
    }
    
    private var controlButtons: some View {
        HStack(spacing: 16) {
            LiquidGlassButton(
                title: "Start",
                systemImage: "play.fill",
                action: {
                    HapticManager.shared.sessionStarted()
                    lyricSyncManager.startLyricSync()
                },
                style: .primary
            )
            
            LiquidGlassButton(
                title: "Stop",
                systemImage: "stop.fill",
                action: {
                    HapticManager.shared.sessionEnded()
                    lyricSyncManager.stopAllLyricSync()
                },
                style: .secondary
            )
        }
    }
    
    private var settingsButton: some View {
        Button(action: {
            HapticManager.shared.impact(.touch)
            showSettings = true
        }) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white)
        }
        .buttonStyle(.glass)
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(morphingScale)
    }
    
    // MARK: - Premium iOS 18 Liquid Glass Animations
    
    private func startLiquidGlassAnimations() {
        // Continuous fluid morphing
        withAnimation(Animation.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
            morphingScale = 1.05
            liquidGlassIntensity = 0.9
        }
        
        // Refraction animation
        withAnimation(Animation.linear(duration: 8.0).repeatForever(autoreverses: false)) {
            refractionOffset = 10
        }
        
        // Fluid animation phase
        withAnimation(Animation.linear(duration: 20.0).repeatForever(autoreverses: false)) {
            fluidAnimationPhase = 1.0
        }
        
        // Entrance animations with staggered timing
        withAnimation(LiquidGlassAnimations.entrance.delay(0.1)) {
            contentOpacity = 1.0
            headerOffset = 0
        }
        
        withAnimation(LiquidGlassAnimations.entrance.delay(0.2)) {
            cardsOffset = 0
        }
        
        withAnimation(LiquidGlassAnimations.entrance.delay(0.3)) {
            controlsOffset = 0
        }
    }
}

// MARK: - Premium iOS 18 Liquid Glass Components

/// Liquid Glass Header with fluid morphing design
struct LiquidGlassHeader: View {
    @State private var glowIntensity: Double = 0.5
    
    var body: some View {
        LiquidGlassContainer {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Lyracalise")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.primary, .secondary.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("Liquid Glass • Premium iOS 18")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .opacity(0.8)
                }
                
                Spacer()
                
                // Dynamic status orb
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .fill(.green)
                            .scaleEffect(0.6)
                            .opacity(glowIntensity)
                    )
                    .shadow(color: .green.opacity(0.3), radius: 4, x: 0, y: 2)
                    .onAppear {
                        withAnimation(Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                            glowIntensity = 1.0
                        }
                    }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

/// Now Playing Card with Liquid Glass material
struct LiquidGlassNowPlayingCard: View {
    let title: String
    let artist: String
    let statusMessage: String
    @State private var refractionOffset: CGFloat = 0
    
    var body: some View {
        LiquidGlassContainer {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Text("Now Playing")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "music.note")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                
                // Content
                VStack(spacing: 12) {
                    Text(title.isEmpty ? "No song playing" : title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    if !artist.isEmpty {
                        Text(artist)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                    }
                    
                    if !statusMessage.isEmpty {
                        Text(statusMessage)
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 8)
                    }
                }
            }
            .padding(24)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(0.1), lineWidth: 0.5)
                    .offset(x: refractionOffset, y: refractionOffset * 0.5)
            )
            .onAppear {
                withAnimation(Animation.linear(duration: 6.0).repeatForever(autoreverses: false)) {
                    refractionOffset = 2
                }
            }
        }
    }
}

/// Status Indicator with Liquid Glass
struct LiquidGlassStatusIndicator: View {
    let status: String
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        LiquidGlassContainer {
            HStack(spacing: 12) {
                Circle()
                    .fill(.blue)
                    .frame(width: 8, height: 8)
                    .scaleEffect(pulseScale)
                    .onAppear {
                        withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                            pulseScale = 1.3
                        }
                    }
                
                Text(status)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
        }
    }
}

/// Liquid Glass Button Style
struct LiquidGlassButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    let style: ButtonStyleType
    @State private var morphScale: CGFloat = 1.0
    
    enum ButtonStyleType {
        case primary, secondary
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(style == .primary ? .white : .primary)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Group {
                    if style == .primary {
                        LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                            .opacity(0.9)
                    } else {
                        Color.clear
                            .background(.ultraThinMaterial)
                    }
                }
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(.white.opacity(0.2), lineWidth: 0.5)
            )
            .scaleEffect(morphScale)
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.1)) {
                    morphScale = 0.95
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        morphScale = 1.0
                    }
                }
                action()
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Liquid Glass Text Field Style
struct LiquidGlassTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.white.opacity(0.1), lineWidth: 0.5)
            )
    }
}

/// Liquid Glass Primary Button Style
struct LiquidGlassPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(0.9)
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Fluid Animation Overlay for background
struct FluidAnimationOverlay: View {
    let phase: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.blue.opacity(0.1),
                                    Color.purple.opacity(0.05),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                        .offset(
                            x: cos(phase + Double(index) * 2.0) * 50,
                            y: sin(phase + Double(index) * 1.5) * 30
                        )
                        .position(
                            x: geometry.size.width * (0.3 + Double(index) * 0.2),
                            y: geometry.size.height * (0.4 + sin(phase + Double(index)) * 0.2)
                        )
                }
            }
        }
    }
}

/// Premium iOS 18 Liquid Glass Animations
enum LiquidGlassAnimations {
    static let entrance = Animation.interpolatingSpring(
        mass: 1.0,
        stiffness: 100,
        damping: 20,
        initialVelocity: 0
    )
    
    static let morphing = Animation.easeInOut(duration: 3.0)
    static let fluid = Animation.linear(duration: 8.0)
}

// MARK: - Premium Settings View

struct PremiumSpotifySettingsView: View {
    @ObservedObject var spotifyManager: SpotifyManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var scale: CGFloat = 0.9
    @State private var opacity: Double = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                // Connection status
                connectionStatus
                
                // Action button
                actionButton
                
                Spacer()
            }
            .padding(24)
            .background(Color.clear)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(PremiumUI.Springs.bouncy) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
    
    private var connectionStatus: some View {
        VStack(spacing: 20) {
            // Status icon
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: spotifyManager.isLoggedIn ? "checkmark.circle.fill" : "person.crop.circle")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(
                            spotifyManager.isLoggedIn ? 
                                LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                LinearGradient(colors: [.gray, .secondary], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                )
                .shadow(color: spotifyManager.isLoggedIn ? .green.opacity(0.3) : .clear, radius: 10, x: 0, y: 5)
            
            VStack(spacing: 8) {
                Text(spotifyManager.isLoggedIn ? "Spotify Connected" : "Connect Spotify")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                if spotifyManager.isLoggedIn, let track = spotifyManager.currentTrack {
                    Text("Now Playing")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    
                    Text("\(track.name) • \(track.artist)")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                } else if !spotifyManager.isLoggedIn {
                    Text("Enable automatic lyric detection\nfor your Spotify music")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
        }
    }
    
    private var actionButton: some View {
        if spotifyManager.isLoggedIn {
            PremiumButton(
                title: "Logout",
                systemImage: "rectangle.portrait.and.arrow.right",
                action: {
                    HapticManager.shared.impact(.emphasis)
                    spotifyManager.logout()
                },
                style: .secondary
            )
        } else {
            PremiumButton(
                title: "Connect Spotify",
                systemImage: "music.note",
                action: {
                    HapticManager.shared.impact(.success)
                    spotifyManager.login()
                },
                style: .primary
            )
        }
    }
}

/// Updated search result view for better integration
struct SearchResultView: View {
    @ObservedObject var lyricSyncManager: LyricSyncManager
    
    var body: some View {
        PremiumSearchResultView(lyricSyncManager: lyricSyncManager)
    }
}

// MARK: - Dynamic Album Background
struct DynamicAlbumBackground: View {
    @ObservedObject var colorExtractor: ColorExtractor
    @State private var animationPhase: Double = 0
    
    var body: some View {
        ZStack {
            // Base gradient background using album colors
            LinearGradient(
                colors: colorExtractor.dominantColors.isEmpty ? 
                    [Color(.systemBackground), Color(.secondarySystemBackground)] :
                    [
                        colorExtractor.primaryColor.opacity(0.8),
                        colorExtractor.accentColor.opacity(0.6),
                        colorExtractor.dominantColors.last?.opacity(0.4) ?? colorExtractor.primaryColor.opacity(0.4)
                    ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .animation(.easeInOut(duration: 2.0), value: colorExtractor.dominantColors)
            
            // Animated overlay for movement
            RadialGradient(
                colors: [
                    colorExtractor.accentColor.opacity(0.3),
                    colorExtractor.primaryColor.opacity(0.1),
                    Color.clear
                ],
                center: UnitPoint(x: 0.5 + cos(animationPhase) * 0.3, y: 0.5 + sin(animationPhase) * 0.3),
                startRadius: 50,
                endRadius: 400
            )
            .animation(.linear(duration: 20).repeatForever(autoreverses: false), value: animationPhase)
            .onAppear {
                animationPhase = 2 * .pi
            }
        }
    }
}
