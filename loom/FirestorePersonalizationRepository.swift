#if canImport(FirebaseFirestore)
import Foundation
import FirebaseFirestore

actor FirestorePersonalizationRepository: PersonalizationRepository {
    private let db: Firestore
    private let fallback: any PersonalizationRepository

    init(
        db: Firestore = Firestore.firestore(),
        fallback: any PersonalizationRepository = LocalPersonalizationRepository()
    ) {
        self.db = db
        self.fallback = fallback
    }

    func loadState(for userKey: String) async throws -> PersonalizationSnapshotState {
        guard let uid = PersonalizationUserIdentity.firebaseUID(from: userKey) else {
            return try await fallback.loadState(for: userKey)
        }

        do {
            let currentRef = db
                .collection("users")
                .document(uid)
                .collection("personalization")
                .document("current")
            let historyRef = db
                .collection("users")
                .document(uid)
                .collection("personalization")
                .document("history")
                .collection("snapshots")

            let currentDoc = try await currentRef.getDocument()
            let historyDocs = try await historyRef.order(by: "createdAt", descending: true).limit(to: 200).getDocuments()

            let current = try currentDoc.data().flatMap(Self.decodeSnapshot)
            let history = try historyDocs.documents.compactMap { doc in
                try Self.decodeSnapshot(doc.data())
            }
            return PersonalizationSnapshotState(current: current, history: history)
        } catch {
            return try await fallback.loadState(for: userKey)
        }
    }

    func saveState(_ state: PersonalizationSnapshotState, for userKey: String) async throws {
        guard let uid = PersonalizationUserIdentity.firebaseUID(from: userKey) else {
            try await fallback.saveState(state, for: userKey)
            return
        }

        do {
            let currentRef = db
                .collection("users")
                .document(uid)
                .collection("personalization")
                .document("current")
            let historyRef = db
                .collection("users")
                .document(uid)
                .collection("personalization")
                .document("history")
                .collection("snapshots")

            if let current = state.current {
                try await currentRef.setData(Self.encodeSnapshot(current))
            } else {
                try? await currentRef.delete()
            }

            for snapshot in state.history {
                let doc = historyRef.document(snapshot.id.uuidString)
                try await doc.setData(Self.encodeSnapshot(snapshot))
            }
        } catch {
            try await fallback.saveState(state, for: userKey)
        }
    }

    private static func encodeSnapshot(_ snapshot: PersonalizationSnapshot) -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return object
    }

    private static func decodeSnapshot(_ data: [String: Any]) throws -> PersonalizationSnapshot {
        let jsonData = try JSONSerialization.data(withJSONObject: data)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PersonalizationSnapshot.self, from: jsonData)
    }
}
#endif
