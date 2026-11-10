//
//  UFoodApp.swift
//  UFood
//
//  Created by Михаил Позур on 10.11.2026.
//

import SwiftUI
import SwiftData
import Foundation

@main
struct UFoodApp: App {
    @State private var healthKitManager = HealthKitManager()
    @State private var foodPresetStore = FoodPresetStore()
    @AppStorage(AppStorageKey.language) private var selectedLanguageRaw = AppLanguage.system.rawValue

    private var language: AppLanguage { .resolved(from: selectedLanguageRaw) }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Product.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(healthKitManager)
                .environment(foodPresetStore)
                .environment(\.locale, language.locale ?? Locale.current)
        }
        .modelContainer(sharedModelContainer)
    }
}
