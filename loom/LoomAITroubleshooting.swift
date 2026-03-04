import SwiftUI
import UIKit

let loomAITroubleshootingDefaultsKey = "loom.enableLoomAITroubleshooting"
let loomAIDebugDefaultsKey = "loom.enableLoomAIDebug"
let loomAISlowResponseThresholdMS: Double = 5_000

func registerLoomAITroubleshootingDefaultIfNeeded() {
    let defaults = UserDefaults.standard
    // Troubleshooting popups are disabled app-wide.
    defaults.set(false, forKey: loomAITroubleshootingDefaultsKey)
    if defaults.object(forKey: loomAIDebugDefaultsKey) == nil {
        defaults.set(true, forKey: loomAIDebugDefaultsKey)
    }
}

func loomAISlowResponseTroubleshootingDetailsIfNeeded(
    feature: String,
    elapsedMS: Double,
    responsePreview: String? = nil,
    intent: String? = nil,
    screen: String? = nil,
    requestID: String? = nil,
    requestHash: String? = nil
) -> String? {
    guard elapsedMS > loomAISlowResponseThresholdMS else { return nil }
    let elapsedSeconds = elapsedMS / 1000
    let intentValue = (intent ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let screenValue = (screen ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let reason = String(
        format: "Slow LoomAI response: %.2fs (> %.2fs). intent=%@ screen=%@",
        elapsedSeconds,
        loomAISlowResponseThresholdMS / 1000,
        intentValue.isEmpty ? "<none>" : intentValue,
        screenValue.isEmpty ? "<none>" : screenValue
    )
    return loomAITroubleshootingLocalDetails(
        feature: feature,
        reason: reason,
        responsePreview: responsePreview,
        requestID: requestID,
        requestHash: requestHash
    )
}

func loomAIDuplicateSuggestionTroubleshootingDetails(
    feature: String,
    reason: String,
    responsePreview: String? = nil,
    requestID: String? = nil,
    requestHash: String? = nil
) -> String {
    let normalizedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
    return loomAITroubleshootingLocalDetails(
        feature: feature,
        reason: "Duplicate suggestion detected. \(normalizedReason)",
        responsePreview: responsePreview,
        requestID: requestID,
        requestHash: requestHash
    )
}

func loomAIReportTroubleshootingIfEnabled(details: String) {
    _ = details
    return
}

func loomAICopyTroubleshootingToClipboard(_ details: String) {
    _ = details
    return
}

@MainActor
final class LoomAITroubleshootingCenter: ObservableObject {
    struct Entry: Identifiable, Equatable {
        let id = UUID()
        let createdAt: Date
        let details: String
    }

    static let shared = LoomAITroubleshootingCenter()

    @Published private(set) var entries: [Entry] = []

    func report(details: String) {
        let trimmed = details.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if entries.last?.details == trimmed { return }
        entries.append(Entry(createdAt: .now, details: trimmed))
        if entries.count > 20 {
            entries = Array(entries.suffix(20))
        }
    }

    func dismiss(_ id: Entry.ID) {
        entries.removeAll { $0.id == id }
    }
}

struct LoomAITroubleshootingBannerHost: View {
    var body: some View {
        EmptyView()
    }
}

func loomAITroubleshootingDetails(
    feature: String,
    error: Error,
    requestID: String? = nil,
    requestHash: String? = nil
) -> String {
    if let serviceError = error as? LoomAIService.LoomAIServiceError {
        return loomAITroubleshootingDetails(
            feature: feature,
            statusCode: serviceError.statusCode,
            contentType: serviceError.contentType,
            rawBody: serviceError.rawBody,
            reason: serviceError.message,
            requestID: requestID,
            requestHash: requestHash
        )
    }

    let nsError = error as NSError
    return loomAITroubleshootingDetails(
        feature: feature,
        statusCode: nil,
        contentType: nil,
        rawBody: nil,
        reason: "\(nsError.domain) (\(nsError.code)): \(nsError.localizedDescription)",
        requestID: requestID,
        requestHash: requestHash
    )
}

func loomAITroubleshootingDetails(
    feature: String,
    statusCode: Int?,
    contentType: String?,
    rawBody: String?,
    reason: String,
    requestID: String? = nil,
    requestHash: String? = nil
) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss"
    let stamp = formatter.string(from: .now)

    var lines: [String] = []
    lines.append("[\(stamp)] feature=\(feature)")
    lines.append("reason=\(reason)")
    if let statusCode {
        lines.append("status=\(statusCode)")
    }
    if let contentType, !contentType.isEmpty {
        lines.append("content-type=\(contentType)")
    }
    if let requestID, !requestID.isEmpty {
        lines.append("request-id=\(requestID)")
    }
    if let requestHash, !requestHash.isEmpty {
        lines.append("request-hash=\(requestHash)")
    }
    if let rawBody {
        let preview = String(rawBody.prefix(2500))
        lines.append("response=\(preview.isEmpty ? "<empty>" : preview)")
    }
    return lines.joined(separator: "\n")
}

func loomAITroubleshootingLocalDetails(
    feature: String,
    reason: String,
    responsePreview: String? = nil,
    requestID: String? = nil,
    requestHash: String? = nil
) -> String {
    let trimmedResponse = responsePreview?
        .replacingOccurrences(of: "\r\n", with: "\n")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    return loomAITroubleshootingDetails(
        feature: feature,
        statusCode: nil,
        contentType: nil,
        rawBody: trimmedResponse,
        reason: reason,
        requestID: requestID,
        requestHash: requestHash
    )
}

struct LoomAITroubleshootingSection: View {
    let details: String

    var body: some View {
        _ = details
        return EmptyView()
    }
}

struct LoomAIBottomCopyTroubleshootingButton: View {
    let details: String

    var body: some View {
        _ = details
        return EmptyView()
    }
}
