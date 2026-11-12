//
//  EditFoodView.swift
//  UFood
//

import SwiftData
import SwiftUI

struct EditFoodView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(FoodTagStore.self) private var foodTagStore
    @AppStorage(AppStorageKey.theme) private var selectedPresetRaw = ColorPreset.oceanMint.rawValue

    @Bindable var product: Product

    @State private var name: String
    @State private var kkalsPer100gText: String
    @State private var eatenGrammsText: String
    @State private var selectedTag: String
    @State private var saveTrigger = 0

    private var theme: ColorPreset { .resolved(from: selectedPresetRaw) }

    init(product: Product) {
        self.product = product
        _name = State(initialValue: product.name)
        _kkalsPer100gText = State(initialValue: CalorieMath.formatted(product.kkalsPer100g))
        _eatenGrammsText = State(initialValue: CalorieMath.formatted(product.eatenGramms))
        _selectedTag = State(initialValue: product.tag ?? FoodTag.defaultTags.first?.id ?? "fruits")
    }

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
                return String(localized: "Enter a valid number for kcal per 100g.")
            }
            if value <= 0 {
                return String(localized: "Kcal per 100g must be greater than zero.")
            }
        }

        let gramsText = eatenGrammsText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !gramsText.isEmpty {
            guard let value = eatenGramms else {
                return String(localized: "Enter a valid number for grams eaten.")
            }
            if value <= 0 {
                return String(localized: "Grams eaten must be greater than zero.")
            }
        }

        return nil
    }

    private var previewKcal: Double? {
        guard let kkalsPer100g, let eatenGramms, isValid else { return nil }
        return CalorieMath.kcal(per100g: kkalsPer100g, grams: eatenGramms)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Name") {
                        TextField("Name", text: $name)
                            .textInputAutocapitalization(.words)
                            .multilineTextAlignment(.trailing)
                    }

                    LabeledContent("kcal per 100g") {
                        TextField("0", text: $kkalsPer100gText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    LabeledContent("Grams eaten") {
                        TextField("0", text: $eatenGrammsText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    if let validationMessage {
                        Text(validationMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Product")
                } footer: {
                    Text("Use a comma or a dot for decimals. Balance updates after saving.")
                }

                Section("Tag") {
                    Picker("Tag", selection: $selectedTag) {
                        ForEach(foodTagStore.tags) { tag in
                            Text(tag.title).tag(tag.id)
                        }
                    }
                }

                if let previewKcal {
                    Section {
                        HStack {
                            Text("This entry")
                            Spacer()
                            Text("\(CalorieMath.integerKcal(previewKcal)) kcal")
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(theme.accent)
                                .contentTransition(.numericText())
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .navigationTitle("Edit Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .frame(minHeight: AppCardStyle.minTapSize)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                        .frame(minHeight: AppCardStyle.minTapSize)
                }
            }
            .sensoryFeedback(.success, trigger: saveTrigger)
        }
        .tint(theme.primary)
    }

    private func save() {
        guard let kkalsPer100g, let eatenGramms, isValid else { return }
        product.name = trimmedName
        product.kkalsPer100g = kkalsPer100g
        product.eatenGramms = eatenGramms
        product.tag = selectedTag
        saveTrigger += 1
        dismiss()
    }
}
