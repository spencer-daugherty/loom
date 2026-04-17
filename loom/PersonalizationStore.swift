import Foundation
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

struct PersonalizationSnapshotState: Codable, Sendable {
    var current: PersonalizationSnapshot?
    var history: [PersonalizationSnapshot]

    static let empty = PersonalizationSnapshotState(current: nil, history: [])
}

protocol PersonalizationRepository: Sendable {
    func loadState(for userKey: String) async throws -> PersonalizationSnapshotState
    func saveState(_ state: PersonalizationSnapshotState, for userKey: String) async throws
    func clearState(for userKey: String) async throws
}

actor LocalPersonalizationRepository: PersonalizationRepository {
    private let baseDirectoryURL: URL

    init(baseDirectoryURL: URL? = nil) {
        if let baseDirectoryURL {
            self.baseDirectoryURL = baseDirectoryURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.baseDirectoryURL = appSupport.appendingPathComponent("loom-personalization", isDirectory: true)
        }
    }

    func loadState(for userKey: String) async throws -> PersonalizationSnapshotState {
        let url = fileURL(for: userKey)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .empty
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PersonalizationSnapshotState.self, from: data)
    }

    func saveState(_ state: PersonalizationSnapshotState, for userKey: String) async throws {
        let url = fileURL(for: userKey)
        try ensureDirectory()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(state)
        try data.write(to: url, options: [.atomic])
    }

    func clearState(for userKey: String) async throws {
        let url = fileURL(for: userKey)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    private func ensureDirectory() throws {
        try FileManager.default.createDirectory(
            at: baseDirectoryURL,
            withIntermediateDirectories: true
        )
    }

    private func fileURL(for userKey: String) -> URL {
        baseDirectoryURL
            .appendingPathComponent(PersonalizationUserIdentity.storageSafeKey(for: userKey))
            .appendingPathExtension("json")
    }
}

enum PersonalizationSaveSource: String, Sendable {
    case onboarding
    case accountEdit = "account_edit"
    case accountReset = "account_reset"
}

@MainActor
final class PersonalizationStore: ObservableObject {
    @Published private(set) var current: PersonalizationSnapshot?
    @Published private(set) var history: [PersonalizationSnapshot] = []
    @Published private(set) var isLoading = false
    @Published private(set) var userKey: String

    private let repository: any PersonalizationRepository

    init(repository: (any PersonalizationRepository)? = nil) {
        self.repository = repository ?? Self.makeDefaultRepository()
        self.userKey = PersonalizationUserIdentity.currentUserKey()

        let cached = Self.cachedState(for: self.userKey)
        apply(state: cached, updateUserKey: false)

        Task {
            await reloadForCurrentUser()
        }
    }

    func reloadForCurrentUser() async {
        let resolvedUserKey = PersonalizationUserIdentity.currentUserKey()
        AppDebugActivityLog.log("PersonalizationStore", "reloadForCurrentUser started userKey=\(resolvedUserKey)")
        if resolvedUserKey != userKey {
            userKey = resolvedUserKey
            AppDebugActivityLog.log("PersonalizationStore", "userKey changed to \(resolvedUserKey), applying cached state")
            apply(state: Self.cachedState(for: resolvedUserKey), updateUserKey: false)
        }

        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await repository.loadState(for: resolvedUserKey)
            apply(state: loaded, updateUserKey: false)
            Self.cacheState(normalizedState(), for: resolvedUserKey)
            AppDebugActivityLog.log(
                "PersonalizationStore",
                "reloadForCurrentUser succeeded current=\(current != nil) history=\(history.count)"
            )
        } catch {
            // Keep cached in-memory state if repository load fails.
            AppDebugActivityLog.log("PersonalizationStore", "reloadForCurrentUser failed error=\(error.localizedDescription)")
        }
    }

    func saveSnapshot(
        from draft: PersonalizationDraft,
        source _: PersonalizationSaveSource
    ) async throws -> PersonalizationSnapshot {
        guard var snapshot = draft.snapshotValue() else {
            AppDebugActivityLog.log("PersonalizationStore", "saveSnapshot failed: incomplete draft")
            throw PersonalizationStoreError.incompleteDraft
        }
        if let existingCurrent = current {
            snapshot.diagnosticRootCause = existingCurrent.diagnosticRootCause
            snapshot.diagnosticNextDirection = existingCurrent.diagnosticNextDirection
        }
        AppDebugActivityLog.log(
            "PersonalizationStore",
            "saveSnapshot started snapshot=\(snapshot.id.uuidString) createdAt=\(snapshot.createdAt.ISO8601Format())"
        )

        var nextHistory = history
        if let existingCurrent = current {
            nextHistory.removeAll { $0.id == existingCurrent.id }
            nextHistory.insert(existingCurrent, at: 0)
        }

        current = snapshot
        history = normalize(history: nextHistory, excluding: snapshot.id)

        let state = normalizedState()
        try await repository.saveState(state, for: userKey)
        Self.cacheState(state, for: userKey)
        AppDebugActivityLog.log(
            "PersonalizationStore",
            "saveSnapshot completed current=\(snapshot.id.uuidString) history=\(history.count)"
        )
        return snapshot
    }

    func persistDiagnosticInsights(
        snapshotID: UUID,
        rootCause: String,
        nextDirection: String
    ) async {
        var updated = false

        if var currentSnapshot = current, currentSnapshot.id == snapshotID {
            currentSnapshot.diagnosticRootCause = rootCause
            currentSnapshot.diagnosticNextDirection = nextDirection
            current = currentSnapshot
            updated = true
        }

        if let historyIndex = history.firstIndex(where: { $0.id == snapshotID }) {
            history[historyIndex].diagnosticRootCause = rootCause
            history[historyIndex].diagnosticNextDirection = nextDirection
            updated = true
        }

        guard updated else {
            AppDebugActivityLog.log(
                "PersonalizationStore",
                "persistDiagnosticInsights skipped snapshot=\(snapshotID.uuidString) reason=missing_snapshot"
            )
            return
        }

        let state = normalizedState()
        do {
            try await repository.saveState(state, for: userKey)
            Self.cacheState(state, for: userKey)
            AppDebugActivityLog.log(
                "PersonalizationStore",
                "persistDiagnosticInsights completed snapshot=\(snapshotID.uuidString)"
            )
        } catch {
            AppDebugActivityLog.log(
                "PersonalizationStore",
                "persistDiagnosticInsights failed snapshot=\(snapshotID.uuidString) error=\(error.localizedDescription)"
            )
        }
    }

    func makeHistorySummary(limit: Int = 3) -> [String] {
        PersonalizationHistoryDiff.recentChanges(
            current: current,
            history: history,
            limit: limit
        )
    }

    func resetCurrentUserState() async {
        let resolvedUserKey = PersonalizationUserIdentity.currentUserKey()
        await resetState(for: resolvedUserKey)
    }

    func resetState(for userKey: String) async {
        do {
            try await repository.clearState(for: userKey)
        } catch {
            AppDebugActivityLog.log("PersonalizationStore", "resetCurrentUserState failed error=\(error.localizedDescription)")
        }
        let emptyState = PersonalizationSnapshotState.empty
        if self.userKey == userKey {
            apply(state: emptyState, updateUserKey: false)
        }
        Self.cacheState(emptyState, for: userKey)
    }

    static func cachedContextForCurrentUser(defaults: UserDefaults = .standard) -> PersonalizationContextValue? {
        let userKey = PersonalizationUserIdentity.currentUserKey(defaults: defaults)
        let state = cachedState(for: userKey, defaults: defaults)
        guard let current = state.current else { return nil }
        return PersonalizationContextValue(
            current: current,
            recentChanges: PersonalizationHistoryDiff.recentChanges(
                current: current,
                history: state.history,
                limit: 3
            )
        )
    }

    static func cachedStateForCurrentUser(defaults: UserDefaults = .standard) -> PersonalizationSnapshotState {
        let userKey = PersonalizationUserIdentity.currentUserKey(defaults: defaults)
        return cachedState(for: userKey, defaults: defaults)
    }

    private func normalizedState() -> PersonalizationSnapshotState {
        PersonalizationSnapshotState(
            current: current,
            history: normalize(history: history, excluding: current?.id)
        )
    }

    private func apply(state: PersonalizationSnapshotState, updateUserKey: Bool) {
        if updateUserKey {
            userKey = PersonalizationUserIdentity.currentUserKey()
        }
        current = state.current
        history = normalize(history: state.history, excluding: state.current?.id)
    }

    private func normalize(history: [PersonalizationSnapshot], excluding currentID: UUID?) -> [PersonalizationSnapshot] {
        var seen = Set<UUID>()
        return history
            .filter { snapshot in
                guard snapshot.id != currentID else { return false }
                return seen.insert(snapshot.id).inserted
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private static func makeDefaultRepository() -> any PersonalizationRepository {
        #if canImport(FirebaseFirestore)
        return FirestorePersonalizationRepository()
        #else
        return LocalPersonalizationRepository()
        #endif
    }

    private static func cacheState(_ state: PersonalizationSnapshotState, for userKey: String, defaults: UserDefaults = .standard) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(state) else { return }
        defaults.set(data, forKey: cacheKey(for: userKey))
    }

    private static func cachedState(for userKey: String, defaults: UserDefaults = .standard) -> PersonalizationSnapshotState {
        guard let data = defaults.data(forKey: cacheKey(for: userKey)) else {
            return .empty
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(PersonalizationSnapshotState.self, from: data)) ?? .empty
    }

    private static func cacheKey(for userKey: String) -> String {
        "loom.personalization.cache.v1.\(PersonalizationUserIdentity.storageSafeKey(for: userKey))"
    }
}

enum PersonalizationStoreError: Error {
    case incompleteDraft
}

enum PersonalizationUserIdentity {
    static func currentUserKey(defaults: UserDefaults = .standard) -> String {
        #if canImport(FirebaseAuth)
        if let uid = Auth.auth().currentUser?.uid.trimmingCharacters(in: .whitespacesAndNewlines),
           !uid.isEmpty {
            return "firebase:\(uid)"
        }
        #endif

        if let googleID = defaults.string(forKey: UserSessionStore.Keys.googleUserID)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !googleID.isEmpty {
            return "google:\(googleID)"
        }
        if let appleID = defaults.string(forKey: UserSessionStore.Keys.appleUserID)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !appleID.isEmpty {
            return "apple:\(appleID)"
        }
        return "device:default"
    }

    static func storageSafeKey(for userKey: String) -> String {
        userKey
            .lowercased()
            .map { char in
                if char.isLetter || char.isNumber { return String(char) }
                return "_"
            }
            .joined()
    }

    #if canImport(FirebaseFirestore)
    static func firebaseUID(from userKey: String) -> String? {
        guard userKey.hasPrefix("firebase:") else { return nil }
        let uid = String(userKey.dropFirst("firebase:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        return uid.isEmpty ? nil : uid
    }
    #endif
}
