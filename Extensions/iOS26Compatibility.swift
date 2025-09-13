import SwiftUI

// MARK: - Premium Glass Design System
// Advanced glass morphism effects using iOS 18 materials

/// Premium Glass Container using iOS 18 materials
struct LiquidGlassContainer<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// Enhanced Material effects using iOS 18 capabilities
extension View {
    @available(iOS 15.0, *)
    func liquidGlassBackground() -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .background(
                // Additional glass effects using iOS 18 materials
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.1),
                                .white.opacity(0.05),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                // Subtle refraction overlay
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.2),
                                .white.opacity(0.1),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
    }
}

/// iOS 18 Premium Design Colors
@available(iOS 15.0, *)
extension Color {
    /// Enhanced glass tint colors for premium iOS 18 design
    static let liquidGlassTint = Color.white.opacity(0.1)
    static let liquidGlassStroke = Color.white.opacity(0.2)
    static let liquidGlassGlow = Color.white.opacity(0.3)
}

/// Advanced glass effects using iOS 18 materials
@available(iOS 15.0, *)
struct LiquidGlassEffect: ViewModifier {
    @State private var refractionOffset: CGFloat = 0
    @State private var glowIntensity: Double = 0.3
    
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .background(
                // Dynamic refraction layer
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.liquidGlassTint,
                                Color.liquidGlassTint.opacity(0.5),
                                Color.clear
                            ],
                            startPoint: UnitPoint(x: 0.2 + refractionOffset * 0.1, y: 0.2),
                            endPoint: UnitPoint(x: 0.8 + refractionOffset * 0.1, y: 0.8)
                        )
                    )
                    .opacity(glowIntensity)
            )
            .overlay(
                // Animated border glow
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        Color.liquidGlassStroke.opacity(glowIntensity),
                        lineWidth: 0.5
                    )
            )
            .onAppear {
                // Continuous refraction animation
                withAnimation(Animation.linear(duration: 8.0).repeatForever(autoreverses: false)) {
                    refractionOffset = 1.0
                }
                
                // Subtle glow pulsing
                withAnimation(Animation.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                    glowIntensity = 0.6
                }
            }
    }
}

@available(iOS 15.0, *)
extension View {
    /// Apply liquid glass effect
    func liquidGlassStyle() -> some View {
        self.modifier(LiquidGlassEffect())
    }
}

/// Premium morphing animations using iOS 18 capabilities
@available(iOS 15.0, *)
enum LiquidGlassMorphing {
    
    /// Creates a fluid morphing animation
    static func fluidMorph(duration: Double = 3.0) -> Animation {
        Animation.timingCurve(0.2, 0.8, 0.2, 1.0, duration: duration)
            .repeatForever(autoreverses: true)
    }
    
    /// Creates a refraction animation
    static func refraction(duration: Double = 8.0) -> Animation {
        Animation.linear(duration: duration)
            .repeatForever(autoreverses: false)
    }
    
    /// Creates an entrance animation with premium feel
    static func entrance(delay: Double = 0.0) -> Animation {
        Animation.interpolatingSpring(
            mass: 1.0,
            stiffness: 100,
            damping: 20,
            initialVelocity: 0
        ).delay(delay)
    }
}

/// Premium Glass Button using iOS 18 materials
@available(iOS 15.0, *)
struct LiquidGlassButtonEffect: ButtonStyle {
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                // Dynamic highlight on press
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.2 : 0.1))
                    .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            )
    }
}

/// Premium Glass Card using iOS 18 materials
@available(iOS 15.0, *)
struct LiquidGlassCard<Content: View>: View {
    let content: Content
    @State private var morphScale: CGFloat = 1.0
    @State private var refractionPhase: Double = 0
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .background(
                // Morphing background layer
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.1),
                                Color.white.opacity(0.05),
                                Color.clear
                            ],
                            startPoint: UnitPoint(x: 0.2 + refractionPhase * 0.3, y: 0.2),
                            endPoint: UnitPoint(x: 0.8 - refractionPhase * 0.3, y: 0.8)
                        )
                    )
                    .scaleEffect(morphScale)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
            )
            .onAppear {
                // Continuous morphing
                withAnimation(LiquidGlassMorphing.fluidMorph()) {
                    morphScale = 1.02
                }
                
                // Refraction phase animation
                withAnimation(LiquidGlassMorphing.refraction()) {
                    refractionPhase = 1.0
                }
            }
    }
}