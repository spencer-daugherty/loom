import SwiftUI
import SwiftData
import UIKit

struct LoomAIChatView: View {
    var isActivePage: Bool = false
    private let bottomScrollAnchorID = "loom_chat_bottom_anchor"

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \LoomAIChatMessage.createdAt, order: .forward) private var allMessages: [LoomAIChatMessage]
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
    @State private var formattedAssistantByMessageID: [UUID: AttributedString] = [:]
    @State private var appliedSuggestedActionIDs: Set<String> = []
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
    @State private var showDeepThinkingOverlay = false
    @State private var deepThinkingLines: [String] = []
    @FocusState private var isInputFocused: Bool
    private let keyboardTopGap: CGFloat = 12
    private let bestUseLoomChipTitle = "How can I best use Loom?"
    private let bestUseLoomPrompt = "Based on everything Loom knows about me - my purpose vision, passions, fulfillment areas, goals, personality profile, current activity-explain the single most effective way for me to use Loom right now to reduce stress and live fulfilled."
    private let requestTimedOutMessage = "The request timed out."

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

    var body: some View {
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
                                    groundingSectionView(items: LoomAIChatMessageGroundingCodec.decode(message.groundingJSON))
                                    suggestionCardsSectionView(
                                        cards: LoomAIChatMessageSuggestionCardsCodec.decode(message.suggestionCardsJSON),
                                        fallbackActions: LoomAIChatMessageActionsCodec.decode(message.actionsJSON),
                                        nextAction: LoomAIChatMessageNextActionCodec.decode(message.nextActionJSON)
                                    )
                                }
                            }
                            .id(message.id)
                        }

                        if viewModel.isSending || showDeepThinkingOverlay {
                            VStack(spacing: 8) {
                                if viewModel.isSending && !showDeepThinkingOverlay {
                                    HStack(spacing: 8) {
                                        LoomTypingDotsIndicator()
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                if showDeepThinkingOverlay {
                                    LoomAIDeepStateScanningCard(lines: deepThinkingLines)
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
                    appliedSuggestedActionIDs = []
                    chipCategoryOverrides = [:]
                    guard isActivePage else {
                        needsRefreshWhenActive = true
                        return
                    }
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(bottomScrollAnchorID, anchor: .bottom)
                    }
                    viewModel.refreshLatestActions(from: messages)
                    viewModel.refreshSuggestedPromptChips(in: modelContext, threadMessages: messages)
                    Task { await viewModel.refreshFollowUpPromptChipsIfNeeded(in: modelContext, threadMessages: messages) }
                }
                .onChange(of: allMessages.count) { _, _ in
                    refreshThreadMessageCache()
                    if !isActivePage {
                        needsRefreshWhenActive = true
                    }
                }
                .onChange(of: viewModel.isSending) { _, _ in
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
                    viewModel.refreshLatestActions(from: messages)
                    viewModel.refreshSuggestedPromptChips(in: modelContext, threadMessages: messages)
                    Task { await viewModel.refreshFollowUpPromptChipsIfNeeded(in: modelContext, threadMessages: messages) }
                    DispatchQueue.main.async {
                        proxy.scrollTo(bottomScrollAnchorID, anchor: .bottom)
                    }
                }
                .onChange(of: isActivePage) { _, isActive in
                    guard isActive else { return }
                    viewModel.refreshRemainingDailyResponses()
                    if needsRefreshWhenActive {
                        viewModel.refreshLatestActions(from: messages)
                        viewModel.refreshSuggestedPromptChips(in: modelContext, threadMessages: messages)
                        Task { await viewModel.refreshFollowUpPromptChipsIfNeeded(in: modelContext, threadMessages: messages) }
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
                    if loomAITroubleshootingEnabled {
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
                composer
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, max(8, keyboardHeight > 0 ? keyboardHeight + keyboardTopGap : 8))
            .background(
                Rectangle()
                    .fill(Color(.systemGroupedBackground))
                    .ignoresSafeArea(edges: .bottom)
            )
        }
        .alert("Loom", isPresented: $showActionExecutionAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(actionExecutionAlertText)
        }
        .onAppear {
            guard isActivePage else { return }
            scheduleAutoFocusInput()
        }
        .onChange(of: isActivePage) { _, isActive in
            if !isActive {
                inputAutoFocusTask?.cancel()
                inputAutoFocusTask = nil
                deepThinkingDelayTask?.cancel()
                deepThinkingDelayTask = nil
                showDeepThinkingOverlay = false
                isInputFocused = false
                dismissKeyboard()
            } else {
                scheduleAutoFocusInput()
                updateDeepThinkingState()
            }
        }
        .onDisappear {
            inputAutoFocusTask?.cancel()
            inputAutoFocusTask = nil
            sendCurrentMessageTask?.cancel()
            sendCurrentMessageTask = nil
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
                viewModel.refreshLatestActions(from: messages)
                viewModel.refreshSuggestedPromptChips(in: modelContext, threadMessages: messages)
                Task { await viewModel.refreshFollowUpPromptChipsIfNeeded(in: modelContext, threadMessages: messages) }
            } else {
                needsRefreshWhenActive = true
            }
            _ = try? viewModel.ensureThread(in: modelContext, threadKey: newKey)
        }
    }

    private func refreshThreadMessageCache() {
        let filtered = allMessages.filter { $0.threadKey == activeThreadKey }
        threadMessages = filtered
        latestAssistantMessageIDCache = filtered.last(where: { $0.roleRaw == LoomAIChatRole.assistant.rawValue })?.id
        let validIDs = Set(filtered.map(\.id))
        formattedAssistantByMessageID = formattedAssistantByMessageID.filter { validIDs.contains($0.key) }
        for message in filtered where message.roleRaw == LoomAIChatRole.assistant.rawValue {
            if formattedAssistantByMessageID[message.id] == nil {
                formattedAssistantByMessageID[message.id] = formattedAssistantAttributedString(message.content)
            }
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
                    .padding(.vertical, 8)
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
                        .padding(.vertical, 8)
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
        if isBestUseLoomChip(originalChip) || isBestUseLoomChip(resolvedTitle) {
            return bestUseLoomPrompt
        }
        guard !messages.isEmpty else { return resolvedTitle }
        let latestAssistant = messages.last(where: { $0.roleRaw == LoomAIChatRole.assistant.rawValue })
        let chips = LoomAIChatMessageChipsCodec.decode(latestAssistant?.chipsJSON)
        if let match = chips.first(where: { $0.title.caseInsensitiveCompare(originalChip) == .orderedSame }) {
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

    private func messageBubble(_ message: LoomAIChatMessage) -> some View {
        let isUser = message.roleRaw == LoomAIChatRole.user.rawValue
        let assistantContent = isUser ? "" : sanitizedAssistantMessageContent(for: message)
        return HStack {
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

                #if DEBUG
                if !isUser {
                    Text(messageTimestampLine(message.createdAt))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
                #endif
            }
            .frame(width: isUser ? nil : assistantBubbleWidth, alignment: .leading)
            .frame(maxWidth: isUser ? userBubbleMaxWidth : assistantBubbleWidth, alignment: isUser ? .trailing : .leading)
            if !isUser { Spacer(minLength: 0) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    @ViewBuilder
    private func messageBubbleText(_ message: LoomAIChatMessage, isUser: Bool, assistantContent: String) -> some View {
        if isUser {
            Text(message.content)
                .font(.subheadline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        } else {
            LoomAITokenizedMessageView(content: assistantContent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
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

    private func formattedAssistantText(for message: LoomAIChatMessage) -> AttributedString {
        if let cached = formattedAssistantByMessageID[message.id] {
            return cached
        }
        return formattedAssistantAttributedString(message.content)
    }

    private func formattedAssistantAttributedString(_ content: String) -> AttributedString {
        let displayContent = normalizedAssistantDisplayText(content)
        var attributed: AttributedString
        if let parsed = try? AttributedString(
            markdown: displayContent,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)
        ) {
            attributed = parsed
        } else {
            attributed = AttributedString(displayContent)
        }

        styleFulfillmentAreaNames(in: &attributed)
        boldScoreNumbers(in: &attributed)
        return attributed
    }

    private func normalizedAssistantDisplayText(_ content: String) -> String {
        var normalized = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let hasInlineNumericSequence =
            normalized.range(of: #"\d+[\)\.]\s+\S+.*\d+[\)\.]\s+\S+"#, options: .regularExpression) != nil

        guard hasInlineNumericSequence else {
            return normalized
        }

        // Break inline numbered sequences onto separate lines.
        normalized = normalized.replacingOccurrences(
            of: #"\s+(\d+[\)\.])\s+"#,
            with: "\n$1 ",
            options: .regularExpression
        )

        // Convert "1)" style markers into markdown-numbered list markers.
        normalized = normalized.replacingOccurrences(
            of: #"(?m)^(\d+)\)\s+"#,
            with: "$1. ",
            options: .regularExpression
        )

        // Add a blank line between intro text and a following numbered list for markdown parsing.
        normalized = normalized.replacingOccurrences(
            of: #":\n(?=\d+\.)"#,
            with: ":\n\n",
            options: .regularExpression
        )

        return normalized
    }

    private func styleFulfillmentAreaNames(in attributed: inout AttributedString) {
        let areaNames = [
            "Career & Business",
            "Leadership & Impact",
            "Wealth & Lifestyle",
            "Mind & Meaning",
            "Love & Relationships",
            "Health & Vitality",
            "Health & Energy"
        ]

        for name in areaNames {
            var searchStart = attributed.startIndex
            while searchStart < attributed.endIndex,
                  let range = attributed[searchStart...].range(of: name) {
                attributed[range].font = .subheadline.bold()
                attributed[range].foregroundColor = FulfillmentCategoryTheme.color(for: name)
                searchStart = range.upperBound
            }
        }
    }

    private func boldScoreNumbers(in attributed: inout AttributedString) {
        let source = String(attributed.characters)
        guard let regex = try? NSRegularExpression(pattern: #"(?<!\d)\d+(?:\.\d+)?(?!\d)"#) else { return }
        let nsRange = NSRange(source.startIndex..<source.endIndex, in: source)
        let matches = regex.matches(in: source, options: [], range: nsRange)

        for match in matches.reversed() {
            guard let stringRange = Range(match.range, in: source),
                  let attrRange = Range(stringRange, in: attributed) else { continue }
            attributed[attrRange].font = .subheadline.bold()
        }
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
        nextAction: LoomAISuggestedAction?
    ) -> some View {
        let cardsActions = suggestionCardActions(from: cards)
        let hasCards = !cards.isEmpty
        let hasFallback = !fallbackActions.isEmpty
        let dedupedFallback = deduplicatedActions(fallbackActions)
        let next = deduplicatedNextAction(nextAction, existing: cardsActions + dedupedFallback)

        if hasCards || hasFallback || next != nil {
            VStack(alignment: .leading, spacing: 8) {
                if hasCards {
                    ForEach(cards) { card in
                        suggestionCardView(card)
                    }
                } else if hasFallback {
                    suggestedActionsView(actions: dedupedFallback)
                }

                if let next {
                    VStack(alignment: .leading, spacing: 6) {
                        suggestedActionButton(next)
                    }
                }
            }
            .padding(.top, 2)
        }
    }

    private func suggestionCardView(_ card: LoomAISuggestionCard) -> some View {
        let cardHeading = card.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return VStack(alignment: .leading, spacing: 6) {
            let options = card.options.map(suggestionOptionToAction)
            ForEach(options) { action in
                suggestedActionButton(action, cardHeading: cardHeading)
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

    @ViewBuilder
    private func suggestedActionsView(actions: [LoomAISuggestedAction]) -> some View {
        if !actions.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(actions) { action in
                        suggestedActionButton(action)
                    }
                }
            }
            .padding(.top, 2)
        }
    }

    private func suggestedActionButton(_ action: LoomAISuggestedAction, cardHeading: String? = nil) -> some View {
        let isApplied = appliedSuggestedActionIDs.contains(action.id) || isSuggestedActionPersistentlyApplied(action)
        return Button {
            guard !isApplied else { return }
            let didApply = viewModel.executeSuggestedAction(action, in: modelContext)
            if let error = viewModel.errorMessage, !error.isEmpty {
                actionExecutionAlertText = error
                showActionExecutionAlert = true
            } else if didApply {
                appliedSuggestedActionIDs.insert(action.id)
            }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                suggestedActionLeadingIcon(for: action, isApplied: isApplied)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 3) {
                    if let heading = cardHeading?.trimmingCharacters(in: .whitespacesAndNewlines), !heading.isEmpty {
                        Text(heading)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(suggestedActionSecondaryColor(isApplied: isApplied))
                            .multilineTextAlignment(.leading)
                    }

                    suggestedActionPrimaryText(for: action, isApplied: isApplied)

                    if let subtitle = suggestedActionSubtitle(for: action), !subtitle.isEmpty {
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
        .disabled(isApplied)
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
                topLine: isApplied
                    ? "Added Identity to \(identityDraft.category):"
                    : "Add Identity to \(identityDraft.category):",
                detail: identityDraft.identity,
                isApplied: isApplied
            )
        } else if action.type == "createLittleWin" || action.type == "addLittleWin" || action.type == "replaceLittleWin" {
            suggestedLittleWinPrimaryText(action: action, isApplied: isApplied)
        } else if action.type == "replaceFulfillmentMission" || action.type == "updateFulfillmentMission" {
            suggestedSimpleTwoLineAction(
                topLine: missionTopLine(for: action, isApplied: isApplied),
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
        let category = (action.payload["categoryName"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let identity = (action.payload["identity"] ?? action.payload["role"] ?? action.payload["text"] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let replaceIdentity = (action.payload["replaceIdentity"] ?? action.payload["oldIdentity"] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let isReplace = action.type == "replaceFulfillmentIdentity"
        let top = isReplace
            ? (category.isEmpty ? "Replace Identity:" : "Replace Identity in \(category):")
            : ""
        let appliedTop = isReplace
            ? top.replacingOccurrences(of: "Replace ", with: "Replaced ", options: [.anchored])
            : ""

        return VStack(alignment: .leading, spacing: 3) {
            if isReplace {
                Text(isApplied ? appliedTop : top)
                    .font(.subheadline.italic())
                    .foregroundStyle(suggestedActionPrimaryColor(isApplied: isApplied).opacity(isApplied ? 0.88 : 0.95))
            }
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
        let passion = (action.payload["passion"] ?? action.payload["title"] ?? action.payload["text"] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
        let activity = (action.payload["activity"] ?? action.payload["text"] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let isReplace = action.type == "replaceLittleWin"
        let replaced = (action.payload["replaceActivity"] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

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
        switch action.type {
        case "createLittleWin", "addLittleWin":
            return nil
        case "replaceLittleWin":
            return nil
        case "replaceFulfillmentMission", "updateFulfillmentMission":
            return missionActionSubtitle(action)
        case "addFulfillmentIdentity":
            return categoryOnlySubtitle(action, fallback: "Adds a new identity role.")
        case "replaceFulfillmentIdentity":
            return categoryOnlySubtitle(action, fallback: "")
        case "replacePurposeVision", "updatePurposeVision":
            return "Updates your Purpose Vision."
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

            Button {
                startSendingCurrentMessage()
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Color(.tertiarySystemFill)
                            : Color.blue
                        )
                    Image(systemName: "arrow.up")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(
                            viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isDailyLimitReached
                            ? Color.secondary
                            : Color.white
                        )
                }
                .frame(width: composerControlHeight, height: composerControlHeight)
            }
            .buttonStyle(.plain)
            .frame(width: composerControlHeight, height: composerControlHeight, alignment: .bottom)
            .disabled(viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending || viewModel.isDailyLimitReached)
        }
        .frame(minHeight: 56)
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func scheduleAutoFocusInput() {
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
        viewModel.draft = displayTrimmed
        startSendingCurrentMessage(
            displayedUserMessage: displayTrimmed,
            transportMessageOverride: trimmed
        )
    }

    private func startSendingCurrentMessage(
        displayedUserMessage: String? = nil,
        transportMessageOverride: String? = nil
    ) {
        guard !viewModel.isSending else { return }
        sendCurrentMessageTask?.cancel()
        sendCurrentMessageTask = Task { @MainActor in
            await viewModel.sendCurrentMessage(
                in: modelContext,
                threadKey: activeThreadKey,
                displayedUserMessage: displayedUserMessage,
                transportMessageOverride: transportMessageOverride
            )
            sendCurrentMessageTask = nil
        }
    }

    private func createNewChatFromPullDown() {
        if sendCurrentMessageTask != nil || viewModel.isSending {
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
        if viewModel.isSending {
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
        deepThinkingDelayTask?.cancel()
        showDeepThinkingOverlay = false

        deepThinkingDelayTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled, viewModel.isSending else { return }
            deepThinkingLines = makeDeepThinkingLines()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                showDeepThinkingOverlay = true
            }
        }
    }

    private func makeDeepThinkingLines() -> [String] {
        var lines: [String] = []

        if let personalization = PersonalizationStore.cachedContextForCurrentUser()?.current {
            let areas = personalization.lifeAreasSelected.prefix(2).joined(separator: ", ")
            lines.append("How Loom See's You (So Far): \(personalization.stressSource)")
            if !areas.isEmpty {
                lines.append("How Loom See's You (So Far): life areas \(areas)")
            }
            lines.append("How Loom See's You (So Far): planning reality \(personalization.planningReality)")
        }

        if let diagnostics = diagnosticsSnapshots.first {
            let rootCause = diagnostics.rootCauseText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !rootCause.isEmpty {
                lines.append("Root Cause: \(rootCause)")
            }
            let nextDirection = diagnostics.nextDirectionText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !nextDirection.isEmpty {
                lines.append("Next Direction: \(nextDirection)")
            }
        }

        if let goal = outcomes.first {
            let goalTitle = goal.outcome.trimmingCharacters(in: .whitespacesAndNewlines)
            if !goalTitle.isEmpty {
                lines.append("Goal: \(goalTitle)")
            }
            let goalReason = goal.reasons.trimmingCharacters(in: .whitespacesAndNewlines)
            if !goalReason.isEmpty {
                lines.append("Goal Reason: \(goalReason)")
            }
        }

        let areaNames = fulfillments
            .map { $0.category.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !areaNames.isEmpty {
            lines.append("Fulfillment Areas: \(areaNames.prefix(3).joined(separator: ", "))")
            lines.append("Fulfillment Graph: \(areaNames.count) areas, \(fulfillmentFocusRows.count) little wins, \(outcomes.count) goals")
        }

        let identities = fulfillmentRoles
            .sorted { $0.rank < $1.rank }
            .map { $0.role.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if let identity = identities.first {
            lines.append("Identity: \(identity)")
        }

        let littleWins = fulfillmentFocusRows
            .sorted { $0.rank < $1.rank }
            .map { $0.activity.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if let littleWin = littleWins.first {
            lines.append("Little Wins: \(littleWin)")
        }

        if let vision = drivingForces.first?.ultimateVision.trimmingCharacters(in: .whitespacesAndNewlines),
           !vision.isEmpty {
            lines.append("Vision: \(vision)")
        }

        let passionTitles = passions
            .map { $0.passion.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !passionTitles.isEmpty {
            lines.append("Passions: \(passionTitles.prefix(2).joined(separator: ", "))")
        }

        let capture = captureItems
            .filter { !$0.isGhost }
            .sorted { $0.createdAt > $1.createdAt }
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !capture.isEmpty {
            lines.append("Capture List: \(capture.prefix(2).joined(separator: " • "))")
        }

        let currentWeek = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start
        if let currentWeek {
            let chunkIDs = Set(plannedChunks.filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeek) }.map(\.id))
            let currentActions = plannedChunkActions
                .filter { chunkIDs.contains($0.plannedChunkId) }
                .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if !currentActions.isEmpty {
                lines.append("Action Plan: \(currentActions.prefix(2).joined(separator: " • "))")
            }
        }

        let fallback = [
            "Searching purpose and personalization signals...",
            "Searching root cause and next direction...",
            "Searching goals, reasons, and fulfillment graph...",
            "Searching identity, passions, and little wins...",
            "Searching capture list and action plans..."
        ]

        let merged = (lines + fallback).map { String($0.prefix(180)) }.filter { !$0.isEmpty }
        let randomized = merged.shuffled()
        return Array(randomized.prefix(max(6, min(14, randomized.count))))
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

    let lines: [String]

    @State private var activeIndex = 0
    @State private var incomingIndex = 0
    @State private var isTransitioning = false
    @State private var cycleTask: Task<Void, Never>? = nil
    private let baseTextAreaMinHeight: CGFloat = 88
    private let cardHeightScale: CGFloat = 0.8

    private var textAreaMinHeight: CGFloat {
        baseTextAreaMinHeight * cardHeightScale
    }

    private var cardWidth: CGFloat {
        UIScreen.main.bounds.width * 0.75
    }

    private var sources: [SourceLine] {
        let parsed = lines.map { line -> SourceLine in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let separator = trimmed.firstIndex(of: ":") else {
                return SourceLine(title: "Searching Sources", preview: trimmed)
            }
            let prefix = String(trimmed[..<separator]).trimmingCharacters(in: .whitespacesAndNewlines)
            let suffix = String(trimmed[trimmed.index(after: separator)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return SourceLine(
                title: prefix.isEmpty ? "Searching Sources" : prefix,
                preview: suffix.isEmpty ? trimmed : suffix
            )
        }
        if parsed.isEmpty {
            return [SourceLine(title: "Searching Sources", preview: "Searching your Loom context...")]
        }
        return parsed
    }

    private var currentSource: SourceLine {
        sources[min(max(activeIndex, 0), max(0, sources.count - 1))]
    }

    private var nextSource: SourceLine {
        sources[min(max(incomingIndex, 0), max(0, sources.count - 1))]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image("LoomAI")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 12, height: 12)
                    .opacity(0.92)
                Text("Reading: \(currentSource.title)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.90))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }

            ZStack(alignment: .topLeading) {
                textLayer(nextSource.preview)
                    .opacity(isTransitioning ? 1 : 0)
                    .offset(y: isTransitioning ? 0 : 18)

                textLayer(currentSource.preview)
                    .opacity(isTransitioning ? 0 : 1)
                    .offset(y: isTransitioning ? -18 : 0)
            }
            .frame(maxWidth: .infinity, minHeight: textAreaMinHeight, alignment: .topLeading)
            .mask(verticalEdgeFadeMask)
            .animation(.easeInOut(duration: 0.45), value: isTransitioning)
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
            incomingIndex = min(incomingIndex, max(0, sources.count - 1))
            if sources.count > 1, cycleTask == nil {
                startCycling()
            } else if sources.count <= 1 {
                cycleTask?.cancel()
                cycleTask = nil
                isTransitioning = false
            }
        }
    }

    private func textLayer(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.white.opacity(0.96))
            .multilineTextAlignment(.leading)
            .lineLimit(4)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var verticalEdgeFadeMask: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.00),
                .init(color: .black, location: 0.16),
                .init(color: .black, location: 0.84),
                .init(color: .clear, location: 1.00)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func startCycling() {
        cycleTask?.cancel()
        guard sources.count > 1 else { return }
        cycleTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_150_000_000)
                guard !Task.isCancelled else { break }
                incomingIndex = (activeIndex + 1) % sources.count
                isTransitioning = true
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard !Task.isCancelled else { break }
                activeIndex = incomingIndex
                isTransitioning = false
            }
        }
    }
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

    private var lines: [[Segment]] {
        let normalized = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        return normalized
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { parseSegments(in: String($0)) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                let pieces = tokenPieces(from: line)
                if pieces.isEmpty {
                    Text("")
                        .font(.subheadline)
                } else {
                    LoomTokenFlowLayout(horizontalSpacing: 4, verticalSpacing: 6) {
                        ForEach(Array(pieces.enumerated()), id: \.offset) { _, piece in
                            pieceView(piece)
                        }
                    }
                }
            }
        }
    }

    private enum Piece: Hashable {
        case text(String)
        case purposeText(String)
        case token(kind: String, value: String)
    }

    private func tokenPieces(from segments: [Segment]) -> [Piece] {
        var out: [Piece] = []
        for segment in segments {
            switch segment {
            case .text(let value):
                let chunks = value
                    .split(whereSeparator: { $0.isWhitespace })
                    .map(String.init)
                    .filter { !$0.isEmpty }
                for chunk in chunks {
                    out.append(.text(chunk))
                }
            case .token(let kind, let value):
                if kind == "P", !isPassionReferenceToken(value) {
                    let words = value
                        .split(whereSeparator: { $0.isWhitespace })
                        .map(String.init)
                        .filter { !$0.isEmpty }
                    if words.isEmpty { continue }
                    for (index, word) in words.enumerated() {
                        var token = word
                        if index == 0 { token = "\"\(token)" }
                        if index == words.count - 1 { token = "\(token)\"" }
                        out.append(.purposeText(token))
                    }
                } else {
                    out.append(.token(kind: kind, value: value))
                }
            }
        }
        return out
    }

    @ViewBuilder
    private func pieceView(_ piece: Piece) -> some View {
        switch piece {
        case .text(let value):
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.primary)
        case .purposeText(let value):
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        case .token(let kind, let value):
            switch kind {
            case "P":
                if isPassionReferenceToken(value) {
                    Text(value)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(passionTokenForegroundColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(passionTokenBackgroundColor)
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(passionTokenBorderColor, lineWidth: 1)
                        )
                } else {
                    Text("\"\(value)\"")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
            case "F":
                let base = fixedColor(FulfillmentCategoryTheme.color(for: value))
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(base)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(lightened(base, amount: 0.82))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(base.opacity(0.42), lineWidth: 1)
                    )
            case "O":
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(outcomeTokenForegroundColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(outcomeTokenBackgroundColor)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(outcomeTokenBorderColor, lineWidth: 1)
                    )
            case "A":
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary.opacity(0.85))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.primary.opacity(0.10))
                    )
            default:
                Text(value).font(.subheadline)
            }
        }
    }

    private var outcomeTokenForegroundColor: Color {
        Color(red: 0.16, green: 0.28, blue: 0.53)
    }

    private var outcomeTokenBackgroundColor: Color {
        Color(red: 0.87, green: 0.92, blue: 0.99)
    }

    private var outcomeTokenBorderColor: Color {
        Color(red: 0.46, green: 0.63, blue: 0.90)
    }

    private var passionTokenForegroundColor: Color {
        Color(red: 0.26, green: 0.26, blue: 0.28)
    }

    private var passionTokenBackgroundColor: Color {
        Color(red: 0.92, green: 0.92, blue: 0.93)
    }

    private var passionTokenBorderColor: Color {
        Color(red: 0.72, green: 0.72, blue: 0.74)
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
        let pattern = #"\[\[(P|F|O|A):([^\]]+)\]\]"#
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
}

private struct LoomTokenFlowLayout: Layout {
    var horizontalSpacing: CGFloat = 4
    var verticalSpacing: CGFloat = 6

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache _: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var point = CGPoint.zero
        var lineHeight: CGFloat = 0
        var maxLineWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if point.x > 0, point.x + size.width > maxWidth {
                point.x = 0
                point.y += lineHeight + verticalSpacing
                lineHeight = 0
            }
            maxLineWidth = max(maxLineWidth, point.x + size.width)
            lineHeight = max(lineHeight, size.height)
            point.x += size.width + horizontalSpacing
        }

        let totalHeight = point.y + lineHeight
        let resolvedWidth: CGFloat = {
            guard maxWidth.isFinite else { return maxLineWidth }
            return min(maxLineWidth, maxWidth)
        }()
        return CGSize(
            width: resolvedWidth.isFinite ? max(0, resolvedWidth) : 0,
            height: totalHeight
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal _: ProposedViewSize,
        subviews: Subviews,
        cache _: inout ()
    ) {
        var point = CGPoint(x: bounds.minX, y: bounds.minY)
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if point.x > bounds.minX, point.x + size.width > bounds.maxX {
                point.x = bounds.minX
                point.y += lineHeight + verticalSpacing
                lineHeight = 0
            }
            subview.place(
                at: point,
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
            lineHeight = max(lineHeight, size.height)
            point.x += size.width + horizontalSpacing
        }
    }
}
