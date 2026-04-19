import SwiftUI
import SwiftData
import UIKit

struct LoomAIChatView: View {
    var isActivePage: Bool = false
    private let bottomScrollAnchorID = "loom_chat_bottom_anchor"

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(UserSessionStore.Keys.isSubscribed) private var isSubscribed = false
    @AppStorage(SubscriptionAccessGate.inactivePurchaseOverrideKey) private var inactivePurchaseOverrideEnabled = false
    @Query private var fulfillments: [Fulfillment]
    @Query(sort: \Outcomes.end, order: .forward) private var outcomes: [Outcomes]
    @Query private var fulfillmentFocusRows: [FulfillmentFocus]
    @Query private var fulfillmentRoles: [FulfillmentRoles]
    @Query private var passions: [Passion]
    @Query private var drivingForces: [DrivingForce]
    @Query private var captureItems: [RollingCaptureItem]
    @Query private var plannedChunks: [PlannedChunk]
    @Query private var plannedChunkActions: [PlannedChunkAction]
    @Query(sort: \DiagnosticsInsightsSnapshot.generatedAt, order: .reverse) private var diagnosticsSnapshots: [DiagnosticsInsightsSnapshot]

    @StateObject private var viewModel = LoomAIViewModel()
    @State private var showActionExecutionAlert = false
    @State private var actionExecutionAlertText = ""
    @State private var keyboardHeight: CGFloat = 0
    @AppStorage(loomAITroubleshootingDefaultsKey) private var loomAITroubleshootingEnabled = true
    @State private var activeThreadKey = LoomAIChatThreadSelectionStore.currentThreadKey()
    @State private var threadMessages: [LoomAIChatMessage] = []
    @State private var latestAssistantMessageIDCache: UUID?
    @State private var appliedSuggestedActionSnapshots: [String: LoomAISuggestedAction] = [:]
    @State private var inFlightSuggestedActionSnapshots: [String: LoomAISuggestedAction] = [:]
    @State private var chipCategoryOverrides: [String: String] = [:]
    @State private var hasEnsuredThread = false
    @State private var needsRefreshWhenActive = true
    @State private var inputAutoFocusTask: Task<Void, Never>? = nil
    @State private var sendCurrentMessageTask: Task<Void, Never>? = nil
    @State private var showCancelledNotice = false
    @State private var cancelledNoticeOpacity: Double = 1
    @State private var cancelledNoticeWorkItem: DispatchWorkItem? = nil
    @State private var cancelledNoticeToken = UUID()
    @State private var displayedErrorMessage: String? = nil
    @State private var transientErrorOpacity: Double = 1
    @State private var transientErrorWorkItem: DispatchWorkItem? = nil
    @State private var transientErrorToken = UUID()
    @State private var deepThinkingDelayTask: Task<Void, Never>? = nil
    @State private var promptChipRefreshTask: Task<Void, Never>? = nil
    @State private var showDeepThinkingOverlay = false
    @State private var deepThinkingTrace: [LoomAIDeepSearchTraceStep] = []
    @State private var suppressPendingLoadingUI = false
    @FocusState private var isInputFocused: Bool
    @AppStorage(loomAICustomChatDefaultsKey) private var enableLoomAICustomChat = false
    private let keyboardTopGap: CGFloat = 12
    private let bestUseLoomChipTitle = "How can I best use Loom?"
    private let requestTimedOutMessage = "The request timed out."
    private let compatibilityNoteText = "Use a device compatible with Apple Intelligence for better personalization"
    private let appleModelStatusText = "Running LoomAI Mark I model on Apple Intelligence"

    private var messages: [LoomAIChatMessage] { threadMessages }
    private var assistantBubbleWidth: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        return min(screenWidth * 0.74, screenWidth - 52)
    }
    private var userBubbleMaxWidth: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        return min(screenWidth * 0.74, screenWidth - 52)
    }

    private var latestAssistantMessageID: UUID? { latestAssistantMessageIDCache }

    private var visiblePromptChips: [String] {
        messages.isEmpty ? viewModel.suggestedPromptChips : viewModel.followUpPromptChips
    }

    private var supportsCustomChat: Bool {
        viewModel.activeChatProviderKind == .appleIntelligence && LoomDeveloperBuild.enabled(enableLoomAICustomChat)
    }

    private var shouldShowCompatibilityNote: Bool {
        viewModel.activeChatProviderKind != .appleIntelligence
    }

    private var shouldShowAppleModelStatus: Bool {
        viewModel.activeChatProviderKind == .appleIntelligence
    }

    private var promptChipVerticalPadding: CGFloat {
        16
    }

    private var promptBarTopPadding: CGFloat {
        supportsCustomChat ? 8 : 4
    }

    private var promptBarBottomPadding: CGFloat {
        supportsCustomChat ? max(8, keyboardHeight > 0 ? keyboardHeight + keyboardTopGap : 8) : 4
    }

    private var shouldShowLoadingUI: Bool {
        viewModel.isSending && !suppressPendingLoadingUI
    }

    private var shouldShowSendingControl: Bool {
        viewModel.isSending && !suppressPendingLoadingUI
    }

    private var hasActiveSubscriptionAccess: Bool {
        SubscriptionAccessGate.hasActiveSubscription(
            isSubscribed: isSubscribed,
            inactivePurchaseOverrideEnabled: inactivePurchaseOverrideEnabled
        )
    }

    private var contextSnapshotInvalidationKey: String {
        let formatter = ISO8601DateFormatter()
        func stamp(_ date: Date?) -> String {
            date.map(formatter.string(from:)) ?? "-"
        }

        let plannedChunkIDs = Set(plannedChunks.map(\.id))
        let currentThreadStamp = stamp(messages.last?.createdAt)
        return [
            "thread=\(activeThreadKey)",
            "threadStamp=\(currentThreadStamp)",
            "provider=\(viewModel.activeChatProviderKind.rawValue)",
            "purpose=\(stamp(drivingForces.map(\.updatedAt).max()))",
            "passions=\(passions.count)|\(stamp(passions.map(\.date).max()))",
            "fulfillment=\(fulfillments.count)|\(stamp(fulfillments.map(\.updatedAt).max()))",
            "outcomes=\(outcomes.count)|\(stamp(outcomes.map(\.updatedAt).max()))",
            "capture=\(captureItems.count)|\(stamp(captureItems.map(\.createdAt).max()))",
            "plan=\(plannedChunks.count)|\(plannedChunkIDs.count)|\(stamp(plannedChunkActions.filter { plannedChunkIDs.contains($0.plannedChunkId) }.map(\.createdAt).max()))",
            "diag=\(stamp(diagnosticsSnapshots.first?.generatedAt))"
        ].joined(separator: "|")
    }

    var body: some View {
        let resolvedActionMap = resolvedVisibleSuggestionActionMap()
        VStack(spacing: 10) {
            if viewModel.isDailyLimitReached {
                LoomAIInlineLimitNotice(text: "Daily LoomAI limit reached. Resets tomorrow.")
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
            } else if viewModel.shouldShowFiveLeftWarning {
                LoomAIInlineLimitNotice(text: "You're approaching your daily limit.")
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
            }
            if showCancelledNotice {
                LoomAICancelNotice(text: "Cancelled")
                    .padding(.horizontal, 12)
                    .opacity(cancelledNoticeOpacity)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if messages.isEmpty {
                            emptyState
                        }

                        ForEach(messages) { message in
                            VStack(alignment: .leading, spacing: 8) {
                                messageBubble(message)
                                if message.roleRaw == LoomAIChatRole.assistant.rawValue {
                                    unrelatedPromptLinksView(for: message)
                                    groundingSectionView(items: LoomAIChatMessageGroundingCodec.decode(message.groundingJSON))
                                    suggestionCardsSectionView(
                                        cards: LoomAIChatMessageSuggestionCardsCodec.decode(message.suggestionCardsJSON),
                                        fallbackActions: LoomAIChatMessageActionsCodec.decode(message.actionsJSON),
                                        nextAction: LoomAIChatMessageNextActionCodec.decode(message.nextActionJSON),
                                        resolvedActionMap: resolvedActionMap
                                    )
                                }
                            }
                            .id(message.id)
                        }

                        if shouldShowLoadingUI || showDeepThinkingOverlay {
                            VStack(spacing: 8) {
                                if shouldShowLoadingUI && !showDeepThinkingOverlay {
                                    HStack(spacing: 8) {
                                        LoomTypingDotsIndicator()
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                if showDeepThinkingOverlay {
                                    LoomAIDeepStateScanningCard(steps: deepThinkingTrace)
                                    .transition(.opacity)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 2)
                        }

                        Color.clear
                            .frame(height: 1)
                            .id(bottomScrollAnchorID)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                }
                .refreshable {
                    createNewChatFromPullDown()
                }
                .onChange(of: messages.last?.id) { _, newID in
                    guard newID != nil else { return }
                    appliedSuggestedActionSnapshots = [:]
                    inFlightSuggestedActionSnapshots = [:]
                    chipCategoryOverrides = [:]
                    guard isActivePage else {
                        needsRefreshWhenActive = true
                        return
                    }
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(bottomScrollAnchorID, anchor: .bottom)
                    }
                    schedulePromptChipRefresh(immediate: true)
                }
                .onChange(of: viewModel.isSending) { _, _ in
                    if !viewModel.isSending {
                        suppressPendingLoadingUI = false
                    }
                    updateDeepThinkingState()
                    guard isActivePage else { return }
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(bottomScrollAnchorID, anchor: .bottom)
                    }
                }
                .onAppear {
                    refreshThreadMessageCache()
                    viewModel.refreshRemainingDailyResponses()
                    updateDeepThinkingState()
                    if !hasEnsuredThread {
                        _ = try? viewModel.ensureThread(in: modelContext, threadKey: activeThreadKey)
                        hasEnsuredThread = true
                    }
                    guard isActivePage else {
                        needsRefreshWhenActive = true
                        return
                    }
                    schedulePromptChipRefresh(immediate: true)
                    DispatchQueue.main.async {
                        proxy.scrollTo(bottomScrollAnchorID, anchor: .bottom)
                    }
                }
                .onChange(of: isActivePage) { _, isActive in
                    guard isActive else { return }
                    viewModel.refreshRemainingDailyResponses()
                    if needsRefreshWhenActive {
                        schedulePromptChipRefresh(immediate: true)
                        needsRefreshWhenActive = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(bottomScrollAnchorID, anchor: .bottom)
                        }
                    }
                }
            }

            if let error = displayedErrorMessage, !error.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.black.opacity(0.7))
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(Color.black.opacity(0.75))
                        Spacer(minLength: 0)
                    }
                    if LoomDeveloperBuild.enabled(loomAITroubleshootingEnabled) {
                        let troubleshooting = {
                            if let detail = viewModel.debugFailureDetail {
                                return loomAITroubleshootingDetails(
                                    feature: "loom_chat",
                                    statusCode: detail.statusCode,
                                    contentType: detail.contentType,
                                    rawBody: detail.bodyPreview,
                                    reason: error
                                )
                            }
                            return loomAITroubleshootingLocalDetails(
                                feature: "loom_chat",
                                reason: error
                            )
                        }()
                        LoomAITroubleshootingSection(details: troubleshooting)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray5))
                )
                .padding(.horizontal, 12)
                .opacity(shouldAutoDismissError(error) ? transientErrorOpacity : 1)
            }

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 8) {
                if !visiblePromptChips.isEmpty {
                    suggestedPromptChipBar
                }
                if shouldShowCompatibilityNote {
                    Text(compatibilityNoteText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 2)
                }
                if shouldShowAppleModelStatus {
                    Text(appleModelStatusText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 2)
                }
                if supportsCustomChat {
                    composer
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, promptBarTopPadding)
            .padding(.bottom, promptBarBottomPadding)
        }
        .alert("Loom", isPresented: $showActionExecutionAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(actionExecutionAlertText)
        }
        .onAppear {
            guard isActivePage else { return }
            if supportsCustomChat {
                scheduleAutoFocusInput()
            } else {
                isInputFocused = false
                dismissKeyboard()
            }
        }
        .onChange(of: isActivePage) { _, isActive in
            if !isActive {
                cancelCurrentMessageRequest()
                inputAutoFocusTask?.cancel()
                inputAutoFocusTask = nil
                promptChipRefreshTask?.cancel()
                promptChipRefreshTask = nil
                deepThinkingDelayTask?.cancel()
                deepThinkingDelayTask = nil
                showDeepThinkingOverlay = false
                isInputFocused = false
                dismissKeyboard()
            } else {
                if supportsCustomChat {
                    scheduleAutoFocusInput()
                } else {
                    isInputFocused = false
                    dismissKeyboard()
                }
                updateDeepThinkingState()
            }
        }
        .onDisappear {
            cancelCurrentMessageRequest()
            inputAutoFocusTask?.cancel()
            inputAutoFocusTask = nil
            promptChipRefreshTask?.cancel()
            promptChipRefreshTask = nil
            cancelledNoticeWorkItem?.cancel()
            cancelledNoticeWorkItem = nil
            transientErrorWorkItem?.cancel()
            transientErrorWorkItem = nil
            deepThinkingDelayTask?.cancel()
            deepThinkingDelayTask = nil
            showDeepThinkingOverlay = false
            isInputFocused = false
            dismissKeyboard()
        }
        .onAppear {
            handleTransientErrorUpdate(viewModel.errorMessage)
        }
        .onChange(of: viewModel.errorMessage) { _, newValue in
            handleTransientErrorUpdate(newValue)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            guard isActivePage else { return }
            updateKeyboardHeight(note)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            guard isActivePage else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                keyboardHeight = 0
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .loomAIChatThreadSelectionDidChange)) { _ in
            let newKey = LoomAIChatThreadSelectionStore.currentThreadKey()
            guard newKey != activeThreadKey else { return }
            if sendCurrentMessageTask != nil || viewModel.isSending {
                sendCurrentMessageTask?.cancel()
                sendCurrentMessageTask = nil
                showCancelledNoticeTemporarily()
            }
            activeThreadKey = newKey
            refreshThreadMessageCache()
            if isActivePage {
                schedulePromptChipRefresh(immediate: true)
            } else {
                needsRefreshWhenActive = true
            }
            _ = try? viewModel.ensureThread(in: modelContext, threadKey: newKey)
        }
        .onReceive(NotificationCenter.default.publisher(for: .loomAIChatMessagesDidChange)) { note in
            if let changedThreadKey = note.object as? String,
               changedThreadKey != activeThreadKey {
                return
            }
            refreshThreadMessageCache()
            if isActivePage {
                schedulePromptChipRefresh(immediate: true)
            } else {
                needsRefreshWhenActive = true
            }
        }
    }

    private func refreshThreadMessageCache() {
        let filtered = fetchThreadMessages(threadKey: activeThreadKey)
        threadMessages = filtered
        latestAssistantMessageIDCache = filtered.last(where: { $0.roleRaw == LoomAIChatRole.assistant.rawValue })?.id
    }

    private func fetchThreadMessages(threadKey: String) -> [LoomAIChatMessage] {
        let descriptor = FetchDescriptor<LoomAIChatMessage>(
            predicate: #Predicate<LoomAIChatMessage> { message in
                message.threadKey == threadKey
            },
            sortBy: [SortDescriptor(\LoomAIChatMessage.createdAt, order: .forward)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func schedulePromptChipRefresh(immediate: Bool = false) {
        promptChipRefreshTask?.cancel()
        promptChipRefreshTask = Task { @MainActor in
            if !immediate {
                try? await Task.sleep(nanoseconds: 180_000_000)
            }
            guard !Task.isCancelled else { return }
            viewModel.refreshLatestActions(from: messages)
            viewModel.refreshSuggestedPromptChips(
                in: modelContext,
                threadMessages: messages,
                snapshotInvalidationKey: contextSnapshotInvalidationKey
            )
            await viewModel.refreshFollowUpPromptChipsIfNeeded(
                in: modelContext,
                threadMessages: messages,
                snapshotInvalidationKey: contextSnapshotInvalidationKey
            )
        }
    }

    private func handleTransientErrorUpdate(_ newMessage: String?) {
        transientErrorWorkItem?.cancel()
        transientErrorWorkItem = nil
        transientErrorOpacity = 1

        guard let raw = newMessage else {
            displayedErrorMessage = nil
            return
        }

        let message = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else {
            displayedErrorMessage = nil
            return
        }

        displayedErrorMessage = message
        guard shouldAutoDismissError(message) else { return }

        let token = UUID()
        transientErrorToken = token
        let hideWorkItem = DispatchWorkItem {
            guard transientErrorToken == token else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                transientErrorOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                guard transientErrorToken == token else { return }
                if displayedErrorMessage == message {
                    displayedErrorMessage = nil
                }
            }
        }
        transientErrorWorkItem = hideWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: hideWorkItem)
    }

    private func shouldAutoDismissError(_ message: String) -> Bool {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == requestTimedOutMessage { return true }
        return trimmed.hasPrefix("Couldn’t find the existing")
            || trimmed.hasPrefix("Couldn't find the existing")
    }

    private var suggestedPromptChipBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(visiblePromptChips, id: \.self) { chip in
                    suggestedPromptChip(chip)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func suggestedPromptChip(_ chip: String) -> some View {
        let resolvedChip = resolvedPromptChipText(for: chip)
        let promptToSend = resolvedPromptChipPrompt(for: chip, resolvedTitle: resolvedChip)
        let matchedCategory = fulfillmentCategoryMatch(in: resolvedChip)
        let matchedPassionArea = matchedCategory == nil ? passionAreaMatch(in: resolvedChip) : nil
        let matchedOutcome = (matchedPassionArea == nil && matchedCategory == nil) ? outcomeTitleMatch(in: resolvedChip) : nil
        let highlightedToken = matchedPassionArea ?? matchedCategory ?? matchedOutcome
        let highlightColor = matchedPassionArea.map { _ in Color.secondary }
            ?? matchedCategory.map { FulfillmentCategoryTheme.color(for: $0) }
            ?? matchedOutcome.map { outcomeChipColor(for: $0) }
            ?? .primary

        return HStack(spacing: 0) {
            Button {
                let shouldMaskPromptInBubble = isBestUseLoomChip(resolvedChip) || isBestUseLoomChip(chip)
                sendPrompt(
                    promptToSend,
                    displayedAs: shouldMaskPromptInBubble ? resolvedChip : nil
                )
            } label: {
                promptChipLabelText(
                    chipText: resolvedChip,
                    highlightedToken: highlightedToken,
                    highlightColor: highlightColor
                )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.leading, 12)
                    .padding(.trailing, highlightedToken == nil ? 12 : 8)
                    .padding(.vertical, promptChipVerticalPadding)
            }
            .buttonStyle(.plain)

            if let highlightedToken {
                Divider()
                    .frame(height: 16)
                    .overlay(Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.08))
                    .padding(.trailing, 2)

                Menu {
                    ForEach(replacementOptions(for: highlightedToken, in: resolvedChip), id: \.self) { option in
                        Button {
                            chipCategoryOverrides[chip] = replacingPromptToken(in: chip, currentToken: highlightedToken, with: option)
                        } label: {
                            if option == highlightedToken {
                                Label(option, systemImage: "checkmark")
                            } else {
                                Text(option)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(highlightColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, promptChipVerticalPadding)
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            Capsule(style: .continuous)
                .fill(colorScheme == .dark ? Color(.secondarySystemBackground) : Color(.systemBackground))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.08), lineWidth: 1)
        )
    }

    private func promptChipLabelText(chipText: String, highlightedToken: String?, highlightColor: Color) -> Text {
        guard let highlightedToken,
              let range = chipText.range(of: highlightedToken, options: [.caseInsensitive]) else {
            return Text(chipText)
        }

        let prefix = String(chipText[..<range.lowerBound])
        let middle = String(chipText[range])
        let suffix = String(chipText[range.upperBound...])

        return Text(prefix)
        + Text(middle).bold().foregroundColor(highlightColor)
        + Text(suffix)
    }

    private var fulfillmentCategoryNamesForChipSelection: [String] {
        let dynamic = fulfillments.map(\.category)
        var seen = Set<String>()
        return dynamic
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0.lowercased()).inserted }
            .sorted()
    }

    private func fulfillmentCategoryMatch(in chipText: String) -> String? {
        fulfillmentCategoryNamesForChipSelection
            .sorted { $0.count > $1.count }
            .first(where: { chipText.localizedCaseInsensitiveContains($0) })
    }

    private var outcomeTitlesForChipSelection: [String] {
        var seen = Set<String>()
        return outcomes
            .map(\.outcome)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0.lowercased()).inserted }
            .sorted()
    }

    private var passionAreaNamesForChipSelection: [String] {
        PassionType.allCases.map(\.rawValue)
    }

    private func isPassionSelectorChip(_ chipText: String) -> Bool {
        chipText.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .hasPrefix("new passions for ")
    }

    private func outcomeTitleMatch(in chipText: String) -> String? {
        outcomeTitlesForChipSelection
            .sorted { $0.count > $1.count }
            .first(where: { chipText.localizedCaseInsensitiveContains($0) })
    }

    private func passionAreaMatch(in chipText: String) -> String? {
        guard isPassionSelectorChip(chipText) else { return nil }
        return passionAreaNamesForChipSelection
            .first(where: { option in
                let suffix = chipText
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .dropFirst("new passions for ".count)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return String(suffix).caseInsensitiveCompare(option) == .orderedSame
            })
    }

    private func outcomeChipColor(for outcomeTitle: String) -> Color {
        if let category = outcomes.first(where: {
            $0.outcome.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(outcomeTitle) == .orderedSame
        })?.category {
            return FulfillmentCategoryTheme.color(for: category)
        }
        return .blue
    }

    private func replacementOptions(for highlightedToken: String, in chipText: String) -> [String] {
        if isPassionSelectorChip(chipText),
           let matchedPassionArea = passionAreaMatch(in: chipText),
           matchedPassionArea.caseInsensitiveCompare(highlightedToken) == .orderedSame {
            return passionAreaNamesForChipSelection
        }
        if let matchedCategory = fulfillmentCategoryMatch(in: chipText),
           matchedCategory.caseInsensitiveCompare(highlightedToken) == .orderedSame {
            return fulfillmentCategoryNamesForChipSelection
        }
        if let matchedOutcome = outcomeTitleMatch(in: chipText),
           matchedOutcome.caseInsensitiveCompare(highlightedToken) == .orderedSame {
            return outcomeTitlesForChipSelection
        }
        return []
    }

    private func resolvedPromptChipText(for originalChip: String) -> String {
        chipCategoryOverrides[originalChip] ?? originalChip
    }

    private func resolvedPromptChipPrompt(for originalChip: String, resolvedTitle: String) -> String {
        guard !messages.isEmpty else { return resolvedTitle }
        let latestAssistant = messages.last(where: { $0.roleRaw == LoomAIChatRole.assistant.rawValue })
        let chips = LoomAIChatMessageChipsCodec.decode(latestAssistant?.chipsJSON)
        if let match = chips.first(where: { $0.title.caseInsensitiveCompare(originalChip) == .orderedSame }) {
            if isBestUseLoomChip(originalChip) || isBestUseLoomChip(resolvedTitle) {
                return resolvedTitle
            }
            return chipCategoryOverrides[originalChip] ?? match.prompt
        }
        return resolvedTitle
    }

    private func isBestUseLoomChip(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare(bestUseLoomChipTitle) == .orderedSame
    }

    private func replacingPromptToken(in chip: String, currentToken: String, with newValue: String) -> String {
        guard let range = chip.range(of: currentToken, options: [.caseInsensitive]) else {
            return chip
        }
        return chip.replacingCharacters(in: range, with: newValue)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image("LoomAI")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                Text("Ask LoomAI to analyze and improve your Purpose Vision, Passions, Fulfillment Areas, Little Wins, Goals, Actions, Capture List, and any questions about Loom.")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(.secondarySystemBackground) : Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func messageBubble(_ message: LoomAIChatMessage) -> some View {
        let isUser = message.roleRaw == LoomAIChatRole.user.rawValue
        let assistantContent = isUser ? "" : sanitizedAssistantMessageContent(for: message)
        let shouldShowBubble = isUser
            || !assistantContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !assistantHasRenderableSuggestions(message)

        if shouldShowBubble {
            HStack {
                if isUser { Spacer(minLength: 0) }
                VStack(alignment: .leading, spacing: 4) {
                    messageBubbleText(message, isUser: isUser, assistantContent: assistantContent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(
                                    isUser
                                    ? Color.accentColor
                                    : (colorScheme == .dark ? Color(.secondarySystemBackground) : Color(.systemGray5))
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(
                                    isUser
                                    ? Color.clear
                                    : Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.10),
                                    lineWidth: 1
                                )
                        )
                        .contextMenu {
                            Button {
                                UIPasteboard.general.string = copyableMessageText(for: message)
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                        }

                    if !isUser {
                        HStack(spacing: 8) {
                            if let providerLabel = assistantProviderLabel(for: message) {
                                Text(providerLabel)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            #if DEBUG
                            Text(messageTimestampLine(message.createdAt))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            #endif
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .frame(width: isUser ? nil : assistantBubbleWidth, alignment: .leading)
                .frame(maxWidth: isUser ? userBubbleMaxWidth : assistantBubbleWidth, alignment: isUser ? .trailing : .leading)
                if !isUser { Spacer(minLength: 0) }
            }
            .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
        }
    }

    @ViewBuilder
    private func messageBubbleText(_ message: LoomAIChatMessage, isUser: Bool, assistantContent: String) -> some View {
        if isUser {
            userMessageText(message.content)
                .font(.subheadline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        } else {
            LoomAITokenizedMessageView(
                content: assistantContent,
                highlightReferences: assistantMessageHighlightReferences(for: message)
            )
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .textSelection(.enabled)
        }
    }

    private func userMessageText(_ content: String) -> Text {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let match = routedChipDisplaySegments(for: trimmed) else {
            return Text(trimmed)
        }
        return Text(match.prefix) + Text(match.reference).bold()
    }

    private func routedChipDisplaySegments(for content: String) -> (prefix: String, reference: String)? {
        let prefixes = [
            "Daily Little Wins for ",
            "New Mission for ",
            "New identities for ",
            "New Identity for ",
            "Next step for ",
            "Plan for ",
            "New passions for "
        ]

        for prefix in prefixes {
            guard content.count > prefix.count,
                  content.hasPrefix(prefix) else { continue }
            let reference = String(content.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !reference.isEmpty else { continue }
            return (prefix, reference)
        }

        return nil
    }

    private func copyableMessageText(for message: LoomAIChatMessage) -> String {
        guard message.roleRaw == LoomAIChatRole.assistant.rawValue else {
            return message.content
        }
        return sanitizedAssistantMessageContent(for: message).replacingOccurrences(
            of: #"\[\[(P|F|O|A):([^\]]+)\]\]"#,
            with: "$2",
            options: .regularExpression
        )
    }

    private func sanitizedAssistantMessageContent(for message: LoomAIChatMessage) -> String {
        var content = message.content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        if let trimmedRedirect = trimmedUnrelatedPromptRedirect(in: content) {
            return trimmedRedirect
        }

        let hasSuggestionCards = !LoomAIChatMessageSuggestionCardsCodec.decode(message.suggestionCardsJSON).isEmpty
        let hasFallbackActions = !LoomAIChatMessageActionsCodec.decode(message.actionsJSON).isEmpty
        let hasNextAction = LoomAIChatMessageNextActionCodec.decode(message.nextActionJSON) != nil
        let hasAnySuggestions = hasSuggestionCards || hasFallbackActions || hasNextAction

        if hasAnySuggestions {
            let lines = content
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map(String.init)
                .filter { rawLine in
                    let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    guard !line.isEmpty else { return true }
                    if line.contains("option") && line.contains("below") { return false }
                    if line.contains("suggestion") && line.contains("below") { return false }
                    if line.contains("choose") && line.contains("option") { return false }
                    if line.contains("pick") && line.contains("option") { return false }
                    return true
                }
            content = lines.joined(separator: "\n")
        }

        // Smooth a common awkward phrase when purpose text is injected inline.
        content = content.replacingOccurrences(
            of: #"(?i)\bgiven your bigger\s+(?=(\[\[P:|I ))"#,
            with: "Given your bigger vision, ",
            options: .regularExpression
        )

        content = content.replacingOccurrences(
            of: #"\n{3,}"#,
            with: "\n\n",
            options: .regularExpression
        )

        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }

    private func assistantMessageHighlightReferences(for message: LoomAIChatMessage) -> [LoomAIInlineReference] {
        var references: [LoomAIInlineReference] = []
        var seen = Set<String>()
        let decodedAnnotations = LoomAIChatMessageAnnotationsCodec.decode(message.messageAnnotationsJSON)

        func appendReference(_ reference: LoomAIInlineReference) {
            let key = "\(reference.kind)|\(reference.displayText.lowercased())|\(reference.categoryName?.lowercased() ?? "")"
            guard seen.insert(key).inserted else { return }
            references.append(reference)
        }

        if !decodedAnnotations.isEmpty {
            for annotation in decodedAnnotations {
                let text = annotation.displayText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }
                appendReference(
                    .init(
                        kind: annotation.kind,
                        displayText: text,
                        categoryName: annotation.categoryName?.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                )
            }
            return references.sorted {
                if $0.displayText.count != $1.displayText.count {
                    return $0.displayText.count > $1.displayText.count
                }
                return $0.displayText.localizedCaseInsensitiveCompare($1.displayText) == .orderedAscending
            }
        }

        let categoryNameByID = Dictionary(uniqueKeysWithValues: fulfillments.map {
            ($0.category_id, $0.category.trimmingCharacters(in: .whitespacesAndNewlines))
        })

        for fulfillment in fulfillments {
            let category = fulfillment.category.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !category.isEmpty else { continue }
            appendReference(.init(kind: "C", displayText: category, categoryName: category))
        }

        for outcome in outcomes {
            let title = outcome.outcome.trimmingCharacters(in: .whitespacesAndNewlines)
            let category = outcome.category.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty, !category.isEmpty else { continue }
            appendReference(.init(kind: "C", displayText: title, categoryName: category))
        }

        for row in fulfillmentFocusRows {
            let activity = row.activity.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !activity.isEmpty,
                  let category = categoryNameByID[row.category_id]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !category.isEmpty else { continue }
            appendReference(.init(kind: "C", displayText: activity, categoryName: category))
        }

        for role in fulfillmentRoles {
            let identity = role.role.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !identity.isEmpty,
                  let category = categoryNameByID[role.category_id]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !category.isEmpty else { continue }
            appendReference(.init(kind: "C", displayText: identity, categoryName: category))
        }

        for passion in passions {
            let title = passion.passion.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }
            appendReference(.init(kind: "P", displayText: title, categoryName: nil))
        }

        return references.sorted {
            if $0.displayText.count != $1.displayText.count {
                return $0.displayText.count > $1.displayText.count
            }
            return $0.displayText.localizedCaseInsensitiveCompare($1.displayText) == .orderedAscending
        }
    }

    private func assistantHasRenderableSuggestions(_ message: LoomAIChatMessage) -> Bool {
        !LoomAIChatMessageSuggestionCardsCodec.decode(message.suggestionCardsJSON).isEmpty
            || !LoomAIChatMessageActionsCodec.decode(message.actionsJSON).isEmpty
            || LoomAIChatMessageNextActionCodec.decode(message.nextActionJSON) != nil
    }

    private func trimmedUnrelatedPromptRedirect(in content: String) -> String? {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let lower = trimmed.lowercased()
        guard lower.contains("unrelated to loom"),
              lower.contains("loom-specific help:") else { return nil }
        guard let range = trimmed.range(of: "help:", options: [.caseInsensitive]) else { return nil }
        return String(trimmed[..<range.upperBound])
    }

    private func assistantProviderLabel(for message: LoomAIChatMessage) -> String? {
        let debug = LoomAIDebugCodec.decode(message.debugJSON)
        if let suggestionSource = debug?.suggestionSource?.trimmingCharacters(in: .whitespacesAndNewlines),
           !suggestionSource.isEmpty {
            return suggestionSource
        }

        let model = debug?.model?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard let model else { return nil }
        if model.hasPrefix("apple.intelligence") {
            return "Apple Intelligence"
        }
        if model.hasPrefix("loom.local.compatibility") {
            return "Loom Database"
        }
        return nil
    }

    @ViewBuilder
    private func unrelatedPromptLinksView(for message: LoomAIChatMessage) -> some View {
        if shouldShowUnrelatedPromptLinks(for: message) {
            VStack(alignment: .leading, spacing: 6) {
                unrelatedPromptLinkButton(title: "Open Loom Ecosystem") {
                    NotificationCenter.default.post(name: .loomAIOpenLifeOSInsights, object: nil)
                }
                unrelatedPromptLinkButton(title: "Launch tutorial") {
                    NotificationCenter.default.post(name: .loomAILaunchTutorial, object: nil)
                }
            }
            .padding(.top, 2)
        }
    }

    private func shouldShowUnrelatedPromptLinks(for message: LoomAIChatMessage) -> Bool {
        guard message.roleRaw == LoomAIChatRole.assistant.rawValue else { return false }
        let content = sanitizedAssistantMessageContent(for: message).lowercased()
        guard content.contains("unrelated to loom"),
              content.contains("loom-specific help:") else { return false }
        let chips = LoomAIChatMessageChipsCodec.decode(message.chipsJSON)
        let chipTitles = Set(chips.map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        return chipTitles.contains("loom ecosystem map") && chipTitles.contains("purpose onboarding")
    }

    private func unrelatedPromptLinkButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
                    .multilineTextAlignment(.leading)
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue.opacity(0.9))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.blue.opacity(colorScheme == .dark ? 0.16 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.blue.opacity(colorScheme == .dark ? 0.34 : 0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    #if DEBUG
    private func messageTimestampLine(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "h:mm a, MMM d, yyyy"
        return formatter.string(from: date).uppercased()
    }
    #endif

    @ViewBuilder
    private func groundingSectionView(items: [LoomAIGroundingItem]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Sources")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(groundingLabels(items), id: \.self) { label in
                            Text(label)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(Color.secondary.opacity(colorScheme == .dark ? 0.18 : 0.10))
                                )
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(Color.secondary.opacity(colorScheme == .dark ? 0.24 : 0.16), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.trailing, 2)
                }
            }
            .padding(.top, 2)
        }
    }

    private func groundingLabels(_ items: [LoomAIGroundingItem]) -> [String] {
        var seen = Set<String>()
        var output: [String] = []
        for item in items.prefix(6) {
            let label = groundingPillLabel(for: item).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty else { continue }
            let key = label.lowercased()
            guard seen.insert(key).inserted else { continue }
            output.append(label)
        }
        return output
    }

    private func groundingLineText(_ item: LoomAIGroundingItem) -> String {
        let section = item.section.trimmingCharacters(in: .whitespacesAndNewlines)
        let field = item.field.trimmingCharacters(in: .whitespacesAndNewlines)
        let timestamp = normalizedGroundingTimestampText(item.timestamp)
        if !timestamp.isEmpty {
            return "\(section) • \(field) • \(timestamp)"
        }
        return "\(section) • \(field)"
    }

    private func groundingPillLabel(for item: LoomAIGroundingItem) -> String {
        let section = item.section.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let field = item.field.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let combined = "\(section).\(field)"

        if combined.contains("mission") { return "Mission" }
        if combined.contains("vision") { return "Vision" }
        if combined.contains("purpose") { return "Purpose" }
        if combined.contains("passion") { return "Passions" }
        if combined.contains("identity") { return "Identity" }
        if combined.contains("littlewin") || combined.contains("little_win") { return "Little Wins" }
        if combined.contains("fulfillment") || combined.contains("category") { return "Fulfillment Areas" }
        if combined.contains("outcome") || combined.contains("goal") { return "Goals" }
        if combined.contains("actionblock") || combined.contains("action_block") || combined.contains("actions") {
            return "Action Plan"
        }
        if combined.contains("capture") { return "Capture" }
        if combined.contains("diagnostic") || combined.contains("personalization") { return "Diagnostic" }
        if combined.contains("recently_deleted") { return "Recently Deleted" }

        let preferred = friendlyGroundingSegment(from: field) ?? friendlyGroundingSegment(from: section)
        return preferred ?? "Context"
    }

    private func friendlyGroundingSegment(from raw: String) -> String? {
        let stripped = raw
            .replacingOccurrences(of: #"\[[0-9]+\]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\[[^\]]*\]"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !stripped.isEmpty else { return nil }
        let components = stripped.split(separator: ".").map(String.init).filter { !$0.isEmpty }
        guard let tail = components.last else { return nil }
        let cleanedTail = tail
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTail.isEmpty else { return nil }
        return cleanedTail
            .split(separator: " ")
            .map { word -> String in
                guard let first = word.first else { return String(word) }
                return String(first).uppercased() + word.dropFirst()
            }
            .joined(separator: " ")
    }

    private func normalizedGroundingTimestampText(_ raw: String) -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return "" }
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: value) else { return value }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    @ViewBuilder
    private func suggestionCardsSectionView(
        cards: [LoomAISuggestionCard],
        fallbackActions: [LoomAISuggestedAction],
        nextAction: LoomAISuggestedAction?,
        resolvedActionMap: [String: LoomAISuggestedAction]
    ) -> some View {
        let cardsActions = suggestionCardActions(from: cards)
        let hasCards = !cards.isEmpty
        let hasFallback = !fallbackActions.isEmpty
        let dedupedFallback = deduplicatedActions(fallbackActions)
        let next = hasCards ? nil : deduplicatedNextAction(nextAction, existing: cardsActions + dedupedFallback)

        if hasCards || hasFallback || next != nil {
            VStack(alignment: .leading, spacing: 8) {
                if hasCards {
                    ForEach(cards) { card in
                        suggestionCardView(card, resolvedActionMap: resolvedActionMap)
                    }
                } else if hasFallback {
                    suggestedActionsView(actions: dedupedFallback, resolvedActionMap: resolvedActionMap)
                }

                if let next {
                    VStack(alignment: .leading, spacing: 6) {
                        suggestedActionButton(next, resolvedActionMap: resolvedActionMap)
                    }
                }
            }
            .padding(.top, 2)
        }
    }

    private func suggestionCardView(
        _ card: LoomAISuggestionCard,
        resolvedActionMap: [String: LoomAISuggestedAction]
    ) -> some View {
        let options = card.options.map(suggestionOptionToAction)
        let resolvedOptions = options.map { resolvedActionMap[suggestedActionStateKey($0)] ?? $0 }
        let cardHeading = displayedSuggestionCardHeading(for: card, actions: resolvedOptions)
        return VStack(alignment: .leading, spacing: 6) {
            if !cardHeading.isEmpty {
                Text(cardHeading)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 12)
            }
            ForEach(options) { action in
                suggestedActionButton(action, resolvedActionMap: resolvedActionMap)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func suggestionOptionToAction(_ option: LoomAISuggestionOption) -> LoomAISuggestedAction {
        let title = normalizedSuggestionOptionTitle(option.title)
        return LoomAISuggestedAction(
            id: option.id,
            title: title,
            type: option.type,
            payload: option.payload
        )
    }

    private func normalizedSuggestionOptionTitle(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let withoutPrefix = trimmed.replacingOccurrences(
            of: #"^[A-Za-z]\s*[\.\)\:\-]\s+"#,
            with: "",
            options: .regularExpression
        )
        return withoutPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func suggestionCardActions(from cards: [LoomAISuggestionCard]) -> [LoomAISuggestedAction] {
        cards.flatMap(\.options).map(suggestionOptionToAction)
    }

    private func deduplicatedActions(_ actions: [LoomAISuggestedAction]) -> [LoomAISuggestedAction] {
        var seen = Set<String>()
        var unique: [LoomAISuggestedAction] = []
        for action in actions {
            let key = "\(action.type.lowercased())|\(action.payload.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: "&"))"
            if seen.insert(key).inserted {
                unique.append(action)
            }
        }
        return unique
    }

    private func deduplicatedNextAction(
        _ action: LoomAISuggestedAction?,
        existing: [LoomAISuggestedAction]
    ) -> LoomAISuggestedAction? {
        guard let action else { return nil }
        let key = "\(action.type.lowercased())|\(action.payload.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: "&"))"
        let hasMatch = existing.contains { candidate in
            let candidateKey = "\(candidate.type.lowercased())|\(candidate.payload.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: "&"))"
            return candidateKey == key
        }
        return hasMatch ? nil : action
    }

    private enum SuggestedCapacityFamily: Hashable {
        case identity
        case littleWin
    }

    private struct SuggestedReplacementPoolKey: Hashable {
        let family: SuggestedCapacityFamily
        let categoryID: UUID
    }

    private let suggestionUnavailableReasonKey = "__loomUnavailableReason"

    private func suggestedActionStateKey(_ action: LoomAISuggestedAction) -> String {
        let payloadKey = action.payload
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
        return "\(action.id)|\(action.type.lowercased())|\(payloadKey)|\(action.title)"
    }

    private func visibleSuggestionActionsInDisplayOrder() -> [LoomAISuggestedAction] {
        var actions: [LoomAISuggestedAction] = []
        for message in messages where message.roleRaw == LoomAIChatRole.assistant.rawValue {
            let cards = LoomAIChatMessageSuggestionCardsCodec.decode(message.suggestionCardsJSON)
            let fallbackActions = deduplicatedActions(LoomAIChatMessageActionsCodec.decode(message.actionsJSON))
            let cardsActions = suggestionCardActions(from: cards)
            let nextAction = cards.isEmpty
                ? deduplicatedNextAction(
                    LoomAIChatMessageNextActionCodec.decode(message.nextActionJSON),
                    existing: cardsActions + fallbackActions
                )
                : nil

            if !cards.isEmpty {
                actions.append(contentsOf: cardsActions)
            } else {
                actions.append(contentsOf: fallbackActions)
                if let nextAction {
                    actions.append(nextAction)
                }
            }
        }
        return actions
    }

    private func currentResolvedSuggestedAction(for action: LoomAISuggestedAction) -> LoomAISuggestedAction {
        let stateKey = suggestedActionStateKey(action)
        return appliedSuggestedActionSnapshots[stateKey]
            ?? inFlightSuggestedActionSnapshots[stateKey]
            ?? resolvedVisibleSuggestionActionMap()[stateKey]
            ?? action
    }

    private func resolvedVisibleSuggestionActionMap() -> [String: LoomAISuggestedAction] {
        let visibleActions = visibleSuggestionActionsInDisplayOrder()
        var displayOrderByID: [String: Int] = [:]
        for (offset, action) in visibleActions.enumerated() {
            displayOrderByID[suggestedActionStateKey(action)] = offset
        }
        let sortedInFlight = inFlightSuggestedActionSnapshots
            .sorted { lhs, rhs in
                let left = displayOrderByID[lhs.key] ?? .max
                let right = displayOrderByID[rhs.key] ?? .max
                if left != right { return left < right }
                return lhs.key < rhs.key
            }
            .map(\.value)

        var resolvedByID: [String: LoomAISuggestedAction] = [:]
        var optimisticItems = replacementPoolItemsByKey()
        var reservedTargets: [SuggestedReplacementPoolKey: Set<String>] = [:]

        for action in sortedInFlight {
            guard let poolKey = replacementPoolKey(for: action) else { continue }
            optimisticItems[poolKey] = applyingOptimisticAction(
                action,
                to: optimisticItems[poolKey] ?? [],
                family: poolKey.family
            )
            if let replaceTarget = explicitReplacementTarget(for: action, family: poolKey.family) {
                reservedTargets[poolKey, default: []].insert(normalizedReplacementValue(replaceTarget, family: poolKey.family))
            }
        }

        for rawAction in visibleActions {
            let stateKey = suggestedActionStateKey(rawAction)
            if let applied = appliedSuggestedActionSnapshots[stateKey] {
                resolvedByID[stateKey] = applied
                continue
            }
            if let inFlight = inFlightSuggestedActionSnapshots[stateKey] {
                resolvedByID[stateKey] = inFlight
                continue
            }

            guard let poolKey = replacementPoolKey(for: rawAction) else {
                resolvedByID[stateKey] = rawAction
                continue
            }

            let poolItems = optimisticItems[poolKey] ?? []
            let currentReserved = reservedTargets[poolKey] ?? []
            let resolved = resolveCapacityLimitedAction(
                rawAction,
                family: poolKey.family,
                currentItems: poolItems,
                reservedTargets: currentReserved
            )
            resolvedByID[stateKey] = resolved

            if let replaceTarget = explicitReplacementTarget(for: resolved, family: poolKey.family) {
                reservedTargets[poolKey, default: []].insert(normalizedReplacementValue(replaceTarget, family: poolKey.family))
            }
        }

        return resolvedByID
    }

    private func replacementPoolItemsByKey() -> [SuggestedReplacementPoolKey: [String]] {
        var items: [SuggestedReplacementPoolKey: [String]] = [:]

        for category in fulfillments {
            let identityRows = fulfillmentRoles
                .filter { $0.category_id == category.category_id }
                .sorted {
                    if $0.rank != $1.rank { return $0.rank < $1.rank }
                    return $0.updatedAt < $1.updatedAt
                }
                .map { $0.role.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            items[SuggestedReplacementPoolKey(family: .identity, categoryID: category.category_id)] = identityRows

            let littleWinRows = fulfillmentFocusRows
                .filter { $0.category_id == category.category_id }
                .sorted {
                    if $0.rank != $1.rank { return $0.rank < $1.rank }
                    return $0.updatedAt < $1.updatedAt
                }
                .map { $0.activity.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            items[SuggestedReplacementPoolKey(family: .littleWin, categoryID: category.category_id)] = littleWinRows
        }

        return items
    }

    private func replacementPoolKey(for action: LoomAISuggestedAction) -> SuggestedReplacementPoolKey? {
        let lowerType = action.type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let family: SuggestedCapacityFamily
        if lowerType == "addfulfillmentidentity" || lowerType == "replacefulfillmentidentity" {
            family = .identity
        } else if lowerType == "createlittlewin" || lowerType == "addlittlewin" || lowerType == "replacelittlewin" {
            family = .littleWin
        } else {
            return nil
        }

        guard let categoryID = resolvedSuggestedActionCategoryID(for: action) else { return nil }
        return SuggestedReplacementPoolKey(family: family, categoryID: categoryID)
    }

    private func resolveCapacityLimitedAction(
        _ rawAction: LoomAISuggestedAction,
        family: SuggestedCapacityFamily,
        currentItems: [String],
        reservedTargets: Set<String>
    ) -> LoomAISuggestedAction {
        let incoming = LoomAIChatProvider.canonicalInsertedValue(
            actionType: rawAction.type,
            payload: rawAction.payload,
            fallbackTitle: rawAction.title
        )
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !incoming.isEmpty else { return rawAction }

        let normalizedIncoming = normalizedReplacementValue(incoming, family: family)
        let currentCount = currentItems.count
        let explicitTarget = explicitReplacementTarget(for: rawAction, family: family)
        let replaceType = family == .identity ? "replaceFulfillmentIdentity" : "replaceLittleWin"
        let addType: String = {
            switch family {
            case .identity:
                return "addFulfillmentIdentity"
            case .littleWin:
                return rawAction.type == "createLittleWin" ? "createLittleWin" : "addLittleWin"
            }
        }()

        if currentCount < 3 {
            var payload = rawAction.payload
            payload.removeValue(forKey: "replaceIdentity")
            payload.removeValue(forKey: "oldIdentity")
            payload.removeValue(forKey: "replaceActivity")
            payload.removeValue(forKey: "oldActivity")
            payload.removeValue(forKey: suggestionUnavailableReasonKey)
            return LoomAISuggestedAction(
                id: rawAction.id,
                title: rawAction.title,
                type: addType,
                payload: payload
            )
        }

        let availableTargets = currentItems.filter { item in
            let normalized = normalizedReplacementValue(item, family: family)
            return normalized != normalizedIncoming && !reservedTargets.contains(normalized)
        }

        if family == .identity,
           let replaceIdentity = LoomAIChatProvider.selectIdentityReplacement(
            explicitTarget: explicitTarget,
            proposedIdentity: incoming,
            existing: availableTargets
           ) {
            var payload = rawAction.payload
            payload["replaceIdentity"] = replaceIdentity
            payload.removeValue(forKey: "oldIdentity")
            payload.removeValue(forKey: suggestionUnavailableReasonKey)
            return LoomAISuggestedAction(id: rawAction.id, title: rawAction.title, type: replaceType, payload: payload)
        }

        if family == .littleWin,
           let replaceActivity = LoomAIChatProvider.selectLittleWinReplacement(
            explicitTarget: explicitTarget,
            proposedActivity: incoming,
            existing: availableTargets
           ) {
            var payload = rawAction.payload
            payload["replaceActivity"] = replaceActivity
            payload.removeValue(forKey: "oldActivity")
            payload.removeValue(forKey: suggestionUnavailableReasonKey)
            return LoomAISuggestedAction(id: rawAction.id, title: rawAction.title, type: replaceType, payload: payload)
        }

        var payload = rawAction.payload
        payload.removeValue(forKey: "replaceIdentity")
        payload.removeValue(forKey: "oldIdentity")
        payload.removeValue(forKey: "replaceActivity")
        payload.removeValue(forKey: "oldActivity")
        payload[suggestionUnavailableReasonKey] = "No unique replacement available right now."
        return LoomAISuggestedAction(id: rawAction.id, title: rawAction.title, type: replaceType, payload: payload)
    }

    private func applyingOptimisticAction(
        _ action: LoomAISuggestedAction,
        to currentItems: [String],
        family: SuggestedCapacityFamily
    ) -> [String] {
        let incoming = LoomAIChatProvider.canonicalInsertedValue(
            actionType: action.type,
            payload: action.payload,
            fallbackTitle: action.title
        )
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !incoming.isEmpty else { return currentItems }

        let normalizedIncoming = normalizedReplacementValue(incoming, family: family)
        var items = currentItems

        if let replaceTarget = explicitReplacementTarget(for: action, family: family) {
            let normalizedReplace = normalizedReplacementValue(replaceTarget, family: family)
            if let index = items.firstIndex(where: { normalizedReplacementValue($0, family: family) == normalizedReplace }) {
                items[index] = incoming
            } else if !items.contains(where: { normalizedReplacementValue($0, family: family) == normalizedIncoming }) {
                items.append(incoming)
            }
            return items
        }

        if !items.contains(where: { normalizedReplacementValue($0, family: family) == normalizedIncoming }) {
            items.append(incoming)
        }
        return items
    }

    private func explicitReplacementTarget(
        for action: LoomAISuggestedAction,
        family: SuggestedCapacityFamily
    ) -> String? {
        let raw: String
        switch family {
        case .identity:
            raw = action.payload["replaceIdentity"] ?? action.payload["oldIdentity"] ?? ""
        case .littleWin:
            raw = action.payload["replaceActivity"] ?? action.payload["oldActivity"] ?? ""
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func normalizedReplacementValue(_ value: String, family: SuggestedCapacityFamily) -> String {
        switch family {
        case .identity:
            return LoomAIChatProvider.normalizedComparisonKey(value)
        case .littleWin:
            return normalizedSuggestedLittleWinText(value)
        }
    }

    private func suggestedActionUnavailableReason(for action: LoomAISuggestedAction) -> String? {
        let reason = (action.payload[suggestionUnavailableReasonKey] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return reason.isEmpty ? nil : reason
    }

    @ViewBuilder
    private func suggestedActionsView(
        actions: [LoomAISuggestedAction],
        resolvedActionMap: [String: LoomAISuggestedAction]
    ) -> some View {
        if !actions.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(actions) { action in
                        suggestedActionButton(action, resolvedActionMap: resolvedActionMap)
                    }
                }
            }
            .padding(.top, 2)
        }
    }

    private func suggestedActionButton(
        _ action: LoomAISuggestedAction,
        resolvedActionMap: [String: LoomAISuggestedAction]
    ) -> some View {
        let stateKey = suggestedActionStateKey(action)
        let resolvedAction = appliedSuggestedActionSnapshots[stateKey]
            ?? inFlightSuggestedActionSnapshots[stateKey]
            ?? resolvedActionMap[stateKey]
            ?? action
        let isApplied = appliedSuggestedActionSnapshots[stateKey] != nil || isSuggestedActionPersistentlyApplied(resolvedAction)
        let isBusy = inFlightSuggestedActionSnapshots[stateKey] != nil
        let unavailableReason = suggestedActionUnavailableReason(for: resolvedAction)
        return Button {
            let executionAction = currentResolvedSuggestedAction(for: action)
            let currentlyApplied = appliedSuggestedActionSnapshots[stateKey] != nil || isSuggestedActionPersistentlyApplied(executionAction)
            let currentlyBusy = inFlightSuggestedActionSnapshots[stateKey] != nil
            let currentUnavailable = suggestedActionUnavailableReason(for: executionAction)
            guard !currentlyApplied, !currentlyBusy, currentUnavailable == nil else { return }

            inFlightSuggestedActionSnapshots[stateKey] = executionAction
            let didApply = viewModel.executeSuggestedAction(executionAction, in: modelContext)
            if let error = viewModel.errorMessage, !error.isEmpty {
                inFlightSuggestedActionSnapshots.removeValue(forKey: stateKey)
                actionExecutionAlertText = error
                showActionExecutionAlert = true
            } else if didApply {
                appliedSuggestedActionSnapshots[stateKey] = executionAction
                inFlightSuggestedActionSnapshots.removeValue(forKey: stateKey)
            } else {
                inFlightSuggestedActionSnapshots.removeValue(forKey: stateKey)
            }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                suggestedActionLeadingIcon(for: resolvedAction, isApplied: isApplied)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 3) {
                    suggestedActionPrimaryText(for: resolvedAction, isApplied: isApplied)

                    if let subtitle = suggestedActionSubtitle(for: resolvedAction), !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(suggestedActionSecondaryColor(isApplied: isApplied))
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(suggestedActionBackgroundFill(isApplied: isApplied))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(suggestedActionBorderColor(isApplied: isApplied), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isApplied || isBusy || unavailableReason != nil)
        .opacity(isApplied || isBusy || unavailableReason != nil ? 0.78 : 1)
    }

    private func suggestedActionLeadingIcon(for _: LoomAISuggestedAction, isApplied: Bool) -> some View {
        Image("LoomAI")
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .frame(width: 16, height: 16)
            .foregroundStyle(isApplied ? Color.white.opacity(0.90) : Color.white.opacity(0.95))
    }

    @ViewBuilder
    private func suggestedActionPrimaryText(for action: LoomAISuggestedAction, isApplied: Bool) -> some View {
        if let identityDraft = extractedIdentityDraft(from: action) {
            suggestedSimpleTwoLineAction(
                topLine: "",
                detail: identityDraft.identity,
                isApplied: isApplied
            )
        } else if action.type == "createLittleWin" || action.type == "addLittleWin" || action.type == "replaceLittleWin" {
            suggestedLittleWinPrimaryText(action: action, isApplied: isApplied)
        } else if action.type == "replaceFulfillmentMission" || action.type == "updateFulfillmentMission" {
            suggestedSimpleTwoLineAction(
                topLine: "",
                detail: action.payload["mission"] ?? action.payload["text"] ?? action.payload["purpose"] ?? action.title,
                isApplied: isApplied
            )
        } else if action.type == "addFulfillmentIdentity" || action.type == "replaceFulfillmentIdentity" {
            suggestedIdentityPrimaryText(action: action, isApplied: isApplied)
        } else if action.type == "replacePurposeVision" || action.type == "updatePurposeVision" {
            suggestedSimpleTwoLineAction(
                topLine: "",
                detail: action.payload["vision"] ?? action.payload["text"] ?? action.title,
                isApplied: isApplied
            )
        } else if action.type == "addPassion" || action.type == "addPassionItem" {
            suggestedPassionPrimaryText(action: action, isApplied: isApplied)
        } else if action.type == "launchAddFulfillmentAreaPrefill" {
            suggestedAddFulfillmentAreaPrimaryText(action: action, isApplied: isApplied)
        } else {
            Text(suggestedActionButtonLabel(for: action, isApplied: isApplied))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(suggestedActionPrimaryColor(isApplied: isApplied))
                .multilineTextAlignment(.leading)
        }
    }

    private func suggestedSimpleTwoLineAction(topLine: String, detail: String, isApplied: Bool) -> some View {
        let cleaned = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedTopLine = topLine.trimmingCharacters(in: .whitespacesAndNewlines)
        return VStack(alignment: .leading, spacing: 3) {
            if !cleanedTopLine.isEmpty {
                Text(cleanedTopLine)
                    .font(.subheadline.italic())
                    .foregroundStyle(suggestedActionPrimaryColor(isApplied: isApplied).opacity(isApplied ? 0.88 : 0.95))
                    .multilineTextAlignment(.leading)
            }
            if !cleaned.isEmpty {
                Text(cleaned)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(suggestedActionPrimaryColor(isApplied: isApplied))
                    .multilineTextAlignment(.leading)
            }
        }
    }

    private func suggestedIdentityPrimaryText(action: LoomAISuggestedAction, isApplied: Bool) -> some View {
        let identity = LoomAIChatProvider.canonicalInsertedValue(
            actionType: action.type,
            payload: action.payload,
            fallbackTitle: action.title
        )
        let replaceIdentity = effectiveIdentityReplacementName(for: action)
        let isReplace = effectiveIsIdentityReplacement(for: action)

        return VStack(alignment: .leading, spacing: 3) {
            if !identity.isEmpty {
                Text(identity)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(suggestedActionPrimaryColor(isApplied: isApplied))
            }
            if isReplace, !replaceIdentity.isEmpty {
                Text("\(isApplied ? "Replaced" : "Replacing"): \(replaceIdentity)")
                    .font(.caption)
                    .foregroundStyle(suggestedActionSecondaryColor(isApplied: isApplied))
            }
        }
        .multilineTextAlignment(.leading)
    }

    private func suggestedPassionPrimaryText(action: LoomAISuggestedAction, isApplied: Bool) -> some View {
        let passion = LoomAIChatProvider.canonicalInsertedValue(
            actionType: action.type,
            payload: action.payload,
            fallbackTitle: action.title
        )
        return VStack(alignment: .leading, spacing: 3) {
            if !passion.isEmpty {
                Text(passion)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(suggestedActionPrimaryColor(isApplied: isApplied))
            }
        }
        .multilineTextAlignment(.leading)
    }

    private func suggestedAddFulfillmentAreaPrimaryText(action: LoomAISuggestedAction, isApplied: Bool) -> some View {
        let category = (action.payload["categoryName"] ?? action.payload["category"] ?? action.payload["title"] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let top = isApplied ? "Opened Add Fulfillment Area:" : "Open Add Fulfillment Area:"
        return VStack(alignment: .leading, spacing: 3) {
            Text(top)
                .font(.subheadline.italic())
                .foregroundStyle(suggestedActionPrimaryColor(isApplied: isApplied).opacity(isApplied ? 0.88 : 0.95))
            if !category.isEmpty {
                Text(category)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(suggestedActionPrimaryColor(isApplied: isApplied))
            }
        }
        .multilineTextAlignment(.leading)
    }

    private func suggestedLittleWinPrimaryText(action: LoomAISuggestedAction, isApplied: Bool) -> some View {
        let activity = LoomAIChatProvider.canonicalInsertedValue(
            actionType: action.type,
            payload: action.payload,
            fallbackTitle: action.title
        )
        let isReplace = effectiveIsLittleWinReplacement(for: action)
        let replaced = effectiveLittleWinReplacementName(for: action)

        return VStack(alignment: .leading, spacing: 3) {
            if !activity.isEmpty {
                Text(activity)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(suggestedActionPrimaryColor(isApplied: isApplied))
                    .multilineTextAlignment(.leading)
            }

            if isReplace, !replaced.isEmpty {
                Text("\(isApplied ? "Replaced" : "Replacing"): \(replaced)")
                    .font(.caption)
                    .foregroundStyle(suggestedActionSecondaryColor(isApplied: isApplied))
                    .multilineTextAlignment(.leading)
            }
        }
    }

    private func suggestedActionButtonLabel(for action: LoomAISuggestedAction, isApplied: Bool) -> String {
        let base: String
        if action.type == "createLittleWin" {
            let activity = (action.payload["activity"] ?? action.payload["text"] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let category = (action.payload["categoryName"] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !activity.isEmpty, !category.isEmpty {
                base = "Add Little Win to \(category): \(activity)"
            } else if !activity.isEmpty {
                base = "Add Little Win: \(activity)"
            } else {
                base = action.title
            }
        } else {
            base = action.title
        }
        return isApplied ? "Added: \(base)" : base
    }

    private func isSuggestedActionPersistentlyApplied(_ action: LoomAISuggestedAction) -> Bool {
        guard action.type == "createLittleWin" || action.type == "addLittleWin" || action.type == "replaceLittleWin" else { return false }

        let activity = (action.payload["activity"] ?? action.payload["text"] ?? action.title)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !activity.isEmpty else { return false }

        let targetCategoryID: UUID? = {
            if let raw = action.payload["categoryID"], let uuid = UUID(uuidString: raw) {
                return uuid
            }
            if let raw = action.payload["categoryId"], let uuid = UUID(uuidString: raw) {
                return uuid
            }
            if let categoryName = action.payload["categoryName"]?.trimmingCharacters(in: .whitespacesAndNewlines),
               !categoryName.isEmpty {
                return fulfillments.first(where: {
                    $0.category.caseInsensitiveCompare(categoryName) == .orderedSame
                })?.category_id
            }
            return nil
        }()

        guard let targetCategoryID else { return false }
        let normalizedActivity = normalizedSuggestedLittleWinText(activity)
        let hasNew = fulfillmentFocusRows.contains {
            $0.category_id == targetCategoryID &&
            normalizedSuggestedLittleWinText($0.activity) == normalizedActivity
        }
        guard hasNew else { return false }

        if action.type == "replaceLittleWin",
           let replaced = action.payload["replaceActivity"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !replaced.isEmpty {
            let normalizedReplaced = normalizedSuggestedLittleWinText(replaced)
            let oldStillExists = fulfillmentFocusRows.contains {
                $0.category_id == targetCategoryID &&
                normalizedSuggestedLittleWinText($0.activity) == normalizedReplaced
            }
            return !oldStillExists
        }
        return true
    }

    private func normalizedSuggestedLittleWinText(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    private func suggestedActionSubtitle(for action: LoomAISuggestedAction) -> String? {
        if let unavailableReason = suggestedActionUnavailableReason(for: action) {
            return unavailableReason
        }
        switch action.type {
        case "createLittleWin", "addLittleWin":
            return nil
        case "replaceLittleWin":
            return nil
        case "replaceFulfillmentMission", "updateFulfillmentMission":
            return nil
        case "addFulfillmentIdentity":
            return nil
        case "replaceFulfillmentIdentity":
            return nil
        case "replacePurposeVision", "updatePurposeVision":
            return nil
        case "addPassion", "addPassionItem":
            return nil
        case "launchAddFulfillmentAreaPrefill":
            return "Opens the Add Fulfillment Area flow with Loom's suggested prefill."
        case "createAction", "createCaptureAction":
            return nil
        case "addPlanSuggestion":
            return nil
        case "createOutcome":
            return "Creates a new Outcome."
        default:
            return nil
        }
    }

    private func missionActionSubtitle(_ action: LoomAISuggestedAction) -> String? {
        categoryOnlySubtitle(action, fallback: "")
    }

    private func missionTopLine(for action: LoomAISuggestedAction, isApplied: Bool) -> String {
        let category = (action.payload["categoryName"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = isApplied ? "Updated" : "Update"
        return category.isEmpty ? "\(prefix) Mission:" : "\(prefix) \(category) Mission:"
    }

    private func categoryOnlySubtitle(_ action: LoomAISuggestedAction, fallback: String) -> String {
        fallback
    }

    private func suggestedActionSymbolName(for action: LoomAISuggestedAction) -> String? {
        switch action.type {
        case "createLittleWin", "addLittleWin", "replaceLittleWin":
            return "sparkles"
        case "replaceFulfillmentMission", "updateFulfillmentMission":
            return "flag.fill"
        case "addFulfillmentIdentity", "replaceFulfillmentIdentity":
            return "person.crop.circle.badge.plus"
        case "replacePurposeVision", "updatePurposeVision":
            return "eye.fill"
        case "addPassion", "addPassionItem":
            return "heart.text.square.fill"
        case "launchAddFulfillmentAreaPrefill":
            return "square.and.pencil"
        case "createAction", "createCaptureAction", "addPlanSuggestion":
            return "plus.circle.fill"
        case "createOutcome":
            return "target"
        default:
            return nil
        }
    }

    private func extractedIdentityDraft(from action: LoomAISuggestedAction) -> (category: String, identity: String)? {
        let text = (action.payload["text"] ?? action.payload["title"] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        guard let regex = try? NSRegularExpression(pattern: #"(?i)identity\s*\(([^)]+)\)\s*:\s*(.+)$"#) else {
            return nil
        }
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        guard let match = regex.firstMatch(in: text, options: [], range: fullRange),
              match.numberOfRanges >= 3,
              let categoryRange = Range(match.range(at: 1), in: text),
              let detailRange = Range(match.range(at: 2), in: text) else {
            return nil
        }

        let category = text[categoryRange]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        var identity = String(text[detailRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = identity.range(of: " — ") ?? identity.range(of: " – ") ?? identity.range(of: " - ") {
            identity = String(identity[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let range = identity.range(of: "—") ?? identity.range(of: "–") {
            identity = String(identity[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        identity = normalizedSuggestionOptionTitle(identity)
        guard !category.isEmpty, !identity.isEmpty else { return nil }
        return (category, identity)
    }

    private func effectiveIdentityTopLine(for action: LoomAISuggestedAction, fallbackCategory: String, isApplied: Bool) -> String {
        let category = resolvedSuggestedActionCategoryName(for: action) ?? fallbackCategory
        if effectiveIsIdentityReplacement(for: action) {
            return isApplied
                ? (category.isEmpty ? "Replaced Identity:" : "Replaced Identity in \(category):")
                : (category.isEmpty ? "Replace Identity:" : "Replace Identity in \(category):")
        }
        return isApplied
            ? "Added Identity to \(category):"
            : "Add Identity to \(category):"
    }

    private func displayedSuggestionCardHeading(
        for card: LoomAISuggestionCard,
        actions: [LoomAISuggestedAction]
    ) -> String {
        let fallback = card.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let firstAction = actions.first(where: { appliedSuggestedActionSnapshots[suggestedActionStateKey($0)] == nil })
                ?? actions.first else { return fallback }

        switch firstAction.type {
        case "createLittleWin", "addLittleWin", "replaceLittleWin":
            let category = resolvedSuggestedActionCategoryName(for: firstAction)
                ?? (firstAction.payload["categoryName"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let isReplace = effectiveIsLittleWinReplacement(for: firstAction)
            if category.isEmpty {
                return isReplace ? "Tap to Replace Little Win" : "Tap to Add Little Win"
            }
            return isReplace ? "Tap to Replace Little Win in \(category)" : "Tap to Add Little Win to \(category)"
        case "addFulfillmentIdentity", "replaceFulfillmentIdentity":
            let category = resolvedSuggestedActionCategoryName(for: firstAction)
                ?? (firstAction.payload["categoryName"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let isReplace = effectiveIsIdentityReplacement(for: firstAction)
            if category.isEmpty {
                return isReplace ? "Tap to Replace Identity" : "Tap to Add Identity"
            }
            return isReplace ? "Tap to Replace Identity in \(category)" : "Tap to Add Identity to \(category)"
        case "createCaptureAction":
            return "Tap to Add Action to Capture"
        default:
            return fallback
        }
    }

    private func effectiveIsIdentityReplacement(for action: LoomAISuggestedAction) -> Bool {
        action.type == "replaceFulfillmentIdentity" ||
            (action.payload["replaceIdentity"] ?? action.payload["oldIdentity"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private func effectiveIdentityReplacementName(for action: LoomAISuggestedAction) -> String {
        let explicit = (action.payload["replaceIdentity"] ?? action.payload["oldIdentity"] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return explicit
    }

    private func effectiveIsLittleWinReplacement(for action: LoomAISuggestedAction) -> Bool {
        action.type == "replaceLittleWin" ||
            (action.payload["replaceActivity"] ?? action.payload["oldActivity"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private func effectiveLittleWinReplacementName(for action: LoomAISuggestedAction) -> String {
        let explicit = (action.payload["replaceActivity"] ?? action.payload["oldActivity"] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return explicit
    }

    private func resolvedSuggestedActionCategoryID(for action: LoomAISuggestedAction) -> UUID? {
        if let raw = action.payload["categoryID"] ?? action.payload["categoryId"], let id = UUID(uuidString: raw) {
            return id
        }
        if let name = action.payload["categoryName"]?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return fulfillments.first(where: { $0.category.caseInsensitiveCompare(name) == .orderedSame })?.category_id
        }
        return nil
    }

    private func resolvedSuggestedActionCategoryName(for action: LoomAISuggestedAction) -> String? {
        if let name = action.payload["categoryName"]?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name
        }
        if let id = resolvedSuggestedActionCategoryID(for: action) {
            return fulfillments.first(where: { $0.category_id == id })?.category
        }
        return nil
    }

    private func existingIdentityRows(for action: LoomAISuggestedAction) -> [FulfillmentRoles] {
        guard let categoryID = resolvedSuggestedActionCategoryID(for: action) else { return [] }
        return fulfillmentRoles
            .filter { $0.category_id == categoryID }
            .sorted { lhs, rhs in
                if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
                return lhs.updatedAt < rhs.updatedAt
            }
    }

    private func existingLittleWinRows(for action: LoomAISuggestedAction) -> [FulfillmentFocus] {
        guard let categoryID = resolvedSuggestedActionCategoryID(for: action) else { return [] }
        return fulfillmentFocusRows
            .filter { $0.category_id == categoryID }
            .sorted { lhs, rhs in
                if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
                return lhs.updatedAt < rhs.updatedAt
            }
    }

    private func oldestIdentityNameToRotate(for action: LoomAISuggestedAction) -> String? {
        let incoming = LoomAIChatProvider.canonicalInsertedValue(
            actionType: action.type,
            payload: action.payload,
            fallbackTitle: action.title
        )
        return existingIdentityRows(for: action)
            .first(where: { $0.role.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(incoming) != .orderedSame })?
            .role
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func oldestLittleWinNameToRotate(for action: LoomAISuggestedAction) -> String? {
        let incoming = normalizedSuggestedLittleWinText(
            LoomAIChatProvider.canonicalInsertedValue(
                actionType: action.type,
                payload: action.payload,
                fallbackTitle: action.title
            )
        )
        return existingLittleWinRows(for: action)
            .first(where: { normalizedSuggestedLittleWinText($0.activity) != incoming })?
            .activity
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func suggestedActionPrimaryColor(isApplied: Bool) -> Color {
        guard isApplied else { return .white }
        return colorScheme == .dark ? Color.white.opacity(0.92) : Color.black.opacity(0.82)
    }

    private func suggestedActionSecondaryColor(isApplied: Bool) -> Color {
        guard isApplied else { return Color.white.opacity(0.86) }
        return colorScheme == .dark ? Color.white.opacity(0.74) : Color.black.opacity(0.62)
    }

    private func suggestedActionBackgroundFill(isApplied: Bool) -> AnyShapeStyle {
        if isApplied {
            if colorScheme == .dark {
                return AnyShapeStyle(LoomAISharedGradient.actionFill.opacity(0.34))
            } else {
                return AnyShapeStyle(Color(red: 0.90, green: 0.97, blue: 0.92))
            }
        }
        return AnyShapeStyle(LoomAISharedGradient.actionFill.opacity(0.92))
    }

    private func suggestedActionBorderColor(isApplied: Bool) -> Color {
        if isApplied {
            return colorScheme == .dark ? Color.white.opacity(0.18) : Color.green.opacity(0.30)
        }
        return Color.white.opacity(0.24)
    }

    private var composer: some View {
        let composerControlHeight: CGFloat = 48

        return HStack(alignment: .bottom, spacing: 8) {
            TextField("Ask Loom…", text: $viewModel.draft, axis: .vertical)
                .lineLimit(1...4)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled(false)
                .textFieldStyle(.plain)
                .focused($isInputFocused)
                .onSubmit {
                    guard !viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                          !viewModel.isSending,
                          !viewModel.isDailyLimitReached else { return }
                    startSendingCurrentMessage()
                }
                .padding(12)
                .frame(minHeight: composerControlHeight, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    LoomAIAnimatedOutlineBorder(cornerRadius: 12)
                )
                .overlay {
                    if !hasActiveSubscriptionAccess {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.clear)
                            .contentShape(RoundedRectangle(cornerRadius: 12))
                            .onTapGesture {
                                SubscriptionAccessGate.presentInactiveSubscriptionPaywall()
                            }
                    }
                }

            Button {
                if shouldShowSendingControl {
                    cancelCurrentMessageRequest()
                } else {
                    startSendingCurrentMessage()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            shouldShowSendingControl
                            ? Color(.darkGray)
                            : (
                                viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Color(.tertiarySystemFill)
                            : Color.blue
                            )
                        )
                    Image(systemName: shouldShowSendingControl ? "stop.fill" : "arrow.up")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(
                            (!shouldShowSendingControl && (viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isDailyLimitReached))
                            ? Color.secondary
                            : Color.white
                        )
                }
                .frame(width: composerControlHeight, height: composerControlHeight)
            }
            .buttonStyle(.plain)
            .frame(width: composerControlHeight, height: composerControlHeight, alignment: .bottom)
            .disabled((!shouldShowSendingControl && viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) || (!shouldShowSendingControl && viewModel.isDailyLimitReached))
        }
        .frame(minHeight: 56)
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func scheduleAutoFocusInput() {
        guard supportsCustomChat else {
            inputAutoFocusTask?.cancel()
            inputAutoFocusTask = nil
            isInputFocused = false
            dismissKeyboard()
            return
        }
        inputAutoFocusTask?.cancel()
        inputAutoFocusTask = Task { @MainActor in
            guard isActivePage else { return }
            isInputFocused = true
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled, isActivePage else { return }
            if !isInputFocused {
                isInputFocused = true
            }
        }
    }

    private func sendPrompt(_ prompt: String, displayedAs: String? = nil) {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayTrimmed = (displayedAs ?? prompt).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !displayTrimmed.isEmpty,
              !viewModel.isSending,
              !viewModel.isDailyLimitReached else { return }
        guard hasActiveSubscriptionAccess else {
            SubscriptionAccessGate.presentInactiveSubscriptionPaywall()
            return
        }
        viewModel.draft = displayTrimmed
        startSendingCurrentMessage(
            displayedUserMessage: displayTrimmed,
            transportMessageOverride: trimmed,
            artificialResponseDelayNanoseconds: randomChipResponseDelayNanoseconds()
        )
    }

    private func startSendingCurrentMessage(
        displayedUserMessage: String? = nil,
        transportMessageOverride: String? = nil,
        artificialResponseDelayNanoseconds: UInt64 = 0
    ) {
        guard !viewModel.isSending else { return }
        guard hasActiveSubscriptionAccess else {
            SubscriptionAccessGate.presentInactiveSubscriptionPaywall()
            return
        }
        suppressPendingLoadingUI = false
        sendCurrentMessageTask?.cancel()
        sendCurrentMessageTask = Task { @MainActor in
            await viewModel.sendCurrentMessage(
                in: modelContext,
                threadKey: activeThreadKey,
                displayedUserMessage: displayedUserMessage,
                transportMessageOverride: transportMessageOverride,
                artificialResponseDelayNanoseconds: artificialResponseDelayNanoseconds
            )
            sendCurrentMessageTask = nil
        }
    }

    private func randomChipResponseDelayNanoseconds() -> UInt64 {
        UInt64.random(in: 1_000_000_000 ... 3_000_000_000)
    }

    private func cancelCurrentMessageRequest() {
        guard sendCurrentMessageTask != nil || viewModel.isSending else { return }
        suppressPendingLoadingUI = true
        sendCurrentMessageTask?.cancel()
        sendCurrentMessageTask = nil
        deepThinkingDelayTask?.cancel()
        deepThinkingDelayTask = nil
        withAnimation(.easeOut(duration: 0.18)) {
            showDeepThinkingOverlay = false
        }
        viewModel.logCancelledResponse(in: modelContext, threadKey: activeThreadKey)
        showCancelledNoticeTemporarily()
    }

    private func createNewChatFromPullDown() {
        if sendCurrentMessageTask != nil || viewModel.isSending {
            suppressPendingLoadingUI = true
            showCancelledNoticeTemporarily()
        }
        sendCurrentMessageTask?.cancel()
        sendCurrentMessageTask = nil
        let thread = LoomAIChatThread(
            threadKey: UUID().uuidString,
            title: "New Chat",
            createdAt: .now,
            updatedAt: .now
        )
        modelContext.insert(thread)
        try? modelContext.save()
        LoomAIChatThreadSelectionStore.setCurrentThreadKey(thread.threadKey)
    }

    private func showCancelledNoticeTemporarily() {
        viewModel.errorMessage = nil
        viewModel.debugFailureDetail = nil
        cancelledNoticeWorkItem?.cancel()
        let token = UUID()
        cancelledNoticeToken = token
        cancelledNoticeOpacity = 1
        showCancelledNotice = true
        let workItem = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.25)) {
                cancelledNoticeOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                guard cancelledNoticeToken == token else { return }
                showCancelledNotice = false
                cancelledNoticeOpacity = 1
                cancelledNoticeWorkItem = nil
            }
        }
        cancelledNoticeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: workItem)
    }

    private func updateDeepThinkingState() {
        if viewModel.isSending && !suppressPendingLoadingUI {
            scheduleDeepThinkingOverlay()
        } else {
            deepThinkingDelayTask?.cancel()
            deepThinkingDelayTask = nil
            withAnimation(.easeOut(duration: 0.18)) {
                showDeepThinkingOverlay = false
            }
        }
    }

    private func scheduleDeepThinkingOverlay() {
        guard !suppressPendingLoadingUI else {
            deepThinkingDelayTask?.cancel()
            deepThinkingDelayTask = nil
            showDeepThinkingOverlay = false
            return
        }
        deepThinkingDelayTask?.cancel()
        showDeepThinkingOverlay = false

        deepThinkingDelayTask = Task { @MainActor in
            let delayNanoseconds: UInt64 = viewModel.activeChatProviderKind == .appleIntelligence
                ? 2_000_000_000
                : 3_000_000_000
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard !Task.isCancelled, viewModel.isSending, !suppressPendingLoadingUI else { return }
            deepThinkingTrace = makeDeepThinkingTrace()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                showDeepThinkingOverlay = true
            }
        }
    }

    private func makeDeepThinkingTrace() -> [LoomAIDeepSearchTraceStep] {
        if !viewModel.pendingDeepSearchTrace.isEmpty {
            return viewModel.pendingDeepSearchTrace
        }

        var steps: [LoomAIDeepSearchTraceStep] = []
        func appendStep(title: String, preview: String, sourceKind: String) {
            let cleaned = preview.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { return }
            steps.append(
                .init(
                    title: title,
                    preview: String(cleaned.prefix(180)),
                    sourceKind: sourceKind,
                    order: steps.count
                )
            )
        }

        if let personalization = PersonalizationStore.cachedContextForCurrentUser()?.current {
            let areas = personalization.lifeAreasSelected.prefix(2).joined(separator: ", ")
            appendStep(title: "Stress source", preview: personalization.stressSource, sourceKind: "diagnostic")
            if !areas.isEmpty {
                appendStep(title: "Selected life areas", preview: areas, sourceKind: "areas")
            }
            appendStep(title: "Planning reality", preview: personalization.planningReality, sourceKind: "diagnostic")
        }

        if let diagnostics = diagnosticsSnapshots.first {
            let rootCause = diagnostics.rootCauseText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !rootCause.isEmpty {
                appendStep(title: "Root cause", preview: rootCause, sourceKind: "diagnostic")
            }
            let nextDirection = diagnostics.nextDirectionText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !nextDirection.isEmpty {
                appendStep(title: "Next direction", preview: nextDirection, sourceKind: "diagnostic")
            }
        }

        if let goal = outcomes.first {
            let goalTitle = goal.outcome.trimmingCharacters(in: .whitespacesAndNewlines)
            if !goalTitle.isEmpty {
                appendStep(title: "Goal", preview: goalTitle, sourceKind: "goal")
            }
            let goalReason = goal.reasons.trimmingCharacters(in: .whitespacesAndNewlines)
            if !goalReason.isEmpty {
                appendStep(title: "Goal reason", preview: goalReason, sourceKind: "goal")
            }
        }

        let areaNames = fulfillments
            .map { $0.category.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !areaNames.isEmpty {
            appendStep(title: "Fulfillment areas", preview: areaNames.prefix(3).joined(separator: ", "), sourceKind: "fulfillment")
            appendStep(title: "Fulfillment graph", preview: "\(areaNames.count) areas, \(fulfillmentFocusRows.count) little wins, \(outcomes.count) goals", sourceKind: "fulfillment")
        }

        let identities = fulfillmentRoles
            .sorted { $0.rank < $1.rank }
            .map { $0.role.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if let identity = identities.first {
            appendStep(title: "Identity", preview: identity, sourceKind: "identity")
        }

        let littleWins = fulfillmentFocusRows
            .sorted { $0.rank < $1.rank }
            .map { $0.activity.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if let littleWin = littleWins.first {
            appendStep(title: "Little Win", preview: littleWin, sourceKind: "little_win")
        }

        if let vision = drivingForces.first?.ultimateVision.trimmingCharacters(in: .whitespacesAndNewlines),
           !vision.isEmpty {
            appendStep(title: "Vision", preview: vision, sourceKind: "vision")
        }

        let passionTitles = passions
            .map { $0.passion.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !passionTitles.isEmpty {
            appendStep(title: "Passions", preview: passionTitles.prefix(2).joined(separator: ", "), sourceKind: "passions")
        }

        let capture = captureItems
            .filter { !$0.isGhost }
            .sorted { $0.createdAt > $1.createdAt }
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !capture.isEmpty {
            appendStep(title: "Capture list", preview: capture.prefix(2).joined(separator: " • "), sourceKind: "capture")
        }

        let currentWeek = WeeklyMindsetEntry.weekStart(for: .now)
        let chunkIDs = Set(plannedChunks.filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeek) }.map(\.id))
        let currentActions = plannedChunkActions
            .filter { chunkIDs.contains($0.plannedChunkId) }
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !currentActions.isEmpty {
            appendStep(title: "Action plan", preview: currentActions.prefix(2).joined(separator: " • "), sourceKind: "week")
        }
        if steps.isEmpty {
            return [
                .init(title: "Searching Loom context", preview: "Reading your current Loom context and recent activity", sourceKind: "fallback", order: 0)
            ]
        }
        return Array(steps.prefix(6))
    }

    private func updateKeyboardHeight(_ note: Notification) {
        guard let userInfo = note.userInfo else { return }
        let endFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect) ?? .zero
        let duration = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
        let curveRaw = (userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt) ?? 7
        let screenHeight = UIScreen.main.bounds.height
        let overlap = max(0, screenHeight - endFrame.minY)
        let bottomInset = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .safeAreaInsets.bottom ?? 0
        let target = max(0, overlap - bottomInset)

        let animation = Animation.timingCurve(
            curveRaw == 7 ? 0.25 : 0.25,
            0.1,
            0.25,
            1.0,
            duration: duration
        )
        withAnimation(animation) {
            keyboardHeight = target
        }
    }
}

#Preview {
    NavigationStack {
        LoomAIChatView()
    }
    .loomPreviewContainer()
}

private struct LoomTypingDotsIndicator: View {
    @State private var activeIndex: Int = 0

    private let colors: [Color] = [
        Color(red: 0.22, green: 0.47, blue: 1.0),
        Color(red: 0.15, green: 0.83, blue: 0.95),
        Color(red: 0.62, green: 0.40, blue: 0.95)
    ]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(Array(colors.enumerated()), id: \.offset) { idx, color in
                Circle()
                    .fill(color.opacity(activeIndex == idx ? 1 : 0.35))
                    .frame(width: 6, height: 6)
                    .scaleEffect(activeIndex == idx ? 1.15 : 0.9)
                    .animation(.easeInOut(duration: 0.2), value: activeIndex)
            }
        }
        .onAppear {
            guard activeIndex == 0 else { return }
            animate()
        }
    }

    private func animate() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            activeIndex = (activeIndex + 1) % colors.count
            animate()
        }
    }
}

private struct LoomAIDeepStateScanningCard: View {
    struct SourceLine: Identifiable {
        let id = UUID()
        let title: String
        let preview: String
    }

    let steps: [LoomAIDeepSearchTraceStep]

    @State private var activeIndex = 0
    @State private var cycleTask: Task<Void, Never>? = nil
    @State private var previewOffset: CGFloat = 0
    @State private var previewContentHeight: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0
    private let baseTextAreaMinHeight: CGFloat = 96
    private let cardHeightScale: CGFloat = 0.82

    private var textAreaMinHeight: CGFloat {
        baseTextAreaMinHeight * cardHeightScale
    }

    private var cardWidth: CGFloat {
        UIScreen.main.bounds.width * 0.75
    }

    private var sources: [SourceLine] {
        let parsed = steps.map { step in
            SourceLine(
                title: step.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Reading Loom Context" : step.title,
                preview: step.preview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Reading your current Loom context..." : step.preview
            )
        }
        if parsed.isEmpty {
            return [SourceLine(title: "Reading Loom Context", preview: "Reading your current Loom context...")]
        }
        return parsed
    }

    private var currentSource: SourceLine {
        sources[min(max(activeIndex, 0), max(0, sources.count - 1))]
    }

    private var previewTextWidth: CGFloat {
        cardWidth - 24
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image("LoomAI")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 12, height: 12)
                    .foregroundStyle(Color.white.opacity(0.92))
                Text("Deep Search")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.90))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }

            Text(currentSource.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.72))
                .lineLimit(1)

            GeometryReader { geometry in
                scrollingTextLayer
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipped()
                .onAppear {
                    viewportHeight = geometry.size.height
                }
                .onChange(of: geometry.size.height) { _, newValue in
                    viewportHeight = newValue
                }
                .onPreferenceChange(LoomAIDeepPreviewHeightPreferenceKey.self) { height in
                    previewContentHeight = height
                }
            }
            .frame(maxWidth: .infinity, minHeight: textAreaMinHeight, maxHeight: textAreaMinHeight, alignment: .topLeading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: cardWidth, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.black.opacity(0.42))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.20), lineWidth: 0.8)
                )
        )
        .shadow(color: Color.black.opacity(0.24), radius: 14, y: 8)
        .onAppear { startCycling() }
        .onDisappear {
            cycleTask?.cancel()
            cycleTask = nil
        }
        .onChange(of: sources.count) { _, _ in
            activeIndex = min(activeIndex, max(0, sources.count - 1))
            startCycling()
        }
    }

    private var scrollingTextLayer: some View {
        Text(currentSource.preview)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.white.opacity(0.96))
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: previewTextWidth, alignment: .leading)
            .offset(y: previewOffset)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: LoomAIDeepPreviewHeightPreferenceKey.self,
                        value: proxy.size.height
                    )
                }
            )
    }

    private func startCycling() {
        cycleTask?.cancel()
        activeIndex = min(activeIndex, max(0, sources.count - 1))
        previewOffset = 0
        guard !sources.isEmpty else { return }
        cycleTask = Task { @MainActor in
            while !Task.isCancelled {
                previewOffset = 0
                try? await Task.sleep(nanoseconds: 180_000_000)
                guard !Task.isCancelled else { break }

                let preview = currentSource.preview
                let characterCount = max(preview.count, 1)
                let overflow = max(0, previewContentHeight - max(viewportHeight, textAreaMinHeight))
                if overflow > 10 {
                    let panDuration = min(8.8, max(2.8, Double(overflow) / 18.0))
                    withAnimation(.linear(duration: panDuration)) {
                        previewOffset = -overflow
                    }
                    try? await Task.sleep(nanoseconds: UInt64(panDuration * 1_000_000_000))
                    guard !Task.isCancelled else { break }
                    try? await Task.sleep(nanoseconds: 320_000_000)
                } else {
                    let dwellSeconds = min(2.8, 1.1 + (Double(characterCount) * 0.004))
                    try? await Task.sleep(nanoseconds: UInt64(dwellSeconds * 1_000_000_000))
                }
                guard !Task.isCancelled else { break }

                try? await Task.sleep(nanoseconds: 140_000_000)
                guard !Task.isCancelled else { break }

                if sources.count > 1 {
                    activeIndex = (activeIndex + 1) % sources.count
                }
            }
        }
    }
}

private struct LoomAIDeepPreviewHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct LoomAIInlineReference: Hashable {
    let kind: String
    let displayText: String
    let categoryName: String?
}

private struct LoomAIAnimatedOutlineBorder: View {
    let cornerRadius: CGFloat
    @State private var outlineAngle: Double = 0

    private var outlineGradient: AngularGradient {
        AngularGradient(
            colors: LoomAISharedGradient.colors,
            center: .center,
            angle: .degrees(outlineAngle)
        )
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .stroke(outlineGradient.opacity(0.95), lineWidth: 2)
            .onAppear {
                guard outlineAngle == 0 else { return }
                withAnimation(.linear(duration: 7).repeatForever(autoreverses: false)) {
                    outlineAngle = 360
                }
            }
    }
}

private enum LoomAISharedGradient {
    static let colors: [Color] = [
        Color(red: 0.22, green: 0.47, blue: 1.0),
        Color(red: 0.15, green: 0.83, blue: 0.95),
        Color(red: 0.62, green: 0.40, blue: 0.95),
        Color(red: 0.80, green: 0.38, blue: 0.78),
        Color(red: 0.98, green: 0.36, blue: 0.58),
        Color(red: 0.75, green: 0.42, blue: 0.74),
        Color(red: 0.22, green: 0.47, blue: 1.0)
    ]

    static let actionFill = LinearGradient(
        colors: [
            colors[0],
            colors[2],
            colors[4]
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

private struct FlexibleButtonWrap<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            let rows = chunked(items, size: 2)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 6) {
                    ForEach(row) { item in
                        content(item)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func chunked(_ items: [Item], size: Int) -> [[Item]] {
        guard size > 0 else { return [items] }
        var result: [[Item]] = []
        var index = 0
        while index < items.count {
            result.append(Array(items[index..<min(index + size, items.count)]))
            index += size
        }
        return result
    }
}

private struct LoomAIInlineLimitNotice: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.badge.clock")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.black.opacity(0.75))
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.black.opacity(0.78))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(red: 0.98, green: 0.92, blue: 0.72))
        )
    }
}

private struct LoomAICancelNotice: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.88))
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.92))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.gray.opacity(0.8))
        )
    }
}

private struct LoomAITokenizedMessageView: View {
    private enum Segment: Hashable {
        case text(String)
        case token(kind: String, value: String)
    }

    let content: String
    let highlightReferences: [LoomAIInlineReference]

    private var lines: [[Segment]] {
        let normalized = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        return normalized
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { autoHighlightedSegments(parseSegments(in: String($0))) }
    }

    var body: some View {
        Text(attributedContent)
            .font(.subheadline)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var attributedContent: AttributedString {
        var output = AttributedString()
        for (index, line) in lines.enumerated() {
            output.append(attributedString(from: line))
            if index < lines.count - 1 {
                output.append(AttributedString("\n"))
            }
        }
        return output
    }

    private func attributedString(from segments: [Segment]) -> AttributedString {
        var output = AttributedString()
        for segment in segments {
            switch segment {
            case .text(let value):
                output.append(styledInlineText(value))
            case .token(let kind, let value):
                output.append(styledToken(kind: kind, value: value))
            }
        }
        return output
    }

    private func styledInlineText(_ value: String) -> AttributedString {
        var attributed = AttributedString(value)
        attributed.font = .subheadline
        attributed.foregroundColor = .primary
        return attributed
    }

    private func styledToken(kind: String, value: String) -> AttributedString {
        switch kind {
        case "P":
            if isPassionReferenceToken(value) {
                return highlightedText(
                    value,
                    font: .subheadline.weight(.semibold),
                    foreground: passionTokenForegroundColor,
                    background: passionTokenBackgroundColor
                )
            }
            return highlightedText(
                "\"\(value)\"",
                font: .subheadline.weight(.semibold),
                foreground: .primary,
                background: Color(.tertiarySystemFill)
            )
        case "C":
            let payload = inlineCategoryTokenPayload(from: value)
            let base = fixedColor(FulfillmentCategoryTheme.color(for: payload.category))
            return highlightedText(
                payload.display,
                font: .subheadline.weight(.semibold),
                foreground: base,
                background: lightened(base, amount: 0.87)
            )
        case "G":
            let payload = inlineCategoryTokenPayload(from: value)
            let base = fixedColor(FulfillmentCategoryTheme.color(for: payload.category))
            return highlightedText(
                payload.display,
                font: .subheadline.weight(.semibold),
                foreground: base,
                background: lightened(base, amount: 0.87)
            )
        case "R":
            let payload = inlineCategoryTokenPayload(from: value)
            let base = fixedColor(FulfillmentCategoryTheme.color(for: payload.category))
            return highlightedText(
                payload.display,
                font: .subheadline.italic(),
                foreground: base,
                background: lightened(base, amount: 0.90)
            )
        case "S":
            return highlightedText(
                value,
                font: .subheadline.weight(.bold),
                foreground: Color.black.opacity(0.88),
                background: Color(red: 0.94, green: 0.94, blue: 0.95)
            )
        case "I":
            let payload = inlineCategoryTokenPayload(from: value)
            let base = fixedColor(FulfillmentCategoryTheme.color(for: payload.category))
            return highlightedText(
                payload.display,
                font: .subheadline.weight(.semibold),
                foreground: base,
                background: lightened(base, amount: 0.87)
            )
        case "M":
            let payload = inlineCategoryTokenPayload(from: value)
            let base = fixedColor(FulfillmentCategoryTheme.color(for: payload.category))
            return highlightedText(
                payload.display,
                font: .subheadline.italic(),
                foreground: base,
                background: lightened(base, amount: 0.90)
            )
        case "F":
            let base = fixedColor(FulfillmentCategoryTheme.color(for: value))
            return highlightedText(
                value,
                font: .subheadline.weight(.semibold),
                foreground: base,
                background: lightened(base, amount: 0.87)
            )
        case "O":
            return highlightedText(
                value,
                font: .subheadline.weight(.semibold),
                foreground: outcomeTokenForegroundColor,
                background: outcomeTokenBackgroundColor
            )
        case "A":
            return highlightedText(
                value,
                font: .subheadline.weight(.semibold),
                foreground: .primary.opacity(0.88),
                background: Color.primary.opacity(0.10)
            )
        case "N":
            return highlightedText(
                value,
                font: .subheadline.weight(.semibold),
                foreground: .primary.opacity(0.88),
                background: Color(.secondarySystemFill)
            )
        case "V":
            return highlightedText(
                value,
                font: .subheadline.italic(),
                foreground: .primary.opacity(0.90),
                background: Color(.secondarySystemFill)
            )
        default:
            return styledInlineText(value)
        }
    }

    private func highlightedText(
        _ value: String,
        font: Font,
        foreground: Color,
        background: Color
    ) -> AttributedString {
        var attributed = AttributedString(value)
        attributed.font = font
        attributed.foregroundColor = foreground
        attributed.backgroundColor = background
        return attributed
    }

    private func inlineCategoryTokenPayload(from raw: String) -> (display: String, category: String) {
        let components = raw.components(separatedBy: "||")
        if components.count >= 2 {
            let display = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let category = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
            if !display.isEmpty, !category.isEmpty {
                return (display, category)
            }
        }
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return (cleaned, cleaned)
    }

    private var outcomeTokenForegroundColor: Color {
        Color(red: 0.16, green: 0.28, blue: 0.53)
    }

    private var outcomeTokenBackgroundColor: Color {
        Color(red: 0.87, green: 0.92, blue: 0.99)
    }

    private var passionTokenForegroundColor: Color {
        Color(red: 0.26, green: 0.26, blue: 0.28)
    }

    private var passionTokenBackgroundColor: Color {
        Color(red: 0.92, green: 0.92, blue: 0.93)
    }
    private func isPassionReferenceToken(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return false }

        let passionAreas = ["love", "vows", "thrill", "hate", "just"]
        if passionAreas.contains(trimmed) { return true }
        if let first = trimmed.split(separator: ":", maxSplits: 1).first {
            if passionAreas.contains(String(first).trimmingCharacters(in: .whitespacesAndNewlines)) {
                return true
            }
        }
        if trimmed.hasPrefix("love ") || trimmed.hasPrefix("vows ") || trimmed.hasPrefix("thrill ") || trimmed.hasPrefix("hate ") || trimmed.hasPrefix("just ") {
            return true
        }
        return false
    }

    private func fixedColor(_ color: Color) -> Color {
        #if canImport(UIKit)
        let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return color }
        return Color(
            red: Double(red),
            green: Double(green),
            blue: Double(blue),
            opacity: Double(alpha)
        )
        #else
        return color
        #endif
    }

    private func lightened(_ color: Color, amount: CGFloat) -> Color {
        #if canImport(UIKit)
        let ui = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard ui.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return color }
        let clamped = max(0, min(amount, 1))
        return Color(
            red: Double(red + (1 - red) * clamped),
            green: Double(green + (1 - green) * clamped),
            blue: Double(blue + (1 - blue) * clamped),
            opacity: Double(alpha)
        )
        #else
        return color
        #endif
    }

    private func parseSegments(in line: String) -> [Segment] {
        let pattern = #"\[\[([A-Z]):([^\]]+)\]\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [.text(line)] }
        let source = line as NSString
        let range = NSRange(location: 0, length: source.length)
        let matches = regex.matches(in: line, options: [], range: range)
        guard !matches.isEmpty else { return [.text(line)] }

        var segments: [Segment] = []
        var cursor = 0
        for match in matches {
            if match.range.location > cursor {
                let textRange = NSRange(location: cursor, length: match.range.location - cursor)
                let text = source.substring(with: textRange)
                if !text.isEmpty {
                    segments.append(.text(text))
                }
            }
            let kind = source.substring(with: match.range(at: 1))
            let value = source.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                segments.append(.token(kind: kind, value: value))
            }
            cursor = match.range.location + match.range.length
        }
        if cursor < source.length {
            segments.append(.text(source.substring(from: cursor)))
        }
        return segments
    }

    private func autoHighlightedSegments(_ segments: [Segment]) -> [Segment] {
        guard !highlightReferences.isEmpty else { return segments }
        return segments.flatMap { segment in
            switch segment {
            case .text(let value):
                return highlightedPlainTextSegments(in: value)
            case .token:
                return [segment]
            }
        }
    }

    private func highlightedPlainTextSegments(in text: String) -> [Segment] {
        guard !text.isEmpty else { return [.text(text)] }

        var output: [Segment] = []
        var cursor = text.startIndex

        while cursor < text.endIndex {
            var bestMatch: (range: Range<String.Index>, reference: LoomAIInlineReference)?

            for reference in highlightReferences {
                guard let found = rangeOfReference(reference, in: text, from: cursor) else { continue }
                if let existing = bestMatch {
                    if found.lowerBound < existing.range.lowerBound {
                        bestMatch = (found, reference)
                    }
                } else {
                    bestMatch = (found, reference)
                }
            }

            guard let match = bestMatch else {
                output.append(.text(String(text[cursor...])))
                break
            }

            if match.range.lowerBound > cursor {
                output.append(.text(String(text[cursor..<match.range.lowerBound])))
            }

            let matchedText = String(text[match.range])
            let tokenValue: String = {
                switch match.reference.kind {
                case "C", "G", "I", "M", "R":
                    let category = match.reference.categoryName ?? matchedText
                    return "\(matchedText)||\(category)"
                default:
                    return matchedText
                }
            }()
            output.append(.token(kind: match.reference.kind, value: tokenValue))
            cursor = match.range.upperBound
        }

        return output
    }

    private func rangeOfReference(
        _ reference: LoomAIInlineReference,
        in text: String,
        from start: String.Index
    ) -> Range<String.Index>? {
        let needle = reference.displayText
        guard !needle.isEmpty, start < text.endIndex || start == text.startIndex else { return nil }

        var searchRange = start..<text.endIndex
        while let found = text.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive], range: searchRange) {
            if isReferenceBoundary(found, in: text) {
                return found
            }
            searchRange = found.upperBound..<text.endIndex
        }

        let tokens = needle
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return nil }

        let escaped = tokens.map(NSRegularExpression.escapedPattern(for:)).joined(separator: #"[^\p{L}\p{N}]+"#)
        let pattern = #"\b\#(escaped)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let nsRange = NSRange(searchRange, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: nsRange),
              let range = Range(match.range, in: text),
              isReferenceBoundary(range, in: text) else {
            return nil
        }
        return range
    }

    private func isReferenceBoundary(_ range: Range<String.Index>, in text: String) -> Bool {
        func isWordish(_ scalar: UnicodeScalar) -> Bool {
            CharacterSet.alphanumerics.contains(scalar) || scalar == "_"
        }

        if range.lowerBound > text.startIndex {
            let previous = text[text.index(before: range.lowerBound)]
            if previous.unicodeScalars.contains(where: isWordish) {
                return false
            }
        }

        if range.upperBound < text.endIndex {
            let next = text[range.upperBound]
            if next.unicodeScalars.contains(where: isWordish) {
                return false
            }
        }

        return true
    }
}
