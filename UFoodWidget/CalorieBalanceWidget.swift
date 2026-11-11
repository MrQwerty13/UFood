//
//  CalorieBalanceWidget.swift
//  UFood
//

import SwiftUI
import WidgetKit

struct CalorieBalanceEntry: TimelineEntry {
    let date: Date
    let energy: WidgetEnergyData?
}

struct CalorieBalanceProvider: TimelineProvider {
    func placeholder(in context: Context) -> CalorieBalanceEntry {
        CalorieBalanceEntry(date: .now, energy: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (CalorieBalanceEntry) -> Void) {
        completion(CalorieBalanceEntry(date: .now, energy: WidgetEnergyDataStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CalorieBalanceEntry>) -> Void) {
        let now = Date.now
        let entry = CalorieBalanceEntry(date: now, energy: WidgetEnergyDataStore.load(for: now))
        let nextHour = now.addingTimeInterval(60 * 60)
        let nextDay = Calendar.current.dateInterval(of: .day, for: now)?.end ?? nextHour
        completion(Timeline(entries: [entry], policy: .after(min(nextHour, nextDay))))
    }
}

struct CalorieBalanceWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.locale) private var locale

    let entry: CalorieBalanceEntry

    private var colors: [Color] {
        switch entry.energy?.themeID {
        case "orangePink":
            [Color(hex: 0xC05200), Color(hex: 0x6537A4)]
        case "mintPink":
            [Color(hex: 0x0F625A), Color(hex: 0x893B60)]
        default:
            [Color(hex: 0x0053A6), Color(hex: 0x08745F)]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 8 : 12) {
            Text("Calorie balance")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            if let energy = entry.energy {
                balance(energy.balanceKcal)
                HStack(alignment: .bottom, spacing: 8) {
                    metric("Eaten", value: energy.eatenKcal)
                    Spacer(minLength: 4)
                    if let burnedKcal = energy.burnedKcal {
                        metric("Burned", value: burnedKcal)
                    } else {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Burned")
                                .font(.caption2)
                                .opacity(0.8)
                            Text("No data")
                                .font(.caption.weight(.semibold))
                        }
                    }
                }
            } else {
                Text("—")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                Text("No data yet")
                    .font(.caption)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
        .containerBackground(for: .widget) {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private func balance(_ value: Double?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("Balance")
                .font(.caption.weight(.medium))
                .opacity(0.85)
            Spacer(minLength: 2)
            if let value {
                Text(signed(value))
                    .font(.system(size: family == .systemSmall ? 28 : 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("kcal")
                    .font(.caption2.weight(.semibold))
            } else {
                Text("—")
                    .font(.title2.bold())
            }
        }
    }

    private func metric(_ title: LocalizedStringKey, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .opacity(0.8)
            Text(value, format: .number.locale(locale).precision(.fractionLength(0)))
                .font(.caption.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private func signed(_ value: Double) -> String {
        let magnitude = abs(value).formatted(.number.locale(locale).precision(.fractionLength(0)))
        let sign = value < 0 ? "−" : "+"
        return sign + magnitude
    }
}

struct CalorieBalanceWidget: Widget {
    static let kind = WidgetEnergyDataStore.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: CalorieBalanceProvider()) { entry in
            CalorieBalanceWidgetView(entry: entry)
        }
        .configurationDisplayName("Calorie balance")
        .description("Today's eaten and burned calories with your net balance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct UFoodWidgetBundle: WidgetBundle {
    var body: some Widget {
        CalorieBalanceWidget()
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
