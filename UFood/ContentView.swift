//
//  ContentView.swift
//  UFood
//
//  Created by Михаил Позур on 10.11.2026.
//

import Combine
import SwiftUI
import SwiftData
import UIKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(HealthKitManager.self) private var healthKit
    @Environment(DayTracker.self) private var dayTracker
    @AppStorage(AppStorageKey.theme) private var selectedPresetRaw = ColorPreset.oceanMint.rawValue
    @AppStorage(AppStorageKey.displayName) private var displayName = ""
    @State private var isAddingFood = false

    private var theme: ColorPreset { .resolved(from: selectedPresetRaw) }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.softBackground
                    .ignoresSafeArea()

                TodayListView(dayStart: dayTracker.dayStart, theme: theme)
                    .id(dayTracker.dayStart)
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
        }
        .tint(theme.primary)
        .task {
            await healthKit.refreshIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            refreshForCurrentDay()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)
        ) { _ in
            refreshForCurrentDay()
        }
    }

    private func refreshForCurrentDay() {
        dayTracker.refreshIfNeeded()
        Task {
            await healthKit.refreshIfNeeded()
        }
    }
}

private struct TodayListView: View {
    @Environment(\.modelContext) private var modelContext
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

    private var dayTotalKcal: Double { CalorieMath.total(of: todaysProducts) }

    var body: some View {
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

    private var dayTotalCard: some View {
        VStack(spacing: 6) {
            Text("Today")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.onGradient.opacity(0.85))
            Text(CalorieMath.formatted(dayTotalKcal))
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

    private func energyBalanceRow(burned: Double) -> some View {
        let net = dayTotalKcal - burned
        return HStack {
            Label("Burned \(CalorieMath.formatted(burned))", systemImage: "flame.fill")
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

    private func netLabel(_ net: Double) -> String {
        let prefix = net > 0 ? "+" : ""
        return "Net \(prefix)\(CalorieMath.formatted(net))"
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
                HStack(spacing: 6) {
                    if let tag = product.tag {
                        Text(FoodTag.title(for: tag))
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(theme.brandGradient, in: Capsule())
                            .foregroundStyle(theme.onGradient)
                    }
                    Text(
                        "\(CalorieMath.formatted(product.eatenGramms)) g · "
                            + "\(CalorieMath.formatted(product.kkalsPer100g)) kcal/100g"
                    )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("~\(product.formattedKcal)")
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
        .environment(DayTracker())
        .modelContainer(container)
}
