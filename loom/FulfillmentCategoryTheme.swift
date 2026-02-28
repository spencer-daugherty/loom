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
    private static let completedOutcomeColorKeyByArchiveKey = "completed_outcome_color_key_by_archive_v1"
    private static let completedActionBlockChunkColorKeyByArchiveChunkKey = "completed_action_block_chunk_color_key_v1"
    private static let categoryAliasesKey = "fulfillment_category_aliases_v1"

    static let palette: [PaletteOption] = [
        PaletteOption(key: "blue", name: "Blue", color: .blue),
        PaletteOption(key: "indigo", name: "Indigo", color: .indigo),
        PaletteOption(key: "green", name: "Green", color: .green),
        PaletteOption(key: "purple", name: "Purple", color: .purple),
        PaletteOption(key: "red", name: "Red", color: .red),
        PaletteOption(key: "orange", name: "Orange", color: .orange),
        PaletteOption(key: "brown", name: "Brown", color: .brown),
        PaletteOption(key: "pink", name: "Pink", color: Color(red: 0.74, green: 0.20, blue: 0.47))
    ]

    static func defaultColorKeys() -> [String: String] {
        [
            "Career & Business": "blue",
            "Leadership & Impact": "indigo",
            "Wealth & Lifestyle": "green",
            "Wealth & Finance": "green",
            "Mind & Meaning": "purple",
            "Love & Relationships": "red",
            "Health & Vitality": "orange",
            "Health & Energy": "orange"
        ]
    }

    static func persistedColorKeys() -> [String: String] {
        let raw = UserDefaults.standard.dictionary(forKey: userDefaultsKey) as? [String: String] ?? [:]
        return raw.mapValues { $0 == "yellow" ? "brown" : $0 }
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

    static func colorKey(for category: String, colorKeys: [String: String]? = nil) -> String {
        let map = colorKeys ?? persistedColorKeys()
        return map[category] ?? defaultColorKeys()[category] ?? "blue"
    }

    static func color(forKey key: String) -> Color {
        let resolvedKey = key == "yellow" ? "brown" : key
        return palette.first(where: { $0.key == resolvedKey })?.color ?? .gray
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

    static func lightColor(forKey key: String) -> Color {
        #if canImport(UIKit)
        let base = UIColor(color(forKey: key))
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
        return color(forKey: key)
        #endif
    }

    static func saveCompletedOutcomeColorKey(_ colorKey: String, archiveId: UUID) {
        var map = UserDefaults.standard.dictionary(forKey: completedOutcomeColorKeyByArchiveKey) as? [String: String] ?? [:]
        map[archiveId.uuidString] = colorKey
        UserDefaults.standard.set(map, forKey: completedOutcomeColorKeyByArchiveKey)
    }

    static func completedOutcomeColorKey(archiveId: UUID) -> String? {
        let map = UserDefaults.standard.dictionary(forKey: completedOutcomeColorKeyByArchiveKey) as? [String: String] ?? [:]
        return map[archiveId.uuidString]
    }

    static func saveCompletedActionBlockChunkColorKey(_ colorKey: String, archiveId: UUID, chunkId: UUID) {
        var map = UserDefaults.standard.dictionary(forKey: completedActionBlockChunkColorKeyByArchiveChunkKey) as? [String: String] ?? [:]
        map["\(archiveId.uuidString)|\(chunkId.uuidString)"] = colorKey
        UserDefaults.standard.set(map, forKey: completedActionBlockChunkColorKeyByArchiveChunkKey)
    }

    static func completedActionBlockChunkColorKey(archiveId: UUID, chunkId: UUID) -> String? {
        let map = UserDefaults.standard.dictionary(forKey: completedActionBlockChunkColorKeyByArchiveChunkKey) as? [String: String] ?? [:]
        return map["\(archiveId.uuidString)|\(chunkId.uuidString)"]
    }

    static func categoryAliases() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: categoryAliasesKey) as? [String: String] ?? [:]
    }

    static func saveCategoryAlias(from oldName: String, to newName: String) {
        let from = oldName.trimmingCharacters(in: .whitespacesAndNewlines)
        let to = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !from.isEmpty, !to.isEmpty else { return }
        var map = categoryAliases()
        map[from.lowercased()] = to
        UserDefaults.standard.set(map, forKey: categoryAliasesKey)
    }

    static func categoryAlias(for previousName: String) -> String? {
        let key = previousName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return nil }
        return categoryAliases()[key]
    }

    static func clearFulfillmentPreferences() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: userDefaultsKey)
        defaults.removeObject(forKey: completedOutcomeColorKeyByArchiveKey)
        defaults.removeObject(forKey: completedActionBlockChunkColorKeyByArchiveChunkKey)
        defaults.removeObject(forKey: categoryAliasesKey)
    }
}
