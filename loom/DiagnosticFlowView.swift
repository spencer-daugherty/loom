import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct DiagnosticFlowView: View {
    enum Mode {
        case onboarding
        case accountEdit

        var analyticsSource: String {
            switch self {
            case .onboarding: return "diagnostic_onboarding"
            case .accountEdit: return "diagnostic_account"
            }
        }
    }

    private enum Step: Int, CaseIterable {
        case stressSource = 0
        case breakPoint = 1
        case lifeAreas = 2
        case planningReality = 3
        case desiredChange = 4
        case building = 5
    }

    private static let stressOptions: [String] = [
        "Too many priorities competing",
        "Feeling behind or disorganized",
        "Distractions are stealing my focus",
        "Work pressure",
        "Money pressure",
        "Low energy / health",
        "Relationship tension",
        "Not sure yet"
    ]

    private static let breakPointOptions: [String] = [
        "I don’t start",
        "I start, then lose momentum",
        "I get distracted",
        "I overthink it",
        "I don’t finish what I start",
        "I’m not sure"
    ]

    private static let lifeAreaOptions: [String] = fulfillmentStartSelectableDefaultCategories

    private static let planningRealityOptions: [String] = [
        "React to what’s urgent",
        "Keep a simple to-do list",
        "Plan, but get off track",
        "Plan and follow through consistently",
        "It depends on the day"
    ]

    private static let desiredChangeOptions: [String] = [
        "I feel in control (less stress)",
        "I know what matters (clear direction)",
        "I follow through (consistency)",
        "I make faster progress on big goals",
        "I feel balanced across life"
    ]

    let mode: Mode
    let initialDraft: PersonalizationDraft?
    let onComplete: @MainActor (_ draft: PersonalizationDraft, _ elapsedSeconds: Int) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step: Step = .stressSource
    @State private var draft: PersonalizationDraft
    @State private var startedAt = Date()
    @State private var hasLoggedStart = false
    @State private var hasCompletedFlow = false
    @State private var showCustomAreaSheet = false
    @State private var customAreaInput = ""
    @State private var isAutoAdvancing = false
    @State private var stepTask: Task<Void, Never>?
    @State private var revisitedSingleSelectSteps: Set<Step> = []
    @State private var lifeAreaColorKeys: [String: String] = [:]
    @State private var completionErrorMessage: String?
    @Namespace private var loadingSplashNamespace

    init(
        mode: Mode = .onboarding,
        initialDraft: PersonalizationDraft? = nil,
        onComplete: @escaping @MainActor (_ draft: PersonalizationDraft, _ elapsedSeconds: Int) async throws -> Void = { _, _ in }
    ) {
        self.mode = mode
        self.initialDraft = initialDraft
        self.onComplete = onComplete
        let startingDraft = initialDraft ?? PersonalizationDraft()
        _draft = State(initialValue: startingDraft)
        _lifeAreaColorKeys = State(initialValue: startingDraft.lifeAreaColorKeys)
    }

    var body: some View {
        Group {
            if step == .building {
                LoadingSplashView(
                    metrics: [],
                    namespace: loadingSplashNamespace,
                    minimumDisplayDuration: 0.8
                )
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        if let questionIndex = questionIndex(for: step) {
                            DiagnosticThinkingHeader(
                                title: "\(questionIndex) of \(totalQuestionCount)",
                                progress: Double(questionIndex) / Double(max(1, totalQuestionCount))
                            )
                        }

                        if let completionErrorMessage {
                            cautionCard(completionErrorMessage)
                        }

                        switch step {
                        case .stressSource:
                            singleSelectStep(
                                step: .stressSource,
                                prompt: "What’s causing the most stress right now?",
                                helper: "Pick one.",
                                options: Self.stressOptions,
                                selected: draft.stressSource
                            ) { value in
                                completionErrorMessage = nil
                                draft.stressSource = value
                                moveToNextStep(from: .stressSource, after: 240_000_000)
                            }
                        case .breakPoint:
                            singleSelectStep(
                                step: .breakPoint,
                                prompt: "When you try to make progress, what usually breaks first?",
                                helper: "Pick one.",
                                options: Self.breakPointOptions,
                                selected: draft.breakPoint
                            ) { value in
                                completionErrorMessage = nil
                                draft.breakPoint = value
                                moveToNextStep(from: .breakPoint, after: 240_000_000)
                            }
                        case .lifeAreas:
                            lifeAreasStep
                        case .planningReality:
                            singleSelectStep(
                                step: .planningReality,
                                prompt: "Most days, you…",
                                helper: "Pick what’s most true.",
                                options: Self.planningRealityOptions,
                                selected: draft.planningReality
                            ) { value in
                                completionErrorMessage = nil
                                draft.planningReality = value
                                moveToNextStep(from: .planningReality, after: 240_000_000)
                            }
                        case .desiredChange:
                            singleSelectStep(
                                step: .desiredChange,
                                prompt: "If Loom works, what changes first?",
                                helper: "Pick one.",
                                options: Self.desiredChangeOptions,
                                selected: draft.desiredChange
                            ) { value in
                                completionErrorMessage = nil
                                draft.desiredChange = value
                                beginBuildAndFinish()
                            }
                        case .building:
                            EmptyView()
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 28)
                    .reviewPathColumn(maxWidth: 720, horizontalPadding: 20, alignment: .topLeading)
                }
            }
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    handleBackTapped()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                        Text("Back")
                    }
                }
                .disabled(step == .building)
                .opacity(step == .building ? 0 : 1)
            }
        }
        .onAppear {
            if !hasLoggedStart {
                hasLoggedStart = true
                startedAt = Date()
                AnalyticsLogger.log(
                    .diagnosticStarted(
                        source: mode.analyticsSource,
                        step: questionIndex(for: step) ?? 0,
                        stepName: analyticsStepName(for: step),
                        elapsedSeconds: 0
                    )
                )
            }
            ensureLifeAreaColorAssignments()
        }
        .onChange(of: step) { _, newStep in
            if newStep == .lifeAreas {
                ensureLifeAreaColorAssignments()
            }
        }
        .onDisappear {
            cancelPendingStepTask()
            guard !hasCompletedFlow else { return }
            AnalyticsLogger.log(
                .diagnosticAbandoned(
                    source: mode.analyticsSource,
                    step: questionIndex(for: step) ?? 0,
                    stepName: analyticsStepName(for: step),
                    elapsedSeconds: elapsedSeconds
                )
            )
        }
        .sheet(isPresented: $showCustomAreaSheet) {
            NavigationStack {
                Form {
                    Section {
                        TextField("Custom life area", text: $customAreaInput)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled(false)
                    } footer: {
                        Text("Keep it short and clear.")
                    }
                }
                .navigationTitle("Add Area")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            customAreaInput = ""
                            showCustomAreaSheet = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            addCustomAreaAndClose()
                        }
                        .disabled(customAreaInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .presentationDetents([.height(220)])
            .presentationDragIndicator(.visible)
        }
    }

    private var lifeAreasStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Which life areas should Loom help you manage long-term?")
                .font(.system(size: 31, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)

            Text("Choose 3–7 to cover your whole life.")
                .font(.body)
                .foregroundStyle(.secondary)

            if let message = lifeAreasRequirementMessage {
                cautionCard(message)
            }

            VStack(spacing: 8) {
                ForEach(Self.lifeAreaOptions, id: \.self) { option in
                    toggleCard(
                        option,
                        isSelected: draft.lifeAreasSelected.contains(option),
                        selectedColor: lifeAreaSelectionColor(for: option)
                    ) {
                        toggleLifeArea(option)
                    }
                }
                ForEach(customLifeAreas, id: \.self) { custom in
                    toggleCard(
                        custom,
                        isSelected: draft.lifeAreasSelected.contains(custom),
                        selectedColor: lifeAreaSelectionColor(for: custom)
                    ) {
                        toggleLifeArea(custom)
                    }
                }
            }

            Button {
                showCustomAreaSheet = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("+ Add your own")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 2)

            Button {
                continueFromLifeAreas()
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(canContinueFromLifeAreas ? .accentColor : Color(.systemGray3))
            .disabled(!canContinueFromLifeAreas)
            .controlSize(.large)
            .padding(.top, 6)
        }
    }

    private func singleSelectStep(
        step: Step,
        prompt: String,
        helper: String,
        options: [String],
        selected: String?,
        onSelect: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(prompt)
                .font(.system(size: 31, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)

            Text(helper)
                .font(.body)
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                ForEach(options, id: \.self) { option in
                    selectionCard(option, isSelected: option == selected) {
                        onSelect(option)
                    }
                    .disabled(isAutoAdvancing)
                }
            }

            if revisitedSingleSelectSteps.contains(step) {
                Button {
                    continueFromSingleSelect(step)
                } label: {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint((selected?.isEmpty == false) ? .accentColor : Color(.systemGray3))
                .disabled(selected == nil || selected?.isEmpty == true || isAutoAdvancing)
                .controlSize(.large)
                .padding(.top, 4)
            }
        }
    }

    private func selectionCard(
        _ title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            triggerSelectionHaptic()
            action()
        }) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.72) : Color.black.opacity(0.08), lineWidth: isSelected ? 2 : 1)
            )
            .overlay {
                if isSelected {
                    DiagnosticAnimatedOutlineBorder(cornerRadius: 14)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func toggleCard(
        _ title: String,
        isSelected: Bool,
        selectedColor: Color = .accentColor,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            triggerSelectionHaptic()
            action()
        }) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? selectedColor : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? selectedColor.opacity(0.72) : Color.black.opacity(0.08), lineWidth: isSelected ? 2 : 1)
            )
            .overlay {
                if isSelected {
                    DiagnosticAnimatedOutlineBorder(cornerRadius: 14)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func continueFromLifeAreas() {
        guard canContinueFromLifeAreas else { return }
        completionErrorMessage = nil
        triggerSelectionHaptic()
        withAnimation(.easeInOut(duration: reduceMotion ? 0.01 : 0.22)) {
            step = .planningReality
        }
    }

    private func toggleLifeArea(_ area: String) {
        if let existing = draft.lifeAreasSelected.firstIndex(where: { $0.caseInsensitiveCompare(area) == .orderedSame }) {
            removeLifeAreaColorAssignment(for: area)
            draft.lifeAreasSelected.remove(at: existing)
            return
        }

        if draft.lifeAreasSelected.count >= 7 { return }

        draft.lifeAreasSelected.append(area)
        assignLifeAreaDefaultColorIfNeeded(for: area)
        triggerSelectionHaptic()
    }

    private func addCustomAreaAndClose() {
        let custom = customAreaInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !custom.isEmpty else { return }

        if !customLifeAreas.contains(where: { $0.caseInsensitiveCompare(custom) == .orderedSame }) {
            if draft.lifeAreasSelected.count < 7 {
                draft.lifeAreasSelected.append(custom)
                assignLifeAreaDefaultColorIfNeeded(for: custom)
                triggerSelectionHaptic()
            }
        }
        customAreaInput = ""
        showCustomAreaSheet = false
    }

    private func moveToNextStep(from currentStep: Step, after nanoseconds: UInt64) {
        guard !isAutoAdvancing else { return }
        isAutoAdvancing = true

        let next = nextStep(after: currentStep) ?? currentStep
        stepTask?.cancel()
        stepTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            guard step == currentStep else {
                isAutoAdvancing = false
                return
            }
            withAnimation(.easeInOut(duration: reduceMotion ? 0.01 : 0.20)) {
                step = next
            }
            isAutoAdvancing = false
        }
    }

    private func beginBuildAndFinish() {
        stepTask?.cancel()
        stepTask = Task { @MainActor in
            guard !Task.isCancelled else { return }
            guard draft.isComplete else { return }

            draft.lifeAreaColorKeys = selectedLifeAreaColorAssignments()
            completionErrorMessage = nil
            withAnimation(.easeInOut(duration: reduceMotion ? 0.01 : 0.20)) {
                step = .building
            }
            await Task.yield()

            do {
                let elapsed = elapsedSeconds
                try await onComplete(draft, elapsed)
                hasCompletedFlow = true
                AnalyticsLogger.log(
                    .diagnosticCompleted(
                        source: mode.analyticsSource,
                        step: totalQuestionCount,
                        stepName: analyticsStepName(for: .desiredChange),
                        elapsedSeconds: elapsed
                    )
                )
                if mode == .accountEdit {
                    dismiss()
                }
            } catch {
                completionErrorMessage = "We couldn’t finish your diagnostic right now. Please try again."
                withAnimation(.easeInOut(duration: reduceMotion ? 0.01 : 0.20)) {
                    step = .desiredChange
                }
            }
        }
    }

    private func selectedLifeAreaColorAssignments() -> [String: String] {
        var result: [String: String] = [:]
        for area in draft.lifeAreasSelected {
            let trimmed = area.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if let key = lifeAreaColorKey(for: trimmed, map: lifeAreaColorKeys) {
                result[trimmed] = key
            }
        }
        return result
    }

    private var elapsedSeconds: Int {
        max(0, Int(Date().timeIntervalSince(startedAt)))
    }

    private var canContinueFromLifeAreas: Bool {
        let count = draft.lifeAreasSelected.count
        return count >= 3 && count <= 7
    }

    private var lifeAreasRequirementMessage: String? {
        let count = draft.lifeAreasSelected.count
        if count < 3 {
            return "Pick at least \(3 - count) more."
        }
        if count > 7 {
            return "Unselect at least \(count - 7). 7 maximum."
        }
        return nil
    }

    private var customLifeAreas: [String] {
        let builtInSet = Set(Self.lifeAreaOptions.map { $0.lowercased() })
        return draft.lifeAreasSelected.filter { !builtInSet.contains($0.lowercased()) }
    }

    private var allSelectableLifeAreas: [String] {
        var ordered: [String] = []
        for area in Self.lifeAreaOptions + customLifeAreas + draft.lifeAreasSelected {
            if !ordered.contains(where: { $0.caseInsensitiveCompare(area) == .orderedSame }) {
                ordered.append(area)
            }
        }
        return ordered
    }

    private var diagnosticsColorCycleKeys: [String] {
        ["blue", "indigo", "green", "purple", "red", "orange"]
    }

    private func lifeAreaSelectionColor(for area: String) -> Color {
        let key = lifeAreaColorKey(for: area, map: lifeAreaColorKeys)
            ?? FulfillmentCategoryTheme.defaultColorKeys()[area]
            ?? rotatedLifeAreaColorKey(for: area)
        return FulfillmentCategoryTheme.color(forKey: key)
    }

    private func ensureLifeAreaColorAssignments() {
        var map = lifeAreaColorKeys
        for area in draft.lifeAreasSelected {
            assignLifeAreaDefaultColorIfNeeded(for: area, map: &map)
        }
        map = map.filter { candidate in
            draft.lifeAreasSelected.contains { $0.caseInsensitiveCompare(candidate.key) == .orderedSame }
        }
        lifeAreaColorKeys = map
    }

    private func assignLifeAreaDefaultColorIfNeeded(for area: String) {
        var map = lifeAreaColorKeys
        assignLifeAreaDefaultColorIfNeeded(for: area, map: &map)
        lifeAreaColorKeys = map
    }

    private func assignLifeAreaDefaultColorIfNeeded(for area: String, map: inout [String: String]) {
        let trimmed = area.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let preferred = lifeAreaColorKey(for: trimmed, map: map)
            ?? FulfillmentCategoryTheme.defaultColorKeys()[trimmed]
            ?? rotatedLifeAreaColorKey(for: trimmed)
        let unavailable = unavailableLifeAreaColorKeys(for: trimmed, map: map)
        let resolved = nextAvailableLifeAreaColorKey(preferred: preferred, unavailable: unavailable)
        if let existingKey = map.keys.first(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            map[existingKey] = resolved
        } else {
            map[trimmed] = resolved
        }
    }

    private func removeLifeAreaColorAssignment(for area: String) {
        let trimmed = area.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let key = lifeAreaColorKeys.keys.first(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            lifeAreaColorKeys.removeValue(forKey: key)
        }
    }

    private func lifeAreaColorKey(for area: String, map: [String: String]) -> String? {
        if let exact = map[area] { return exact }
        if let matchedKey = map.keys.first(where: { $0.caseInsensitiveCompare(area) == .orderedSame }) {
            return map[matchedKey]
        }
        return nil
    }

    private func unavailableLifeAreaColorKeys(for area: String, map: [String: String]) -> Set<String> {
        let trimmed = area.trimmingCharacters(in: .whitespacesAndNewlines)
        var keys = Set<String>()
        for other in draft.lifeAreasSelected {
            let candidate = other.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !candidate.isEmpty else { continue }
            guard candidate.caseInsensitiveCompare(trimmed) != .orderedSame else { continue }
            let colorKey = lifeAreaColorKey(for: candidate, map: map)
                ?? FulfillmentCategoryTheme.defaultColorKeys()[candidate]
                ?? rotatedLifeAreaColorKey(for: candidate)
            keys.insert(colorKey)
        }
        return keys
    }

    private func nextAvailableLifeAreaColorKey(preferred: String, unavailable: Set<String>) -> String {
        let paletteKeys = FulfillmentCategoryTheme.palette.map(\.key)
        guard !paletteKeys.isEmpty else { return "blue" }
        let preferredKey = paletteKeys.contains(preferred) ? preferred : (paletteKeys.first ?? "blue")
        let startIndex = paletteKeys.firstIndex(of: preferredKey) ?? 0
        for offset in 0..<paletteKeys.count {
            let candidate = paletteKeys[(startIndex + offset) % paletteKeys.count]
            if !unavailable.contains(candidate) {
                return candidate
            }
        }
        return preferredKey
    }

    private func rotatedLifeAreaColorKey(for area: String) -> String {
        let cycleKeys = diagnosticsColorCycleKeys
        guard !cycleKeys.isEmpty else { return "blue" }
        if let idx = allSelectableLifeAreas.firstIndex(where: { $0.caseInsensitiveCompare(area) == .orderedSame }) {
            return cycleKeys[idx % cycleKeys.count]
        }
        return cycleKeys.first ?? "blue"
    }

    private func handleBackTapped() {
        cancelPendingStepTask()
        if let previous = previousStep(for: step) {
            revisitedSingleSelectSteps.insert(previous)
            withAnimation(.easeInOut(duration: reduceMotion ? 0.01 : 0.20)) {
                step = previous
            }
            return
        }
        dismiss()
    }

    private func continueFromSingleSelect(_ step: Step) {
        triggerSelectionHaptic()
        switch step {
        case .stressSource:
            guard draft.stressSource?.isEmpty == false else { return }
            moveToNextStep(from: .stressSource, after: 0)
        case .breakPoint:
            guard draft.breakPoint?.isEmpty == false else { return }
            moveToNextStep(from: .breakPoint, after: 0)
        case .planningReality:
            guard draft.planningReality?.isEmpty == false else { return }
            moveToNextStep(from: .planningReality, after: 0)
        case .desiredChange:
            guard draft.desiredChange?.isEmpty == false else { return }
            beginBuildAndFinish()
        case .lifeAreas, .building:
            break
        }
    }

    private func nextStep(after step: Step) -> Step? {
        switch step {
        case .stressSource: return .breakPoint
        case .breakPoint: return includesLifeAreasStep ? .lifeAreas : .planningReality
        case .lifeAreas: return .planningReality
        case .planningReality: return .desiredChange
        case .desiredChange: return nil
        case .building: return nil
        }
    }

    private func previousStep(for step: Step) -> Step? {
        switch step {
        case .stressSource: return nil
        case .breakPoint: return .stressSource
        case .lifeAreas: return .breakPoint
        case .planningReality: return includesLifeAreasStep ? .lifeAreas : .breakPoint
        case .desiredChange: return .planningReality
        case .building: return .desiredChange
        }
    }

    private var includesLifeAreasStep: Bool {
        mode == .onboarding
    }

    private var visibleQuestionSteps: [Step] {
        if includesLifeAreasStep {
            return [.stressSource, .breakPoint, .lifeAreas, .planningReality, .desiredChange]
        }
        return [.stressSource, .breakPoint, .planningReality, .desiredChange]
    }

    private var totalQuestionCount: Int {
        visibleQuestionSteps.count
    }

    private func questionIndex(for step: Step) -> Int? {
        guard let index = visibleQuestionSteps.firstIndex(of: step) else { return nil }
        return index + 1
    }

    private func analyticsStepName(for step: Step) -> String {
        switch step {
        case .stressSource: return "stress_source"
        case .breakPoint: return "break_point"
        case .lifeAreas: return "life_areas"
        case .planningReality: return "planning_reality"
        case .desiredChange: return "desired_change"
        case .building: return "building"
        }
    }

    @ViewBuilder
    private func cautionCard(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.black.opacity(0.70))
                .padding(.top, 1)
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.black.opacity(0.72))
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(red: 0.98, green: 0.92, blue: 0.72))
        )
    }

    private func cancelPendingStepTask() {
        stepTask?.cancel()
        stepTask = nil
        isAutoAdvancing = false
    }

    private func triggerSelectionHaptic() {
        #if canImport(UIKit)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }
}

private struct DiagnosticThinkingHeader: View {
    let title: String
    let progress: Double

    @State private var shineOffset: CGFloat = -0.7

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image("LoomAI")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                Text("LoomAI")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            GeometryReader { proxy in
                let fullWidth = max(1, proxy.size.width)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.secondary.opacity(0.16))

                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: DiagnosticGradient.tokens,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: fullWidth * max(0, min(1, progress)))

                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.0),
                                    Color.white.opacity(0.45),
                                    Color.white.opacity(0.0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: fullWidth * 0.35)
                        .offset(x: fullWidth * shineOffset)
                }
            }
            .frame(height: 12)
        }
        .onAppear {
            withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                shineOffset = 1.2
            }
        }
    }
}

private struct DiagnosticAnimatedOutlineBorder: View {
    let cornerRadius: CGFloat
    @State private var angle: Double = 0

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(
                AngularGradient(
                    colors: DiagnosticGradient.tokens,
                    center: .center,
                    angle: .degrees(angle)
                ),
                lineWidth: 1.8
            )
            .onAppear {
                guard angle == 0 else { return }
                withAnimation(.linear(duration: 6.5).repeatForever(autoreverses: false)) {
                    angle = 360
                }
            }
    }
}

private enum DiagnosticGradient {
    static let tokens: [Color] = [
        Color(red: 0.22, green: 0.47, blue: 1.0),
        Color(red: 0.15, green: 0.83, blue: 0.95),
        Color(red: 0.62, green: 0.40, blue: 0.95),
        Color(red: 0.80, green: 0.38, blue: 0.78),
        Color(red: 0.98, green: 0.36, blue: 0.58),
        Color(red: 0.22, green: 0.47, blue: 1.0)
    ]
}

#Preview {
    NavigationStack {
        DiagnosticFlowView(mode: .onboarding)
    }
}
