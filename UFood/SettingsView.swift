//
//  SettingsView.swift
//  UFood
//

import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(HealthKitManager.self) private var healthKit
    @Environment(DayTracker.self) private var dayTracker
    @AppStorage(AppStorageKey.theme) private var selectedPresetRaw = ColorPreset.oceanMint.rawValue
    @AppStorage(AppStorageKey.aiProvider) private var selectedAIProviderRaw = AIAssistant.Provider
        .chatGPT.rawValue
    @AppStorage(AppStorageKey.language) private var selectedLanguageRaw = AppLanguage.system.rawValue
    @AppStorage(AppStorageKey.displayName) private var displayName = ""

    private var theme: ColorPreset { .resolved(from: selectedPresetRaw) }
    private var aiProvider: AIAssistant.Provider { .resolved(from: selectedAIProviderRaw) }
    private var language: AppLanguage { .resolved(from: selectedLanguageRaw) }

    var body: some View {
        List {
            profileSection
            TodayEnergySection(dayStart: dayTracker.dayStart, theme: theme)
                .id(dayTracker.dayStart)
            foodPresetsSection
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

    private var foodPresetsSection: some View {
        Section("Presets") {
            NavigationLink {
                FoodPresetManagementView()
            } label: {
                Label("Manage food presets", systemImage: "leaf")
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

}

private struct TodayEnergySection: View {
    @Environment(HealthKitManager.self) private var healthKit
    @Query private var todaysProducts: [Product]

    private let theme: ColorPreset

    init(dayStart: Date, theme: ColorPreset) {
        self.theme = theme
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)
            ?? dayStart.addingTimeInterval(24 * 60 * 60)
        _todaysProducts = Query(
            filter: #Predicate<Product> {
                $0.timestamp >= dayStart && $0.timestamp < dayEnd
            },
            sort: [SortDescriptor(\Product.timestamp, order: .reverse)]
        )
    }

    private var gainedKcal: Double { CalorieMath.total(of: todaysProducts) }
    private var burnedKcal: Double { healthKit.totalBurnedKcal ?? 0 }
    private var netKcal: Double { gainedKcal - burnedKcal }

    var body: some View {
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

    private var burnedSubtitle: String {
        guard healthKit.isAuthorized else { return "Connect Apple Health to load" }
        let active = CalorieMath.formatted(healthKit.activeBurnedKcal ?? 0)
        let resting = CalorieMath.formatted(healthKit.restingBurnedKcal ?? 0)
        return "Active \(active) · Resting \(resting)"
    }

    private var netSubtitle: String {
        switch netKcal {
        case 1...: "Calorie surplus"
        case ..<0: "Calorie deficit"
        default: "Balanced"
        }
    }
}

private struct FoodPresetManagementView: View {
    private enum EditorSheet: Identifiable {
        case add
        case edit(FoodPreset)

        var id: String {
            switch self {
            case .add: "add"
            case .edit(let preset): preset.id
            }
        }

        var preset: FoodPreset? {
            switch self {
            case .add: nil
            case .edit(let preset): preset
            }
        }
    }

    @Environment(FoodPresetStore.self) private var presetStore
    @State private var editorSheet: EditorSheet?
    @State private var isConfirmingRestore = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            ForEach(FoodPreset.Category.allCases) { category in
                Section(category.title) {
                    ForEach(presetStore.presets(for: category)) { preset in
                        Button {
                            editorSheet = .edit(preset)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(preset.name)
                                        .foregroundStyle(.primary)
                                    Text(
                                        "\(CalorieMath.formatted(preset.kkalsPer100g)) kcal/100g · "
                                            + "\(CalorieMath.formatted(preset.defaultGrams)) g"
                                    )
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "pencil")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        let presets = presetStore.presets(for: category)
                        let presetsToDelete = offsets.compactMap {
                            presets.indices.contains($0) ? presets[$0] : nil
                        }
                        for preset in presetsToDelete {
                            do {
                                try presetStore.delete(preset)
                            } catch {
                                errorMessage = error.localizedDescription
                                break
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Food Presets")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Button("Restore built-in presets", systemImage: "arrow.counterclockwise") {
                        isConfirmingRestore = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editorSheet = .add
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add Preset")
            }
        }
        .sheet(item: $editorSheet) { sheet in
            NavigationStack {
                FoodPresetEditorView(preset: sheet.preset)
            }
        }
        .confirmationDialog(
            "Restore built-in presets?",
            isPresented: $isConfirmingRestore,
            titleVisibility: .visible
        ) {
            Button("Restore built-in presets", role: .destructive) {
                do {
                    try presetStore.restoreBuiltInPresets()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        } message: {
            Text(
                "This restores the original names and values and brings back deleted built-in presets. Your custom presets stay."
            )
        }
        .alert(
            "Preset error",
            isPresented: Binding(
                get: { errorMessage != nil || presetStore.errorMessage != nil },
                set: {
                    if !$0 {
                        errorMessage = nil
                        presetStore.clearError()
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                errorMessage = nil
                presetStore.clearError()
            }
        } message: {
            Text(errorMessage ?? presetStore.errorMessage ?? "")
        }
    }
}

private struct FoodPresetEditorView: View {
    @Environment(FoodPresetStore.self) private var presetStore
    @Environment(\.dismiss) private var dismiss

    private let preset: FoodPreset?
    @State private var name: String
    @State private var kkalsPer100gText: String
    @State private var defaultGramsText: String
    @State private var category: FoodPreset.Category
    @State private var errorMessage: String?

    init(preset: FoodPreset?) {
        self.preset = preset
        _name = State(initialValue: preset?.name ?? "")
        _kkalsPer100gText = State(
            initialValue: preset.map { CalorieMath.formatted($0.kkalsPer100g) } ?? ""
        )
        _defaultGramsText = State(
            initialValue: preset.map { CalorieMath.formatted($0.defaultGrams) } ?? "100"
        )
        _category = State(initialValue: preset?.category ?? .fruits)
    }

    private var kkalsPer100g: Double? {
        CalorieMath.parseDecimal(kkalsPer100gText)
    }

    private var defaultGrams: Double? {
        CalorieMath.parseDecimal(defaultGramsText)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (kkalsPer100g ?? 0) > 0
            && (defaultGrams ?? 0) > 0
    }

    var body: some View {
        Form {
            TextField("Name", text: $name)
                .textInputAutocapitalization(.words)
            TextField("kcal per 100g", text: $kkalsPer100gText)
                .keyboardType(.decimalPad)
            TextField("Default grams", text: $defaultGramsText)
                .keyboardType(.decimalPad)
            Picker("Category", selection: $category) {
                ForEach(FoodPreset.Category.allCases) { category in
                    Text(category.title).tag(category)
                }
            }
        }
        .navigationTitle(preset == nil ? "Add Preset" : "Edit Preset")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .fontWeight(.semibold)
                    .disabled(!isValid)
            }
        }
        .alert(
            "Unable to save preset",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func save() {
        guard let kkalsPer100g, let defaultGrams, isValid else { return }

        do {
            if let preset {
                try presetStore.update(
                    preset,
                    name: name,
                    kkalsPer100g: kkalsPer100g,
                    defaultGrams: defaultGrams,
                    category: category
                )
            } else {
                try presetStore.add(
                    name: name,
                    kkalsPer100g: kkalsPer100g,
                    category: category,
                    defaultGrams: defaultGrams
                )
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct EnergyStatRow: View {
    let title: String
    let subtitle: String
    let value: Double?
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
                    Text("\(CalorieMath.formatted(value)) kcal")
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
    .environment(FoodPresetStore())
    .environment(DayTracker())
    .modelContainer(for: Product.self, inMemory: true)
}
