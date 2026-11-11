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
        let isRussian = replyLanguage == "Russian"
        let foodLine = (food?.isEmpty == false)
            ? food!
            : (isRussian ? "неизвестный продукт (я опишу его)" : "unknown food (I will describe it)")
        let kcalLine: String = {
            if let kcalPer100g, kcalPer100g > 0 {
                if isRussian {
                    return "Известная калорийность: \(CalorieMath.formatted(kcalPer100g)) ккал на 100 г (только для ориентира)."
                }
                return "Known value: \(CalorieMath.formatted(kcalPer100g)) kcal per 100g (for context only)."
            }
            return isRussian ? "Калорийность на 100 г неизвестна." : "Calories per 100g: unknown."
        }()

        if isRussian {
            return """
            Я записываю еду в дневник калорий и хочу оценить, сколько граммов съел(а).
            Отвечай по-русски.

            Продукт: \(foodLine)
            \(kcalLine)

            Инструкции:
            1. Задай несколько коротких уточняющих вопросов о размере порции (ладонь, чашка, размер тарелки, упаковка или сравнение с обычными предметами).
            2. После моих ответов назови одну наиболее вероятную оценку в граммах.
            3. Также укажи реалистичный диапазон от минимума до максимума в граммах.
            4. Заверши ответ ровно этой строкой, чтобы я мог(ла) скопировать её в приложение:
            Примерный вес в граммах: <число>

            В конце ответь кратко. Не пересчитывай вес в калории, если я не попрошу.
            """
        }

        return """
        I am logging food in a calorie tracker and need an estimate of how many grams I ate.
        Reply in English.

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
