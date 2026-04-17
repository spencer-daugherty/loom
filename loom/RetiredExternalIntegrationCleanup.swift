import Foundation
import SwiftData

enum RetiredExternalIntegrationCleanup {
    private static let migrationKey = "loom.retiredExternalIntegrationCleanup.v1"
    private static let retiredSourceTypes: Set<String> = ["google_tasks", "microsoft_todo"]
    private static let legacyDefaultsKeys: [String] = [
        "capture_google_tasks_connected",
        "capture_google_tasks_last_sync_unix",
        "capture_google_tasks_initial_import_done",
        "capture_google_tasks_access_token",
        "capture_google_tasks_refresh_token",
        "capture_google_tasks_access_expiry_unix",
        "capture_microsoft_todo_connected",
        "capture_microsoft_todo_last_sync_unix",
        "capture_microsoft_todo_initial_import_done",
        "capture_microsoft_todo_access_token",
        "capture_microsoft_todo_refresh_token",
        "capture_microsoft_todo_access_expiry_unix"
    ]
    private static let sourceDueDateOverridesKey = "capture_source_due_date_overrides_json"

    static func runIfNeeded(in modelContext: ModelContext) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: migrationKey) else { return }

        do {
            var didChangeModels = false
            didChangeModels = migrateRollingCaptureItems(in: modelContext) || didChangeModels
            didChangeModels = migrateQuickCompletedCaptureItems(in: modelContext) || didChangeModels

            if didChangeModels {
                try modelContext.save()
            }

            clearLegacyDefaults()
            clearRetiredSourceDueDateOverrides()
            defaults.set(true, forKey: migrationKey)
            AppDebugActivityLog.log("RetiredExternalIntegrationCleanup", "Completed retired provider cleanup.")
        } catch {
            AppDebugActivityLog.log(
                "RetiredExternalIntegrationCleanup",
                "Cleanup failed error=\(error.localizedDescription)"
            )
        }
    }

    private static func migrateRollingCaptureItems(in modelContext: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<RollingCaptureItem>()
        let items = (try? modelContext.fetch(descriptor)) ?? []
        var didChange = false

        for item in items {
            guard let sourceType = item.sourceType, retiredSourceTypes.contains(sourceType) else { continue }
            item.sourceType = nil
            item.sourceExternalID = nil
            didChange = true
        }
        return didChange
    }

    private static func migrateQuickCompletedCaptureItems(in modelContext: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<QuickCompletedCaptureItem>()
        let items = (try? modelContext.fetch(descriptor)) ?? []
        var didChange = false

        for item in items {
            guard let sourceType = item.sourceType, retiredSourceTypes.contains(sourceType) else { continue }
            item.sourceType = nil
            item.sourceExternalID = nil
            didChange = true
        }
        return didChange
    }

    private static func clearLegacyDefaults() {
        let defaults = UserDefaults.standard
        for key in legacyDefaultsKeys {
            defaults.removeObject(forKey: key)
        }
    }

    private static func clearRetiredSourceDueDateOverrides() {
        let defaults = UserDefaults.standard
        guard let rawJSON = defaults.string(forKey: sourceDueDateOverridesKey),
              let data = rawJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: SourceOverridePayload].self, from: data) else {
            return
        }

        let filtered = decoded.filter { key, _ in
            !retiredSourceTypes.contains { retired in
                key.hasPrefix(retired + "|")
            }
        }

        if filtered.isEmpty {
            defaults.removeObject(forKey: sourceDueDateOverridesKey)
            return
        }

        guard let filteredData = try? JSONEncoder().encode(filtered),
              let filteredJSON = String(data: filteredData, encoding: .utf8) else {
            return
        }
        defaults.set(filteredJSON, forKey: sourceDueDateOverridesKey)
    }

    private struct SourceOverridePayload: Codable {
        let hasDueDate: Bool
        let dueDateUnix: TimeInterval
    }
}
