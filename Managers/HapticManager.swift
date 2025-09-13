import UIKit
import CoreHaptics

/// Premium haptic feedback system with silk-smooth vibrations
/// Designed to feel like Apple-level interactions
@MainActor
class HapticManager: ObservableObject {
    static let shared = HapticManager()
    
    private var hapticEngine: CHHapticEngine?
    private var supportsHaptics: Bool
    
    // Intensity levels (0.0 - 1.0) for different interaction types
    enum HapticLevel {
        case whisper    // 0.1 - Barely noticeable, like a gentle breath
        case touch      // 0.3 - Soft tap, like touching silk
        case press      // 0.5 - Medium press, satisfying confirmation
        case success    // 0.7 - Success feedback, warm and pleasant
        case emphasis   // 0.9 - Strong but refined, like a firm handshake
        case critical   // 1.0 - Emergency only, sharp but controlled
        
        var intensity: Float {
            switch self {
            case .whisper: return 0.1
            case .touch: return 0.3
            case .press: return 0.5
            case .success: return 0.7
            case .emphasis: return 0.9
            case .critical: return 1.0
            }
        }
        
        var sharpness: Float {
            switch self {
            case .whisper: return 0.2   // Very soft edges
            case .touch: return 0.3     // Gentle rounded feel
            case .press: return 0.4     // Balanced sharpness
            case .success: return 0.6   // Crisp but pleasant
            case .emphasis: return 0.8  // Sharp and definitive
            case .critical: return 1.0  // Maximum clarity
            }
        }
    }
    
    // Haptic patterns for different interactions
    enum HapticPattern {
        case lyricChange        // Smooth pulse when lyric changes
        case buttonPress        // Satisfying button tap
        case buttonRelease      // Gentle release feedback
        case syncCorrection     // When user taps to resync
        case loadingComplete    // Success pattern when lyrics load
        case startSession       // Beginning of lyric session
        case endSession         // End of session
        case pause              // When music pauses
        case resume             // When music resumes
        case error              // Gentle error indication
        case heartbeat          // Rhythmic pulse with music
    }
    
    private init() {
        supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        
        guard supportsHaptics else {
            print("[HapticManager] 🚫 Haptics not supported on this device")
            return
        }
        
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
            print("[HapticManager] ✅ Premium haptic engine initialized")
            
            // Handle engine reset scenarios
            hapticEngine?.resetHandler = { [weak self] in
                print("[HapticManager] 🔄 Haptic engine reset")
                do {
                    try self?.hapticEngine?.start()
                } catch {
                    print("[HapticManager] ❌ Failed to restart haptic engine: \(error)")
                }
            }
            
            // Handle engine stopped scenarios
            hapticEngine?.stoppedHandler = { reason in
                print("[HapticManager] ⏹️ Haptic engine stopped: \(reason)")
            }
            
        } catch {
            print("[HapticManager] ❌ Failed to create haptic engine: \(error)")
            hapticEngine = nil
        }
    }
    
    // MARK: - Simple Haptic Feedback (UIKit fallback)
    
    /// Silk-smooth impact feedback
    func impact(_ level: HapticLevel) {
        guard supportsHaptics else { return }
        
        // Use Core Haptics if available, fallback to UIKit
        if hapticEngine != nil {
            playCustomImpact(intensity: level.intensity, sharpness: level.sharpness)
        } else {
            // UIKit fallback with intensity mapping
            let style: UIImpactFeedbackGenerator.FeedbackStyle
            switch level {
            case .whisper, .touch:
                style = .light
            case .press, .success:
                style = .medium
            case .emphasis, .critical:
                style = .heavy
            }
            
            let generator = UIImpactFeedbackGenerator(style: style)
            generator.prepare()
            generator.impactOccurred(intensity: CGFloat(level.intensity))
        }
    }
    
    /// Notification feedback for success/error states
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
    
    /// Selection feedback for UI interactions
    func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
    
    // MARK: - Premium Core Haptics Patterns
    
    /// Play a specific haptic pattern with premium feel
    func play(_ pattern: HapticPattern) {
        guard supportsHaptics, let engine = hapticEngine else {
            // Fallback to UIKit for unsupported devices
            playUIKitFallback(for: pattern)
            return
        }
        
        do {
            let hapticPattern = try createPattern(for: pattern)
            let player = try engine.makePlayer(with: hapticPattern)
            try player.start(atTime: 0)
        } catch {
            print("[HapticManager] ❌ Failed to play pattern \(pattern): \(error)")
            playUIKitFallback(for: pattern)
        }
    }
    
    /// Create custom haptic patterns that feel like silk
    private func createPattern(for pattern: HapticPattern) throws -> CHHapticPattern {
        var events: [CHHapticEvent] = []
        
        switch pattern {
        case .lyricChange:
            // Gentle pulse like a heartbeat
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                ],
                relativeTime: 0
            ))
            
        case .buttonPress:
            // Satisfying button press with quick attack
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                ],
                relativeTime: 0
            ))
            
        case .buttonRelease:
            // Gentle release feedback
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                ],
                relativeTime: 0
            ))
            
        case .syncCorrection:
            // Double tap pattern for sync correction
            events.append(contentsOf: [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                    ],
                    relativeTime: 0.1
                )
            ])
            
        case .loadingComplete:
            // Success celebration pattern
            events.append(contentsOf: [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                    ],
                    relativeTime: 0.15
                )
            ])
            
        case .startSession:
            // Warm startup pattern
            events.append(CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                ],
                relativeTime: 0,
                duration: 0.2
            ))
            
        case .endSession:
            // Gentle fade out
            events.append(CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                ],
                relativeTime: 0,
                duration: 0.3
            ))
            
        case .pause:
            // Single gentle tap
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                ],
                relativeTime: 0
            ))
            
        case .resume:
            // Double gentle tap to indicate restart
            events.append(contentsOf: [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                    ],
                    relativeTime: 0.08
                )
            ])
            
        case .error:
            // Gentle error indication (not harsh)
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
                ],
                relativeTime: 0
            ))
            
        case .heartbeat:
            // Rhythmic pulse pattern
            events.append(contentsOf: [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.2),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                    ],
                    relativeTime: 0.6
                )
            ])
        }
        
        return try CHHapticPattern(events: events, parameters: [])
    }
    
    /// Custom impact with precise intensity and sharpness control
    private func playCustomImpact(intensity: Float, sharpness: Float) {
        guard let engine = hapticEngine else { return }
        
        do {
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                ],
                relativeTime: 0
            )
            
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("[HapticManager] ❌ Failed to play custom impact: \(error)")
        }
    }
    
    /// UIKit fallback for devices without Core Haptics
    private func playUIKitFallback(for pattern: HapticPattern) {
        switch pattern {
        case .lyricChange:
            impact(.touch)
        case .buttonPress:
            impact(.press)
        case .buttonRelease:
            impact(.touch)
        case .syncCorrection:
            impact(.press)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.impact(.touch)
            }
        case .loadingComplete:
            notification(.success)
        case .startSession:
            impact(.success)
        case .endSession:
            impact(.touch)
        case .pause:
            impact(.touch)
        case .resume:
            impact(.press)
        case .error:
            notification(.error)
        case .heartbeat:
            impact(.whisper)
        }
    }
}

// MARK: - Convenience Extensions

extension HapticManager {
    /// Quick access to common haptic patterns
    func lyricChanged() { play(.lyricChange) }
    func buttonTapped() { play(.buttonPress) }
    func buttonReleased() { play(.buttonRelease) }
    func userCorrectedSync() { play(.syncCorrection) }
    func lyricsLoaded() { play(.loadingComplete) }
    func sessionStarted() { play(.startSession) }
    func sessionEnded() { play(.endSession) }
    func musicPaused() { play(.pause) }
    func musicResumed() { play(.resume) }
    func errorOccurred() { play(.error) }
    func rhythmPulse() { play(.heartbeat) }
}