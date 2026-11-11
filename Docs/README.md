# UFood

UFood is an iOS food and calorie tracker. Log meals, review your daily calorie balance, and optionally compare food intake with energy burned from Apple Health.

## Features

- Log foods with calories per 100 g and the portion eaten.
- Choose from built-in fruit and vegetable presets, or manage your own presets.
- Assign a built-in or custom tag to each entry.
- See daily eaten, burned, and net calories.
- Connect to Apple Health to read active and resting energy and save logged dietary energy.
- Add the calorie-balance widget to the Home Screen. It shows eaten calories and, when Apple Health data is available, burned calories and the net balance.
- Choose English, Russian, or the device language.
- Choose a Blue-Green, Orange-Violet, or Mint-Pink theme.
- Copy an AI prompt to estimate portion size, or open a supported AI assistant.

## Requirements

- iOS 17.6 or later
- Xcode with iOS and WidgetKit SDKs
- An Apple Developer team with HealthKit and App Groups capabilities enabled to use those integrations on a physical device

## Project layout

```text
UFood/              iOS app source, assets, and localizations
UFoodWidget/        Home Screen widget extension
WidgetShared/       Data shared between the app and widget
UFood.xcodeproj/    Project configuration
Docs/README.md      Project documentation
```

The app uses SwiftUI, SwiftData, HealthKit, and WidgetKit. Food entries are stored locally with SwiftData. The widget reads a daily summary shared by the app through the `group.MrQwerty13.UFood` App Group.

## Build and run

Open the project in Xcode, select the **UFood** scheme and an iOS Simulator or connected device, then build and run. To use Apple Health or the widget on a device, configure the App Group and HealthKit capabilities for the app and widget extension with the signing team.

If you do not connect Apple Health, the app continues to track food intake. The widget shows eaten calories and indicates that burned calories are unavailable; it does not treat missing Health data as zero.

## Localization

The app and widget interface are localized in English and Russian. The app can follow the device language or use the language selected in Settings. The widget follows the device language.

## Food tags and presets

The built-in tags are Fruits, Vegetables, Drinks, and Snacks. Additional tags can be created while adding food. Presets are managed separately from tags and include fruit and vegetable items.

## Apple Health data

With permission, UFood reads active and resting energy burned for the current day and writes dietary energy for saved food entries. Health data is optional; the food log works without it.

## Dish search

Searching for foods on an external website is not implemented yet. See [the feasibility report](../Future/WEB_DISH_SEARCH_FEASIBILITY.md) for the investigated approaches and trade-offs.
