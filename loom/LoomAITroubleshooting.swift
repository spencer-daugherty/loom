import SwiftUI
import UIKit

let loomAITroubleshootingDefaultsKey = "loom.enableLoomAITroubleshooting"
let loomAISlowResponseThresholdMS: Double = 5_000

func registerLoomAITroubleshootingDefaultIfNeeded() {
    let defaults = UserDefaults.standard
    if defaults.object(forKey: loomAITroubleshootingDefaultsKey) == nil {
        defaults.set(false, forKey: loomAITroubleshootingDefaultsKey)
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
    let text = details.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return }
    guard UserDefaults.standard.bool(forKey: loomAITroubleshootingDefaultsKey) else { return }
    Task { @MainActor in
        LoomAITroubleshootingCenter.shared.report(details: text)
    }
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
    @AppStorage(loomAITroubleshootingDefaultsKey) private var loomAITroubleshootingEnabled = true
    @ObservedObject private var center = LoomAITroubleshootingCenter.shared

    var body: some View {
        if loomAITroubleshootingEnabled, let latest = center.entries.last {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("LoomAI Diagnostic")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer(minLength: 8)
                    Button {
                        center.dismiss(latest.id)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                LoomAITroubleshootingSection(details: latest.details)
            }
            .padding(10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.30), lineWidth: 1)
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
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
        VStack(alignment: .leading, spacing: 6) {
            Text("LoomAI Troubleshooting")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(details)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(Rectangle())
        .contextMenu {
            Button("Copy") {
                UIPasteboard.general.string = details
            }
        }
        .highPriorityGesture(
            LongPressGesture(minimumDuration: 0.4)
                .onEnded { _ in
                    UIPasteboard.general.string = details
                }
        )
    }
}
