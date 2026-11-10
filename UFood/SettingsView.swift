//
//  SettingsView.swift
//  UFood
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(HealthKitManager.self) private var healthKit
    @AppStorage(AppStorageKey.theme) private var selectedPresetRaw = ColorPreset.oceanMint.rawValue
    @AppStorage(AppStorageKey.aiProvider) private var selectedAIProviderRaw = AIAssistant.Provider.chatGPT.rawValue
    @AppStorage(AppStorageKey.language) private var selectedLanguageRaw = AppLanguage.system.rawValue
    @AppStorage(AppStorageKey.displayName) private var displayName = ""
    @Query private var todaysProducts: [Product]

    private var theme: ColorPreset { .resolved(from: selectedPresetRaw) }
    private var aiProvider: AIAssistant.Provider { .resolved(from: selectedAIProviderRaw) }
    private var language: AppLanguage { .resolved(from: selectedLanguageRaw) }
    private var gainedKcal: Int { CalorieMath.totalRounded(of: todaysProducts) }
    private var burnedKcal: Int { healthKit.totalBurnedKcal ?? 0 }
    private var netKcal: Int { gainedKcal - burnedKcal }

    init() {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        _todaysProducts = Query(
            filter: #Predicate<Product> { $0.timestamp >= startOfToday },
            sort: [SortDescriptor(\Product.timestamp, order: .reverse)]
        )
    }

    var body: some View {
        List {
            profileSection
            energySection
            themesSection
            aiProviderSection
            languageSection
        }
        .navigationTitle("Settings")
        .tint(theme.primary)
        .task { await healthKit.refreshIfNeeded() }
        .refreshable { await healthKit.refreshToday() }
    }

    private var profileSection: some View {
        Section("Profile") {
            TextField("Your name", text: $displayName)
                .textInputAutocapitalization(.words)

            if healthKit.isAvailable {
                Button {
                    Task { await healthKit.requestAuthorization() }
                } label: {
                    HStack {
                        Label(
                            healthKit.isAuthorized ? "Apple Health Connected" : "Connect Apple Health",
                            systemImage: healthKit.isAuthorized ? "heart.fill" : "heart"
                        )
                        Spacer()
                        if healthKit.isLoading {
                            ProgressView()
                        }
                    }
                }
            } else {
                Label("Apple Health unavailable", systemImage: "heart.slash")
                    .foregroundStyle(.secondary)
            }

            if let statusMessage = healthKit.statusMessage {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var energySection: some View {
        Section {
            EnergyStatRow(
                title: "Gained",
                subtitle: "Food logged in UFood",
                value: gainedKcal,
                tint: theme.primary
            )
            EnergyStatRow(
                title: "Burned",
                subtitle: burnedSubtitle,
                value: healthKit.isAuthorized ? burnedKcal : nil,
                tint: theme.accent
            )

            if healthKit.isAuthorized {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Net")
                            .font(.headline)
                        Text(netSubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(CalorieMath.signedKcal(netKcal))
                        .font(.title2.weight(.bold).monospacedDigit())
                        .foregroundStyle(netKcal >= 0 ? theme.primary : theme.end)
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Today’s Energy")
        } footer: {
            Text("Net = gained − burned. Positive means surplus, negative means deficit.")
        }
    }

    private var themesSection: some View {
        Section("Themes") {
            ForEach(ColorPreset.allCases) { preset in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedPresetRaw = preset.rawValue
                    }
                } label: {
                    HStack(spacing: 14) {
                        ColorPresetSwatch(preset: preset)
                        Text(preset.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                        if theme == preset {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(preset.brandGradient)
                                .font(.title3)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var aiProviderSection: some View {
        Section("AI Provider") {
            ForEach(AIAssistant.Provider.allCases) { provider in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedAIProviderRaw = provider.rawValue
                    }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.primary)
                        Text(provider.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                        if aiProvider == provider {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(theme.primary)
                                .font(.title3)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var languageSection: some View {
        Section("Language") {
            ForEach(AppLanguage.allCases) { lang in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedLanguageRaw = lang.rawValue
                    }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "globe")
                            .foregroundStyle(.primary)
                        Text(lang.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                        if language == lang {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(theme.primary)
                                .font(.title3)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var burnedSubtitle: String {
        guard healthKit.isAuthorized else { return "Connect Apple Health to load" }
        return "Active \(healthKit.activeBurnedKcal ?? 0) · Resting \(healthKit.restingBurnedKcal ?? 0)"
    }

    private var netSubtitle: String {
        switch netKcal {
        case 1...: "Calorie surplus"
        case ..<0: "Calorie deficit"
        default: "Balanced"
        }
    }
}

private struct EnergyStatRow: View {
    let title: String
    let subtitle: String
    let value: Int?
    let tint: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Group {
                if let value {
                    Text("\(value) kcal")
                        .foregroundStyle(tint)
                } else {
                    Text("—")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.title3.weight(.semibold).monospacedDigit())
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(HealthKitManager())
    .modelContainer(for: Product.self, inMemory: true)
}
