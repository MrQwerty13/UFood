//
//  HistoryView.swift
//  UFood
//

import Charts
import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(HealthKitManager.self) private var healthKit
    @Environment(DayTracker.self) private var dayTracker
    @AppStorage(AppStorageKey.theme) private var selectedPresetRaw = ColorPreset.oceanMint.rawValue
    @Query(sort: \Product.timestamp, order: .reverse) private var allProducts: [Product]
    @State private var viewModel = HistoryViewModel()

    private var theme: ColorPreset { .resolved(from: selectedPresetRaw) }

    private var pastProducts: [Product] {
        let today = dayTracker.dayStart
        return allProducts.filter { $0.timestamp < today }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppSurfaceBackground(theme: theme)

                Group {
                    if viewModel.days.isEmpty && !viewModel.isLoading {
                        emptyState
                    } else {
                        historyList
                    }
                }
            }
            .navigationTitle("History")
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
            }
        }
        .tint(theme.primary)
        .task(id: refreshToken) {
            await viewModel.refresh(
                products: pastProducts,
                todayStart: dayTracker.dayStart,
                healthKit: healthKit
            )
        }
    }

    private var refreshToken: String {
        "\(dayTracker.dayStart.timeIntervalSince1970)"
            + "-\(ProductFingerprint.value(for: pastProducts))"
            + "-\(healthKit.isAuthorized)"
    }

    private var historyList: some View {
        List {
            Section {
                historySummaryHeader
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            if !viewModel.healthAccessGranted {
                Section {
                    healthAccessHint
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }

            Section {
                ForEach(viewModel.days) { day in
                    NavigationLink {
                        HistoryDetailView(dayStart: day.dayStart)
                    } label: {
                        DayHistoryRow(title: day.title, summary: day.summary)
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            } header: {
                Text("Past days")
                    .foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, 56, for: .scrollContent)
        .overlay {
            if viewModel.isLoading && viewModel.days.isEmpty {
                ProgressView()
                    .controlSize(.large)
            }
        }
    }

    private var historySummaryHeader: some View {
        SummaryCard {
            VStack(alignment: .leading, spacing: AppCardStyle.spacing) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("7-day average balance")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    if let average = viewModel.averageBalance7Days {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(CalorieMath.signedIntegerKcal(average))
                                .font(.largeTitle.weight(.bold).monospacedDigit())
                                .foregroundStyle(average < 0 ? Color.green : (average > 0 ? Color.orange : Color.primary))
                                .contentTransition(.numericText())
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                            Text("kcal")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(
                            Text(
                                String(
                                    format: appString("Average balance: %@"),
                                    CalorieMath.accessibilityKcalPhrase(average, includeSign: true)
                                )
                            )
                        )
                    } else {
                        Text("Not enough data yet")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }

                if viewModel.chartPoints.contains(where: \.hasData) {
                    BalanceChartView(points: viewModel.chartPoints)
                        .frame(height: 160)
                        .accessibilityLabel(Text("Balance chart for the last 7 days"))
                } else {
                    Text("No burned calorie data for the last 7 days")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var healthAccessHint: some View {
        SummaryCard {
            VStack(alignment: .leading, spacing: 10) {
                Label(
                    "Food history is shown. Connect Apple Health in Settings to include burned calories.",
                    systemImage: "heart"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)

                Button {
                    Task { await healthKit.requestAuthorization() }
                } label: {
                    Label("Connect Apple Health", systemImage: "heart.fill")
                        .font(.footnote.weight(.semibold))
                        .frame(minHeight: AppCardStyle.minTapSize)
                }
                .buttonStyle(.bordered)
                .disabled(!healthKit.isAvailable)
                .accessibilityHint(Text("Opens Apple Health access request"))
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No history yet", systemImage: "calendar")
        } description: {
            Text("Past days appear here after midnight, or when Apple Health has burned calories for earlier days.")
        }
        .padding()
    }
}

private struct BalanceChartView: View {
    let points: [BalanceChartPoint]

    var body: some View {
        Chart(points) { point in
            BarMark(
                x: .value("Day", point.label),
                y: .value("Balance", point.hasData ? point.balanceKcal : 0)
            )
            .foregroundStyle(barColor(for: point))
            .cornerRadius(6)
            .accessibilityLabel(Text(point.label))
            .accessibilityValue(
                point.hasData
                    ? Text(CalorieMath.accessibilityKcalPhrase(point.balanceKcal, includeSign: true))
                    : Text(appString("no data"))
            )
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(CalorieMath.signedIntegerKcal(number))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let label = value.as(String.self) {
                        Text(label)
                            .font(.caption2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                }
            }
        }
    }

    private func barColor(for point: BalanceChartPoint) -> Color {
        guard point.hasData else { return Color(.tertiarySystemFill) }
        if point.balanceKcal < 0 { return .green }
        if point.balanceKcal > 0 { return .orange }
        return .secondary
    }
}

#Preview {
    HistoryView()
        .environment(HealthKitManager())
        .environment(DayTracker())
        .modelContainer(for: Product.self, inMemory: true)
}
