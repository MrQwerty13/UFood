//
//  AIAssistant.swift
//  UFood
//

import UIKit
import Foundation

enum AIAssistant {
    enum Provider: String, CaseIterable, Identifiable {
        case chatGPT
        case claude
        case deepSeek

        var id: String { rawValue }

        var title: String {
            appString("ai.\(rawValue)")
        }

        static func resolved(from rawValue: String) -> Provider {
            Provider(rawValue: rawValue) ?? .chatGPT
        }
    }

    /// Prompt crafted so the model returns a clean gram estimate for the calorie tracker.
    static func gramsEstimatePrompt(
        foodName: String?,
        kcalPer100g: Double?,
        replyLanguage: String
    ) -> String {
        let food = foodName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let foodLine = (food?.isEmpty == false) ? food! : "unknown food (I will describe it)"
        let kcalLine: String = {
            if let kcalPer100g, kcalPer100g > 0 {
                return "Label / known value: \(CalorieMath.formatted(kcalPer100g)) kcal per 100g (for context only)."
            }
            return "kcal per 100g: unknown."
        }()

        return """
        I am logging food in a calorie tracker and need an estimate of how many grams I ate.
        Please reply in \(replyLanguage).

        Food: \(foodLine)
        \(kcalLine)

        Instructions:
        1. Ask me a few short clarifying questions about portion size (hand/palm, cups, plate fill, package size, common object comparisons).
        2. After my answers, give ONE best estimate in grams.
        3. Also give a realistic min–max range in grams.
        4. End with exactly this line so I can copy it into the app:
        Estimated grams: <number>

        Keep the final answer short. Do not convert to calories unless I ask.
        """
    }

    @MainActor
    static func open(_ provider: Provider, prompt: String) {
        UIPasteboard.general.string = prompt

        switch provider {
        case .chatGPT:
            openPreferred(
                appURL: URL(string: "chatgpt://"),
                webURL: webURL(base: "https://chatgpt.com/", prompt: prompt)
            )
        case .claude:
            openPreferred(
                appURL: URL(string: "claude://"),
                webURL: URL(string: "https://claude.ai/new")
            )
        case .deepSeek:
            openPreferred(
                appURL: URL(string: "deepseek://"),
                webURL: URL(string: "https://chat.deepseek.com/")
            )
        }
    }

    @MainActor
    private static func openPreferred(appURL: URL?, webURL: URL?) {
        let application = UIApplication.shared
        if let appURL, application.canOpenURL(appURL) {
            application.open(appURL)
            return
        }
        if let webURL {
            application.open(webURL)
        }
    }

    private static func webURL(base: String, prompt: String) -> URL? {
        var components = URLComponents(string: base)
        components?.queryItems = [URLQueryItem(name: "q", value: prompt)]
        return components?.url
    }
}
