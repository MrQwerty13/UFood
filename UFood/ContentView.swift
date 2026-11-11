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
            .sheet(isPresented: $isAddingFood, onDismiss: refreshForCurrentDay) {
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

    private var energySummary: DailyEnergySummary {
        DailyEnergySummary(
            eatenKcal: dayTotalKcal,
            activeBurnedKcal: healthKit.activeBurnedKcal,
            basalBurnedKcal: healthKit.restingBurnedKcal,
            healthAccessGranted: healthKit.isAuthorized,
            healthDataAvailable: healthKit.isAvailable
        )
    }

    var body: some View {
        List {
            clearSection {
                DailyEnergyDashboard(
                    summary: energySummary,
                    theme: theme,
                    onEnableHealth: {
                        Task { await healthKit.requestAuthorization() }
                    }
                )
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

    private func deleteProducts(offsets: IndexSet) {
        withAnimation {
            offsets.map { todaysProducts[$0] }.forEach(modelContext.delete)
        }
        Task { await healthKit.refreshIfNeeded() }
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
