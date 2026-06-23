//
//  SlateApp.swift
//  Slate
//
//  Created by Thineth Shehara on 2026-02-07.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct SlateApp: App {
    init() {
        let fileManager = FileManager.default
        if let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            if !fileManager.fileExists(atPath: appSupportURL.path) {
                try? fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true, attributes: nil)
            }
        }
        
        // Request local notification authorization on launch
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [SlateModel.self])
    }
}
