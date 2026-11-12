//
//  ContentView.swift
//  UFood
//
//  Created by Михаил Позур on 10.11.2026.
//

import Combine
import SwiftData
import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(HealthKitManager.self) private var healthKit
    @Environment(DayTracker.self) private var dayTracker
    @AppStorage(AppStorageKey.theme) private var selectedPresetRaw = ColorPreset.oceanMint.rawValue

    private var theme: ColorPreset { .resolved(from: selectedPresetRaw) }

    var body: some View {
        TabView {
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "calendar")
                }

            TodayRootView()
                .tabItem {
                    Label("Today", systemImage: "sun.max.fill")
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

private struct TodayRootView: View {
    @Environment(HealthKitManager.self) private var healthKit
    @Environment(DayTracker.self) private var dayTracker
    @AppStorage(AppStorageKey.theme) private var selectedPresetRaw = ColorPreset.oceanMint.rawValue
    @AppStorage(AppStorageKey.displayName) private var displayName = ""
    @State private var isAddingFood = false
    @State private var saveTrigger = 0

    private var theme: ColorPreset { .resolved(from: selectedPresetRaw) }

    /// The title is localized, while a custom user name is shown as is.
    private var screenTitle: LocalizedStringKey {
        displayName.isEmpty ? "Today" : LocalizedStringKey(displayName)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppSurfaceBackground(theme: theme)

                TodayListView(dayStart: dayTracker.dayStart, theme: theme)
                    .id(dayTracker.dayStart)
            }
            .navigationTitle(screenTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(theme.brandGradient)
                            .frame(minWidth: AppCardStyle.minTapSize, minHeight: AppCardStyle.minTapSize)
                            .contentShape(Rectangle())
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
                            .frame(minWidth: AppCardStyle.minTapSize, minHeight: AppCardStyle.minTapSize)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Add Food")
                }
            }
            .sheet(isPresented: $isAddingFood, onDismiss: refreshForCurrentDay) {
                AddFoodView(onSaved: { saveTrigger += 1 })
            }
            .sensoryFeedback(.success, trigger: saveTrigger)
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
    @State private var deletionTrigger = 0
    @State private var productPendingEdit: Product?

    private let theme: ColorPreset
    private let dayStart: Date

    init(dayStart: Date, theme: ColorPreset) {
        self.theme = theme
        self.dayStart = dayStart
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

            if !todaysProducts.isEmpty {
                Section {
                    ForEach(todaysProducts) { product in
                        Button {
                            productPendingEdit = product
                        } label: {
                            ProductRowView(product: product, theme: theme)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: deleteProducts)
                } header: {
                    Text("Entries")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    emptyState
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, 96, for: .scrollContent)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: deletionTrigger)
        .sheet(item: $productPendingEdit) { product in
            EditFoodView(product: product)
        }
        .onAppear(perform: syncWidgetData)
        .onChange(of: energySummary) { _, _ in
            syncWidgetData()
        }
        .onChange(of: theme) { _, _ in
            syncWidgetData()
        }
    }

    private func syncWidgetData() {
        let burnedKcal = energySummary.healthAccessGranted
            && energySummary.healthDataAvailable
            && energySummary.hasBurnedData
            ? energySummary.burnedKcal
            : nil
        WidgetEnergyDataStore.save(
            WidgetEnergyData(
                dayStart: dayStart,
                eatenKcal: energySummary.eatenKcal,
                burnedKcal: burnedKcal,
                themeID: theme.rawValue
            )
        )
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No food logged today", systemImage: "leaf.fill")
        } description: {
            Text("Tap + to add a custom product or pick a fruit/veggie preset.")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private func deleteProducts(offsets: IndexSet) {
        withAnimation {
            offsets.map { todaysProducts[$0] }.forEach(modelContext.delete)
        }
        deletionTrigger += 1
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
