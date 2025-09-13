import SwiftUI

/// Premium UI components with liquid glass design language
struct PremiumUI {
    
    // MARK: - Colors & Materials
    
    /// Dynamic color scheme that adapts to content
    struct DynamicColors {
        static let primaryGradient = LinearGradient(
            colors: [
                Color(.systemBlue).opacity(0.8),
                Color(.systemPurple).opacity(0.6),
                Color(.systemIndigo).opacity(0.4)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let accentGradient = LinearGradient(
            colors: [
                Color(.systemTeal).opacity(0.7),
                Color(.systemBlue).opacity(0.5)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        
        static let backgroundGradient = LinearGradient(
            colors: [
                Color(.systemBackground),
                Color(.systemBackground).opacity(0.95),
                Color(.secondarySystemBackground).opacity(0.8)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    // MARK: - Animation Springs
    
    /// Premium spring animations that feel like Apple
    struct Springs {
        static let gentle = Animation.spring(
            response: 0.6,
            dampingFraction: 0.8,
            blendDuration: 0.3
        )
        
        static let bouncy = Animation.spring(
            response: 0.4,
            dampingFraction: 0.7,
            blendDuration: 0.2
        )
        
        static let smooth = Animation.spring(
            response: 0.8,
            dampingFraction: 0.9,
            blendDuration: 0.4
        )
        
        static let snappy = Animation.spring(
            response: 0.3,
            dampingFraction: 0.8,
            blendDuration: 0.1
        )
    }
}

// MARK: - Premium Glass Card Component

struct GlassCard<Content: View>: View {
    let content: Content
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    let shadowOpacity: Double
    
    init(
        cornerRadius: CGFloat = 20,
        shadowRadius: CGFloat = 10,
        shadowOpacity: Double = 0.1,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
        self.shadowOpacity = shadowOpacity
    }
    
    var body: some View {
        content
            .background(
                // Liquid glass background
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(PremiumUI.DynamicColors.primaryGradient.opacity(0.1))
                    )
                    .overlay(
                        // Subtle border
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(.white.opacity(0.2), lineWidth: 0.5)
                    )
            )
            .shadow(
                color: .black.opacity(shadowOpacity),
                radius: shadowRadius,
                x: 0,
                y: shadowRadius * 0.3
            )
    }
}

// MARK: - Premium Button Component

struct PremiumButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    let style: ButtonStyle
    
    @State private var isPressed = false
    @State private var scale: CGFloat = 1.0
    
    enum ButtonStyle {
        case primary    // Start button style
        case secondary  // Stop button style
        case accent     // Special actions
        
        var colors: (background: Color, foreground: Color) {
            switch self {
            case .primary:
                return (.green, .white)
            case .secondary:
                return (.red, .white)
            case .accent:
                return (.blue, .white)
            }
        }
        
        var gradient: LinearGradient {
            switch self {
            case .primary:
                return LinearGradient(
                    colors: [.green.opacity(0.8), .mint.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .secondary:
                return LinearGradient(
                    colors: [.red.opacity(0.8), .pink.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .accent:
                return LinearGradient(
                    colors: [.blue.opacity(0.8), .cyan.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
    
    var body: some View {
        Button(action: {
            // Haptic feedback
            HapticManager.shared.buttonTapped()
            
            // Button animation
            withAnimation(PremiumUI.Springs.snappy) {
                scale = 0.95
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(PremiumUI.Springs.bouncy) {
                    scale = 1.0
                }
                
                // Release haptic
                HapticManager.shared.buttonReleased()
            }
            
            action()
        }) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                
                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
            }
            .foregroundColor(style.colors.foreground)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(style.gradient)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(0.3), lineWidth: 1)
                    )
            )
            .scaleEffect(scale)
            .shadow(
                color: style.colors.background.opacity(0.3),
                radius: isPressed ? 5 : 10,
                x: 0,
                y: isPressed ? 2 : 5
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(PremiumUI.Springs.gentle) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Floating Header Component

struct FloatingHeader: View {
    @State private var shimmerOffset: CGFloat = -1
    @State private var breathingScale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 8) {
            // App icon placeholder with breathing animation
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "music.note.house")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(PremiumUI.DynamicColors.accentGradient)
                )
                .scaleEffect(breathingScale)
                .animation(
                    Animation.easeInOut(duration: 3.0).repeatForever(autoreverses: true),
                    value: breathingScale
                )
            
            // App title with shimmer effect
            Text("Lyracalise")
                .font(.system(size: 32, weight: .thin, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            .primary.opacity(0.8),
                            .primary,
                            .primary.opacity(0.8)
                        ],
                        startPoint: UnitPoint(x: shimmerOffset, y: 0.5),
                        endPoint: UnitPoint(x: shimmerOffset + 0.3, y: 0.5)
                    )
                )
                .mask(
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .clear,
                                    .black,
                                    .black,
                                    .clear
                                ],
                                startPoint: UnitPoint(x: shimmerOffset, y: 0.5),
                                endPoint: UnitPoint(x: shimmerOffset + 0.3, y: 0.5)
                            )
                        )
                )
        }
        .onAppear {
            withAnimation(Animation.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                shimmerOffset = 1.3
            }
            
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                breathingScale = 1.05
            }
        }
    }
}

// MARK: - Now Playing Card Component

struct NowPlayingCard: View {
    let title: String
    let artist: String
    let statusMessage: String
    
    @State private var pulseScale: CGFloat = 1.0
    @State private var gradientOffset: CGFloat = 0
    
    var body: some View {
        GlassCard {
            VStack(spacing: 16) {
                // Music icon with pulse animation
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "waveform")
                            .font(.system(size: 32, weight: .ultraLight))
                            .foregroundStyle(PremiumUI.DynamicColors.accentGradient)
                    )
                    .scaleEffect(pulseScale)
                    .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                
                VStack(spacing: 8) {
                    // Song title
                    Text(title.isEmpty ? "No Song Detected" : title)
                        .font(.system(size: 24, weight: .medium, design: .rounded))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Artist name
                    Text(artist.isEmpty ? "Play a song to begin" : artist)
                        .font(.system(size: 18, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                    
                    // Status message with animated gradient
                    if !statusMessage.isEmpty {
                        Text(statusMessage)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple, .blue],
                                    startPoint: UnitPoint(x: gradientOffset, y: 0.5),
                                    endPoint: UnitPoint(x: gradientOffset + 0.5, y: 0.5)
                                )
                            )
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
            }
            .padding(20)
        }
        .onAppear {
            // Pulse animation
            withAnimation(Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulseScale = 1.1
            }
            
            // Gradient animation
            withAnimation(Animation.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                gradientOffset = 1.0
            }
        }
        .onChange(of: title) { _ in
            // Haptic feedback when song changes
            if !title.isEmpty {
                HapticManager.shared.lyricsLoaded()
            }
        }
    }
}

// MARK: - Status Indicator Component

struct StatusIndicator: View {
    let status: String
    @State private var rotation: Double = 0
    
    var body: some View {
        HStack(spacing: 8) {
            // Animated loading indicator
            Circle()
                .stroke(PremiumUI.DynamicColors.accentGradient, lineWidth: 2)
                .frame(width: 16, height: 16)
                .overlay(
                    Circle()
                        .fill(.blue)
                        .frame(width: 4, height: 4)
                        .offset(x: 6)
                        .rotationEffect(.degrees(rotation))
                )
                .onAppear {
                    withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }
            
            Text(status)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(0.2), lineWidth: 0.5)
                )
        )
    }
}