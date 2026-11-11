//
//  DailyEnergyDashboard.swift
//  UFood
//

import SwiftUI

struct DailyEnergyDashboard: View {
    let summary: DailyEnergySummary
    let theme: ColorPreset
    var onEnableHealth: (() -> Void)?

    private let tileSpacing: CGFloat = 10
    private let tileCorner: CGFloat = 18

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(theme.brandGradient)
                .shadow(color: theme.primary.opacity(0.25), radius: 16, y: 8)

            VStack(spacing: 14) {
                Text("Today")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())

                VStack(spacing: tileSpacing) {
                    statTile(
                        title: "Balance",
                        value: summary.balanceText,
                        valueColor: balanceColor
                    ) {
                        if summary.isDeficit {
                            balanceCaption("Calorie deficit")
                        } else if summary.isSurplus {
                            balanceCaption("Calorie surplus")
                        }
                    }

                    statTile(
                        title: "Burned",
                        value: "\(summary.burnedKcalRounded)",
                        valueColor: .primary
                    ) {
                        Text(
                            "Active \(summary.activeBurnedKcalRounded) · Resting \(summary.basalBurnedKcalRounded)"
                        )
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                    }

                    statTile(
                        title: "Eaten",
                        value: "\(summary.eatenKcalRounded)",
                        valueColor: .primary
                    ) {
                        EmptyView()
                    }
                }

                if summary.showsHealthHint {
                    healthHint
                }
            }
            .padding(16)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var balanceColor: Color {
        if summary.isDeficit { return .green }
        if summary.isSurplus { return .orange }
        return .primary
    }

    private func balanceCaption(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private func statTile<Details: View>(
        title: LocalizedStringKey,
        value: String,
        valueColor: Color,
        @ViewBuilder details: () -> Details
    ) -> some View {
        RoundedRectangle(cornerRadius: tileCorner, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: tileCorner, style: .continuous)
                    .strokeBorder(theme.onGradient.opacity(0.2), lineWidth: 1)
            }
            .overlay {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        details()
                    }
                    Spacer(minLength: 4)
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(verbatim: value)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(valueColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Text("kcal")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)
    }

    private var healthHint: some View {
        VStack(spacing: 6) {
            Text("Connect Apple Health to load")
                .font(.caption2)

            Button {
                onEnableHealth?()
            } label: {
                Label("Connect Apple Health", systemImage: "heart.fill")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.primary.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!summary.healthDataAvailable)
        }
        .foregroundStyle(.primary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
