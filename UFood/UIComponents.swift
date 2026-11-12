//
//  UIComponents.swift
//  UFood
//

import SwiftUI

/// Reusable metric tile used inside the daily dashboard, history rows and history detail.
struct MetricCard: View {
    let title: LocalizedStringKey
    let value: String
    var unit: LocalizedStringKey = "kcal"
    var valueColor: Color = .primary
    var accessibilityValue: String? = nil
    var caption: Text? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(verbatim: value)
                    .font(.title.weight(.bold).monospacedDigit())
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
                    .contentTransition(reduceMotion ? .identity : .numericText())

                if value != DailyEnergySummary.noDataPlaceholder {
                    Text(unit)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            if let caption {
                caption
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(AppCardStyle.padding)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppCardStyle.innerCorner, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityValue ?? "\(value) \(String(localized: "kcal"))"))
    }
}

/// Shared food entry row for Today and History detail.
struct ProductRowView: View {
    let product: Product
    let theme: ColorPreset

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

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
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                }
            }

            Spacer(minLength: 8)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(CalorieMath.integerKcal(product.kcal))
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .foregroundStyle(theme.accent)
                    .contentTransition(reduceMotion ? .identity : .numericText())
                Text("kcal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
        .frame(minHeight: AppCardStyle.minTapSize)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            Text(
                "\(product.name), \(CalorieMath.formatted(product.eatenGramms)) g, "
                    + CalorieMath.accessibilityKcalPhrase(product.kcal)
            )
        )
    }
}

/// One past day in the History list.
struct DayHistoryRow: View {
    let title: String
    let summary: DailyEnergySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            HStack(spacing: AppCardStyle.spacing) {
                dayMetric(
                    label: "Balance",
                    value: summary.balanceDisplayText,
                    color: summary.balanceColor,
                    accessibility: summary.accessibilityBalance
                )
                dayMetric(
                    label: "Burned",
                    value: summary.burnedDisplayText,
                    color: summary.hasBurnedData ? .primary : .secondary,
                    accessibility: summary.accessibilityBurned
                )
                dayMetric(
                    label: "Eaten",
                    value: summary.eatenText,
                    color: .primary,
                    accessibility: summary.accessibilityEaten
                )
            }
        }
        .padding(AppCardStyle.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: AppCardStyle.minTapSize)
        .background(
            Color(.secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: AppCardStyle.rowCorner, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            Text("\(title). \(summary.accessibilityBalance). \(summary.accessibilityBurned). \(summary.accessibilityEaten)")
        )
        .accessibilityHint(Text("Shows day details"))
    }

    private func dayMetric(
        label: LocalizedStringKey,
        value: String,
        color: Color,
        accessibility: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(verbatim: value)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if value != DailyEnergySummary.noDataPlaceholder {
                    Text("kcal")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel(Text(accessibility))
    }
}

/// Card used for the seven day balance summary and the day breakdown.
struct SummaryCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(AppCardStyle.padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppCardStyle.outerCorner, style: .continuous))
    }
}

/// App background that keeps the brand tint but stays readable in light and dark mode.
struct AppSurfaceBackground: View {
    let theme: ColorPreset

    var body: some View {
        ZStack {
            Color(.systemBackground)
            theme.softBackground.opacity(0.85)
        }
        .ignoresSafeArea()
    }
}
