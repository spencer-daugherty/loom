import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct FulfillmentCategoryTheme {
    struct PaletteOption {
        let key: String
        let name: String
        let color: Color
    }

    static let userDefaultsKey = "fulfillment_category_color_prefs_v1"

    static let palette: [PaletteOption] = [
        PaletteOption(key: "blue", name: "Blue", color: .blue),
        PaletteOption(key: "indigo", name: "Indigo", color: .indigo),
        PaletteOption(key: "green", name: "Green", color: .green),
        PaletteOption(key: "purple", name: "Purple", color: .purple),
        PaletteOption(key: "red", name: "Red", color: .red),
        PaletteOption(key: "orange", name: "Orange", color: .orange),
        PaletteOption(key: "yellow", name: "Yellow", color: Color(red: 0.65, green: 0.47, blue: 0.00)),
        PaletteOption(key: "pink", name: "Pink", color: Color(red: 0.74, green: 0.20, blue: 0.47))
    ]

    static func defaultColorKeys() -> [String: String] {
        [
            "Career & Business": "blue",
            "Leadership & Impact": "indigo",
            "Wealth & Lifestyle": "green",
            "Mind & Meaning": "purple",
            "Love & Relationships": "red",
            "Health & Vitality": "orange"
        ]
    }

    static func persistedColorKeys() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: userDefaultsKey) as? [String: String] ?? [:]
    }

    static func persistColorKeys(_ map: [String: String]) {
        UserDefaults.standard.set(map, forKey: userDefaultsKey)
    }

    static func resolvedColorKeys(for categories: [String]) -> [String: String] {
        let defaults = defaultColorKeys()
        let persisted = persistedColorKeys()
        var map = defaults.merging(persisted) { _, rhs in rhs }
        let keys = palette.map(\.key)
        var used = Set<String>()

        for category in categories {
            let current = map[category]
            if let current, keys.contains(current), !used.contains(current) {
                used.insert(current)
                continue
            }
            if let next = keys.first(where: { !used.contains($0) }) {
                map[category] = next
                used.insert(next)
            } else if let fallback = defaults[category] {
                map[category] = fallback
            } else {
                map[category] = "blue"
            }
        }
        return map
    }

    static func color(for category: String, colorKeys: [String: String]? = nil) -> Color {
        let map = colorKeys ?? persistedColorKeys()
        let key = map[category] ?? defaultColorKeys()[category] ?? "blue"
        return palette.first(where: { $0.key == key })?.color ?? .gray
    }

    static func lightColor(for category: String) -> Color {
        #if canImport(UIKit)
        let base = UIColor(color(for: category))
        return Color(UIColor { trait in
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            base.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            let factor: CGFloat = trait.userInterfaceStyle == .dark ? 0.4 : 0.8
            red += (1.0 - red) * factor
            green += (1.0 - green) * factor
            blue += (1.0 - blue) * factor
            return UIColor(red: red, green: green, blue: blue, alpha: alpha)
        })
        #else
        return color(for: category)
        #endif
    }
}

