import SwiftUI
import SwiftData

#if canImport(UIKit)
import UIKit
#endif

/// Temporary diagnostics screen for Vision AutoWrite raw worker responses.
/// Delete this file and the `showTemporaryVisionAutoWriteDebugPage` branch in `loomApp.swift`
/// to remove it entirely.
struct TemporaryVisionAutoWriteDebugView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var currentVision: String = ""
    @State private var mode: String = "newVision"
    @State private var previousSuggestionsText: String = ""
    @State private var isLoading = false
    @State private var responseStatus: String = "Idle"
    @State private var responseDurationText: String = "-"
    @State private var rawResponseText: String = ""
    @State private var rawRequestText: String = ""
    @State private var requestCopied = false
    @State private var responseCopied = false

    private let endpointURL = URL(string: "https://loom-ai-minimal.spence0927.workers.dev/purpose/vision/autowrite")!

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Vision AutoWrite Debug")
                    .font(.title2.weight(.bold))

                TextField("Current vision (optional)", text: $currentVision, axis: .vertical)
                    .textFieldStyle(.roundedBorder)

                Picker("Mode", selection: $mode) {
                    Text("newVision").tag("newVision")
                    Text("rewordVision").tag("rewordVision")
                }
                .pickerStyle(.segmented)

                TextField("Previous suggestions (one per line)", text: $previousSuggestionsText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)

                Button {
                    Task { await sendAutoWriteRequest() }
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(.circular)
                        }
                        Text(isLoading ? "Loading..." : "AutoWrite")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)

                Text("Status: \(responseStatus)")
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                Text("Duration: \(responseDurationText)")
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)

                Group {
                    Text("Raw Request JSON")
                        .font(.caption.weight(.semibold))
                    copyableCodeBlock(rawRequestText, copied: $requestCopied)
                }

                Group {
                    Text("Raw Response JSON")
                        .font(.caption.weight(.semibold))
                    copyableCodeBlock(rawResponseText, copied: $responseCopied)
                }

                Spacer(minLength: 0)
            }
            .padding(16)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func copyableCodeBlock(_ text: String, copied: Binding<Bool>) -> some View {
        let value = text.isEmpty ? "<empty>" : text
        ScrollView {
            Text(value)
                .font(.caption.monospaced())
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .padding(.top, 26)
        }
        .frame(minHeight: 120, maxHeight: 220)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            Button {
                markCopied(copied, value: value)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: copied.wrappedValue ? "checkmark.circle.fill" : "doc.on.doc")
                    Text(copied.wrappedValue ? "Copied" : "Copy")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(copied.wrappedValue ? .green : .secondary)
                .padding(8)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button("Copy") {
                markCopied(copied, value: value)
            }
        }
        .highPriorityGesture(
            LongPressGesture(minimumDuration: 0.35)
                .onEnded { _ in
                    markCopied(copied, value: value)
                }
        )
    }

    private func copyToClipboard(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #endif
    }

    private func markCopied(_ copied: Binding<Bool>, value: String) {
        copyToClipboard(value)
        copied.wrappedValue = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            copied.wrappedValue = false
        }
    }

    private func sendAutoWriteRequest() async {
        isLoading = true
        responseStatus = "Preparing request..."
        responseDurationText = "-"
        defer { isLoading = false }
        let startedAt = Date()

        do {
            let contextSnapshot = try LoomAIViewModel().buildContextSnapshot(in: modelContext)
            let requestID = UUID().uuidString
            let previousSuggestions = previousSuggestionsText
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            let body: [String: Any] = [
                "currentVision": currentVision.trimmingCharacters(in: .whitespacesAndNewlines),
                "previousSuggestions": previousSuggestions,
                "mode": mode,
                "context": try contextSnapshot.toDictionary(),
                "client": [
                    "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
                    "platform": "iOS",
                    "locale": Locale.current.identifier,
                    "intent": "autowrite_purpose",
                    "screen": "purpose_vision",
                    "requestId": requestID
                ]
            ]

            let bodyData = try JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys])
            rawRequestText = String(data: bodyData, encoding: .utf8) ?? "<request encoding failed>"

            var request = URLRequest(url: endpointURL)
            request.httpMethod = "POST"
            request.timeoutInterval = 45
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = bodyData

            responseStatus = "Sending..."
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let responseText = String(data: data, encoding: .utf8) ?? "<non-UTF8 \(data.count) bytes>"
            rawResponseText = responseText
            responseStatus = "HTTP \(status)"
            responseDurationText = formatDuration(Date().timeIntervalSince(startedAt))
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorTimedOut {
                responseStatus = "Request timed out"
            } else {
                responseStatus = "Request failed"
            }
            rawResponseText = String(describing: error)
            responseDurationText = formatDuration(Date().timeIntervalSince(startedAt))
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        String(format: "%.2fs", max(0, seconds))
    }
}

private extension LoomAIContextSnapshot {
    func toDictionary() throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dictionary = object as? [String: Any] else {
            return [:]
        }
        return dictionary
    }
}
