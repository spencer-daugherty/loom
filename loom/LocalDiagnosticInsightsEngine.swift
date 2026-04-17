import Foundation

struct LocalDiagnosticInsightsMatchResult: Sendable {
    let candidateID: String
    let layer: String
    let rootCause: String
    let nextDirection: String
    let confidence: Double
}

enum LocalDiagnosticInsightsEngine {
    static func generate(diagnostic: DiagnosticAnswers) -> DiagnosticInsights {
        let match = matchResult(for: diagnostic)
        return DiagnosticInsights(
            rootCause: match.rootCause,
            nextDirection: match.nextDirection,
            debug: nil,
            usage: nil
        )
    }

    static func matchResult(for diagnostic: DiagnosticAnswers) -> LocalDiagnosticInsightsMatchResult {
        let profile = LocalDiagnosticProfile(diagnostic: diagnostic)
        let database = LocalDiagnosticInsightsDatabase.shared

        let modifierMatches = database.modifierCandidates
            .map { score($0, against: profile) }
            .filter { !$0.isDisqualified }
            .sorted(by: LocalScoredCandidate.sortDescending)
        let topModifiers = Array(modifierMatches.prefix(3))

        let coreMatches = database.coreCandidates
            .map { score($0, against: profile) }
            .filter { !$0.isDisqualified }
            .sorted(by: LocalScoredCandidate.sortDescending)

        let bridgeMatches = database.bridgeCandidates
            .map { score($0, against: profile) }
            .filter { !$0.isDisqualified }
            .sorted(by: LocalScoredCandidate.sortDescending)

        let fallbackMatches = database.fallbackCandidates
            .map { score($0, against: profile) }
            .filter { !$0.isDisqualified }
            .sorted(by: LocalScoredCandidate.sortDescending)

        let topCore = coreMatches.first
        let topBridge = bridgeMatches.first
        let topFallback = fallbackMatches.first

        let supportedCore = topCore.map { applyModifierSupport($0, modifiers: topModifiers) }
        let supportedBridge = topBridge.map { applyModifierSupport($0, modifiers: topModifiers) }
        let supportedFallback = topFallback.map { applyModifierSupport($0, modifiers: topModifiers) }

        let bridgeLeadThreshold = 6.0
        let winner: LocalScoredCandidate
        if let bridge = supportedBridge,
           let core = supportedCore,
           bridge.totalScore >= core.totalScore + bridgeLeadThreshold {
            winner = bridge
        } else if let core = supportedCore {
            winner = core
        } else if let bridge = supportedBridge {
            winner = bridge
        } else if let fallback = supportedFallback {
            winner = fallback
        } else {
            let emergency = database.fallbackCandidates.first ?? LocalDiagnosticCandidate.emergencyFallback
            return LocalDiagnosticInsightsMatchResult(
                candidateID: emergency.id,
                layer: emergency.layer,
                rootCause: emergency.rootCause,
                nextDirection: emergency.nextDirection,
                confidence: 0
            )
        }

        let runnerUp = [supportedCore, supportedBridge, supportedFallback]
            .compactMap { $0 }
            .filter { $0.candidate.id != winner.candidate.id }
            .sorted(by: LocalScoredCandidate.sortDescending)
            .first

        let confidence = confidenceScore(for: winner, runnerUp: runnerUp)
        let validated = validatedCandidate(from: winner.candidate, fallbackPool: database.fallbackCandidates)

        return LocalDiagnosticInsightsMatchResult(
            candidateID: validated.id,
            layer: validated.layer,
            rootCause: validated.rootCause,
            nextDirection: validated.nextDirection,
            confidence: confidence
        )
    }

    private static func validatedCandidate(
        from candidate: LocalDiagnosticCandidate,
        fallbackPool: [LocalDiagnosticCandidate]
    ) -> LocalDiagnosticCandidate {
        if isValid(body: candidate.rootCause) && isValid(body: candidate.nextDirection) && !containsAreaLeak(in: candidate.rootCause) && !containsAreaLeak(in: candidate.nextDirection) {
            return candidate
        }

        return fallbackPool.first(where: {
            isValid(body: $0.rootCause) && isValid(body: $0.nextDirection) && !containsAreaLeak(in: $0.rootCause) && !containsAreaLeak(in: $0.nextDirection)
        }) ?? .emergencyFallback
    }

    private static func isValid(body: String) -> Bool {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let wordCount = trimmed.split(whereSeparator: \.isWhitespace).count
        guard wordCount <= 40 else { return false }
        let sentences = trimmed
            .split(whereSeparator: { ".!?".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return (2...3).contains(sentences.count)
    }

    private static func containsAreaLeak(in text: String) -> Bool {
        let lower = text.lowercased()
        return LocalDiagnosticProfile.canonicalAreas.contains(where: { lower.contains($0.lowercased()) })
    }

    private static func confidenceScore(for winner: LocalScoredCandidate, runnerUp: LocalScoredCandidate?) -> Double {
        let base = min(max(winner.totalScore / max(1, winner.maxPossibleScore), 0), 1)
        guard let runnerUp else { return base }
        let margin = max(0, winner.totalScore - runnerUp.totalScore)
        let marginBoost = min(0.25, margin / 40)
        return min(1, base * 0.8 + marginBoost + 0.1)
    }

    private static func applyModifierSupport(
        _ candidate: LocalScoredCandidate,
        modifiers: [LocalScoredCandidate]
    ) -> LocalScoredCandidate {
        var updated = candidate
        let support = modifiers.reduce(0.0) { partial, modifier in
            let sharedTags = Set(candidate.candidate.tags).intersection(modifier.candidate.tags).count
            guard sharedTags > 0 else { return partial }
            let capped = min(2, sharedTags)
            return partial + (Double(capped) * 0.9)
        }
        updated.totalScore += support
        return updated
    }

    private static func score(
        _ candidate: LocalDiagnosticCandidate,
        against profile: LocalDiagnosticProfile
    ) -> LocalScoredCandidate {
        var score = 0.0
        var maxScore = 0.0
        var exactMatches = 0
        var matchedDimensions = 0

        if isDisqualified(candidate.disqualifiers, profile: profile) {
            return LocalScoredCandidate(
                candidate: candidate,
                totalScore: -.greatestFiniteMagnitude,
                maxPossibleScore: 1,
                exactMatches: 0,
                matchedDimensions: 0,
                isDisqualified: true
            )
        }

        func applyListCondition(
            _ list: [String]?,
            actual: String,
            exactWeight: Double,
            mismatchPenalty: Double
        ) {
            guard let list, !list.isEmpty else { return }
            maxScore += exactWeight
            if list.contains(actual) {
                score += exactWeight
                exactMatches += 1
                matchedDimensions += 1
            } else {
                score -= mismatchPenalty
            }
        }

        applyListCondition(candidate.triggerConditions.stressIn, actual: profile.stress, exactWeight: 28, mismatchPenalty: 16)
        applyListCondition(candidate.triggerConditions.breaksFirstIn, actual: profile.breaksFirst, exactWeight: 24, mismatchPenalty: 14)
        applyListCondition(candidate.triggerConditions.planningStyleIn, actual: profile.planningStyle, exactWeight: 16, mismatchPenalty: 10)
        applyListCondition(candidate.triggerConditions.firstChangeIn, actual: profile.firstChange, exactWeight: 14, mismatchPenalty: 8)
        applyListCondition(candidate.triggerConditions.areaSpreadIn, actual: profile.areaSpread, exactWeight: 10, mismatchPenalty: 5)

        if let min = candidate.triggerConditions.areasCountMin {
            maxScore += 5
            if profile.areasCount >= min {
                score += 5
                matchedDimensions += 1
            } else {
                score -= 6
            }
        }

        if let max = candidate.triggerConditions.areasCountMax {
            maxScore += 5
            if profile.areasCount <= max {
                score += 5
                matchedDimensions += 1
            } else {
                score -= 6
            }
        }

        if let exact = candidate.triggerConditions.areasCountExact {
            maxScore += 9
            if profile.areasCount == exact {
                score += 9
                exactMatches += 1
                matchedDimensions += 1
            } else {
                score -= 8
            }
        }

        if let requiresCustomArea = candidate.triggerConditions.requiresCustomArea {
            maxScore += 6
            if profile.hasCustomArea == requiresCustomArea {
                score += 6
                matchedDimensions += 1
            } else {
                score -= 7
            }
        }

        if candidate.layer == "bridge" {
            score += 1.5
        } else if candidate.layer == "fallback" {
            score -= 4
        }

        if candidate.tags.contains("stable_planner"), profile.planningStyle == "plan_follow_through" {
            score += 3
        }
        if candidate.tags.contains("breaks_not_sure"), profile.breaksFirst == "not_sure" {
            score += 3
        }
        if candidate.tags.contains("areas_6_7"), profile.areasCount >= 6 {
            score += 3
        }
        if candidate.tags.contains("areas_5_7"), profile.areasCount >= 5 {
            score += 2
        }
        if candidate.tags.contains("areas_5_7"), profile.areasCount >= 5 {
            matchedDimensions += 1
        }

        return LocalScoredCandidate(
            candidate: candidate,
            totalScore: score,
            maxPossibleScore: max(maxScore, 1),
            exactMatches: exactMatches,
            matchedDimensions: matchedDimensions,
            isDisqualified: false
        )
    }

    private static func isDisqualified(
        _ conditions: LocalDiagnosticConditions?,
        profile: LocalDiagnosticProfile
    ) -> Bool {
        guard let conditions else { return false }
        if let stress = conditions.stressIn, stress.contains(profile.stress) {
            return true
        }
        if let breaks = conditions.breaksFirstIn, breaks.contains(profile.breaksFirst) {
            return true
        }
        if let planning = conditions.planningStyleIn, planning.contains(profile.planningStyle) {
            return true
        }
        if let change = conditions.firstChangeIn, change.contains(profile.firstChange) {
            return true
        }
        if let spread = conditions.areaSpreadIn, spread.contains(profile.areaSpread) {
            return true
        }
        if let exact = conditions.areasCountExact, exact == profile.areasCount {
            return true
        }
        if let min = conditions.areasCountMin, profile.areasCount >= min {
            return true
        }
        if let max = conditions.areasCountMax, profile.areasCount <= max {
            return true
        }
        if let requiresCustomArea = conditions.requiresCustomArea, requiresCustomArea == profile.hasCustomArea {
            return true
        }
        return false
    }
}

private struct LocalScoredCandidate: Sendable {
    let candidate: LocalDiagnosticCandidate
    var totalScore: Double
    let maxPossibleScore: Double
    let exactMatches: Int
    let matchedDimensions: Int
    let isDisqualified: Bool

    static func sortDescending(lhs: LocalScoredCandidate, rhs: LocalScoredCandidate) -> Bool {
        if lhs.totalScore != rhs.totalScore { return lhs.totalScore > rhs.totalScore }
        if lhs.exactMatches != rhs.exactMatches { return lhs.exactMatches > rhs.exactMatches }
        if lhs.matchedDimensions != rhs.matchedDimensions { return lhs.matchedDimensions > rhs.matchedDimensions }
        return lhs.candidate.id < rhs.candidate.id
    }
}

private struct LocalDiagnosticProfile: Sendable {
    static let canonicalAreas: Set<String> = [
        "Career & Business",
        "Faith & Spirituality",
        "Wealth & Finance",
        "Learning & Education",
        "Love & Relationships",
        "Health & Energy",
        "Lifestyle & Experiences",
        "Mindset & Resilience",
        "Service & Impact",
        "Home & Life"
    ]

    let stress: String
    let breaksFirst: String
    let planningStyle: String
    let firstChange: String
    let areasCount: Int
    let areaSpread: String
    let hasCustomArea: Bool

    init(diagnostic: DiagnosticAnswers) {
        self.stress = Self.normalizedStress(diagnostic.stress)
        self.breaksFirst = Self.normalizedBreaksFirst(diagnostic.breaksFirst)
        self.planningStyle = Self.normalizedPlanning(diagnostic.planningStyle)
        self.firstChange = Self.normalizedFirstChange(diagnostic.firstChange)
        let normalizedAreas = diagnostic.areas
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.areasCount = normalizedAreas.count
        self.hasCustomArea = normalizedAreas.contains(where: { !Self.canonicalAreas.contains($0) })
        self.areaSpread = Self.deriveAreaSpread(from: normalizedAreas, hasCustomArea: hasCustomArea)
    }

    private static func normalizedStress(_ value: String) -> String {
        switch OnboardingStressSourceAnswer(matching: value) {
        case .tooManyPrioritiesCompeting: return "competing_priorities"
        case .feelingBehindOrDisorganized: return "behind_disorganized"
        case .distractionsAreStealingMyFocus: return "distractions"
        case .workPressure: return "work_pressure"
        case .moneyPressure: return "money_pressure"
        case .lowEnergyHealth: return "low_energy"
        case .relationshipTension: return "relationship_tension"
        case .notSureYet, .none: return "not_sure"
        }
    }

    private static func normalizedBreaksFirst(_ value: String) -> String {
        switch OnboardingBreakPointAnswer(matching: value) {
        case .dontStart: return "dont_start"
        case .loseMomentum: return "lose_momentum"
        case .getDistracted: return "get_distracted"
        case .overthinkIt: return "overthink"
        case .dontFinish: return "dont_finish"
        case .notSure, .none: return "not_sure"
        }
    }

    private static func normalizedPlanning(_ value: String) -> String {
        switch OnboardingPlanningRealityAnswer(matching: value) {
        case .reactToUrgent: return "react_urgent"
        case .simpleTodo: return "simple_todo"
        case .planButOffTrack: return "plan_offtrack"
        case .planAndFollowThrough: return "plan_follow_through"
        case .dependsOnDay, .none: return "depends_day"
        }
    }

    private static func normalizedFirstChange(_ value: String) -> String {
        switch OnboardingDesiredChangeAnswer(matching: value) {
        case .inControl: return "feel_control"
        case .clearDirection: return "know_what_matters"
        case .followThrough: return "follow_through"
        case .fasterProgress: return "faster_progress"
        case .balancedLife, .none: return "feel_balanced"
        }
    }

    private static func deriveAreaSpread(from areas: [String], hasCustomArea: Bool) -> String {
        if hasCustomArea && areas.count >= 5 {
            return "mixed_wide"
        }
        if areas.count >= 6 {
            return "mixed_wide"
        }

        let innerSet: Set<String> = ["Faith & Spirituality", "Mindset & Resilience", "Learning & Education"]
        let outerSet: Set<String> = ["Career & Business", "Wealth & Finance", "Service & Impact"]
        let relationalSet: Set<String> = ["Love & Relationships", "Home & Life"]
        let growthSet: Set<String> = ["Lifestyle & Experiences", "Learning & Education", "Service & Impact"]

        let inner = areas.filter { innerSet.contains($0) }.count
        let outer = areas.filter { outerSet.contains($0) }.count
        let relational = areas.filter { relationalSet.contains($0) }.count
        let growth = areas.filter { growthSet.contains($0) }.count

        let counts: [(String, Int)] = [
            ("inner_weighted", inner),
            ("outer_weighted", outer),
            ("home_relational_weighted", relational),
            ("growth_weighted", growth)
        ]

        if let strongest = counts.max(by: { $0.1 < $1.1 }), strongest.1 >= 2 {
            if counts.filter({ $0.1 == strongest.1 }).count == 1 {
                return strongest.0
            }
        }

        return "balanced_mix"
    }
}

private struct LocalDiagnosticDatabase: Codable, Sendable {
    let coreCandidates: [LocalDiagnosticCandidate]
    let modifierCandidates: [LocalDiagnosticCandidate]
    let bridgeCandidates: [LocalDiagnosticCandidate]
    let fallbackCandidates: [LocalDiagnosticCandidate]
}

private struct LocalDiagnosticCandidate: Codable, Sendable {
    let id: String
    let layer: String
    let archetype: String
    let subarchetype: String
    let intensity: String
    let tags: [String]
    let triggerConditions: LocalDiagnosticConditions
    let disqualifiers: LocalDiagnosticConditions?
    let rootCause: String
    let nextDirection: String
    let rationale: String

    static let emergencyFallback = LocalDiagnosticCandidate(
        id: "LOCAL_EMERGENCY_FALLBACK",
        layer: "fallback",
        archetype: "Fallback",
        subarchetype: "Emergency",
        intensity: "low",
        tags: ["fallback"],
        triggerConditions: .init(),
        disqualifiers: nil,
        rootCause: "The pattern is still hard to pin down. Too much stays mentally open, so the day loses shape.",
        nextDirection: "Loom will narrow the day to one clear result and a short order. That creates structure before every answer is clear.",
        rationale: "Emergency local fallback."
    )
}

private struct LocalDiagnosticConditions: Codable, Sendable {
    let stressIn: [String]?
    let breaksFirstIn: [String]?
    let planningStyleIn: [String]?
    let firstChangeIn: [String]?
    let areasCountMin: Int?
    let areasCountMax: Int?
    let areasCountExact: Int?
    let areaSpreadIn: [String]?
    let requiresCustomArea: Bool?

    init(
        stressIn: [String]? = nil,
        breaksFirstIn: [String]? = nil,
        planningStyleIn: [String]? = nil,
        firstChangeIn: [String]? = nil,
        areasCountMin: Int? = nil,
        areasCountMax: Int? = nil,
        areasCountExact: Int? = nil,
        areaSpreadIn: [String]? = nil,
        requiresCustomArea: Bool? = nil
    ) {
        self.stressIn = stressIn
        self.breaksFirstIn = breaksFirstIn
        self.planningStyleIn = planningStyleIn
        self.firstChangeIn = firstChangeIn
        self.areasCountMin = areasCountMin
        self.areasCountMax = areasCountMax
        self.areasCountExact = areasCountExact
        self.areaSpreadIn = areaSpreadIn
        self.requiresCustomArea = requiresCustomArea
    }
}

private enum LocalDiagnosticInsightsDatabase {
    static let shared: LocalDiagnosticDatabase = {
        let data = Data(LocalDiagnosticInsightsDatabaseJSON.utf8)
        do {
            return try JSONDecoder().decode(LocalDiagnosticDatabase.self, from: data)
        } catch {
            assertionFailure("Failed to decode local diagnostic insights database: \(error)")
            return LocalDiagnosticDatabase(
                coreCandidates: [],
                modifierCandidates: [],
                bridgeCandidates: [],
                fallbackCandidates: [.emergencyFallback]
            )
        }
    }()
}
