# Lyracalise

**Version: v0.3**

Lyracalise is a personal-use iOS app that displays synced lyrics for the currently playing Apple Music track. It features a modern, minimal UI and shows live lyrics on the app screen, Lock Screen, and Dynamic Island using Live Activities. The lyric display is always visually consistent and adapts to any lyric length.

- Built with SwiftUI and ActivityKit
- No music playback, only lyric sync
- Designed for iOS 17+ (tested on iOS 17/18 betas)
- Not for App Store distribution

---

**v0.3: UI Overhaul & Bug Fixes**
- **Plain Lyrics UI:** Completely redesigned the interface for non-synced lyrics. It now features a large, scrollable card that expands to fill the screen, providing a much better reading experience for full song lyrics.
- **Visual Polish:** Added a fade-out effect to the top and bottom of the scrolling lyrics, ensuring the text doesn't cut off abruptly. Updated the font to be cleaner and more readable.
- **Scraping Fix:** Corrected a significant bug in the lyric fetching logic that was causing special characters (like quotes and apostrophes) to display as garbled HTML entities. Lyrics are now clean and correctly formatted.
- **Code Health:** Resolved several API deprecation warnings related to `ActivityKit` and removed redundant code to improve stability. 