import SwiftUI

/// Premium Glass Privacy Education View
struct PrivacyEducationView: View {
    @Binding var isPresented: Bool
    @StateObject private var locationManager = PrivacyLocationManager()
    @State private var currentStep = 0
    @State private var liquidGlassIntensity: Double = 0.8
    @State private var refractionOffset: CGFloat = 0
    @State private var morphingScale: CGFloat = 1.0
    @State private var glowIntensity: Double = 0.3
    @State private var animationOffset: CGFloat = 0
    
    private let steps = [
        PrivacyStep(
            icon: "shield.fill",
            title: "Privacy First",
            description: "Lyracalise is designed with your privacy in mind. We don't collect or store any personal data.",
            color: .blue
        ),
        PrivacyStep(
            icon: "location.fill",
            title: "Background Sync",
            description: "For extended background lyric sync, you can optionally enable location services. This helps keep the app alive longer.",
            color: .green
        ),
        PrivacyStep(
            icon: "checkmark.shield.fill",
            title: "Your Choice",
            description: "Background location is completely optional. The app works great either way!",
            color: .purple
        )
    ]
    
    var body: some View {
        ZStack {
            // Premium Glass Background Container
            LiquidGlassContainer {
                ZStack {
                    // Base glass layer using iOS 18 materials
                    Color.clear
                        .background(.ultraThinMaterial)
                    
                    // Dynamic refraction overlay
                    LinearGradient(
                        colors: [
                            Color(.systemBlue).opacity(0.08),
                            Color(.systemPurple).opacity(0.05),
                            Color(.systemTeal).opacity(0.08),
                            Color(.systemPink).opacity(0.04)
                        ],
                        startPoint: UnitPoint(x: 0.2 + refractionOffset * 0.3, y: 0.2),
                        endPoint: UnitPoint(x: 0.8 - refractionOffset * 0.3, y: 0.8)
                    )
                    .opacity(liquidGlassIntensity)
                    .scaleEffect(morphingScale)
                    
                    // Fluid animation overlay
                    FluidAnimationOverlay(phase: refractionOffset)
                        .opacity(0.4)
                }
            }
            .ignoresSafeArea()
            .onAppear {
                startLiquidGlassAnimations()
            }
            
            VStack(spacing: 32) {
                // Premium Glass Header
                VStack(spacing: 16) {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "music.note.house")
                                .font(.system(size: 32, weight: .light))
                                .foregroundStyle(PremiumUI.DynamicColors.accentGradient)
                        )
                        .shadow(color: .blue.opacity(0.3), radius: 15, x: 0, y: 8)
                        .scaleEffect(1.0 + glowIntensity * 0.1)
                    
                    Text("Welcome to Lyracalise")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                }
                
                // Step content
                TabView(selection: $currentStep) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        PrivacyStepView(step: step)
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
                .frame(height: 300)
                
                // Navigation buttons
                HStack(spacing: 16) {
                    if currentStep > 0 {
                        PremiumButton(
                            title: "Back",
                            systemImage: "chevron.left",
                            action: {
                                withAnimation(PremiumUI.Springs.smooth) {
                                    currentStep -= 1
                                }
                            },
                            style: .secondary
                        )
                        .frame(maxWidth: 120)
                    }
                    
                    Spacer()
                    
                    if currentStep < steps.count - 1 {
                        PremiumButton(
                            title: "Next",
                            systemImage: "chevron.right",
                            action: {
                                withAnimation(PremiumUI.Springs.smooth) {
                                    currentStep += 1
                                }
                            },
                            style: .primary
                        )
                        .frame(maxWidth: 120)
                    } else {
                        PremiumButton(
                            title: "Get Started",
                            systemImage: "checkmark",
                            action: {
                                HapticManager.shared.lyricsLoaded()
                                locationManager.requestLocationPermissionForBackgroundExecution()
                                isPresented = false
                            },
                            style: .accent
                        )
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            // Background flow animation
            withAnimation(Animation.linear(duration: 12.0).repeatForever(autoreverses: false)) {
                animationOffset = 1.0
            }
            
            // Glow pulse animation
            withAnimation(Animation.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                glowIntensity = 1.0
            }
        }
        .interactiveDismissDisabled(true)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Check if permission was granted in Settings
            if locationManager.hasBackgroundLocationPermission {
                isPresented = false
            }
        }
    }
    
    // MARK: - Premium Glass Animations
    
    private func startLiquidGlassAnimations() {
        // Morphing scale animation
        withAnimation(LiquidGlassMorphing.fluidMorph(duration: 4.0)) {
            morphingScale = 1.03
        }
        
        // Refraction animation
        withAnimation(LiquidGlassMorphing.refraction(duration: 12.0)) {
            refractionOffset = 1.0
        }
        
        // Liquid glass intensity pulsing
        withAnimation(Animation.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) {
            liquidGlassIntensity = 0.95
        }
    }
}

struct PrivacyStep {
    let icon: String
    let title: String
    let description: String
    let color: Color
}

struct PrivacyStepView: View {
    let step: PrivacyStep
    @State private var iconScale: CGFloat = 0.8
    @State private var contentOpacity: Double = 0
    
    var body: some View {
        GlassCard(cornerRadius: 24, shadowRadius: 20, shadowOpacity: 0.15) {
            VStack(spacing: 24) {
                // Icon
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 100, height: 100)
                    .overlay(
                        Image(systemName: step.icon)
                            .font(.system(size: 40, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [step.color, step.color.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .shadow(color: step.color.opacity(0.3), radius: 12, x: 0, y: 6)
                    .scaleEffect(iconScale)
                
                VStack(spacing: 16) {
                    Text(step.title)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text(step.description)
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .opacity(contentOpacity)
            }
            .padding(24)
        }
        .onAppear {
            withAnimation(PremiumUI.Springs.bouncy.delay(0.2)) {
                iconScale = 1.0
            }
            
            withAnimation(PremiumUI.Springs.smooth.delay(0.4)) {
                contentOpacity = 1.0
            }
        }
    }
}

// Legacy components for compatibility
struct PrivacyFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
                .flexibleFrame(maxHeight: .infinity, alignment: .top)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
        }
    }
}

extension View {
    func flexibleFrame(maxWidth: CGFloat? = nil, maxHeight: CGFloat? = nil, alignment: Alignment = .center) -> some View {
        frame(maxWidth: maxWidth, maxHeight: maxHeight, alignment: alignment)
    }
}

#Preview {
    PrivacyEducationView(isPresented: .constant(true))
}