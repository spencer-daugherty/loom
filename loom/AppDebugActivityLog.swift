import Foundation
import Combine

@MainActor
final class AppDebugActivityLog: ObservableObject {
    struct Entry: Identifiable, Hashable {
        let id: UUID
        let timestamp: Date
        let subsystem: String
        let message: String
    }

    static let shared = AppDebugActivityLog()
    private static let lineFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    @Published private(set) var entries: [Entry] = []
    private let maxEntryCount = 1500

    private init() {}

    func clear() {
        guard LoomDeveloperBuild.isInternalBuild else { return }
        entries.removeAll()
    }

    func exportText(limit: Int = 800) -> String {
        guard LoomDeveloperBuild.isInternalBuild else { return "<unavailable in release builds>" }
        let recent = entries.suffix(max(1, limit))
        guard !recent.isEmpty else { return "<no activity yet>" }
        return recent
            .map { entry in
                let time = Self.lineFormatter.string(from: entry.timestamp)
                return "[\(time)] [\(entry.subsystem)] \(entry.message)"
            }
            .joined(separator: "\n")
    }

    private func append(subsystem: String, message: String) {
        guard LoomDeveloperBuild.isInternalBuild else { return }
        let trimmedMessage = message
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return }

        entries.append(
            Entry(
                id: UUID(),
                timestamp: .now,
                subsystem: subsystem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "App" : subsystem,
                message: String(trimmedMessage.prefix(600))
            )
        )

        if entries.count > maxEntryCount {
            entries.removeFirst(entries.count - maxEntryCount)
        }
    }

    nonisolated static func log(_ subsystem: String, _ message: String) {
        guard LoomDeveloperBuild.isInternalBuild else { return }
        Task { @MainActor in
            AppDebugActivityLog.shared.append(subsystem: subsystem, message: message)
        }
    }
}
