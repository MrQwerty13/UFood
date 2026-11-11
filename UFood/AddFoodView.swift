//
//  AddFoodView.swift
//  UFood
//
//  Created by Михаил Позур on 10.11.2026.
//

import SwiftUI
import SwiftData
import UIKit

struct AddFoodView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(HealthKitManager.self) private var healthKit
    @Environment(FoodPresetStore.self) private var presetStore
    @Environment(FoodTagStore.self) private var foodTagStore
    @AppStorage(AppStorageKey.theme) private var selectedPresetRaw = ColorPreset.oceanMint.rawValue
    @AppStorage(AppStorageKey.aiProvider) private var selectedAIProviderRaw = AIAssistant.Provider.chatGPT.rawValue
    @AppStorage(AppStorageKey.language) private var selectedLanguageRaw = AppLanguage.system.rawValue

    @State private var name = ""
    @State private var kkalsPer100gText = ""
    @State private var eatenGrammsText = ""
    @State private var selectedCategory: FoodPreset.Category = .fruits
    @State private var selectedTag = "fruits"
    @State private var newTagName = ""
    @State private var tagErrorMessage: String?
    @State private var didCopyPrompt = false

    private var theme: ColorPreset { .resolved(from: selectedPresetRaw) }
    private var aiProvider: AIAssistant.Provider { .resolved(from: selectedAIProviderRaw) }
    private var language: AppLanguage { .resolved(from: selectedLanguageRaw) }

    private var kkalsPer100g: Double? {
        CalorieMath.parseDecimal(kkalsPer100gText)
    }

    private var eatenGramms: Double? {
        CalorieMath.parseDecimal(eatenGrammsText)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isValid: Bool {
        !trimmedName.isEmpty && (kkalsPer100g ?? 0) > 0 && (eatenGramms ?? 0) > 0
    }

    private var validationMessage: String? {
        let kcalText = kkalsPer100gText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !kcalText.isEmpty {
            guard let value = kkalsPer100g else {
                return "Enter a valid number for kcal per 100g."
            }
            if value <= 0 {
                return "Kcal per 100g must be greater than zero."
            }
        }

        let gramsText = eatenGrammsText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !gramsText.isEmpty {
            guard let value = eatenGramms else {
                return "Enter a valid number for grams eaten."
            }
            if value <= 0 {
                return "Grams eaten must be greater than zero."
            }
        }

        return nil
    }

    private var previewKcal: Double? {
        guard let kkalsPer100g, let eatenGramms, isValid else { return nil }
        return CalorieMath.kcal(per100g: kkalsPer100g, grams: eatenGramms)
    }

    private var gramsPrompt: String {
        AIAssistant.gramsEstimatePrompt(
            foodName: trimmedName,
            kcalPer100g: kkalsPer100g,
            replyLanguage: language.promptLanguageName
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                presetsSection
                tagSection
                customSection
                if let previewKcal {
                    previewSection(previewKcal)
                }
            }
            .navigationTitle("Add Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
            .alert("Prompt copied", isPresented: $didCopyPrompt) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Paste it into ChatGPT or Claude, then enter the estimated grams here.")
            }
        }
        .tint(theme.primary)
    }

    private var presetsSection: some View {
        Section {
            Picker("Category", selection: $selectedCategory) {
                ForEach(FoodPreset.Category.allCases) { category in
                    Text(category.title).tag(category)
                }
            }
            .pickerStyle(.segmented)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                ForEach(presetStore.presets(for: selectedCategory)) { preset in
                    PresetChip(
                        preset: preset,
                        theme: theme,
                        isSelected: isSelected(preset),
                        action: { applyPreset(preset) }
                    )
                }
            }
            .padding(.vertical, 4)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        } header: {
            Text("Presets")
        } footer: {
            Text("Tap a preset to fill name and kcal. Adjust grams if needed, then save.")
        }
    }

    private var customSection: some View {
        Section("Custom / edit") {
            TextField("Name", text: $name)
                .textInputAutocapitalization(.words)

            TextField("kcal per 100g", text: $kkalsPer100gText)
                .keyboardType(.decimalPad)

            TextField("Grams eaten", text: $eatenGrammsText)
                .keyboardType(.decimalPad)

            if let validationMessage {
                Text(validationMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Menu {
                ForEach(AIAssistant.Provider.allCases) { provider in
                    Button {
                        openAI(provider)
                    } label: {
                        if provider == aiProvider {
                            Label(provider.title, systemImage: "checkmark")
                        } else {
                            Text(provider.title)
                        }
                    }
                }
                Divider()
                Button {
                    UIPasteboard.general.string = gramsPrompt
                    didCopyPrompt = true
                } label: {
                    Text("Copy prompt only")
                }
            } label: {
                Label("Ask AI how many grams", systemImage: "sparkles")
            }
        }
    }

    private var tagSection: some View {
        Section("Tag") {
            Picker("Tag", selection: $selectedTag) {
                ForEach(foodTagStore.tags) { tag in
                    Text(tag.title).tag(tag.id)
                }
            }

            HStack {
                TextField("New tag", text: $newTagName)
                    .textInputAutocapitalization(.words)
                Button("Add tag", systemImage: "plus", action: addTag)
                    .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let tagErrorMessage {
                Text(tagErrorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private func previewSection(_ previewKcal: Double) -> some View {
        Section {
            HStack {
                Text("This entry")
                Spacer()
                Text("~\(CalorieMath.formatted(previewKcal)) kcal")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(theme.accent)
            }
        }
    }

    private func isSelected(_ preset: FoodPreset) -> Bool {
        trimmedName.caseInsensitiveCompare(preset.name) == .orderedSame
            && kkalsPer100g == preset.kkalsPer100g
    }

    private func applyPreset(_ preset: FoodPreset) {
        name = preset.name
        kkalsPer100gText = CalorieMath.formatted(preset.kkalsPer100g)
        if eatenGrammsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            eatenGrammsText = CalorieMath.formatted(preset.defaultGrams)
        }
    }

    private func addTag() {
        do {
            try foodTagStore.add(newTagName)
            selectedTag = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
            newTagName = ""
            tagErrorMessage = nil
        } catch {
            tagErrorMessage = error.localizedDescription
        }
    }

    private func openAI(_ provider: AIAssistant.Provider) {
        selectedAIProviderRaw = provider.rawValue
        AIAssistant.open(provider, prompt: gramsPrompt)
        didCopyPrompt = true
    }

    private func save() {
        guard let kkalsPer100g, let eatenGramms, isValid else { return }
        let product = Product(
            name: trimmedName,
            kkalsPer100g: kkalsPer100g,
            eatenGramms: eatenGramms,
            tag: selectedTag
        )
        modelContext.insert(product)
        Task {
            await healthKit.saveDietaryEnergy(kcal: product.kcal, at: product.timestamp)
        }
        dismiss()
    }
}

private struct PresetChip: View {
    let preset: FoodPreset
    let theme: ColorPreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(preset.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? theme.onGradient : .primary)
                Text("\(CalorieMath.formatted(preset.kkalsPer100g)) kcal/100g")
                    .font(.caption)
                    .foregroundStyle(isSelected ? theme.onGradient.opacity(0.9) : .secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                Group {
                    if isSelected {
                        theme.brandGradient
                    } else {
                        Color(.secondarySystemGroupedBackground)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.clear : theme.secondary.opacity(0.35),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AddFoodView()
        .environment(HealthKitManager())
        .environment(FoodPresetStore())
        .modelContainer(for: Product.self, inMemory: true)
}
