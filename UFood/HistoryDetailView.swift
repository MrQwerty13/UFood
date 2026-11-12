//
//  HistoryDetailView.swift
//  UFood
//

import SwiftData
import SwiftUI

struct HistoryDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitManager.self) private var healthKit
    @AppStorage(AppStorageKey.theme) private var selectedPresetRaw = ColorPreset.oceanMint.rawValue
    @Query private var products: [Product]
    @State private var viewModel = HistoryViewModel()
    @State private var summary: DailyEnergySummary?
    @State private var productPendingEdit: Product?
    @State private var deletionTrigger = 0

    private let dayStart: Date
    private var theme: ColorPreset { .resolved(from: selectedPresetRaw) }

    init(dayStart: Date) {
        self.dayStart = Calendar.current.startOfDay(for: dayStart)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: self.dayStart)
            ?? self.dayStart.addingTimeInterval(24 * 60 * 60)
        let start = self.dayStart
        _products = Query(
            filter: #Predicate<Product> {
                $0.timestamp >= start && $0.timestamp < dayEnd
            },
            sort: [SortDescriptor(\Product.timestamp, order: .reverse)]
        )
    }

    var body: some View {
        ZStack {
            AppSurfaceBackground(theme: theme)

            List {
                Section {
                    if let summary {
                        detailMetrics(summary)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .listRowBackground(Color.clear)
                    }
                }

                if let summary, !summary.healthAccessGranted {
                    Section {
                        Label(
                            "Burned calories need Apple Health access. Food entries still update the balance.",
                            systemImage: "heart"
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    }
                }

                Section {
                    if products.isEmpty {
                        ContentUnavailableView {
                            Label("No food logged", systemImage: "leaf")
                        } description: {
                            Text("This day has no food entries.")
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    } else {
                        ForEach(products) { product in
                            Button {
                                productPendingEdit = product
                            } label: {
                                ProductRowView(product: product, theme: theme)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: deleteProducts)
                    }
                } header: {
                    Text("Entries")
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(DayDateFormatting.longDayTitle(dayStart))
        .navigationBarTitleDisplayMode(.large)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: deletionTrigger)
        .sheet(item: $productPendingEdit) { product in
            EditFoodView(product: product)
        }
        .task(id: productsFingerprint) {
            summary = await viewModel.summary(
                for: dayStart,
                products: Array(products),
                healthKit: healthKit
            )
        }
    }

    /// Changes whenever an entry of this day is added, edited or deleted,
    /// so the balance is recalculated right away.
    private var productsFingerprint: String {
        ProductFingerprint.value(for: products)
    }

    @ViewBuilder
    private func detailMetrics(_ summary: DailyEnergySummary) -> some View {
        VStack(spacing: AppCardStyle.spacing) {
            DailyEnergyDashboard(
                summary: summary,
                theme: theme,
                title: "Day",
                onEnableHealth: {
                    Task { await healthKit.requestAuthorization() }
                }
            )

            if summary.hasBurnedData {
                HStack(spacing: AppCardStyle.spacing) {
                    MetricCard(
                        title: "Active",
                        value: CalorieMath.integerKcal(summary.activeBurnedKcal),
                        valueColor: .primary,
                        accessibilityValue: String(
                            format: appString("Active: %@"),
                            CalorieMath.accessibilityKcalPhrase(summary.activeBurnedKcal)
                        )
                    )

                    MetricCard(
                        title: "Resting",
                        value: CalorieMath.integerKcal(summary.basalBurnedKcal),
                        valueColor: .primary,
                        accessibilityValue: String(
                            format: appString("Resting: %@"),
                            CalorieMath.accessibilityKcalPhrase(summary.basalBurnedKcal)
                        )
                    )
                }
            }
        }
    }

    private func deleteProducts(offsets: IndexSet) {
        withAnimation {
            offsets.map { products[$0] }.forEach(modelContext.delete)
        }
        deletionTrigger += 1
    }
}
