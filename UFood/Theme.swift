//
//  Theme.swift
//  UFood
//

import SwiftUI

enum ColorPreset: String, CaseIterable, Identifiable {
    case oceanMint
    case orangePink
    case mintPink

    var id: String { rawValue }

    var title: String {
        appString("theme.\(rawValue)")
    }

    var colors: [Color] {
        switch self {
        case .oceanMint:
            [
                Color("AccentColor"),
                Color(hex: 0x0076E6),
                Color(hex: 0x0092CE),
                Color(hex: 0x00AAB4),
                Color(hex: 0x00BF94),
                Color(hex: 0x22D36B),
            ]
        case .orangePink:
            [0xFF7A00, 0xE67C63, 0xCE7A90, 0xB675B4, 0xA06CD6, 0x8B5CF6].map { Color(hex: $0) }
        case .mintPink:
            [0x176B64, 0x347D73, 0x507D7A, 0x80596F, 0x984E69, 0xB34F73].map { Color(hex: $0) }
        }
    }

    var primary: Color { colors[0] }
    var secondary: Color { colors[2] }
    var accent: Color { colors[3] }
    var end: Color { colors[5] }

    var onGradient: Color {
        .white
    }

    var brandGradient: LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var softBackground: LinearGradient {
        LinearGradient(
            colors: [primary.opacity(0.12), secondary.opacity(0.08), end.opacity(0.10)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func resolved(from rawValue: String) -> ColorPreset {
        ColorPreset(rawValue: rawValue) ?? .oceanMint
    }
}

enum ThemeStorage {
    static let key = "selectedColorPreset"
}

struct ColorPresetSwatch: View {
    let preset: ColorPreset
    var width: CGFloat = 84
    var height: CGFloat = 28

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(preset.colors.enumerated()), id: \.offset) { _, color in
                color
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}
