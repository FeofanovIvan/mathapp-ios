//
//  MathAppApp.swift
//  MathApp
//
//  Created by Ivan Feofanov on 02/01/25.
//

import SwiftUI
import Firebase
import UIKit

@main
struct MathAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    let persistenceController = PersistenceController.shared
    @StateObject private var appTimerManager = AppTimerManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            LoginView()
                .environment(\.managedObjectContext, persistenceController.firebaseContext)
                .environmentObject(appTimerManager)
                .preferredColorScheme(.light)
                .onAppear {
                    DataUpdateScheduler.performEGEUpdateIfNeeded(context: persistenceController.firebaseContext)
                    DataUpdateScheduler.performOGEUpdateIfNeeded(context: persistenceController.ogeContext)
                    DataUpdateScheduler.performGameUpdateIfNeeded() // ⬅️ игры
                }
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .active:
                print("🌱 App became active")
                appTimerManager.startTimer()
                // можно обновлять и тут — сработает защита по датам и «isDownloading»
                DataUpdateScheduler.performEGEUpdateIfNeeded(context: persistenceController.localContext)
                DataUpdateScheduler.performOGEUpdateIfNeeded(context: persistenceController.ogeContext)
            case .inactive, .background:
                print("🌙 App became inactive/background")
                appTimerManager.stopTimer()
            default:
                break
            }
        }
    }
}

import Foundation
import CoreData

class AppTimerManager: ObservableObject {
    private var startTime: Date?
    private var accumulatedTime: TimeInterval = 0

    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(resetTimer), name: .forceResetAppTimer, object: nil)
    }

    func startTimer() { startTime = Date() }

    func stopTimer() {
        guard let start = startTime else { return }
        let sessionTime = Date().timeIntervalSince(start)
        accumulatedTime += sessionTime
        startTime = nil
        saveActiveTimeToCoreData(seconds: sessionTime)
    }

    @objc private func resetTimer() {
        print("🔁 Таймер сброшен")
        startTime = nil
        accumulatedTime = 0
    }

    private func saveActiveTimeToCoreData(seconds: TimeInterval) {
        let context = PersistenceController.shared.localContext
        let fetchRequest: NSFetchRequest<AppUsageStats> = AppUsageStats.fetchRequest()

        if let usage = try? context.fetch(fetchRequest).first {
            usage.totalActiveSeconds += Int64(seconds)
        } else {
            let newUsage = AppUsageStats(context: context)
            newUsage.totalActiveSeconds = Int64(seconds)
        }

        do {
            try context.save()
        } catch {
            print("❌ Failed to save usage time: \(error.localizedDescription)")
        }
    }
}

extension Notification.Name {
    static let forceResetAppTimer = Notification.Name("ForceResetAppTimer")
}
