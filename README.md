# Lyracalise

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