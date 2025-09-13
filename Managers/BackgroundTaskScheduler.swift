//
//  BackgroundTaskScheduler.swift
//  Lyracalise
//
//  Created by Vishnu Vardhan on 12/9/25.
//

import Foundation
import BackgroundTasks
import UIKit
import WidgetKit

/// Schedules background tasks for maintaining real-time updates like Uber/Swiggy
class BackgroundTaskScheduler {
    static let shared = BackgroundTaskScheduler()
    
    private let backgroundTaskIdentifier = "com.vishnu.lyracalise.refresh"
    
    private init() {}
    
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { task in
            self.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
        }
    }
    
    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15) // 15 seconds from now
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background refresh scheduled successfully")
        } catch {
            print("Could not schedule background refresh: \(error)")
        }
    }
    
    private func handleBackgroundRefresh(task: BGAppRefreshTask) {
        // Schedule the next background refresh
        scheduleBackgroundRefresh()
        
        // Set expiration handler
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        // Fetch current track in background
        BackgroundSessionManager.shared.fetchCurrentTrackInBackground { track in
            if let track = track {
                // Update shared data for widgets
                if let sharedDefaults = UserDefaults(suiteName: "group.com.vishnu.lyracalise") {
                    sharedDefaults.set(track.name, forKey: "songTitle")
                    sharedDefaults.set(track.artist, forKey: "artist")
                    
                    // You could also update lyric here if needed
                    // For now, we'll rely on the main app for lyric sync
                }
                
                // Notify widgets to update
                WidgetCenter.shared.reloadAllTimelines()
            }
            
            task.setTaskCompleted(success: track != nil)
        }
    }
}
