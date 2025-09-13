//
//  LyracaliseApp.swift
//  Lyracalise
//
//  Created by Vishnu Vardhan on 23/6/25.
//

import SwiftUI
import BackgroundTasks

@main
struct LyracaliseApp: App {
    init() {
        // Register background tasks on app launch
        BackgroundTaskScheduler.shared.registerBackgroundTasks()
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    // Schedule background refresh when app goes to background
                    BackgroundTaskScheduler.shared.scheduleBackgroundRefresh()
                }
        }
    }
}

// MARK: - Background Session Handling
extension LyracaliseApp {
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        if identifier == "com.vishnu.lyracalise.background" {
            // This ensures background URL sessions work when app is force-closed
            completionHandler()
        }
    }
}
