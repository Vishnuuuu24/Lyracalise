import SwiftUI

// MARK: - Premium iOS 18 Liquid Glass Lyric Canvas

struct LyricCanvas: View {
    let lyrics: [LyricEntry]
    let currentLineIndex: Int?
    let currentLine: String
    @ObservedObject var colorExtractor: ColorExtractor
    let onLyricTap: (Int, LyricEntry) -> Void
    @Namespace private var lyricNamespace
    
    @State private var scrollOffset: CGFloat = 0
    @State private var liquidGlowIntensity: Double = 0.5
    @State private var refractionPhase: CGFloat = 0
    @State private var morphingScale: CGFloat = 1.0
    @State private var backgroundFlow: CGFloat = 0
    @State private var glowIntensity: Double = 0.5
    
    var body: some View {
        ZStack {
            if lyrics.isEmpty {
                // Empty state like Apple Music
                AppleMusicEmptyLyricsView(colorExtractor: colorExtractor)
            } else {
                // Full-screen lyrics like Apple Music
                GeometryReader { geometry in
                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 20) { // Increased spacing like Apple Music
                                // Top padding for centering
                                Color.clear.frame(height: geometry.size.height * 0.3)
                                
                                ForEach(Array(lyrics.enumerated()), id: \.offset) { index, lyric in
                                    AppleMusicLyricLineView(
                                        lyric: lyric.line,
                                        index: index,
                                        isCurrentLine: currentLineIndex == index,
                                        isAdjacentLine: abs((currentLineIndex ?? -10) - index) == 1,
                                        colorExtractor: colorExtractor,
                                        namespace: lyricNamespace,
                                        onTap: {
                                            onLyricTap(index, lyric)
                                        }
                                    )
                                    .id(index)
                                }
                                
                                // Bottom padding for centering
                                Color.clear.frame(height: geometry.size.height * 0.4)
                            }
                            .padding(.horizontal, 32) // Apple Music padding
                        }
                        .onChange(of: currentLineIndex) { newIndex in
                            if let newIndex = newIndex {
                                withAnimation(.easeInOut(duration: 0.6)) { // Smoother like Apple Music
                                    proxy.scrollTo(newIndex, anchor: .center)
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Background flow animation
            withAnimation(Animation.linear(duration: 10.0).repeatForever(autoreverses: false)) {
                backgroundFlow = 1.0
            }
            
            // Glow pulse animation
            withAnimation(Animation.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                glowIntensity = 1.0
            }
        }
        .onChange(of: currentLine) { _ in
            // Haptic feedback when lyric changes
            HapticManager.shared.lyricChanged()
        }
    }
}

// MARK: - Apple Music Style Lyric Line Component

struct AppleMusicLyricLineView: View {
    let lyric: String
    let index: Int
    let isCurrentLine: Bool
    let isAdjacentLine: Bool
    @ObservedObject var colorExtractor: ColorExtractor
    let namespace: Namespace.ID
    let onTap: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var shimmerOffset: CGFloat = -1
    
    var body: some View {
        Button(action: {
            // Enhanced haptic feedback
            HapticManager.shared.userCorrectedSync()
            
            // Smooth bounce animation
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                scale = 1.02
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    scale = 1.0
                }
            }
            
            onTap()
        }) {
            // Ultra-robust container for consistent line wrapping across all text types
            ZStack {
                // Invisible text that exactly matches the largest possible visible configuration
                Text(lyric)
                    .font(.system(size: baseSize, weight: .bold, design: .rounded)) // Exact same font as visible text
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                    .scaleEffect(maxTextScale) // Exact same max scale as visible text
                    .opacity(0) // Invisible but reserves exact space needed
                
                // Visible text with consistent rendering - no font changes, only scaling/opacity
                Text(lyric)
                    .font(.system(size: baseSize, weight: baseWeight, design: .rounded)) // Fixed font always
                    .foregroundStyle(foregroundStyle)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.vertical, verticalPadding)
                    .scaleEffect(textScale) // Only scaling changes for size
                    .opacity(textOpacity) // Use opacity for weight effect
                    .animation(.easeInOut(duration: 0.3), value: isCurrentLine) // Shorter, smoother animation
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(scale)
        .shadow(
            color: isCurrentLine ? .white.opacity(0.2) : .clear,
            radius: isCurrentLine ? 8 : 0,
            x: 0,
            y: 0
        )
        .animation(.easeInOut(duration: 0.3), value: isCurrentLine) // Gentler shadow animation
        .overlay(
            // Shimmer effect for current line like Apple Music
            isCurrentLine ? 
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                .white.opacity(0.4),
                                .clear
                            ],
                            startPoint: UnitPoint(x: shimmerOffset, y: 0.5),
                            endPoint: UnitPoint(x: shimmerOffset + 0.3, y: 0.5)
                        )
                    )
                    .mask(
                        Text(lyric)
                            .font(.system(size: baseSize, weight: baseWeight, design: .rounded)) // Consistent font
                            .multilineTextAlignment(.center)
                            .scaleEffect(textScale)
                    )
                : nil
        )
        .onAppear {
            if isCurrentLine {
                startShimmerAnimation()
            }
        }
        .onChange(of: isCurrentLine) { isCurrent in
            if isCurrent {
                startShimmerAnimation()
            }
        }
    }
    
    // Fixed base font size for ultra-consistent line wrapping
    private var baseSize: CGFloat {
        return 24 // Single base size for all lines
    }
    
    // Fixed base weight to prevent font rendering changes
    private var baseWeight: Font.Weight {
        return .semibold // Single weight for all text to prevent blinking
    }
    
    // Maximum scale for space reservation
    private var maxTextScale: CGFloat {
        return 1.3 // Largest scale we'll ever use
    }
    
    // Use scaling for size differences - very conservative values
    private var textScale: CGFloat {
        if isCurrentLine {
            return 1.3  // Larger scale for current line
        } else if isAdjacentLine {
            return 1.15  // Slightly larger for adjacent
        } else {
            return 1.0   // Normal scale for others
        }
    }
    
    // Use opacity instead of font weight to prevent rendering issues
    private var textOpacity: Double {
        if isCurrentLine {
            return 1.0   // Full opacity for current
        } else if isAdjacentLine {
            return 0.85  // Slightly dimmed for adjacent
        } else {
            return 0.7   // More dimmed for others
        }
    }
    
    // Legacy property kept for compatibility
    private var fontWeight: Font.Weight {
        return baseWeight // Always use base weight now
    }
    
    private var foregroundStyle: some ShapeStyle {
        // Use consistent white gradient for better international text rendering
        if isCurrentLine {
            // Bright white for current line
            return LinearGradient(
                colors: [.white, .white.opacity(0.98), .white],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            // Consistent white for all other lines (opacity handled separately)
            return LinearGradient(
                colors: [.white.opacity(0.9), .white.opacity(0.85), .white.opacity(0.9)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
    
    private var verticalPadding: CGFloat {
        // Use consistent padding to prevent height jumps
        return 18
    }
    
    private func startShimmerAnimation() {
        shimmerOffset = -1.0
        
        withAnimation(Animation.linear(duration: 2.5).repeatForever(autoreverses: false)) {
            shimmerOffset = 1.5
        }
    }
}

// MARK: - Apple Music Style Empty State Component

struct AppleMusicEmptyLyricsView: View {
    @ObservedObject var colorExtractor: ColorExtractor
    @State private var breathingScale: CGFloat = 1.0
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        VStack(spacing: 32) {
            // Animated music icon like Apple Music
            ZStack {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.2), .white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(rotationAngle))
                
                Image(systemName: "music.note")
                    .font(.system(size: 48, weight: .ultraLight))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white.opacity(0.8), .white.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(breathingScale)
            }
            
            VStack(spacing: 16) {
                Text("No Lyrics")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                
                Text("Start playing music to see\nlyrics appear here")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Breathing animation
            withAnimation(Animation.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                breathingScale = 1.1
            }
            
            // Rotation animation
            withAnimation(Animation.linear(duration: 25.0).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
        }
    }
}

// MARK: - Search Results Sheet Component

struct PremiumSearchResultView: View {
    @ObservedObject var lyricSyncManager: LyricSyncManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            GlassCard(cornerRadius: 0) {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(lyricSyncManager.searchResults) { result in
                            SearchResultRow(result: result) {
                                HapticManager.shared.buttonTapped()
                                lyricSyncManager.selectSearchResult(result)
                                dismiss()
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Choose Version")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        HapticManager.shared.impact(.touch)
                        dismiss()
                    }
                    .foregroundStyle(PremiumUI.DynamicColors.accentGradient)
                }
            }
        }
    }
}

struct SearchResultRow: View {
    let result: LrclibSearchResult
    let action: () -> Void
    
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        Button(action: {
            withAnimation(PremiumUI.Springs.snappy) {
                scale = 0.98
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(PremiumUI.Springs.bouncy) {
                    scale = 1.0
                }
            }
            
            action()
        }) {
            GlassCard(cornerRadius: 16, shadowRadius: 8, shadowOpacity: 0.08) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(result.name)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text(result.artistName)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    HStack {
                        Text(result.albumName)
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(String(format: "%.0f:%02.0f", 
                                   (result.duration / 60).rounded(.down), 
                                   result.duration.truncatingRemainder(dividingBy: 60)))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(scale)
    }
}

// MARK: - Premium iOS 18 Liquid Glass Components

/// Premium iOS 18 Liquid Glass Background with Dynamic Morphing
extension LyricCanvas {
    @available(iOS 15.0, *)
    private var liquidGlassBackground: some View {
        ZStack {
            // Base glass material using iOS 18
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .scaleEffect(morphingScale)
            
            // Dynamic refraction layer
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            .blue.opacity(0.08),
                            .purple.opacity(0.05),
                            .pink.opacity(0.08),
                            .teal.opacity(0.06)
                        ],
                        startPoint: UnitPoint(x: 0.2 + refractionPhase * 0.3, y: 0.2),
                        endPoint: UnitPoint(x: 0.8 - refractionPhase * 0.3, y: 0.8)
                    )
                )
                .opacity(liquidGlowIntensity)
                .mask(RoundedRectangle(cornerRadius: 24, style: .continuous))
            
            // Liquid glass glow overlay
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.liquidGlassStroke.opacity(liquidGlowIntensity), lineWidth: 0.5)
        }
        .onAppear {
            startLiquidGlassAnimations()
        }
    }
    
    /// Start continuous liquid glass animations
    private func startLiquidGlassAnimations() {
        // Morphing scale animation
        withAnimation(LiquidGlassMorphing.fluidMorph(duration: 4.0)) {
            morphingScale = 1.02
        }
        
        // Refraction phase animation
        withAnimation(LiquidGlassMorphing.refraction(duration: 10.0)) {
            refractionPhase = 1.0
        }
        
        // Glow intensity pulsing
        withAnimation(Animation.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
            liquidGlowIntensity = 0.8
        }
    }
}

/// Premium iOS 18 Liquid Glass Empty Lyrics View
@available(iOS 15.0, *)
struct LiquidGlassEmptyLyricsView: View {
    @ObservedObject var colorExtractor: ColorExtractor
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowIntensity: Double = 0.3
    
    var body: some View {
        VStack(spacing: 24) {
            // Animated music note icon with liquid glass effect
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle()
                            .stroke(Color.liquidGlassStroke.opacity(glowIntensity), lineWidth: 1)
                    )
                    .scaleEffect(pulseScale)
                
                Image(systemName: "music.note")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [colorExtractor.primaryColor.readableTextColor, colorExtractor.accentColor.readableTextColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 12) {
                Text("No Lyrics Loaded")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [colorExtractor.primaryColor.readableTextColor, colorExtractor.primaryColor.readableTextColor.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .multilineTextAlignment(.center)
                
                Text("Start playing music to see lyrics appear here with fluid, liquid glass animations")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(colorExtractor.primaryColor.readableTextColor.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 16)
                    .opacity(glowIntensity + 0.4)
            }
        }
        .padding(40)
        .onAppear {
            startEmptyStateAnimations()
        }
    }
    
    private func startEmptyStateAnimations() {
        // Continuous pulse animation
        withAnimation(Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            pulseScale = 1.1
        }
        
        // Glow intensity animation
        withAnimation(Animation.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
            glowIntensity = 0.7
        }
    }
}

/// Premium iOS 18 Liquid Glass Lyric Line View
@available(iOS 15.0, *)
struct LiquidGlassLyricLineView: View {
    let lyric: String
    let index: Int
    let isCurrentLine: Bool
    let isAdjacentLine: Bool
    @ObservedObject var colorExtractor: ColorExtractor
    let namespace: Namespace.ID
    let onTap: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var liquidShimmerOffset: CGFloat = -0.5
    @State private var refractionGlow: Double = 0.3
    
    private var fontSize: CGFloat {
        if isCurrentLine { return 28 } // Increased from 22
        if isAdjacentLine { return 18 }
        return 16
    }
    
    private var fontWeight: Font.Weight {
        if isCurrentLine { return .bold }
        if isAdjacentLine { return .semibold }
        return .regular
    }
    
    private var opacity: Double {
        if isCurrentLine { return 1.0 }
        if isAdjacentLine { return 0.9 }
        return 0.7
    }
    
    private var liquidGlassIntensity: Double {
        if isCurrentLine { return 0.9 }
        if isAdjacentLine { return 0.6 }
        return 0.3
    }
    
    var body: some View {
        Button(action: {
            // Liquid glass button animation
            withAnimation(LiquidGlassMorphing.entrance()) {
                scale = 1.1
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(LiquidGlassMorphing.entrance()) {
                    scale = 1.0
                }
            }
            
            onTap()
        }) {
            Text(lyric)
                .font(.system(
                    size: fontSize,
                    weight: fontWeight,
                    design: .rounded
                ))
                .foregroundStyle(
                    isCurrentLine ? 
                        LinearGradient(
                            colors: [
                                colorExtractor.primaryColor.readableTextColor,
                                colorExtractor.accentColor.readableTextColor,
                                .white.opacity(0.9),
                                colorExtractor.primaryColor.readableTextColor
                            ],
                            startPoint: UnitPoint(x: liquidShimmerOffset, y: 0),
                            endPoint: UnitPoint(x: liquidShimmerOffset + 0.3, y: 0)
                        ) : 
                        LinearGradient(
                            colors: [colorExtractor.primaryColor.readableTextColor.opacity(opacity), colorExtractor.primaryColor.readableTextColor.opacity(opacity * 0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                )
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.vertical, isCurrentLine ? 16 : 12)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(scale)
        .glassEffect(
            isCurrentLine ? .regular.tint(colorExtractor.accentColor).interactive() : .regular,
            in: .rect(cornerRadius: 12)
        )
        .glassEffectID("lyric-\(index)", in: namespace)
        .id(index)
        .onAppear {
            if isCurrentLine {
                startLiquidShimmerAnimation()
            }
        }
        .onChange(of: isCurrentLine) { oldValue, newValue in
            if newValue {
                startLiquidShimmerAnimation()
            }
        }
    }
    
    private func startLiquidShimmerAnimation() {
        // Reset shimmer position
        liquidShimmerOffset = -0.5
        
        // Liquid glass shimmer animation
        withAnimation(Animation.linear(duration: 2.0).repeatForever(autoreverses: false)) {
            liquidShimmerOffset = 1.2
        }
        
        // Refraction glow pulsing
        withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            refractionGlow = 0.8
        }
    }
}