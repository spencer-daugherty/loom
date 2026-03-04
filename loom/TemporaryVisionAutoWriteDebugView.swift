import SwiftUI
import SwiftData

#if canImport(UIKit)
import UIKit
#endif

/// Temporary diagnostics screen for Vision AutoWrite raw worker responses.
/// Delete this file and the `showTemporaryVisionAutoWriteDebugPage` branch in `loomApp.swift`
/// to remove it entirely.
struct TemporaryVisionAutoWriteDebugView: View {
    private enum DebugMode: String {
        case newVision
        case rewordVision
        case loomAI
    }

    @Environment(\.modelContext) private var modelContext
    @AppStorage("loom.ai.context.compact.enabled") private var compactContextEnabled = true

    @State private var currentVision: String = ""
    @State private var mode: DebugMode = .newVision
    @State private var previousSuggestionsText: String = ""
    @State private var loomAIPrompt: String = ""
    @State private var isLoading = false
    @State private var responseStatus: String = "Idle"
    @State private var responseDurationText: String = "-"
    @State private var rawResponseText: String = ""
    @State private var rawRequestText: String = ""
    @State private var rawContextText: String = ""
    @State private var usageSummaryText: String = "-"
    @State private var estimatedCostText: String = "-"
    @State private var requestCopied = false
    @State private var responseCopied = false
    @State private var contextCopied = false
    @FocusState private var isInputFocused: Bool

    private let autoWriteEndpointURL = URL(string: "https://loom-ai-minimal.spence0927.workers.dev/purpose/vision/autowrite")!
    private let chatEndpointURL = URL(string: "https://loom-ai-minimal.spence0927.workers.dev/chat")!

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Vision AutoWrite Debug")
                    .font(.title2.weight(.bold))

                Picker("Mode", selection: $mode) {
                    Text("newVision").tag(DebugMode.newVision)
                    Text("rewordVision").tag(DebugMode.rewordVision)
                    Text("LoomAI").tag(DebugMode.loomAI)
                }
                .pickerStyle(.segmented)

                Toggle("Compact", isOn: $compactContextEnabled)
                    .toggleStyle(.switch)

                if mode == .loomAI {
                    TextField("Prompt", text: $loomAIPrompt, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .focused($isInputFocused)
                } else {
                    TextField("Current vision (optional)", text: $currentVision, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .focused($isInputFocused)

                    TextField("Previous suggestions (one per line)", text: $previousSuggestionsText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .focused($isInputFocused)
                }

                Button {
                    Task { await sendRequest() }
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(.circular)
                        }
                        Text(isLoading ? "Loading..." : (mode == .loomAI ? "Send" : "AutoWrite"))
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
                if mode == .loomAI {
                    Text("Usage: \(usageSummaryText)")
                        .font(.footnote.monospaced())
                        .foregroundStyle(.secondary)
                    Text("Estimated cost: \(estimatedCostText)")
                        .font(.footnote.monospaced())
                        .foregroundStyle(.secondary)
                }

                Group {
                    Text("Raw Request JSON")
                        .font(.caption.weight(.semibold))
                    copyableCodeBlock(rawRequestText, copied: $requestCopied)
                }

                if mode == .loomAI {
                    Group {
                        Text("Raw Context JSON")
                            .font(.caption.weight(.semibold))
                        copyableCodeBlock(rawContextText, copied: $contextCopied)
                    }
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isInputFocused {
                HStack {
                    Spacer(minLength: 0)
                    Button {
                        dismissKeyboard()
                    } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(.secondarySystemBackground))
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.systemBackground).opacity(0.96))
            }
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

    private func dismissKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
        isInputFocused = false
    }

    private func markCopied(_ copied: Binding<Bool>, value: String) {
        copyToClipboard(value)
        copied.wrappedValue = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            copied.wrappedValue = false
        }
    }

    private func sendRequest() async {
        if mode == .loomAI {
            await sendLoomAIChatRequest()
        } else {
            await sendAutoWriteRequest()
        }
    }

    private func sendAutoWriteRequest() async {
        isLoading = true
        responseStatus = "Preparing request..."
        responseDurationText = "-"
        usageSummaryText = "-"
        estimatedCostText = "-"
        rawContextText = ""
        defer { isLoading = false }
        let startedAt = Date()

        do {
            let fullSnapshot = try LoomAIViewModel().buildContextSnapshot(in: modelContext)
            let contextSnapshot = compactContextEnabled ? fullSnapshot.compactedForLoomAI() : fullSnapshot
            let requestID = UUID().uuidString
            let previousSuggestions = previousSuggestionsText
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            let body: [String: Any] = [
                "currentVision": currentVision.trimmingCharacters(in: .whitespacesAndNewlines),
                "previousSuggestions": previousSuggestions,
                "mode": mode.rawValue,
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

            var request = URLRequest(url: autoWriteEndpointURL)
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

    private func sendLoomAIChatRequest() async {
        isLoading = true
        responseStatus = "Preparing request..."
        responseDurationText = "-"
        usageSummaryText = "-"
        estimatedCostText = "-"
        defer { isLoading = false }
        let startedAt = Date()

        let prompt = loomAIPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            responseStatus = "Prompt required"
            rawRequestText = "<empty prompt>"
            rawContextText = ""
            rawResponseText = "<no request sent>"
            responseDurationText = formatDuration(Date().timeIntervalSince(startedAt))
            return
        }

        do {
            let fullSnapshot = try LoomAIViewModel().buildContextSnapshot(in: modelContext)
            let contextSnapshot = compactContextEnabled ? fullSnapshot.compactedForLoomAI() : fullSnapshot
            let context = try contextSnapshot.toDictionary()
            let contextData = try JSONSerialization.data(withJSONObject: context, options: [.prettyPrinted, .sortedKeys])
            rawContextText = String(data: contextData, encoding: .utf8) ?? "<context encoding failed>"

            let body: [String: Any] = [
                "messages": [
                    [
                        "role": "user",
                        "content": prompt
                    ]
                ],
                "context": context,
                "client": [
                    "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
                    "platform": "iOS",
                    "locale": Locale.current.identifier,
                    "intent": "loomai_chat",
                    "screen": "loomai_chat_debug",
                    "userLocalDate": Self.localDayKey(),
                    "timezone": TimeZone.current.identifier
                ]
            ]

            let bodyData = try JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys])
            rawRequestText = String(data: bodyData, encoding: .utf8) ?? "<request encoding failed>"

            var request = URLRequest(url: chatEndpointURL)
            request.httpMethod = "POST"
            request.timeoutInterval = 60
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = bodyData

            responseStatus = "Sending..."
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let responseText = String(data: data, encoding: .utf8) ?? "<non-UTF8 \(data.count) bytes>"
            rawResponseText = responseText
            responseStatus = "HTTP \(status)"
            responseDurationText = formatDuration(Date().timeIntervalSince(startedAt))
            updateUsageEstimate(from: data)
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

    private func updateUsageEstimate(from data: Data) {
        guard
            let object = try? JSONSerialization.jsonObject(with: data, options: []),
            let json = object as? [String: Any]
        else {
            usageSummaryText = "-"
            estimatedCostText = "-"
            return
        }
        guard let usage = json["usage"] as? [String: Any] else {
            usageSummaryText = "n/a"
            estimatedCostText = "n/a"
            return
        }

        let model = (usage["model"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "gpt-5.2"
        let inputTokens = intValue(usage["inputTokens"])
        let cachedInputTokens = intValue(usage["cachedInputTokens"])
        let outputTokens = intValue(usage["outputTokens"])
        let totalTokens = intValue(usage["totalTokens"])

        usageSummaryText = "in \(inputTokens) (cached \(cachedInputTokens)) out \(outputTokens) total \(totalTokens)"

        let pricing = pricingForModel(model)
        let nonCachedInput = max(0, inputTokens - cachedInputTokens)
        let cost =
            (Double(nonCachedInput) / 1_000_000.0) * pricing.inputPerM +
            (Double(cachedInputTokens) / 1_000_000.0) * pricing.cachedInputPerM +
            (Double(outputTokens) / 1_000_000.0) * pricing.outputPerM
        estimatedCostText = String(format: "$%.6f", cost)
    }

    private func intValue(_ raw: Any?) -> Int {
        if let value = raw as? Int { return max(0, value) }
        if let value = raw as? NSNumber { return max(0, value.intValue) }
        if let text = raw as? String, let value = Int(text) { return max(0, value) }
        return 0
    }

    private func pricingForModel(_ model: String) -> (inputPerM: Double, cachedInputPerM: Double, outputPerM: Double) {
        switch model {
        case "gpt-5.2":
            return (0.875, 0.0875, 7.00)
        case "gpt-5.1":
            return (1.25, 0.125, 10.00)
        case "gpt-5-mini":
            return (0.25, 0.025, 2.00)
        default:
            return (0.875, 0.0875, 7.00)
        }
    }

    private static func localDayKey() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
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
