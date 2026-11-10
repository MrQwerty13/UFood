//
//  ContentView.swift
//  UFood
//
//  Created by Михаил Позур on 10.11.2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitManager.self) private var healthKit
    @Query private var todaysProducts: [Product]
    @AppStorage(AppStorageKey.theme) private var selectedPresetRaw = ColorPreset.oceanMint.rawValue
    @AppStorage(AppStorageKey.displayName) private var displayName = ""
    @State private var isAddingFood = false

    private var theme: ColorPreset { .resolved(from: selectedPresetRaw) }
    private var dayTotalKcal: Int { CalorieMath.totalRounded(of: todaysProducts) }

    init() {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        _todaysProducts = Query(
            filter: #Predicate<Product> { $0.timestamp >= startOfToday },
            sort: [SortDescriptor(\Product.timestamp, order: .reverse)]
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.softBackground
                    .ignoresSafeArea()

                List {
                    clearSection {
                        dayTotalCard
                    }

                    if healthKit.isAuthorized, let burned = healthKit.totalBurnedKcal {
                        clearSection {
                            energyBalanceRow(burned: burned)
                        }
                    }

                    Section {
                        if todaysProducts.isEmpty {
                            emptyState
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        } else {
                            ForEach(todaysProducts) { product in
                                ProductRow(product: product, theme: theme)
                            }
                            .onDelete(perform: deleteProducts)
                        }
                    } header: {
                        Text("Entries")
                            .foregroundStyle(theme.secondary)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(displayName.isEmpty ? "UFood" : displayName)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(theme.brandGradient)
                    }
                    .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAddingFood = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(theme.onGradient, theme.brandGradient)
                            .font(.title2)
                    }
                    .accessibilityLabel("Add Food")
                }
            }
            .sheet(isPresented: $isAddingFood) {
                AddFoodView()
            }
            .task {
                await healthKit.refreshIfNeeded()
            }
        }
        .tint(theme.primary)
    }

    private var dayTotalCard: some View {
        VStack(spacing: 6) {
            Text("Today")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.onGradient.opacity(0.85))
            Text("\(dayTotalKcal)")
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(theme.onGradient)
            Text("kcal gained")
                .font(.title3.weight(.medium))
                .foregroundStyle(theme.onGradient.opacity(0.9))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(theme.brandGradient, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: theme.primary.opacity(0.25), radius: 16, y: 8)
    }

    private func energyBalanceRow(burned: Int) -> some View {
        let net = dayTotalKcal - burned
        return HStack {
            Label("Burned \(burned)", systemImage: "flame.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.accent)
            Spacer()
            Text(netLabel(net))
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(net >= 0 ? theme.primary : theme.end)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 36))
                .foregroundStyle(theme.brandGradient)
            Text("No food logged today")
                .font(.headline)
            Text("Tap + to add a custom product or pick a fruit/veggie preset.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private func netLabel(_ net: Int) -> String {
        let prefix = net > 0 ? "+" : ""
        return "Net \(prefix)\(net)"
    }

    private func deleteProducts(offsets: IndexSet) {
        withAnimation {
            offsets.map { todaysProducts[$0] }.forEach(modelContext.delete)
        }
    }

    @ViewBuilder
    private func clearSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        Section {
            content()
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
    }
}

private struct ProductRow: View {
    let product: Product
    let theme: ColorPreset

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.headline)
                Text("\(product.eatenGramms) g · \(product.kkalsPer100g) kcal/100g")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("~\(product.roundedKcal)")
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(theme.accent)
                Text("kcal")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Product.self, configurations: config)
    container.mainContext.insert(Product(name: "Yoghurt", kkalsPer100g: 67, eatenGramms: 50))
    container.mainContext.insert(Product(name: "Banana", kkalsPer100g: 89, eatenGramms: 120))

    return ContentView()
        .environment(HealthKitManager())
        .modelContainer(container)
}
