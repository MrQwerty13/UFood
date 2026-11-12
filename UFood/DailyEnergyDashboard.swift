//
//  DailyEnergyDashboard.swift
//  UFood
//

import SwiftUI

struct DailyEnergyDashboard: View {
    let summary: DailyEnergySummary
    let theme: ColorPreset
    var title: LocalizedStringKey = "Today"
    var onEnableHealth: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppCardStyle.outerCorner, style: .continuous)
                .fill(theme.brandGradient.opacity(0.92))
                .background(
                    RoundedRectangle(cornerRadius: AppCardStyle.outerCorner, style: .continuous)
                        .fill(.regularMaterial)
                )

            VStack(spacing: AppCardStyle.spacing) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())

                VStack(spacing: AppCardStyle.spacing) {
                    MetricCard(
                        title: "Balance",
                        value: summary.balanceDisplayText,
                        valueColor: summary.balanceColor,
                        accessibilityValue: summary.accessibilityBalance,
                        caption: balanceCaption
                    )

                    MetricCard(
                        title: "Burned",
                        value: summary.burnedDisplayText,
                        valueColor: summary.hasBurnedData ? .primary : .secondary,
                        accessibilityValue: summary.accessibilityBurned,
                        caption: burnedCaption
                    )

                    MetricCard(
                        title: "Eaten",
                        value: summary.eatenText,
                        accessibilityValue: summary.accessibilityEaten
                    )
                }
                .animation(reduceMotion ? nil : .snappy, value: summary)

                if summary.showsHealthHint {
                    healthHint
                }
            }
            .padding(AppCardStyle.padding)
        }
        .modifier(SquareLayoutUnlessAccessibilitySize(dynamicTypeSize: dynamicTypeSize))
        .accessibilityElement(children: .contain)
    }

    private var balanceCaption: Text? {
        guard summary.hasBurnedData else { return nil }
        if summary.isDeficit {
            return Text("Calorie deficit")
        }
        if summary.isSurplus {
            return Text("Calorie surplus")
        }
        return nil
    }

    private var burnedCaption: Text? {
        guard summary.hasBurnedData else { return nil }
        let text = String(
            format: appString("Active %@ · Resting %@"),
            CalorieMath.integerKcal(Double(summary.activeBurnedKcalRounded)),
            CalorieMath.integerKcal(Double(summary.basalBurnedKcalRounded))
        )
        return Text(verbatim: text)
    }

    private var healthHint: some View {
        VStack(spacing: 8) {
            Text("Connect Apple Health to load")
                .font(.caption)
                .multilineTextAlignment(.center)

            Button {
                onEnableHealth?()
            } label: {
                Label("Connect Apple Health", systemImage: "heart.fill")
                    .font(.caption.weight(.semibold))
                    .frame(minHeight: AppCardStyle.minTapSize)
                    .padding(.horizontal, 12)
                    .background(.primary.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!summary.healthDataAvailable)
            .accessibilityHint(Text("Opens Apple Health access request"))
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppCardStyle.rowCorner, style: .continuous))
    }
}

/// Keeps the square dashboard on standard text sizes and lets it grow
/// when Dynamic Type is turned up, so nothing gets clipped.
private struct SquareLayoutUnlessAccessibilitySize: ViewModifier {
    let dynamicTypeSize: DynamicTypeSize

    func body(content: Content) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            content.frame(maxWidth: .infinity, alignment: .center)
        } else {
            content.aspectRatio(1, contentMode: .fit)
        }
    }
}

#Preview {
    DailyEnergyDashboard(
        summary: DailyEnergySummary(
            eatenKcal: 850,
            activeBurnedKcal: 320,
            basalBurnedKcal: 1400,
            healthAccessGranted: true,
            healthDataAvailable: true
        ),
        theme: .oceanMint
    )
    .padding()
}
