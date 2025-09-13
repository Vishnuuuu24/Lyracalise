# Lyracalise

**Real-time Lyrics for Your Music Experience**

Lyracalise is a premium iOS app that displays synchronized lyrics for your currently playing music. Built with modern SwiftUI and featuring Apple Music-inspired design, it provides seamless lyric synchronization with beautiful animations and intelligent caching.

## ✨ Features

### 🎵 Smart Lyric Sync
- **Real-time synchronization** with any playing music
- **Automatic song detection** from Spotify and other apps
- **Intelligent fallback system** with multiple lyric sources
- **Manual sync adjustment** by tapping any lyric line

### 🎨 Premium Design
- **Apple Music-inspired UI** with glassmorphism effects
- **Dynamic backgrounds** that adapt to album artwork
- **Smooth animations** with 60fps performance
- **Dark/Light mode** automatic adaptation

### 📱 iOS Native Integration
- **Live Activities** on Lock Screen and Dynamic Island
- **Home Screen Widgets** in all sizes (small, medium, large, extra large)
- **Background sync** support with extended execution time
- **Haptic feedback** for enhanced user experience

### 🧠 Intelligent Caching
- **30-day smart caching** system for frequently played songs
- **Last-access-time tracking** keeps popular songs cached
- **Automatic cleanup** of unused lyrics
- **Offline access** to cached content

### 🔒 Privacy & Security
- **No personal data collection** or tracking
- **Secure credential storage** using iOS Keychain
- **Local-first architecture** with encrypted caching
- **Privacy-safe location usage** for background execution only

## 🛠 Technical Specifications

- **Platform:** iOS 16.0+
- **Framework:** SwiftUI, ActivityKit, WidgetKit
- **Architecture:** MVVM with Combine
- **Storage:** Core Data + iOS Keychain
- **Networking:** URLSession with secure token management
- **Performance:** Memory-efficient with smart caching

## 📦 Version History

### v1.0 - App Store Ready
- ✅ **Premium UI/UX** with glassmorphism design
- ✅ **Smart caching system** with 30-day retention
- ✅ **Complete iOS integration** (widgets, live activities)
- ✅ **Security hardening** with proper credential management
- ✅ **App Store compliance** with privacy descriptions
- ✅ **Error handling** and user-friendly messaging
- ✅ **Performance optimization** for smooth experience

### Previous Versions
- **v0.4.5:** All widget sizes & flawless live activity lifecycle
- **v0.4.4:** Polished widgets with instant live activity
- **v0.4.3:** Home screen widgets & glassy UI introduction
- **v0.4.1:** Local-first engine with auto-sync capabilities
- **v0.3:** UI overhaul with plain lyrics support
- **v0.2:** Improved Live Activity UI and consistency

## 🚀 Getting Started

1. **Prerequisites:**
   - iOS 16.0 or later
   - Spotify account (recommended)
   - Xcode 15+ for development

2. **Installation:**
   ```bash
   git clone https://github.com/Vishnuuuu24/Lyracalise.git
   cd Lyracalise
   open Lyracalise.xcodeproj
   ```

3. **Configuration:**
   - Update `SpotifyConfiguration.swift` with your API credentials
   - Ensure proper signing certificates are configured
   - Build and run on device for full functionality

## 📋 App Store Readiness

### ✅ Completed
- [x] Privacy usage descriptions
- [x] Secure credential configuration
- [x] Smart caching implementation
- [x] Premium UI with glassmorphism
- [x] Complete iOS widget integration
- [x] Background execution optimization
- [x] Proper .gitignore setup
- [x] Security audit completion

### 🔄 In Progress
- [ ] App icon creation (1024x1024)
- [ ] App Store screenshots
- [ ] App Store metadata finalization

### 📝 Documentation
- See `APP_STORE_GUIDE.md` for detailed App Store submission guidance
- Review privacy policy requirements for your region
- Ensure compliance with local app store guidelines

## 🤝 Contributing

This project is primarily for personal use and App Store submission. For development:
1. Fork the repository
2. Create a feature branch
3. Test thoroughly on device
4. Submit pull request with detailed description

## 📄 License

Private project for personal use and App Store distribution.

## 🔗 Links

- **Repository:** [github.com/Vishnuuuu24/Lyracalise](https://github.com/Vishnuuuu24/Lyracalise)
- **Developer:** [@Vishnuuuu24](https://github.com/Vishnuuuu24)

---

*Built with ❤️ using SwiftUI and modern iOS technologies***v0.3: UI Overhaul & Bug Fixes**
- **Plain Lyrics UI:** Completely redesigned the interface for non-synced lyrics. It now features a large, scrollable card that expands to fill the screen, providing a much better reading experience for full song lyrics.
- **Visual Polish:** Added a fade-out effect to the top and bottom of the scrolling lyrics, ensuring the text doesn't cut off abruptly. Updated the font to be cleaner and more readable.
- **Scraping Fix:** Corrected a significant bug in the lyric fetching logic that was causing special characters (like quotes and apostrophes) to display as garbled HTML entities. Lyrics are now clean and correctly formatted.
- **Code Health:** Resolved several API deprecation warnings related to `ActivityKit` and removed redundant code to improve stability.

---
**Version: v0.4.1**

Lyracalise is a personal-use iOS app that displays synced lyrics for the currently playing song from any music app. It features a robust, local-first sync engine and an intelligent fallback system for online lyric fetching.

- **Local & Online:** Prioritizes a local `Lyrics/` folder and falls back to a powerful multi-source online search.
- **Engine:** Real-time sync engine driven by precise player timing.
- **UI:** Interactive, Apple Music-style scrolling lyrics with tap-to-sync functionality.
- **Auto-Sync:** Can automatically generate timings for plain, unsynced lyrics.
- **Compatibility:** Built with SwiftUI and ActivityKit for iOS 17+.

---

**v0.4.1: The Local-First Engine & Auto-Sync**
- **Local Lyrics Database:** The app now runs on a local-first model, prioritizing `.lrc` files from a user-provided `Lyrics/` folder for instant, offline access.
- **Intelligent Web Search:** If a local file isn't found, the app automatically queries multiple high-quality web APIs (like lrclib.net and NetEase) for synced `.lrc` files.
- **Auto-Sync Engine:** As a final fallback, the app can fetch plain lyrics from Genius and use a new on-the-fly engine to generate estimated timings based on song duration and word count.
- **Interactive UI:** The UI has been completely rebuilt into an Apple Music-style scrolling view. It highlights the current line and allows the user to tap any lyric to manually resync playback.
- **Robust Fallbacks:** Greatly improved the parsing of manual search queries and fixed numerous networking bugs. The app now gracefully handles cases where song duration is unavailable by displaying clean, scrollable static lyrics.

---
**Version: v0.4.3**

Lyracalise is a personal-use iOS app that displays synced lyrics for the currently playing song from any music app. It features a robust, local-first sync engine and an intelligent fallback system for online lyric fetching.

---

**v0.4.3: Home Screen Widget & Glassy UI**
- **Home Screen Widget:** Add a beautiful, glassy widget for medium and large sizes that displays the current lyric, song, and artist in real time, using App Group data sharing.
- **Glassy Backgrounds:** Both the widget and live activity now use a fully transparent, system glass background for a modern look.
- **Live Activity Improvements:** Live activity now matches the widget's style and only one is ever active at a time.
- **Auto Font Fitting:** All text in the widget auto-adjusts to fit perfectly, never overlapping or truncating.
- **Bug Fixes & Polish:** Improved reliability, fixed background warnings, and ensured seamless data updates between app and widget.

---

**v0.4.4: Polished Widgets & Live Activity**
- **Instant Live Activity:** Live activity now starts automatically as soon as the app opens, always ready to display lyrics.
- **Widget & Live Activity Reset:** Both reset to display only the app name when the app is stopped or terminated—no more stale or leftover data.
- **No Stale Data:** Widgets never show old song/artist info after reinstall or stop; always clean and up-to-date.
- **Glassy, Modern UI:** Both widget and live activity use a fully transparent, system glass background for a premium look.
- **Auto Font Fitting:** All text auto-adjusts to fit perfectly, never overlapping or truncating.
- **Robust Song Detection:** The app actively detects and displays the currently playing song on launch, not just a placeholder.
- **One-Tap Stop:** A single Stop button ends all live activities and resets everything instantly.

---

**v0.4.5: All Widget Sizes & Flawless Live Activity**
- **All Widget Sizes:** Widgets now support every size—small, medium, large, extra large, and all Lock Screen/complication types. Add Lyracalise anywhere!
- **Perfect Live Activity Lifecycle:** Live activity never stacks, always restarts for each new song, and disappears cleanly when a song ends.
- **Flawless Stop/Start:** Stop truly halts all lyric syncing and widget/live activity updates; Start resumes instantly from the current Spotify state.
- **Background & Lock Support:** Lyrics, widgets, and live activities keep updating even when the app is backgrounded or the phone is locked (as long as iOS allows).
- **All Previous Features:**
    - Instant live activity on app open
    - Widget & live activity reset on stop/terminate
    - No stale data ever
    - Glassy, modern UI
    - Auto font fitting
    - Robust song detection
    - One-tap Stop

---
