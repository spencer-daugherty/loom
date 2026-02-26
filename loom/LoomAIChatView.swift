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

    @StateObject private var viewModel = LoomAIViewModel()
    @State private var showActionExecutionAlert = false
    @State private var actionExecutionAlertText = ""
    @State private var keyboardHeight: CGFloat = 0
    @State private var showDebugErrorDetails = false
    @State private var activeThreadKey = LoomAIChatThreadSelectionStore.currentThreadKey()
    @State private var appliedSuggestedActionIDs: Set<String> = []
    @State private var chipCategoryOverrides: [String: String] = [:]
    @FocusState private var isInputFocused: Bool
    private let keyboardTopGap: CGFloat = 12

    private var messages: [LoomAIChatMessage] {
        allMessages.filter { $0.threadKey == activeThreadKey }
    }

    private var latestAssistantMessageID: UUID? {
        messages.last(where: { $0.roleRaw == LoomAIChatRole.assistant.rawValue })?.id
    }

    var body: some View {
        VStack(spacing: 10) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if messages.isEmpty {
                            emptyState
                        }

                        ForEach(messages) { message in
                            VStack(alignment: .leading, spacing: 8) {
                                messageBubble(message)
                                if message.id == latestAssistantMessageID {
                                    suggestedActionsView(actions: LoomAIChatMessageActionsCodec.decode(message.actionsJSON))
                                }
                            }
                            .id(message.id)
                        }

                        if viewModel.isSending {
                            HStack(spacing: 8) {
                                LoomTypingDotsIndicator()
                            }
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
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(bottomScrollAnchorID, anchor: .bottom)
                    }
                    viewModel.refreshLatestActions(from: messages)
                    viewModel.refreshSuggestedPromptChips(in: modelContext, threadMessages: messages)
                }
                .onChange(of: viewModel.isSending) { _, _ in
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(bottomScrollAnchorID, anchor: .bottom)
                    }
                }
                .onAppear {
                    viewModel.refreshLatestActions(from: messages)
                    viewModel.refreshSuggestedPromptChips(in: modelContext, threadMessages: messages)
                    _ = try? viewModel.ensureThread(in: modelContext, threadKey: activeThreadKey)
                    DispatchQueue.main.async {
                        proxy.scrollTo(bottomScrollAnchorID, anchor: .bottom)
                    }
                }
            }

            if let error = viewModel.errorMessage, !error.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.black.opacity(0.7))
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(Color.black.opacity(0.75))
                        Spacer(minLength: 0)
                    }
                    #if DEBUG
                    if let detail = viewModel.debugFailureDetail {
                        DisclosureGroup(isExpanded: $showDebugErrorDetails) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Status: \(detail.statusCode.map(String.init) ?? "unknown")")
                                Text("Content-Type: \(detail.contentType ?? "unknown")")
                                Text(detail.bodyPreview.isEmpty ? "<empty body>" : detail.bodyPreview)
                                    .textSelection(.enabled)
                            }
                            .font(.caption2)
                            .foregroundStyle(Color.black.opacity(0.72))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        } label: {
                            Text("Debug response details")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.black.opacity(0.72))
                        }
                    }
                    #endif
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(red: 0.98, green: 0.92, blue: 0.72))
                )
                .padding(.horizontal, 12)
            }

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 8) {
                if !viewModel.suggestedPromptChips.isEmpty {
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isInputFocused = true
            }
        }
        .onChange(of: isActivePage) { _, isActive in
            if isActive {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isInputFocused = true
                }
            } else {
                isInputFocused = false
                dismissKeyboard()
            }
        }
        .onDisappear {
            isInputFocused = false
            dismissKeyboard()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            updateKeyboardHeight(note)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.2)) {
                keyboardHeight = 0
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .loomAIChatThreadSelectionDidChange)) { _ in
            let newKey = LoomAIChatThreadSelectionStore.currentThreadKey()
            guard newKey != activeThreadKey else { return }
            activeThreadKey = newKey
            viewModel.refreshLatestActions(from: messages)
            viewModel.refreshSuggestedPromptChips(in: modelContext, threadMessages: messages)
            _ = try? viewModel.ensureThread(in: modelContext, threadKey: newKey)
        }
    }

    private var suggestedPromptChipBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.suggestedPromptChips, id: \.self) { chip in
                    suggestedPromptChip(chip)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func suggestedPromptChip(_ chip: String) -> some View {
        let resolvedChip = resolvedPromptChipText(for: chip)
        let matchedCategory = fulfillmentCategoryMatch(in: resolvedChip)
        let matchedOutcome = matchedCategory == nil ? outcomeTitleMatch(in: resolvedChip) : nil
        let highlightedToken = matchedCategory ?? matchedOutcome
        let highlightColor = matchedCategory.map { FulfillmentCategoryTheme.color(for: $0) }
            ?? matchedOutcome.map { outcomeChipColor(for: $0) }
            ?? .primary

        return HStack(spacing: 0) {
            Button {
                sendPrompt(resolvedChip)
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

    private func outcomeTitleMatch(in chipText: String) -> String? {
        outcomeTitlesForChipSelection
            .sorted { $0.count > $1.count }
            .first(where: { chipText.localizedCaseInsensitiveContains($0) })
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
                Text("Ask Loom about your Purpose, Fulfillment, Outcomes, or weekly plan.")
                    .font(.subheadline.weight(.semibold))
            }
            Text("Examples: “What should I focus on this week?”, “Which fulfillment area is slipping?”, “Turn these capture actions into groups.”")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
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
        return HStack {
            if isUser { Spacer(minLength: 30) }
            VStack(alignment: .leading, spacing: 4) {
                messageBubbleText(message.content, isUser: isUser)
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
                    .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
                    .fixedSize(horizontal: false, vertical: true)

                #if DEBUG
                if !isUser, let debug = LoomAIDebugCodec.decode(message.debugJSON) {
                    Text(groundingDebugLine(debug))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
                #endif
            }
            if !isUser { Spacer(minLength: 30) }
        }
    }

    @ViewBuilder
    private func messageBubbleText(_ content: String, isUser: Bool) -> some View {
        if isUser {
            Text(content)
                .font(.subheadline)
                .foregroundStyle(.white)
                .textSelection(.enabled)
        } else {
            Text(formattedAssistantAttributedString(content))
                .font(.subheadline)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
    }

    private func formattedAssistantAttributedString(_ content: String) -> AttributedString {
        var attributed: AttributedString
        if let parsed = try? AttributedString(
            markdown: content,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            attributed = parsed
        } else {
            attributed = AttributedString(content)
        }

        styleFulfillmentAreaNames(in: &attributed)
        boldScoreNumbers(in: &attributed)
        return attributed
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
    private func groundingDebugLine(_ debug: LoomAIDebug) -> String {
        let grounded = debug.usedContext.map { $0 ? "true" : "false" } ?? "unknown"
        let ctxBytes = debug.contextBytes.map(String.init) ?? "unknown"
        let model = (debug.model?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? debug.model! : "unknown"
        return "grounded: \(grounded) | ctxBytes: \(ctxBytes) | model: \(model)"
    }
    #endif

    @ViewBuilder
    private func suggestedActionsView(actions: [LoomAISuggestedAction]) -> some View {
        if !actions.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Suggestions")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(actions) { action in
                        suggestedActionButton(action)
                    }
                }
            }
            .padding(.top, 2)
        }
    }

    private func suggestedActionButton(_ action: LoomAISuggestedAction) -> some View {
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

    @ViewBuilder
    private func suggestedActionLeadingIcon(for action: LoomAISuggestedAction, isApplied: Bool) -> some View {
        if isApplied {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(colorScheme == .dark ? Color.green : Color(red: 0.10, green: 0.50, blue: 0.24))
        } else {
            Image("LoomAI")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: 16, height: 16)
                .foregroundStyle(Color.white.opacity(0.95))
        }
    }

    @ViewBuilder
    private func suggestedActionPrimaryText(for action: LoomAISuggestedAction, isApplied: Bool) -> some View {
        if action.type == "createLittleWin" || action.type == "replaceLittleWin" {
            suggestedLittleWinPrimaryText(action: action, isApplied: isApplied)
        } else {
            Text(suggestedActionButtonLabel(for: action, isApplied: isApplied))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(suggestedActionPrimaryColor(isApplied: isApplied))
                .multilineTextAlignment(.leading)
        }
    }

    private func suggestedLittleWinPrimaryText(action: LoomAISuggestedAction, isApplied: Bool) -> some View {
        let activity = (action.payload["activity"] ?? action.payload["text"] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let category = (action.payload["categoryName"] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let isReplace = action.type == "replaceLittleWin"
        let topLineBase: String = {
            if isReplace {
                return category.isEmpty ? "Replace Little Win:" : "Replace Little Win in \(category):"
            } else {
                return category.isEmpty ? "Add Little Win:" : "Add Little Win to \(category):"
            }
        }()
        let topLine = isApplied
            ? topLineBase.replacingOccurrences(of: "Add ", with: "Added ", options: [.anchored])
                .replacingOccurrences(of: "Replace ", with: "Replaced ", options: [.anchored])
            : topLineBase
        let replaced = (action.payload["replaceActivity"] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return VStack(alignment: .leading, spacing: 3) {
            Text(topLine)
                .font(.subheadline.italic())
                .foregroundStyle(suggestedActionPrimaryColor(isApplied: isApplied).opacity(isApplied ? 0.88 : 0.95))
                .multilineTextAlignment(.leading)

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
        guard action.type == "createLittleWin" || action.type == "replaceLittleWin" else { return false }

        let activity = (action.payload["activity"] ?? action.payload["text"] ?? action.title)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !activity.isEmpty else { return false }

        let targetCategoryID: UUID? = {
            if let raw = action.payload["categoryID"], let uuid = UUID(uuidString: raw) {
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
        case "createLittleWin":
            return nil
        case "replaceLittleWin":
            return "Replaces the existing Little Win shown below."
        case "createAction":
            return "Adds this to Capture."
        case "createOutcome":
            return "Creates a new Outcome."
        default:
            return nil
        }
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
                    guard !viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !viewModel.isSending else { return }
                    Task { await viewModel.sendCurrentMessage(in: modelContext, threadKey: activeThreadKey) }
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
                Task { await viewModel.sendCurrentMessage(in: modelContext, threadKey: activeThreadKey) }
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
                            viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Color.secondary
                            : Color.white
                        )
                }
                .frame(width: composerControlHeight, height: composerControlHeight)
            }
            .buttonStyle(.plain)
            .frame(width: composerControlHeight, height: composerControlHeight, alignment: .bottom)
            .disabled(viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
        }
        .frame(minHeight: 56)
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func sendPrompt(_ prompt: String) {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !viewModel.isSending else { return }
        viewModel.draft = trimmed
        Task { await viewModel.sendCurrentMessage(in: modelContext, threadKey: activeThreadKey) }
    }

    private func createNewChatFromPullDown() {
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
