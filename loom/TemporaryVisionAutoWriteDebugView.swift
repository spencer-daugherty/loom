import SwiftUI
import SwiftData

#if canImport(UIKit)
import UIKit
#endif

/// Temporary diagnostics screen for Vision AutoWrite raw worker responses.
/// Delete this file and the `showTemporaryVisionAutoWriteDebugPage` branch in `loomApp.swift`
/// to remove it entirely.
struct TemporaryVisionAutoWriteDebugView: View {
    private static let diagnosticsFallbackMessage = "Processing error. Please try again later."

    private enum DebugMode: String, CaseIterable, Identifiable {
        case newVision
        case rewordVision
        case loomAI
        case diagnostic
        case personalities
        case autoGroup
        case resultAutoWrite
        case all

        var id: String { rawValue }

        var title: String {
            switch self {
            case .newVision:
                return "newVision"
            case .rewordVision:
                return "rewordVision"
            case .loomAI:
                return "LoomAI"
            case .diagnostic:
                return "Diagnostic"
            case .personalities:
                return "Personalities"
            case .autoGroup:
                return "AutoGroup"
            case .resultAutoWrite:
                return "Result AutoWrite"
            case .all:
                return "All"
            }
        }
    }

    let onClose: () -> Void

    init(onClose: @escaping () -> Void = {}) {
        self.onClose = onClose
    }

    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var appActivityLog = AppDebugActivityLog.shared
    @StateObject private var personalizationStore = PersonalizationStore()
    @Query(sort: \DrivingForce.updatedAt, order: .reverse) private var drivingForces: [DrivingForce]
    @Query(sort: \Passion.date, order: .forward) private var passions: [Passion]
    @Query(sort: \DiagnosticsInsightsSnapshot.generatedAt, order: .reverse) private var diagnosticsInsightsSnapshots: [DiagnosticsInsightsSnapshot]
    @Query(sort: \PurposeProfileInsightsSnapshot.generatedAt, order: .reverse) private var purposeProfileInsightsSnapshots: [PurposeProfileInsightsSnapshot]

    @State private var currentVision: String = ""
    @State private var mode: DebugMode = .loomAI
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
    @State private var loomAIDebugChips: [LoomAIPromptChip] = []
    @State private var loomAIDebugEvidence: [String] = []
    @State private var lastDiagnosticRunSnapshot: PersonalizationSnapshot?
    @State private var lastDiagnosticRunHash: String?
    @State private var lastDiagnosticRunSnapshotKey: String?
    @State private var requestCopied = false
    @State private var responseCopied = false
    @State private var contextCopied = false
    @State private var allCopied = false
    @State private var copyAllCopied = false
    @FocusState private var isInputFocused: Bool

    private let autoWriteEndpointURL = URL(string: "https://loom-ai-minimal.spence0927.workers.dev/purpose/vision/autowrite")!
    private let chatEndpointURL = URL(string: "https://loom-ai-minimal.spence0927.workers.dev/chat")!
    private let diagnosticInsightsEndpointURL = URL(string: "https://loom-ai-minimal.spence0927.workers.dev/diagnostic/insights")!
    private let purposeProfileInsightsEndpointURL = URL(string: "https://loom-ai-minimal.spence0927.workers.dev/purpose/insights/profile")!
    private let encoder = JSONEncoder()

    private static let diagnosticStressOptions: [String] = [
        "Too many priorities competing",
        "Feeling behind or disorganized",
        "Distractions are stealing my focus",
        "Work pressure",
        "Money pressure",
        "Low energy / health",
        "Relationship tension",
        "Not sure yet"
    ]

    private static let diagnosticBreakPointOptions: [String] = [
        "I don’t start",
        "I start, then lose momentum",
        "I get distracted",
        "I overthink it",
        "I don’t finish what I start",
        "I’m not sure"
    ]

    private static let diagnosticPlanningRealityOptions: [String] = [
        "React to what’s urgent",
        "Keep a simple to-do list",
        "Plan, but get off track",
        "Plan and follow through consistently",
        "It depends on the day"
    ]

    private static let diagnosticDesiredChangeOptions: [String] = [
        "I feel in control (less stress)",
        "I know what matters (clear direction)",
        "I follow through (consistency)",
        "I make faster progress on big goals",
        "I feel balanced across life"
    ]

    private static let randomVisionOptions: [String] = [
        "I build a calm, focused life where my work and health both move forward each week.",
        "I create stable routines that protect deep work, strong relationships, and clear recovery time.",
        "I grow my career and finances with steady consistency while still staying present at home.",
        "I become the kind of person who starts quickly, follows through, and keeps promises to myself.",
        "I design each week around my highest priorities so urgent noise does not run my life.",
        "I maintain high energy and simple systems that help me finish important work without burning out.",
        "I make meaningful progress on long-term goals while keeping balance across my core life areas.",
        "I operate with clear direction, strong boundaries, and daily action on what matters most."
    ]

    private static let randomPassionOptions: [String] = [
        "Fitness training",
        "Public speaking",
        "Building useful products",
        "Family time",
        "Deep learning",
        "Financial independence",
        "Writing ideas clearly",
        "Coaching others",
        "Travel and exploration",
        "Creative problem solving",
        "Leading teams",
        "Designing better systems",
        "Helping friends grow",
        "Protecting focus time",
        "Community impact",
        "Learning new skills"
    ]

    private static let randomRootCauseOptions: [String] = [
        "You set plans but urgent tasks keep stealing attention before real progress starts.",
        "Important work is clear, but starting friction and distractions break momentum early.",
        "Too many priorities compete at once, so your day gets split before one thing is completed.",
        "Energy drops and decision fatigue push your schedule toward quick wins instead of key priorities.",
        "Plans exist, but unprotected focus blocks make it easy for reactive work to take over."
    ]

    private static let randomNextDirectionOptions: [String] = [
        "Loom will place one clear priority first and route other tasks behind it.",
        "Loom will lock a short start block daily so activation happens before distractions.",
        "Loom will separate urgent items from meaningful items so your week stays directional.",
        "Loom will add structured checkpoints to keep momentum after you begin.",
        "Loom will turn your priorities into a simple sequence with fewer switching costs."
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Vision AutoWrite Debug")
                            .font(.title2.weight(.bold))
                        Spacer(minLength: 0)
                        Button(copyAllCopied ? "Copied" : "Copy All") {
                            markCopied($copyAllCopied, value: comprehensiveDebugExportText())
                        }
                        .buttonStyle(.bordered)
                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.primary)
                                .frame(width: 30, height: 30)
                                .background(
                                    Circle()
                                        .fill(Color(.secondarySystemBackground))
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close Debug")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Mode")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Picker("Mode", selection: $mode) {
                            ForEach(DebugMode.allCases) { item in
                                Text(item.title).tag(item)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    NavigationLink("Compact") {
                        CompactContextDebugView()
                    }
                    .font(.subheadline.weight(.semibold))

                    if mode == .loomAI {
                        TextField("Prompt", text: $loomAIPrompt, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .focused($isInputFocused)

                        if !loomAIDebugChips.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Debug Chips")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(loomAIDebugChips) { chip in
                                            Button {
                                                guard !isLoading else { return }
                                                loomAIPrompt = chip.prompt
                                                Task { await sendLoomAIChatRequest() }
                                            } label: {
                                                Text(chip.title)
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundStyle(.primary)
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 7)
                                                    .background(
                                                        Capsule(style: .continuous)
                                                            .fill(Color(.secondarySystemBackground))
                                                    )
                                                    .overlay(
                                                        Capsule(style: .continuous)
                                                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                                                    )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }

                        if !loomAIDebugEvidence.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Worker Debug Evidence")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                ForEach(Array(loomAIDebugEvidence.enumerated()), id: \.offset) { _, item in
                                    Text("• \(item)")
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } else if mode == .diagnostic {
                        Text("Runs the same save-and-refresh path as Edit diagnostic answers in Personalization, using randomized diagnostic answers.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else if mode == .personalities {
                        Text("Sends randomized diagnostic inputs plus root cause, next direction, vision, and passions to the Purpose Personality endpoint. Tap Send Random to inspect full JSON below.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else if mode == .autoGroup {
                        Text("Sends your existing Capture list (latest up to 25) to AutoGroup using intent autogroup_plan.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else if mode == .resultAutoWrite {
                        Text("Sends Plan Result AutoWrite payload JSON (area + actions) as a user message with intent plan_result_autowrite.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else if mode == .all {
                        Text("Live app activity log. Includes networking and refresh paths (for example Personalization insights).")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        TextField("Current vision (optional)", text: $currentVision, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .focused($isInputFocused)

                        TextField("Previous suggestions (one per line)", text: $previousSuggestionsText, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .focused($isInputFocused)
                    }

                    if mode == .all {
                        HStack(spacing: 10) {
                            Button("Clear Log") {
                                appActivityLog.clear()
                            }
                            .buttonStyle(.bordered)
                            Button(allCopied ? "Copied" : "Copy Log") {
                                markCopied($allCopied, value: appActivityLog.exportText())
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity)
                        Group {
                            Text("All Activity")
                                .font(.caption.weight(.semibold))
                            copyableCodeBlock(appActivityLog.exportText(), copied: $allCopied)
                        }
                    } else {
                        Button {
                            Task { await sendRequest() }
                        } label: {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                }
                                Text(isLoading ? "Loading..." : buttonTitle)
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
                        Text("Usage: \(usageSummaryText)")
                            .font(.footnote.monospaced())
                            .foregroundStyle(.secondary)
                        Text("Cost: \(estimatedCostText)")
                            .font(.footnote.monospaced())
                            .foregroundStyle(.secondary)

                        Group {
                            Text("Raw Request JSON")
                                .font(.caption.weight(.semibold))
                            copyableCodeBlock(rawRequestText, copied: $requestCopied)
                        }

                        if mode == .loomAI || mode == .autoGroup || mode == .resultAutoWrite {
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
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .task(id: mode) {
                if mode == .loomAI {
                    await refreshLoomAIDebugChips()
                } else {
                    loomAIDebugEvidence = []
                }
            }
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
                .padding(.top, 44)
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
                HStack(spacing: 6) {
                    Image(systemName: copied.wrappedValue ? "checkmark.circle.fill" : "doc.on.doc")
                    Text(copied.wrappedValue ? "Copied" : "Copy")
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(copied.wrappedValue ? .green : .primary)
                .padding(.horizontal, 12)
                .frame(minHeight: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(.systemBackground).opacity(0.92))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.black.opacity(0.12), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            .padding(.trailing, 4)
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
        } else if mode == .diagnostic {
            await sendDiagnosticInsightsRequest()
        } else if mode == .personalities {
            await sendPurposeProfileInsightsRequest()
        } else if mode == .autoGroup {
            await sendAutoGroupRequest()
        } else if mode == .resultAutoWrite {
            await sendResultAutoWriteRequest()
        } else if mode == .all {
            return
        } else {
            await sendAutoWriteRequest()
        }
    }

    private var buttonTitle: String {
        switch mode {
        case .loomAI:
            return "Send"
        case .diagnostic:
            return "Send Random"
        case .personalities:
            return "Send Random"
        case .autoGroup:
            return "AutoGroup"
        case .resultAutoWrite:
            return "Send"
        case .all:
            return "Refresh"
        case .newVision, .rewordVision:
            return "AutoWrite"
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
            let contextSnapshot = fullSnapshot.compactedForLoomAI()
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
            let (firstData, firstResponse) = try await URLSession.shared.data(for: request)
            let firstStatus = (firstResponse as? HTTPURLResponse)?.statusCode ?? -1

            var finalData = firstData
            var finalStatus = firstStatus

            if shouldRetryDiagnosticInsightsDebugResponse(statusCode: firstStatus, data: firstData) {
                responseStatus = "Retrying..."
                let (retryData, retryResponse) = try await URLSession.shared.data(for: request)
                finalData = retryData
                finalStatus = (retryResponse as? HTTPURLResponse)?.statusCode ?? -1
            }

            let responseText = String(data: finalData, encoding: .utf8) ?? "<non-UTF8 \(finalData.count) bytes>"
            rawResponseText = responseText
            responseStatus = "HTTP \(finalStatus)"
            responseDurationText = formatDuration(Date().timeIntervalSince(startedAt))
            updateUsageEstimate(from: finalData, requestData: bodyData, fallbackModel: "gpt-5.1")
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
        loomAIDebugEvidence = []
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
            let contextSnapshot = fullSnapshot.compactedForLoomAI()
            loomAIDebugChips = buildAllLoomAIDebugChips(from: contextSnapshot)
            let messages = [LoomAIService.TransportMessage(role: "user", content: prompt)]
            let userLocalDate = Self.localDayKey()
            let timezone = TimeZone.current.identifier
            let service = LoomAIService()

            let preview = try service.buildChatRequestPreview(
                messages: messages,
                context: contextSnapshot,
                intent: "loomai_chat",
                screen: "loomai_chat_debug",
                userLocalDate: userLocalDate,
                timezone: timezone
            )

            rawRequestText = try prettyJSONText(from: preview.bodyData)
            rawContextText = try encodePrettyJSONText(preview.request.context)

            responseStatus = "Sending..."
            let response = try await service.sendChat(
                messages: messages,
                context: contextSnapshot,
                intent: "loomai_chat",
                screen: "loomai_chat_debug",
                userLocalDate: userLocalDate,
                timezone: timezone
            )
            let responseEnvelope = DebugLoomAIResponseEnvelope(
                message: response.message,
                grounding: response.grounding,
                suggestionCards: response.suggestionCards,
                nextAction: response.nextAction,
                chips: response.chips,
                actions: response.actions,
                debug: response.debug,
                usage: response.usage
            )
            loomAIDebugEvidence = response.debug?.evidence ?? []
            loomAIDebugChips = mergedDebugChips(
                preferred: buildAllLoomAIDebugChips(from: contextSnapshot),
                server: response.chips
            )
            let responseData = try encodePrettyJSONData(responseEnvelope)
            rawResponseText = String(data: responseData, encoding: .utf8) ?? "<response encoding failed>"
            responseStatus = "HTTP 200"
            responseDurationText = formatDuration(Date().timeIntervalSince(startedAt))
            updateUsageEstimate(
                from: responseData,
                requestData: preview.bodyData,
                fallbackModel: response.usage?.model ?? "gpt-5.2"
            )
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorTimedOut {
                responseStatus = "Request timed out"
            } else {
                responseStatus = "Request failed"
            }
            loomAIDebugEvidence = []
            rawResponseText = String(describing: error)
            responseDurationText = formatDuration(Date().timeIntervalSince(startedAt))
        }
    }

    @MainActor
    private func refreshLoomAIDebugChips() async {
        do {
            let snapshot = try LoomAIViewModel().buildContextSnapshot(in: modelContext).compactedForLoomAI()
            loomAIDebugChips = buildAllLoomAIDebugChips(from: snapshot)
        } catch {
            loomAIDebugChips = []
        }
    }

    private func sendDiagnosticInsightsRequest() async {
        isLoading = true
        responseStatus = "Preparing request..."
        responseDurationText = "-"
        usageSummaryText = "-"
        estimatedCostText = "-"
        rawContextText = ""
        loomAIDebugEvidence = []
        defer { isLoading = false }
        let startedAt = Date()

        do {
            let draft = makeRandomDiagnosticDraft()
            let requestPreview = makeDiagnosticRequestBody(from: draft)
            let bodyData = try JSONSerialization.data(withJSONObject: requestPreview, options: [.prettyPrinted, .sortedKeys])
            rawRequestText = String(data: bodyData, encoding: .utf8) ?? "<request encoding failed>"
            responseStatus = "Saving snapshot..."
            let savedSnapshot = try await personalizationStore.saveSnapshot(from: draft, source: .accountEdit)
            let savedDiagnosticsHash = DiagnosticsInsightsHasher.hash(for: savedSnapshot)
            let savedSnapshotKey = DiagnosticsInsightsHasher.snapshotKey(
                userKey: personalizationStore.userKey,
                diagnosticsHash: savedDiagnosticsHash
            )
            lastDiagnosticRunSnapshot = savedSnapshot
            lastDiagnosticRunHash = savedDiagnosticsHash
            lastDiagnosticRunSnapshotKey = savedSnapshotKey
            AppDebugActivityLog.log(
                "Personalization",
                "Debug Diagnostic saved. mode=debug snapshot=\(savedSnapshot.id.uuidString)"
            )

            responseStatus = "Refreshing insights..."
            let envelope = await runDiagnosticAccountRefresh(snapshot: savedSnapshot)
            let responseData = try encodePrettyJSONData(envelope)
            rawResponseText = String(data: responseData, encoding: .utf8) ?? "<response encoding failed>"
            responseStatus = "HTTP 200"
            responseDurationText = formatDuration(Date().timeIntervalSince(startedAt))
            loomAIDebugEvidence = diagnosticDebugEvidence(from: envelope.debug)
            updateUsageEstimate(from: responseData, requestData: bodyData, fallbackModel: envelope.usage?.model ?? "gpt-5.1")
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorTimedOut {
                responseStatus = "Request timed out"
            } else {
                responseStatus = "Request failed"
            }
            loomAIDebugEvidence = []
            rawResponseText = String(describing: error)
            responseDurationText = formatDuration(Date().timeIntervalSince(startedAt))
        }
    }

    private func sendPurposeProfileInsightsRequest() async {
        isLoading = true
        responseStatus = "Preparing request..."
        responseDurationText = "-"
        usageSummaryText = "-"
        estimatedCostText = "-"
        rawContextText = ""
        defer { isLoading = false }
        let startedAt = Date()

        do {
            let body = makeRandomPurposeProfileRequestBody()
            let bodyData = try JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys])
            rawRequestText = String(data: bodyData, encoding: .utf8) ?? "<request encoding failed>"

            var request = URLRequest(url: purposeProfileInsightsEndpointURL)
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
            updateUsageEstimate(from: data, requestData: bodyData, fallbackModel: "gpt-5-mini")
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

    private func sendAutoGroupRequest() async {
        isLoading = true
        responseStatus = "Preparing request..."
        responseDurationText = "-"
        usageSummaryText = "-"
        estimatedCostText = "-"
        defer { isLoading = false }
        let startedAt = Date()

        let candidates = loadAutoGroupCandidates()
        guard candidates.count >= 6 else {
            responseStatus = "Need at least 6 capture items"
            rawRequestText = "<no request sent>"
            rawContextText = ""
            rawResponseText = "AutoGroup debug requires at least 6 non-empty, non-ghost Capture items."
            responseDurationText = formatDuration(Date().timeIntervalSince(startedAt))
            return
        }

        do {
            let normalizedItems: [(id: String, text: String)] = candidates.map { item in
                let cleanText = item.text
                    .replacingOccurrences(of: "\n", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return (item.id.uuidString, cleanText)
            }
            let actionLines = normalizedItems.enumerated().map { index, item in
                "\(index + 1). id=\(item.id) | text=\(item.text)"
            }

            let instruction = """
            You are helping with Loom Plan Step 3 (Group).
            Group the provided Capture actions into meaningful topical groups.

            Hard rules:
            - Return ONLY JSON
            - High-confidence only. If confidence is not high, return confidence="low" and groups=[]
            - Minimum 2 groups
            - Each group must have at least 3 actions
            - Maximum 8 groups
            - Use only the provided actionIDs
            - Do not duplicate an actionID across groups
            - Prefer grouping by what the actions are related to (topic/domain), not by effort level or urgency
            - Set fulfillmentArea to an empty string unless an action explicitly names one
            - It is OK to leave low-confidence/ambiguous actions ungrouped if needed
            - If leaving actions ungrouped, still satisfy the minimum grouping rules with the grouped subset

            Return JSON exactly:
            {"confidence":"high","reason":"short string","groups":[{"name":"string","fulfillmentArea":"string","actionIDs":["uuid"]}]}

            Capture actions to group (latest up to 25):
            \(actionLines.joined(separator: "\n"))
            """

            let context: [String: Any] = [
                "capture": [
                    "totalCount": normalizedItems.count,
                    "topItems": Array(normalizedItems.prefix(8).map { $0.text })
                ],
                "captureItems": normalizedItems.map { item in
                    [
                        "id": item.id,
                        "text": item.text
                    ]
                }
            ]
            let contextData = try JSONSerialization.data(withJSONObject: context, options: [.prettyPrinted, .sortedKeys])
            rawContextText = String(data: contextData, encoding: .utf8) ?? "<context encoding failed>"

            let body: [String: Any] = [
                "messages": [
                    [
                        "role": "user",
                        "content": instruction
                    ]
                ],
                "context": context,
                "client": [
                    "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
                    "platform": "iOS",
                    "locale": Locale.current.identifier,
                    "intent": "autogroup_plan",
                    "screen": "plan_group_debug",
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
            updateUsageEstimate(from: data, requestData: bodyData, fallbackModel: "gpt-5-mini")
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

    private func loadAutoGroupCandidates() -> [RollingCaptureItem] {
        do {
            var descriptor = FetchDescriptor<RollingCaptureItem>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            descriptor.fetchLimit = 120
            let fetched = try modelContext.fetch(descriptor)
            return Array(
                fetched
                    .filter { !$0.isGhost && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    .prefix(25)
            )
        } catch {
            AppDebugActivityLog.log("Debug", "AutoGroup candidate fetch failed: \(error.localizedDescription)")
            return []
        }
    }

    private struct PlanResultAutoWriteRequestPayload: Encodable {
        let areaName: String
        let actions: [String]
    }

    private func sendResultAutoWriteRequest() async {
        isLoading = true
        responseStatus = "Preparing request..."
        responseDurationText = "-"
        usageSummaryText = "-"
        estimatedCostText = "-"
        defer { isLoading = false }
        let startedAt = Date()

        guard let target = loadResultAutoWriteTarget() else {
            responseStatus = "No Result data"
            rawRequestText = "<no request sent>"
            rawContextText = ""
            rawResponseText = "Result AutoWrite debug needs at least one Result block with actions in the current plan week."
            responseDurationText = formatDuration(Date().timeIntervalSince(startedAt))
            return
        }

        do {
            let payload = PlanResultAutoWriteRequestPayload(areaName: target.areaName, actions: target.actions)
            let payloadData = try encoder.encode(payload)
            let payloadJSON = String(data: payloadData, encoding: .utf8) ?? "{}"

            let contextSnapshot = minimalPlanResultContextSnapshot()
            let context = try contextSnapshot.toDictionary()
            let contextData = try JSONSerialization.data(withJSONObject: context, options: [.prettyPrinted, .sortedKeys])
            rawContextText = String(data: contextData, encoding: .utf8) ?? "<context encoding failed>"

            let body: [String: Any] = [
                "messages": [
                    [
                        "role": "user",
                        "content": payloadJSON
                    ]
                ],
                "context": context,
                "client": [
                    "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
                    "platform": "iOS",
                    "locale": Locale.current.identifier,
                    "intent": "plan_result_autowrite",
                    "screen": "plan_result",
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
            updateUsageEstimate(from: data, requestData: bodyData, fallbackModel: "gpt-5-mini")
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

    private func loadResultAutoWriteTarget() -> (areaName: String, actions: [String])? {
        do {
            let weekStart = WeeklyMindsetEntry.weekStart(for: Date())
            let chunks = try modelContext.fetch(
                FetchDescriptor<PlannedChunk>(sortBy: [SortDescriptor(\.chunkIndex, order: .forward)])
            )
            .filter { Calendar.current.isDate($0.weekStart, inSameDayAs: weekStart) }

            guard !chunks.isEmpty else { return nil }

            let actions = try modelContext.fetch(
                FetchDescriptor<PlannedChunkAction>(sortBy: [SortDescriptor(\.sortOrder, order: .forward)])
            )
            .filter { Calendar.current.isDate($0.weekStart, inSameDayAs: weekStart) }

            let actionsByChunk = Dictionary(grouping: actions, by: \.plannedChunkId)
            var grouped: [(areaName: String, actions: [String])] = []
            var seenAreaKeys: Set<String> = []

            for chunk in chunks {
                let areaName = chunk.label.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !areaName.isEmpty else { continue }
                let areaKey = areaName.lowercased()
                guard seenAreaKeys.insert(areaKey).inserted else { continue }

                let chunkActions = chunks
                    .filter { $0.label.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(areaName) == .orderedSame }
                    .flatMap { groupedChunk -> [PlannedChunkAction] in
                        actionsByChunk[groupedChunk.id] ?? []
                    }
                    .map {
                        $0.text
                            .replacingOccurrences(of: "\n", with: " ")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    .filter { !$0.isEmpty }

                let uniqueActions = uniqueOrdered(chunkActions)
                if !uniqueActions.isEmpty {
                    grouped.append((areaName: areaName, actions: uniqueActions))
                }
            }

            if let preferred = grouped.first(where: { $0.actions.count >= 2 }) {
                return preferred
            }
            return grouped.first
        } catch {
            AppDebugActivityLog.log("Debug", "Result AutoWrite target fetch failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func uniqueOrdered(_ items: [String]) -> [String] {
        var seen = Set<String>()
        var output: [String] = []
        for item in items {
            let normalized = item.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else { continue }
            let key = normalized.lowercased()
            guard seen.insert(key).inserted else { continue }
            output.append(normalized)
        }
        return output
    }

    private func minimalPlanResultContextSnapshot() -> LoomAIContextSnapshot {
        LoomAIContextSnapshot(
            generatedAt: .now,
            personalizationHash: "",
            diagnostic: nil,
            drivingForce: nil,
            fulfillmentCategories: [],
            activeOutcomes: [],
            currentWeekActionBlocks: [],
            recentActivity: .init(
                quickCompletesLast7Days: 0,
                littleWinsCompletionsLast7Days: 0,
                carryoversLast7Days: 0
            ),
            capture: nil,
            recentlyDeleted: nil,
            sectionTimestamps: nil,
            dataInventory: [],
            appGuide: [],
            notes: [],
            purposeDraft: nil,
            fulfillmentSetup: nil,
            personalization: nil,
            reflectionJournal: nil,
            shareAttachmentPreview: nil
        )
    }

    private func makeDiagnosticRequestBody(from draft: PersonalizationDraft) -> [String: Any] {
        let snapshot = draft.snapshotValue()!
        let diagnostic = DiagnosticAnswers(snapshot: snapshot)

        return [
            "diagnostic": [
                "stress": diagnostic.stress,
                "breaksFirst": diagnostic.breaksFirst,
                "areas": diagnostic.areas,
                "planningStyle": diagnostic.planningStyle,
                "firstChange": diagnostic.firstChange
            ],
            "client": [
                "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
                "platform": "ios",
                "screen": "account_personalization_debug"
            ]
        ]
    }

    private func makeRandomPurposeProfileRequestBody() -> [String: Any] {
        let diagnostic = makeRandomDiagnosticAnswers()
        let vision = Self.randomVisionOptions.randomElement() ?? "I build a focused life with steady progress."
        let passions = randomPassions()

        return [
            "diagnostic": diagnostic,
            "vision": vision,
            "passions": passions,
            "client": [
                "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
                "platform": "iOS",
                "locale": Locale.current.identifier,
                "intent": "purpose_profile_insights",
                "screen": "purpose_profile_debug"
            ]
        ]
    }

    private func makeRandomDiagnosticAnswers() -> [String: Any] {
        let stress = Self.diagnosticStressOptions.randomElement() ?? "Not sure yet"
        let breaksFirst = Self.diagnosticBreakPointOptions.randomElement() ?? "I’m not sure"
        let planningStyle = Self.diagnosticPlanningRealityOptions.randomElement() ?? "It depends on the day"
        let firstChange = Self.diagnosticDesiredChangeOptions.randomElement() ?? "I feel balanced across life"
        let areas = randomDiagnosticLifeAreas()
        return [
            "stress": stress,
            "breaksFirst": breaksFirst,
            "areas": areas,
            "planningStyle": planningStyle,
            "firstChange": firstChange
        ]
    }

    private func makeRandomDiagnosticDraft() -> PersonalizationDraft {
        let diagnostic = makeRandomDiagnosticAnswers()
        let areas = diagnostic["areas"] as? [String] ?? []
        let colorDefaults = FulfillmentCategoryTheme.defaultColorKeys()
        let colorKeys = Dictionary(uniqueKeysWithValues: areas.map { area in
            (area, colorDefaults[area] ?? FulfillmentCategoryTheme.colorKey(for: area))
        })
        return PersonalizationDraft(
            stressSource: diagnostic["stress"] as? String,
            breakPoint: diagnostic["breaksFirst"] as? String,
            lifeAreasSelected: areas,
            lifeAreaColorKeys: colorKeys,
            planningReality: diagnostic["planningStyle"] as? String,
            desiredChange: diagnostic["firstChange"] as? String
        )
    }

    private func runDiagnosticAccountRefresh(snapshot: PersonalizationSnapshot) async -> DiagnosticInsights {
        let userKey = personalizationStore.userKey
        let diagnostics = DiagnosticAnswers(snapshot: snapshot)
        let diagnosticsHash = DiagnosticsInsightsHasher.hash(for: snapshot)
        let diagnosticsSnapshotKey = DiagnosticsInsightsHasher.snapshotKey(
            userKey: userKey,
            diagnosticsHash: diagnosticsHash
        )
        AppDebugActivityLog.log(
            "Personalization",
            "refreshInsightsForUpdatedDiagnostic start user=\(userKey) diagnosticsHash=\(String(diagnosticsHash.prefix(8)))"
        )

        let fallbackDiagnosticsSnapshot = diagnosticsInsightsSnapshots.first(where: {
            $0.userKey == userKey && $0.diagnosticsHash == diagnosticsHash
        })

        var rootCause = fallbackDiagnosticsSnapshot?.rootCauseText.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var nextDirection = fallbackDiagnosticsSnapshot?.nextDirectionText.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var debug: LoomAIDebug?
        var usage: LoomAIUsage?
        var receivedFreshValidInsights = false
        let fulfillmentText = fallbackDiagnosticsSnapshot?.fulfillmentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? fallbackDiagnosticsSnapshot!.fulfillmentText
            : "Every task, goal, and little win will land in one of these areas, so your life stays organized."

        do {
            let response = try await LoomAIService().fetchDiagnosticInsights(
                diagnostic: diagnostics,
                client: DiagnosticInsightsClient(
                    appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                    platform: "ios",
                    screen: "account_personalization_debug"
                )
            )
            usage = response.usage
            debug = response.debug
            let normalizedRoot = normalizeInsightsBody(response.rootCause)
            let normalizedNext = normalizeInsightsBody(response.nextDirection)
            if isRenderableDiagnosticInsightBody(normalizedRoot),
               isRenderableDiagnosticInsightBody(normalizedNext),
               normalizedRoot != Self.diagnosticsFallbackMessage,
               normalizedNext != Self.diagnosticsFallbackMessage {
                rootCause = normalizedRoot
                nextDirection = normalizedNext
                receivedFreshValidInsights = true
                AppDebugActivityLog.log(
                    "Personalization",
                    "Diagnostic insights refreshed from API root/next chars=\(rootCause.count)/\(nextDirection.count)"
                )
                upsertDiagnosticsInsightsSnapshot(
                    snapshotKey: diagnosticsSnapshotKey,
                    userKey: userKey,
                    diagnosticsHash: diagnosticsHash,
                    rootCause: rootCause,
                    fulfillmentText: fulfillmentText,
                    nextDirection: nextDirection,
                    purposeRefreshCycleKey: fallbackDiagnosticsSnapshot?.purposeRefreshCycleKey
                )
            } else {
                AppDebugActivityLog.log(
                    "Personalization",
                    "Diagnostic insights response rejected; preserving prior root/next"
                )
            }
        } catch {
            AppDebugActivityLog.log("Personalization", "Diagnostic insights refresh failed: \(error.localizedDescription)")
        }

        let currentVision = currentVisionForProfileInsights()
        let currentPassions = currentPassionsForProfileInsights()
        let fallbackRecord = PurposeProfileMatcher.bestMatch(
            inputs: .init(
                stress: diagnostics.stress,
                breakPoint: diagnostics.breaksFirst,
                planning: diagnostics.planningStyle,
                desired: diagnostics.firstChange,
                areas: diagnostics.areas,
                vision: currentVision,
                passions: currentPassions
            )
        )

        let monthKey = PurposeProfileInsightsHasher.monthKey()
        let inputsHash = PurposeProfileInsightsHasher.hash(
            diagnostic: diagnostics,
            vision: currentVision,
            passions: currentPassions
        )
        let purposeSnapshotKey = PurposeProfileInsightsHasher.snapshotKey(
            userKey: userKey,
            monthKey: monthKey,
            inputsHash: inputsHash
        )
        AppDebugActivityLog.log(
            "Personalization",
            "Purpose profile refresh request month=\(monthKey) inputsHash=\(String(inputsHash.prefix(8)))"
        )

        let resolvedRecord: PurposeProfileRecord
        do {
            let response = try await LoomAIService().fetchPurposeProfileInsights(
                diagnostic: diagnostics,
                vision: currentVision,
                passions: currentPassions
            )
            resolvedRecord = PurposeProfilesCatalog.record(named: response.profile) ?? PurposeProfileRecord(
                profile: response.profile,
                strength: response.strength,
                weakness: response.weakness,
                stressTrigger: response.stressTrigger,
                breakingPoint: response.breakingPoint
            )
            AppDebugActivityLog.log("Personalization", "Purpose profile refreshed profile=\(resolvedRecord.profile)")
        } catch {
            resolvedRecord = fallbackRecord
            AppDebugActivityLog.log("Personalization", "Purpose profile refresh failed, using fallback profile=\(fallbackRecord.profile)")
        }

        upsertPurposeProfileSnapshot(
            snapshotKey: purposeSnapshotKey,
            userKey: userKey,
            monthKey: monthKey,
            inputsHash: inputsHash,
            record: resolvedRecord
        )

        if receivedFreshValidInsights || fallbackDiagnosticsSnapshot != nil {
            upsertDiagnosticsInsightsSnapshot(
                snapshotKey: diagnosticsSnapshotKey,
                userKey: userKey,
                diagnosticsHash: diagnosticsHash,
                rootCause: rootCause,
                fulfillmentText: fulfillmentText,
                nextDirection: nextDirection,
                purposeRefreshCycleKey: purposeSnapshotKey
            )
        }
        AppDebugActivityLog.log(
            "Personalization",
            "refreshInsightsForUpdatedDiagnostic completed profileKey=\(purposeSnapshotKey)"
        )

        return DiagnosticInsights(
            rootCause: receivedFreshValidInsights ? rootCause : Self.diagnosticsFallbackMessage,
            nextDirection: receivedFreshValidInsights ? nextDirection : Self.diagnosticsFallbackMessage,
            debug: debug,
            usage: usage
        )
    }

    private func normalizeInsightsBody(_ text: String) -> String {
        text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isRenderableDiagnosticInsightBody(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }
        let sentences = text
            .split(whereSeparator: { ".!?".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return sentences.count >= 2 && sentences.count <= 3
    }

    private func currentVisionForProfileInsights() -> String {
        (drivingForces.first?.ultimateVision ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func currentPassionsForProfileInsights() -> [String] {
        let normalized = passions
            .map(\.passion)
            .map {
                $0.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
        return Array(Set(normalized)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func upsertDiagnosticsInsightsSnapshot(
        snapshotKey: String,
        userKey: String,
        diagnosticsHash: String,
        rootCause: String,
        fulfillmentText: String,
        nextDirection: String,
        purposeRefreshCycleKey: String?
    ) {
        if let existing = diagnosticsInsightsSnapshots.first(where: { $0.snapshotKey == snapshotKey }) {
            existing.generatedAt = .now
            existing.userKey = userKey
            existing.diagnosticsHash = diagnosticsHash
            existing.rootCauseText = rootCause
            existing.fulfillmentText = fulfillmentText
            existing.nextDirectionText = nextDirection
            existing.purposeRefreshCycleKey = purposeRefreshCycleKey
            existing.version = DiagnosticsInsightsHasher.schemaVersion
        } else {
            modelContext.insert(
                DiagnosticsInsightsSnapshot(
                    snapshotKey: snapshotKey,
                    userKey: userKey,
                    diagnosticsHash: diagnosticsHash,
                    generatedAt: .now,
                    rootCauseText: rootCause,
                    fulfillmentText: fulfillmentText,
                    nextDirectionText: nextDirection,
                    purposeRefreshCycleKey: purposeRefreshCycleKey,
                    version: DiagnosticsInsightsHasher.schemaVersion
                )
            )
        }
        do {
            try modelContext.save()
            AppDebugActivityLog.log(
                "Personalization",
                "Persisted diagnostics snapshot key=\(snapshotKey) diagnosticsHash=\(String(diagnosticsHash.prefix(8)))"
            )
        } catch {
            AppDebugActivityLog.log(
                "Personalization",
                "Persist diagnostics snapshot failed key=\(snapshotKey) error=\(error.localizedDescription)"
            )
        }
    }

    private func upsertPurposeProfileSnapshot(
        snapshotKey: String,
        userKey: String,
        monthKey: String,
        inputsHash: String,
        record: PurposeProfileRecord
    ) {
        if let existing = purposeProfileInsightsSnapshots.first(where: { $0.snapshotKey == snapshotKey }) {
            existing.generatedAt = .now
            existing.userKey = userKey
            existing.monthKey = monthKey
            existing.inputsHash = inputsHash
            existing.profile = record.profile
            existing.strength = record.strength
            existing.weakness = record.weakness
            existing.stressTrigger = record.stressTrigger
            existing.breakingPoint = record.breakingPoint
        } else {
            modelContext.insert(
                PurposeProfileInsightsSnapshot(
                    snapshotKey: snapshotKey,
                    userKey: userKey,
                    monthKey: monthKey,
                    inputsHash: inputsHash,
                    generatedAt: .now,
                    profile: record.profile,
                    strength: record.strength,
                    weakness: record.weakness,
                    stressTrigger: record.stressTrigger,
                    breakingPoint: record.breakingPoint
                )
            )
        }
        try? modelContext.save()
    }

    private func randomDiagnosticLifeAreas() -> [String] {
        let options = fulfillmentStartSelectableDefaultCategories.shuffled()
        let count = Int.random(in: 3...7)
        return Array(options.prefix(min(count, options.count)))
    }

    private func randomPassions() -> [String] {
        let count = Int.random(in: 4...10)
        return Array(Self.randomPassionOptions.shuffled().prefix(min(count, Self.randomPassionOptions.count)))
    }

    private func shouldRetryDiagnosticInsightsDebugResponse(statusCode: Int, data: Data) -> Bool {
        guard !(200...299).contains(statusCode) else { return false }
        let text = String(data: data, encoding: .utf8)?.lowercased() ?? ""
        let hasMissingModelOutput = text.contains("\"error\":\"missing model output\"")
        let hasTokenCapSignal = text.contains("max_output_tokens")
            || text.contains("\"status\": \"incomplete\"")
            || text.contains("\"status\":\"incomplete\"")
        return hasMissingModelOutput && hasTokenCapSignal
    }

    private func updateUsageEstimate(from data: Data, requestData: Data? = nil, fallbackModel: String? = nil) {
        guard
            let object = try? JSONSerialization.jsonObject(with: data, options: []),
            let json = object as? [String: Any]
        else {
            applyEstimatedUsageFallback(requestData: requestData, responseData: data, fallbackModel: fallbackModel)
            return
        }
        guard let usage = json["usage"] as? [String: Any] else {
            applyEstimatedUsageFallback(requestData: requestData, responseData: data, fallbackModel: fallbackModel)
            return
        }

        let model = (usage["model"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let inputTokens = intValue(usage["inputTokens"])
        let cachedInputTokens = intValue(usage["cachedInputTokens"])
        let outputTokens = intValue(usage["outputTokens"])
        let totalTokens = intValue(usage["totalTokens"])

        usageSummaryText = "in \(inputTokens) (cached \(cachedInputTokens)) out \(outputTokens) total \(totalTokens)"

        guard let cost = LoomAIUsageCostCalculator.exactCostUSD(
            model: model,
            inputTokens: inputTokens,
            cachedInputTokens: cachedInputTokens,
            outputTokens: outputTokens
        ) else {
            usageSummaryText = "in \(inputTokens) (cached \(cachedInputTokens)) out \(outputTokens) total \(totalTokens)"
            estimatedCostText = "unavailable"
            return
        }
        estimatedCostText = String(format: "$%.6f", cost)
    }

    private func applyEstimatedUsageFallback(requestData: Data?, responseData: Data, fallbackModel: String?) {
        _ = requestData
        _ = responseData
        _ = fallbackModel
        usageSummaryText = "n/a"
        estimatedCostText = "unavailable"
    }

    private func estimatedTokenCount(for data: Data) -> Int {
        // Fast approximation for debug display when upstream usage is unavailable.
        max(1, Int(ceil(Double(data.count) / 4.0)))
    }

    private func intValue(_ raw: Any?) -> Int {
        if let value = raw as? Int { return max(0, value) }
        if let value = raw as? NSNumber { return max(0, value.intValue) }
        if let text = raw as? String, let value = Int(text) { return max(0, value) }
        return 0
    }

    private func prettyJSONText(from data: Data) throws -> String {
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        let prettyData = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        return String(data: prettyData, encoding: .utf8) ?? "<json encoding failed>"
    }

    private func encodePrettyJSONData<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(value)
    }

    private func encodePrettyJSONText<T: Encodable>(_ value: T) throws -> String {
        let data = try encodePrettyJSONData(value)
        return String(data: data, encoding: .utf8) ?? "<json encoding failed>"
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

    private func comprehensiveDebugExportText() -> String {
        let sectionDivider = "\n\n------------------------------\n\n"
        let modeDescription = mode.title
        let prompt = loomAIPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let previousSuggestions = previousSuggestionsText.trimmingCharacters(in: .whitespacesAndNewlines)
        let chipsText: String = {
            guard !loomAIDebugChips.isEmpty else { return "<none>" }
            return loomAIDebugChips.map { "• \($0.title) => \($0.prompt)" }.joined(separator: "\n")
        }()
        let evidenceText: String = {
            guard !loomAIDebugEvidence.isEmpty else { return "<none>" }
            return loomAIDebugEvidence.map { "• \($0)" }.joined(separator: "\n")
        }()

        let header = """
        Loom Debug Export
        timestamp: \(ISO8601DateFormatter().string(from: Date()))
        mode: \(modeDescription)
        status: \(responseStatus)
        duration: \(responseDurationText)
        usage: \(usageSummaryText)
        estimatedCost: \(estimatedCostText)
        """

        let inputs = """
        Inputs
        prompt: \(prompt.isEmpty ? "<empty>" : prompt)
        currentVision: \(currentVision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "<empty>" : currentVision.trimmingCharacters(in: .whitespacesAndNewlines))
        previousSuggestions:
        \(previousSuggestions.isEmpty ? "<empty>" : previousSuggestions)
        """

        let chips = """
        Debug Chips
        \(chipsText)
        """

        let evidence = """
        Worker Debug Evidence
        \(evidenceText)
        """

        let request = """
        Raw Request JSON
        \(rawRequestText.isEmpty ? "<empty>" : rawRequestText)
        """

        let context = """
        Raw Context JSON
        \(rawContextText.isEmpty ? "<empty>" : rawContextText)
        """

        let response = """
        Raw Response JSON
        \(rawResponseText.isEmpty ? "<empty>" : rawResponseText)
        """

        let personalizationState = """
        Personalization Diagnostic State
        \(personalizationDiagnosticStateExportText())
        """

        let appLog = """
        App Activity Log
        \(appActivityLog.exportText().isEmpty ? "<empty>" : appActivityLog.exportText())
        """

        return [
            header,
            inputs,
            chips,
            evidence,
            request,
            context,
            response,
            personalizationState,
            appLog
        ].joined(separator: sectionDivider)
    }

    private func personalizationDiagnosticStateExportText() -> String {
        guard mode == .diagnostic else { return "<not captured for this mode>" }
        let userKey = PersonalizationUserIdentity.currentUserKey()
        let personalizationState = PersonalizationStore.cachedStateForCurrentUser()
        let current = lastDiagnosticRunSnapshot ?? personalizationState.current
        guard let current else {
            return "currentSnapshot: <none>"
        }

        let diagnosticsHash = lastDiagnosticRunHash ?? DiagnosticsInsightsHasher.hash(for: current)
        let snapshotKey = lastDiagnosticRunSnapshotKey ?? DiagnosticsInsightsHasher.snapshotKey(
            userKey: userKey,
            diagnosticsHash: diagnosticsHash
        )
        let matchingDiagnosticsSnapshot = diagnosticsInsightsSnapshots.first(where: {
            $0.userKey == userKey && $0.diagnosticsHash == diagnosticsHash
        })

        let currentSnapshotJSON = (try? encodePrettyJSONText(current)) ?? "<json encoding failed>"
        let diagnosticsSnapshotJSON: String = {
            guard let matchingDiagnosticsSnapshot else { return "<none>" }
            return (try? encodePrettyJSONText(
                DiagnosticsSnapshotExport(
                    snapshotKey: matchingDiagnosticsSnapshot.snapshotKey,
                    userKey: matchingDiagnosticsSnapshot.userKey,
                    diagnosticsHash: matchingDiagnosticsSnapshot.diagnosticsHash,
                    generatedAt: matchingDiagnosticsSnapshot.generatedAt,
                    rootCauseText: matchingDiagnosticsSnapshot.rootCauseText,
                    fulfillmentText: matchingDiagnosticsSnapshot.fulfillmentText,
                    nextDirectionText: matchingDiagnosticsSnapshot.nextDirectionText,
                    purposeRefreshCycleKey: matchingDiagnosticsSnapshot.purposeRefreshCycleKey,
                    version: matchingDiagnosticsSnapshot.version
                )
            )) ?? "<json encoding failed>"
        }()

        let filteredLog = filteredDiagnosticActivityLogText()

        return """
        userKey: \(userKey)
        lastRunDiagnosticsHash: \(lastDiagnosticRunHash ?? "<none>")
        lastRunDiagnosticsSnapshotKey: \(lastDiagnosticRunSnapshotKey ?? "<none>")
        currentDiagnosticsHash: \(diagnosticsHash)
        currentDiagnosticsSnapshotKey: \(snapshotKey)

        Current Personalization Snapshot
        \(currentSnapshotJSON)

        Latest Persisted DiagnosticsInsightsSnapshot For Current Hash
        \(diagnosticsSnapshotJSON)

        Filtered Personalization Activity
        \(filteredLog)
        """
    }

    private func filteredDiagnosticActivityLogText(limit: Int = 220) -> String {
        let allowedSubsystems: Set<String> = [
            "Personalization",
            "PersonalizationStore",
            "DiagnosticsInsights",
            "DiagnosticsInsightsAccount"
        ]
        let lines = appActivityLog.entries
            .filter { allowedSubsystems.contains($0.subsystem) }
            .suffix(max(1, limit))
            .map { entry in
                let time = ISO8601DateFormatter().string(from: entry.timestamp)
                return "[\(time)] [\(entry.subsystem)] \(entry.message)"
            }
        return lines.isEmpty ? "<none>" : lines.joined(separator: "\n")
    }

    private func buildAllLoomAIDebugChips(from snapshot: LoomAIContextSnapshot) -> [LoomAIPromptChip] {
        var chips: [LoomAIPromptChip] = []
        var seen = Set<String>()
        func add(_ title: String, _ prompt: String) {
            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedTitle.isEmpty, !trimmedPrompt.isEmpty else { return }
            let key = "\(trimmedTitle.lowercased())|\(trimmedPrompt.lowercased())"
            guard seen.insert(key).inserted else { return }
            chips.append(.init(id: "debug-chip-\(seen.count)", title: trimmedTitle, prompt: trimmedPrompt))
        }

        add("How can I best use Loom?", "How can I best use Loom?")
        add("What is Loom?", "What is Loom?")
        add("Improve my Purpose Vision", "Improve my Purpose Vision")

        let categories = snapshot.fulfillmentCategories
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        for category in categories {
            add("Daily Little Wins for \(category)", "Daily Little Wins for \(category)")
            add("New Mission for \(category)", "New Mission for \(category)")
            add("New Identity for \(category)", "New Identity for \(category)")
        }

        let goals = snapshot.activeOutcomes
            .map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 5 }
        for goal in goals {
            add("Next step for \(goal)", "Next step for \(goal)")
            add("Plan for \(goal)", "Plan for \(goal)")
        }

        for passion in ["Love", "Vows", "Thrill", "Hate"] {
            add("New passions for \(passion)", "New passions for \(passion)")
        }

        return chips
    }

    private func mergedDebugChips(
        preferred: [LoomAIPromptChip],
        server: [LoomAIPromptChip]
    ) -> [LoomAIPromptChip] {
        var merged: [LoomAIPromptChip] = []
        var seen = Set<String>()
        let source = preferred + server
        for chip in source {
            let title = chip.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let prompt = chip.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty, !prompt.isEmpty else { continue }
            let key = "\(title.lowercased())|\(prompt.lowercased())"
            guard seen.insert(key).inserted else { continue }
            merged.append(.init(id: chip.id, title: title, prompt: prompt))
        }
        return merged
    }

    private func diagnosticDebugEvidence(from debug: LoomAIDebug?) -> [String] {
        guard let debug else { return [] }
        if let evidence = debug.evidence, !evidence.isEmpty {
            return evidence
        }
        return []
    }
}

private struct DebugLoomAIResponseEnvelope: Encodable {
    var message: String
    var grounding: [LoomAIGroundingItem]
    var suggestionCards: [LoomAISuggestionCard]
    var nextAction: LoomAISuggestedAction?
    var chips: [LoomAIPromptChip]
    var actions: [LoomAIAction]
    var debug: LoomAIDebug?
    var usage: LoomAIUsage?
}

private struct DiagnosticsSnapshotExport: Encodable {
    var snapshotKey: String
    var userKey: String
    var diagnosticsHash: String
    var generatedAt: Date
    var rootCauseText: String
    var fulfillmentText: String
    var nextDirectionText: String
    var purposeRefreshCycleKey: String?
    var version: Int
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

private struct CompactContextDebugView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var compactJSONText: String = ""
    @State private var statusText: String = "Loading..."
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status: \(statusText)")
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)

            ScrollView {
                Text(compactJSONText.isEmpty ? "<empty>" : compactJSONText)
                    .font(.caption.monospaced())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
            }
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )

            HStack(spacing: 10) {
                Button(copied ? "Copied" : "Copy") {
                    #if canImport(UIKit)
                    UIPasteboard.general.string = compactJSONText
                    #endif
                    copied = true
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(1.2))
                        copied = false
                    }
                }
                .buttonStyle(.bordered)

                Button("Refresh") {
                    Task { await loadCompactJSON() }
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .navigationTitle("Compact")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadCompactJSON()
        }
    }

    private func loadCompactJSON() async {
        statusText = "Loading..."
        do {
            let fullSnapshot = try LoomAIViewModel().buildContextSnapshot(in: modelContext)
            let compact = fullSnapshot.compactedForLoomAI()
            let dictionary = try compact.toDictionary()
            let data = try JSONSerialization.data(withJSONObject: dictionary, options: [.prettyPrinted, .sortedKeys])
            compactJSONText = String(data: data, encoding: .utf8) ?? "<encoding failed>"
            statusText = "Ready"
        } catch {
            compactJSONText = String(describing: error)
            statusText = "Failed"
        }
    }
}
