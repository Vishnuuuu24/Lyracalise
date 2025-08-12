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
        var timestamp: Date
    }

    var songTitle: String
    var artist: String
}

