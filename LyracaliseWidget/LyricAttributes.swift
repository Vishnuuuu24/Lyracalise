//
//  LyricAttributes.swift
//  Lyracalise
//
//  Created by Vishnu Vardhan on 13/6/25.
//

import ActivityKit
import SwiftUI

struct LyricAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var currentLyric: String
        var songTitle: String    // Moved here so we can update it!
        var artist: String       // Moved here so we can update it!
        var timestamp: Date
    }

    var appName: String = "Lyracalise" // Static identifier - never changes
    var uniqueID: String // Keep this for unique identification
}

