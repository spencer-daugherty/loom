import Foundation

enum OnboardingPersonalityTrait: String, CaseIterable, Codable, Sendable {
    case ER
    case XP
    case SF
    case HD
    case ID
    case FT
    case UB
    case MB
}

struct OnboardingPersonalityTraitVector: Codable, Hashable, Sendable {
    var ER: Double
    var XP: Double
    var SF: Double
    var HD: Double
    var ID: Double
    var FT: Double
    var UB: Double
    var MB: Double

    init(
        ER: Double = 0,
        XP: Double = 0,
        SF: Double = 0,
        HD: Double = 0,
        ID: Double = 0,
        FT: Double = 0,
        UB: Double = 0,
        MB: Double = 0
    ) {
        self.ER = ER
        self.XP = XP
        self.SF = SF
        self.HD = HD
        self.ID = ID
        self.FT = FT
        self.UB = UB
        self.MB = MB
    }

    subscript(_ trait: OnboardingPersonalityTrait) -> Double {
        get {
            switch trait {
            case .ER: return ER
            case .XP: return XP
            case .SF: return SF
            case .HD: return HD
            case .ID: return ID
            case .FT: return FT
            case .UB: return UB
            case .MB: return MB
            }
        }
        set {
            switch trait {
            case .ER: ER = newValue
            case .XP: XP = newValue
            case .SF: SF = newValue
            case .HD: HD = newValue
            case .ID: ID = newValue
            case .FT: FT = newValue
            case .UB: UB = newValue
            case .MB: MB = newValue
            }
        }
    }

    static let zero = OnboardingPersonalityTraitVector()
}

func + (lhs: OnboardingPersonalityTraitVector, rhs: OnboardingPersonalityTraitVector) -> OnboardingPersonalityTraitVector {
    .init(
        ER: lhs.ER + rhs.ER,
        XP: lhs.XP + rhs.XP,
        SF: lhs.SF + rhs.SF,
        HD: lhs.HD + rhs.HD,
        ID: lhs.ID + rhs.ID,
        FT: lhs.FT + rhs.FT,
        UB: lhs.UB + rhs.UB,
        MB: lhs.MB + rhs.MB
    )
}

func += (lhs: inout OnboardingPersonalityTraitVector, rhs: OnboardingPersonalityTraitVector) {
    lhs = lhs + rhs
}

func / (lhs: OnboardingPersonalityTraitVector, rhs: Double) -> OnboardingPersonalityTraitVector {
    guard rhs != 0 else { return .zero }
    return .init(
        ER: lhs.ER / rhs,
        XP: lhs.XP / rhs,
        SF: lhs.SF / rhs,
        HD: lhs.HD / rhs,
        ID: lhs.ID / rhs,
        FT: lhs.FT / rhs,
        UB: lhs.UB / rhs,
        MB: lhs.MB / rhs
    )
}

func * (lhs: Double, rhs: OnboardingPersonalityTraitVector) -> OnboardingPersonalityTraitVector {
    .init(
        ER: lhs * rhs.ER,
        XP: lhs * rhs.XP,
        SF: lhs * rhs.SF,
        HD: lhs * rhs.HD,
        ID: lhs * rhs.ID,
        FT: lhs * rhs.FT,
        UB: lhs * rhs.UB,
        MB: lhs * rhs.MB
    )
}

func * (lhs: OnboardingPersonalityTraitVector, rhs: Double) -> OnboardingPersonalityTraitVector {
    rhs * lhs
}

enum OnboardingCanonicalLifeArea: String, CaseIterable, Codable, Sendable {
    case careerBusiness = "Career & Business"
    case faithSpirituality = "Faith & Spirituality"
    case wealthFinance = "Wealth & Finance"
    case learningEducation = "Learning & Education"
    case loveRelationships = "Love & Relationships"
    case healthEnergy = "Health & Energy"
    case lifestyleExperiences = "Lifestyle & Experiences"
    case mindsetResilience = "Mindset & Resilience"
    case serviceImpact = "Service & Impact"
    case homeLife = "Home & Life"
}

enum OnboardingStressSourceAnswer: String, CaseIterable, Codable, Sendable {
    case tooManyPrioritiesCompeting = "Too many priorities competing"
    case feelingBehindOrDisorganized = "Feeling behind or disorganized"
    case distractionsAreStealingMyFocus = "Distractions are stealing my focus"
    case workPressure = "Work pressure"
    case moneyPressure = "Money pressure"
    case lowEnergyHealth = "Low energy / health"
    case relationshipTension = "Relationship tension"
    case notSureYet = "Not sure yet"

    init?(matching raw: String) {
        let normalized = Self.normalize(raw)
        switch normalized {
        case Self.normalize("Too many priorities competing"): self = .tooManyPrioritiesCompeting
        case Self.normalize("Feeling behind or disorganized"): self = .feelingBehindOrDisorganized
        case Self.normalize("Distractions are stealing my focus"): self = .distractionsAreStealingMyFocus
        case Self.normalize("Work pressure"): self = .workPressure
        case Self.normalize("Money pressure"): self = .moneyPressure
        case Self.normalize("Low energy / health"): self = .lowEnergyHealth
        case Self.normalize("Relationship tension"): self = .relationshipTension
        case Self.normalize("Not sure yet"): self = .notSureYet
        default: return nil
        }
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "’", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum OnboardingBreakPointAnswer: String, CaseIterable, Codable, Sendable {
    case dontStart = "I don’t start"
    case loseMomentum = "I start, then lose momentum"
    case getDistracted = "I get distracted"
    case overthinkIt = "I overthink it"
    case dontFinish = "I don’t finish what I start"
    case notSure = "I’m not sure"

    init?(matching raw: String) {
        let normalized = Self.normalize(raw)
        switch normalized {
        case Self.normalize("I don’t start"), Self.normalize("I don't start"): self = .dontStart
        case Self.normalize("I start, then lose momentum"): self = .loseMomentum
        case Self.normalize("I get distracted"): self = .getDistracted
        case Self.normalize("I overthink it"): self = .overthinkIt
        case Self.normalize("I don’t finish what I start"), Self.normalize("I don't finish what I start"): self = .dontFinish
        case Self.normalize("I’m not sure"), Self.normalize("I'm not sure"): self = .notSure
        default: return nil
        }
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "’", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum OnboardingPlanningRealityAnswer: String, CaseIterable, Codable, Sendable {
    case reactToUrgent = "React to what’s urgent"
    case simpleTodo = "Keep a simple to-do list"
    case planButOffTrack = "Plan, but get off track"
    case planAndFollowThrough = "Plan and follow through consistently"
    case dependsOnDay = "It depends on the day"

    init?(matching raw: String) {
        let normalized = Self.normalize(raw)
        switch normalized {
        case Self.normalize("React to what’s urgent"), Self.normalize("React to what's urgent"): self = .reactToUrgent
        case Self.normalize("Keep a simple to-do list"): self = .simpleTodo
        case Self.normalize("Plan, but get off track"): self = .planButOffTrack
        case Self.normalize("Plan and follow through consistently"): self = .planAndFollowThrough
        case Self.normalize("It depends on the day"): self = .dependsOnDay
        default: return nil
        }
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "’", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum OnboardingDesiredChangeAnswer: String, CaseIterable, Codable, Sendable {
    case inControl = "I feel in control (less stress)"
    case clearDirection = "I know what matters (clear direction)"
    case followThrough = "I follow through (consistency)"
    case fasterProgress = "I make faster progress on big goals"
    case balancedLife = "I feel balanced across life"

    init?(matching raw: String) {
        let normalized = Self.normalize(raw)
        switch normalized {
        case Self.normalize("I feel in control (less stress)"): self = .inControl
        case Self.normalize("I know what matters (clear direction)"): self = .clearDirection
        case Self.normalize("I follow through (consistency)"): self = .followThrough
        case Self.normalize("I make faster progress on big goals"): self = .fasterProgress
        case Self.normalize("I feel balanced across life"): self = .balancedLife
        default: return nil
        }
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "’", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct OnboardingQuestionnaireResponses: Codable, Hashable, Sendable {
    var stressSource: OnboardingStressSourceAnswer
    var breakPoint: OnboardingBreakPointAnswer
    var selectedAreas: [String]
    var planningReality: OnboardingPlanningRealityAnswer
    var desiredChange: OnboardingDesiredChangeAnswer

    init(
        stressSource: OnboardingStressSourceAnswer,
        breakPoint: OnboardingBreakPointAnswer,
        selectedAreas: [String],
        planningReality: OnboardingPlanningRealityAnswer,
        desiredChange: OnboardingDesiredChangeAnswer
    ) {
        self.stressSource = stressSource
        self.breakPoint = breakPoint
        self.selectedAreas = selectedAreas
        self.planningReality = planningReality
        self.desiredChange = desiredChange
    }

    init?(
        stressSource: String,
        breakPoint: String,
        selectedAreas: [String],
        planningReality: String,
        desiredChange: String
    ) {
        guard
            let q1 = OnboardingStressSourceAnswer(matching: stressSource),
            let q2 = OnboardingBreakPointAnswer(matching: breakPoint),
            let q4 = OnboardingPlanningRealityAnswer(matching: planningReality),
            let q5 = OnboardingDesiredChangeAnswer(matching: desiredChange)
        else {
            return nil
        }
        self.init(
            stressSource: q1,
            breakPoint: q2,
            selectedAreas: selectedAreas,
            planningReality: q4,
            desiredChange: q5
        )
    }
}

enum LoomPersonalityProfileID: String, CaseIterable, Codable, Sendable {
    case strategicIntegrator = "P1_StrategicIntegrator"
    case structuredClarityDriver = "P2_StructuredClarityDriver"
    case adaptiveCatalyst = "P3_AdaptiveCatalyst"
    case rapidExperimenter = "P4_RapidExperimenter"
    case momentumBuilder = "P5_MomentumBuilder"
    case operationalCommander = "P6_OperationalCommander"
    case adaptiveStabilizer = "P7_AdaptiveStabilizer"
    case crisisNavigator = "P8_CrisisNavigator"
    case purposeLedPlanner = "P9_PurposeLedPlanner"
    case analyticalArchitect = "P10_AnalyticalArchitect"
    case reflectiveSynthesizer = "P11_ReflectiveSynthesizer"
    case independentPathfinder = "P12_IndependentPathfinder"
    case steadyAlignmentBuilder = "P13_SteadyAlignmentBuilder"
    case qualitySentinel = "P14_QualitySentinel"
    case supportiveAdapter = "P15_SupportiveAdapter"
    case pragmaticRealist = "P16_PragmaticRealist"

    var numericID: Int {
        switch self {
        case .strategicIntegrator: return 1
        case .structuredClarityDriver: return 2
        case .adaptiveCatalyst: return 3
        case .rapidExperimenter: return 4
        case .momentumBuilder: return 5
        case .operationalCommander: return 6
        case .adaptiveStabilizer: return 7
        case .crisisNavigator: return 8
        case .purposeLedPlanner: return 9
        case .analyticalArchitect: return 10
        case .reflectiveSynthesizer: return 11
        case .independentPathfinder: return 12
        case .steadyAlignmentBuilder: return 13
        case .qualitySentinel: return 14
        case .supportiveAdapter: return 15
        case .pragmaticRealist: return 16
        }
    }

    var profileName: String {
        switch self {
        case .strategicIntegrator: return "Strategic Integrator"
        case .structuredClarityDriver: return "Structured Clarity Driver"
        case .adaptiveCatalyst: return "Adaptive Catalyst"
        case .rapidExperimenter: return "Rapid Experimenter"
        case .momentumBuilder: return "Momentum Builder"
        case .operationalCommander: return "Operational Commander"
        case .adaptiveStabilizer: return "Adaptive Stabilizer"
        case .crisisNavigator: return "Crisis Navigator"
        case .purposeLedPlanner: return "Purpose-Led Planner"
        case .analyticalArchitect: return "Analytical Architect"
        case .reflectiveSynthesizer: return "Reflective Synthesizer"
        case .independentPathfinder: return "Independent Pathfinder"
        case .steadyAlignmentBuilder: return "Steady Alignment Builder"
        case .qualitySentinel: return "Quality Sentinel"
        case .supportiveAdapter: return "Supportive Adapter"
        case .pragmaticRealist: return "Pragmatic Realist"
        }
    }
}

struct OnboardingProfileProbability: Codable, Hashable, Sendable {
    var profileID: LoomPersonalityProfileID
    var profileName: String
    var probability: Double
}

struct OnboardingRankedProfile: Codable, Hashable, Sendable {
    var profileID: LoomPersonalityProfileID
    var profileName: String
    var rawScore: Double
    var probability: Double
    var directBonus: Double
}

struct OnboardingProfileScoreBreakdown: Codable, Hashable, Sendable {
    var profileID: LoomPersonalityProfileID
    var profileName: String
    var baseMatch: Double
    var directBonus: Double
    var calibrationOffset: Double
    var rawScore: Double
}

struct OnboardingPersonalityMatchResult: Codable, Hashable, Sendable {
    var winner: OnboardingRankedProfile
    var winnerScore: Double
    var topProfiles: [OnboardingRankedProfile]
    var rankedProfiles: [OnboardingRankedProfile]
    var normalizedTraits: OnboardingPersonalityTraitVector
    var rawTraits: OnboardingPersonalityTraitVector
    var probabilities: [OnboardingProfileProbability]
    var confidence: Double
    var lowConfidence: Bool
    var scoreBreakdowns: [OnboardingProfileScoreBreakdown]
}

enum OnboardingPersonalityMatcher {
    private static let tau = 0.70

    static func match(responses: OnboardingQuestionnaireResponses) -> OnboardingPersonalityMatchResult {
        let rawTraits = rawTraitVector(for: responses)
        let normalizedTraits = normalizedTraitVector(from: rawTraits)
        let scoreBreakdowns = allScoreBreakdowns(normalizedTraits: normalizedTraits, responses: responses)
        let orderedBreakdowns = orderedScoreBreakdowns(
            scoreBreakdowns,
            normalizedTraits: normalizedTraits,
            rawTraits: rawTraits,
            responses: responses
        )
        let rawScoreOrdered = scoreBreakdowns.sorted {
            if abs($0.rawScore - $1.rawScore) > 0.0001 {
                return $0.rawScore > $1.rawScore
            }
            return $0.profileID.numericID < $1.profileID.numericID
        }
        let probabilities = softmaxProbabilities(from: scoreBreakdowns)
        let probabilityByProfile = Dictionary(uniqueKeysWithValues: probabilities.map { ($0.profileID, $0.probability) })
        let rankedProfiles = orderedBreakdowns.map { breakdown in
            OnboardingRankedProfile(
                profileID: breakdown.profileID,
                profileName: breakdown.profileName,
                rawScore: breakdown.rawScore,
                probability: probabilityByProfile[breakdown.profileID] ?? 0,
                directBonus: breakdown.directBonus
            )
        }
        let winner = rankedProfiles.first ?? OnboardingRankedProfile(
            profileID: .steadyAlignmentBuilder,
            profileName: LoomPersonalityProfileID.steadyAlignmentBuilder.profileName,
            rawScore: 0,
            probability: 0,
            directBonus: 0
        )
        let topRawScore = rawScoreOrdered.first?.rawScore ?? winner.rawScore
        let secondScore = rawScoreOrdered.dropFirst().first?.rawScore ?? topRawScore
        let confidence = confidenceScore(
            topRawScore: topRawScore,
            secondRawScore: secondScore,
            probabilities: probabilities,
            responses: responses
        )
        let lowConfidence = confidence < 0.52 || (topRawScore - secondScore) < 0.25

        return OnboardingPersonalityMatchResult(
            winner: winner,
            winnerScore: winner.rawScore,
            topProfiles: Array(rankedProfiles.prefix(3)),
            rankedProfiles: rankedProfiles,
            normalizedTraits: normalizedTraits,
            rawTraits: rawTraits,
            probabilities: probabilities,
            confidence: confidence,
            lowConfidence: lowConfidence,
            scoreBreakdowns: orderedBreakdowns
        )
    }

    static func match(
        stressSource: String,
        breakPoint: String,
        selectedAreas: [String],
        planningReality: String,
        desiredChange: String
    ) -> OnboardingPersonalityMatchResult? {
        guard let responses = OnboardingQuestionnaireResponses(
            stressSource: stressSource,
            breakPoint: breakPoint,
            selectedAreas: selectedAreas,
            planningReality: planningReality,
            desiredChange: desiredChange
        ) else {
            return nil
        }
        return match(responses: responses)
    }

    static func rawTraitVector(for responses: OnboardingQuestionnaireResponses) -> OnboardingPersonalityTraitVector {
        questionTraitDeltasQ1[responses.stressSource, default: .zero]
            + questionTraitDeltasQ2[responses.breakPoint, default: .zero]
            + questionTraitDeltasQ4[responses.planningReality, default: .zero]
            + questionTraitDeltasQ5[responses.desiredChange, default: .zero]
            + lifeAreaContribution(for: responses.selectedAreas)
    }

    static func normalizedTraitVector(from rawTraits: OnboardingPersonalityTraitVector) -> OnboardingPersonalityTraitVector {
        var normalized = OnboardingPersonalityTraitVector.zero
        for trait in OnboardingPersonalityTrait.allCases {
            let denom = denominators[trait, default: 1]
            normalized[trait] = clamp(rawTraits[trait] / denom, min: -1, max: 1)
        }
        return normalized
    }

    static func lifeAreaContribution(for selectedAreas: [String]) -> OnboardingPersonalityTraitVector {
        guard !selectedAreas.isEmpty else { return .zero }
        let vectors = selectedAreas.map(vectorForSelectedArea)
        let mean = vectors.reduce(.zero, +) / Double(vectors.count)
        var contribution = 1.25 * mean
        let breadth = max(0, selectedAreas.count - 3)
        contribution.HD += 0.05 * Double(breadth)
        contribution.MB += 0.10 * Double(breadth)
        return contribution
    }

    static func customAreaVector(for input: String) -> OnboardingPersonalityTraitVector {
        let normalized = normalizedCustomAreaText(input)
        guard !normalized.isEmpty else { return .zero }

        let scoredAreas = OnboardingCanonicalLifeArea.allCases.compactMap { area -> (OnboardingCanonicalLifeArea, Int)? in
            let keywords = areaKeywords[area, default: []]
            let hits = keywords.reduce(into: 0) { partial, keyword in
                if normalized.contains(keyword) {
                    partial += 1
                }
            }
            return hits > 0 ? (area, hits) : nil
        }
        .sorted {
            if $0.1 != $1.1 { return $0.1 > $1.1 }
            return $0.0.rawValue < $1.0.rawValue
        }

        guard let best = scoredAreas.first else { return .zero }
        if scoredAreas.count > 1 {
            let second = scoredAreas[1]
            if best.1 - second.1 <= 1, second.1 > 0 {
                let average = (areaVectors[best.0, default: .zero] + areaVectors[second.0, default: .zero]) / 2
                return 0.75 * average
            }
        }
        return 0.75 * areaVectors[best.0, default: .zero]
    }

    static func tieBreakWinner(
        first: OnboardingProfileScoreBreakdown,
        second: OnboardingProfileScoreBreakdown,
        normalizedTraits: OnboardingPersonalityTraitVector,
        rawTraits: OnboardingPersonalityTraitVector,
        responses: OnboardingQuestionnaireResponses
    ) -> LoomPersonalityProfileID {
        if let winner = mostEvidencedTraitWinner(
            first: first.profileID,
            second: second.profileID,
            normalizedTraits: normalizedTraits,
            rawTraits: rawTraits
        ) {
            return winner
        }

        if abs(first.directBonus - second.directBonus) > 0.0001 {
            return first.directBonus > second.directBonus ? first.profileID : second.profileID
        }

        let prefersMeaningBalance = responses.selectedAreas.count >= 5 || responses.desiredChange == .balancedLife
        let focusTrait: OnboardingPersonalityTrait = prefersMeaningBalance ? .MB : .FT
        let firstDistance = abs(normalizedTraits[focusTrait] - profileCentroids[first.profileID, default: .zero][focusTrait])
        let secondDistance = abs(normalizedTraits[focusTrait] - profileCentroids[second.profileID, default: .zero][focusTrait])
        if abs(firstDistance - secondDistance) > 0.0001 {
            return firstDistance < secondDistance ? first.profileID : second.profileID
        }

        return first.profileID.numericID <= second.profileID.numericID ? first.profileID : second.profileID
    }

    private static func allScoreBreakdowns(
        normalizedTraits: OnboardingPersonalityTraitVector,
        responses: OnboardingQuestionnaireResponses
    ) -> [OnboardingProfileScoreBreakdown] {
        LoomPersonalityProfileID.allCases.map { profileID in
            let baseMatch = baseProfileMatch(profileID: profileID, normalizedTraits: normalizedTraits)
            let directBonus = directBonus(profileID: profileID, responses: responses)
            let calibrationOffset = calibrationOffsets[profileID, default: 0]
            return OnboardingProfileScoreBreakdown(
                profileID: profileID,
                profileName: profileID.profileName,
                baseMatch: baseMatch,
                directBonus: directBonus,
                calibrationOffset: calibrationOffset,
                rawScore: baseMatch + directBonus + calibrationOffset
            )
        }
    }

    private static func orderedScoreBreakdowns(
        _ scoreBreakdowns: [OnboardingProfileScoreBreakdown],
        normalizedTraits: OnboardingPersonalityTraitVector,
        rawTraits: OnboardingPersonalityTraitVector,
        responses: OnboardingQuestionnaireResponses
    ) -> [OnboardingProfileScoreBreakdown] {
        var ordered = scoreBreakdowns.sorted {
            if abs($0.rawScore - $1.rawScore) > 0.0001 {
                return $0.rawScore > $1.rawScore
            }
            return $0.profileID.numericID < $1.profileID.numericID
        }

        guard ordered.count >= 2 else { return ordered }
        if abs(ordered[0].rawScore - ordered[1].rawScore) < 0.15 {
            let winner = tieBreakWinner(
                first: ordered[0],
                second: ordered[1],
                normalizedTraits: normalizedTraits,
                rawTraits: rawTraits,
                responses: responses
            )
            if winner == ordered[1].profileID {
                ordered.swapAt(0, 1)
            }
        }
        return ordered
    }

    private static func mostEvidencedTraitWinner(
        first: LoomPersonalityProfileID,
        second: LoomPersonalityProfileID,
        normalizedTraits: OnboardingPersonalityTraitVector,
        rawTraits: OnboardingPersonalityTraitVector
    ) -> LoomPersonalityProfileID? {
        let firstCentroid = profileCentroids[first, default: .zero]
        let secondCentroid = profileCentroids[second, default: .zero]
        let differingTraits = OnboardingPersonalityTrait.allCases.filter { firstCentroid[$0] != secondCentroid[$0] }
        guard !differingTraits.isEmpty else { return nil }

        let selectedTrait = differingTraits.max { lhs, rhs in
            let lhsEvidence = min(1, abs(rawTraits[lhs]) / denominators[lhs, default: 1]) * traitWeights[lhs, default: 1]
            let rhsEvidence = min(1, abs(rawTraits[rhs]) / denominators[rhs, default: 1]) * traitWeights[rhs, default: 1]
            if abs(lhsEvidence - rhsEvidence) > 0.0001 {
                return lhsEvidence < rhsEvidence
            }
            return lhs.rawValue > rhs.rawValue
        }
        guard let trait = selectedTrait else { return nil }

        let firstDistance = abs(normalizedTraits[trait] - firstCentroid[trait])
        let secondDistance = abs(normalizedTraits[trait] - secondCentroid[trait])
        if abs(firstDistance - secondDistance) <= 0.0001 {
            return nil
        }
        return firstDistance < secondDistance ? first : second
    }

    private static func confidenceScore(
        topRawScore: Double,
        secondRawScore: Double,
        probabilities: [OnboardingProfileProbability],
        responses: OnboardingQuestionnaireResponses
    ) -> Double {
        let marginNorm = clamp((topRawScore - secondRawScore) / 0.75, min: 0, max: 1)
        let fitNorm = clamp(topRawScore / 9.70, min: 0, max: 1)

        let entropy = -probabilities.reduce(0) { partial, item in
            guard item.probability > 0 else { return partial }
            return partial + (item.probability * log(item.probability))
        }
        let entropyNorm = 1 - (entropy / log(16))

        var unsurePenalty = 0.0
        if responses.stressSource == .notSureYet { unsurePenalty += 0.08 }
        if responses.breakPoint == .notSure { unsurePenalty += 0.08 }
        if responses.planningReality == .dependsOnDay { unsurePenalty += 0.04 }

        var contradictionPenalty = 0.0
        if responses.planningReality == .planAndFollowThrough,
           [.loseMomentum, .getDistracted, .dontFinish].contains(responses.breakPoint) {
            contradictionPenalty += 0.10
        }

        return clamp(
            0.45 * marginNorm +
            0.35 * entropyNorm +
            0.20 * fitNorm -
            unsurePenalty -
            contradictionPenalty,
            min: 0,
            max: 1
        )
    }

    private static func softmaxProbabilities(from scoreBreakdowns: [OnboardingProfileScoreBreakdown]) -> [OnboardingProfileProbability] {
        guard let maxScore = scoreBreakdowns.map(\.rawScore).max() else { return [] }
        let exponents = scoreBreakdowns.map { breakdown in
            exp((breakdown.rawScore - maxScore) / tau)
        }
        let denominator = exponents.reduce(0, +)
        return zip(scoreBreakdowns, exponents).map { breakdown, exponent in
            OnboardingProfileProbability(
                profileID: breakdown.profileID,
                profileName: breakdown.profileName,
                probability: denominator == 0 ? 0 : exponent / denominator
            )
        }
        .sorted {
            if abs($0.probability - $1.probability) > 0.0000001 {
                return $0.probability > $1.probability
            }
            return $0.profileID.numericID < $1.profileID.numericID
        }
    }

    private static func vectorForSelectedArea(_ area: String) -> OnboardingPersonalityTraitVector {
        if let canonical = OnboardingCanonicalLifeArea.allCases.first(where: {
            $0.rawValue.caseInsensitiveCompare(area.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
        }) {
            return areaVectors[canonical, default: .zero]
        }
        return customAreaVector(for: area)
    }

    private static func baseProfileMatch(
        profileID: LoomPersonalityProfileID,
        normalizedTraits: OnboardingPersonalityTraitVector
    ) -> Double {
        let centroid = profileCentroids[profileID, default: .zero]
        return OnboardingPersonalityTrait.allCases.reduce(0) { partial, trait in
            partial + traitWeights[trait, default: 1] * (1 - abs(normalizedTraits[trait] - centroid[trait]) / 2)
        }
    }

    private static func directBonus(
        profileID: LoomPersonalityProfileID,
        responses: OnboardingQuestionnaireResponses
    ) -> Double {
        let stressBonus = q1Bonus[responses.stressSource]?[profileID] ?? 0
        let breakBonus = q2Bonus[responses.breakPoint]?[profileID] ?? 0
        let planningBonus = q4Bonus[responses.planningReality]?[profileID] ?? 0
        let desiredBonus = q5Bonus[responses.desiredChange]?[profileID] ?? 0
        return stressBonus + breakBonus + planningBonus + desiredBonus
    }

    private static func normalizedCustomAreaText(_ value: String) -> String {
        let lowered = value.lowercased()
        let punctuation = CharacterSet.punctuationCharacters
        let scalars = lowered.unicodeScalars.map { punctuation.contains($0) ? " " : String($0) }.joined()
        return scalars.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func clamp(_ value: Double, min lower: Double, max upper: Double) -> Double {
        Swift.min(Swift.max(value, lower), upper)
    }

    private static func vec(
        _ ER: Double,
        _ XP: Double,
        _ SF: Double,
        _ HD: Double,
        _ ID: Double,
        _ FT: Double,
        _ UB: Double,
        _ MB: Double
    ) -> OnboardingPersonalityTraitVector {
        .init(ER: ER, XP: XP, SF: SF, HD: HD, ID: ID, FT: FT, UB: UB, MB: MB)
    }

    private static let denominators: [OnboardingPersonalityTrait: Double] = [
        .ER: 2.5, .XP: 4.5, .SF: 5.5, .HD: 4.5, .ID: 4.5, .FT: 5.5, .UB: 5.5, .MB: 5.5
    ]

    private static let traitWeights: [OnboardingPersonalityTrait: Double] = [
        .ER: 0.75, .XP: 1.00, .SF: 1.20, .HD: 0.80, .ID: 0.90, .FT: 1.10, .UB: 0.90, .MB: 0.90
    ]

    private static let areaVectors: [OnboardingCanonicalLifeArea: OnboardingPersonalityTraitVector] = [
        .careerBusiness: vec(0.4, -0.1, 0.7, -0.1, 0.3, 0.4, 0.5, -0.6),
        .faithSpirituality: vec(-0.2, 0.5, 0.1, 0.8, -0.1, 0.1, -0.5, 1.1),
        .wealthFinance: vec(-0.1, -0.7, 0.8, -0.1, 0.2, 0.4, 0.3, -0.9),
        .learningEducation: vec(-0.2, 1.0, 0.3, 0.0, 0.1, 0.1, -0.2, 0.3),
        .loveRelationships: vec(0.2, 0.0, 0.1, 1.1, 0.0, 0.1, -0.3, 1.0),
        .healthEnergy: vec(-0.1, -0.1, 0.6, 0.2, 0.2, 0.7, -0.2, 0.8),
        .lifestyleExperiences: vec(0.6, 0.7, -0.5, 0.3, 0.4, -0.1, 0.2, 0.5),
        .mindsetResilience: vec(-0.1, 0.3, 0.4, 0.4, 0.1, 0.4, -0.2, 0.9),
        .serviceImpact: vec(0.1, 0.2, 0.2, 0.9, 0.0, 0.2, -0.2, 1.0),
        .homeLife: vec(-0.1, -0.3, 0.8, 0.3, 0.1, 0.5, -0.2, 0.6)
    ]

    private static let areaKeywords: [OnboardingCanonicalLifeArea: [String]] = [
        .careerBusiness: ["career", "business", "work", "job", "profession", "promotion", "leadership", "entrepreneur", "company"],
        .faithSpirituality: ["faith", "spiritual", "spirituality", "religion", "god", "prayer", "church", "soul", "sacred"],
        .wealthFinance: ["wealth", "finance", "financial", "money", "budget", "saving", "savings", "invest", "investing", "debt", "income"],
        .learningEducation: ["learning", "education", "study", "studying", "school", "college", "read", "reading", "skill", "skills", "knowledge"],
        .loveRelationships: ["love", "relationship", "relationships", "marriage", "dating", "partner", "spouse", "family", "friend", "friends", "connection"],
        .healthEnergy: ["health", "fitness", "exercise", "workout", "sleep", "nutrition", "diet", "energy", "wellness", "recovery"],
        .lifestyleExperiences: ["lifestyle", "travel", "fun", "adventure", "experience", "experiences", "hobby", "hobbies", "leisure"],
        .mindsetResilience: ["mindset", "resilience", "confidence", "stress", "discipline", "focus", "clarity", "mental", "emotion", "emotional"],
        .serviceImpact: ["service", "impact", "community", "volunteer", "volunteering", "mentor", "mentoring", "mission", "cause", "contribution"],
        .homeLife: ["home", "house", "household", "routine", "organization", "organizing", "chores", "clean", "life", "admin"]
    ]

    private static let questionTraitDeltasQ1: [OnboardingStressSourceAnswer: OnboardingPersonalityTraitVector] = [
        .tooManyPrioritiesCompeting: vec(0.2, 0.2, 1.4, 0.6, -0.2, -0.3, 0.2, 0.3),
        .feelingBehindOrDisorganized: vec(-0.1, -0.2, 1.6, 0.0, -0.5, -0.8, 0.5, 0.0),
        .distractionsAreStealingMyFocus: vec(0.1, 0.4, 1.1, 0.0, -0.2, -0.7, 0.4, -0.1),
        .workPressure: vec(0.4, -0.2, 0.5, -0.2, 0.2, 0.0, 1.1, -0.7),
        .moneyPressure: vec(-0.2, -0.8, 0.9, -0.1, 0.1, 0.2, 0.8, -1.0),
        .lowEnergyHealth: vec(-0.4, -0.2, 0.3, 0.2, -1.0, -0.6, 0.2, 0.8),
        .relationshipTension: vec(0.1, 0.0, 0.2, 1.6, -0.3, -0.2, 0.4, 1.0),
        .notSureYet: vec(-0.2, 0.3, -0.1, 0.0, -0.2, -0.2, 0.0, 0.1)
    ]

    private static let questionTraitDeltasQ2: [OnboardingBreakPointAnswer: OnboardingPersonalityTraitVector] = [
        .dontStart: vec(-0.3, 0.2, 0.3, 0.2, -1.6, -0.5, -0.4, 0.2),
        .loseMomentum: vec(0.2, 0.3, -0.3, 0.0, 0.4, -1.4, 0.1, 0.0),
        .getDistracted: vec(0.2, 0.6, -0.6, 0.0, 0.1, -1.1, 0.3, -0.1),
        .overthinkIt: vec(-0.4, 0.8, 0.4, 0.0, -1.0, -0.3, -0.5, 0.2),
        .dontFinish: vec(0.3, 0.5, -0.7, -0.1, 0.5, -1.5, 0.2, -0.2),
        .notSure: vec(0.0, 0.0, 0.0, 0.0, -0.3, -0.3, 0.0, 0.0)
    ]

    private static let questionTraitDeltasQ4: [OnboardingPlanningRealityAnswer: OnboardingPersonalityTraitVector] = [
        .reactToUrgent: vec(0.2, -0.4, -0.8, -0.2, 0.3, -0.2, 1.6, -0.6),
        .simpleTodo: vec(-0.1, -0.2, 0.7, 0.0, 0.2, 0.4, -0.1, 0.0),
        .planButOffTrack: vec(0.0, 0.0, 0.2, 0.0, 0.1, -0.9, 0.4, 0.0),
        .planAndFollowThrough: vec(0.0, -0.1, 1.4, 0.0, 0.5, 1.5, -0.4, 0.1),
        .dependsOnDay: vec(0.0, 0.2, -0.2, 0.1, 0.0, -0.2, 0.2, 0.1)
    ]

    private static let questionTraitDeltasQ5: [OnboardingDesiredChangeAnswer: OnboardingPersonalityTraitVector] = [
        .inControl: vec(0.0, -0.2, 0.9, 0.2, 0.1, 0.4, -0.4, 0.5),
        .clearDirection: vec(-0.1, 0.5, 1.0, 0.0, 0.1, 0.2, -0.3, 0.4),
        .followThrough: vec(0.0, -0.2, 0.7, 0.0, 0.2, 1.4, -0.2, 0.1),
        .fasterProgress: vec(0.2, 0.1, 0.4, -0.3, 0.5, 0.6, 0.6, -0.8),
        .balancedLife: vec(0.0, 0.0, 0.3, 0.8, 0.0, 0.2, -0.5, 1.3)
    ]

    private static let profileCentroids: [LoomPersonalityProfileID: OnboardingPersonalityTraitVector] = [
        .strategicIntegrator: vec(1.0, 1.0, 1.0, 1.0, 0.2, 0.6, -0.1, 0.4),
        .structuredClarityDriver: vec(1.0, 1.0, 1.0, -1.0, 0.4, 0.7, 0.1, -0.2),
        .adaptiveCatalyst: vec(1.0, 1.0, -1.0, 1.0, 0.8, -0.4, 0.1, 0.3),
        .rapidExperimenter: vec(1.0, 1.0, -1.0, -1.0, 1.0, -0.5, 0.4, -0.4),
        .momentumBuilder: vec(1.0, -1.0, 1.0, 1.0, 0.5, 0.8, -0.1, 0.4),
        .operationalCommander: vec(1.0, -1.0, 1.0, -1.0, 0.7, 0.9, 0.4, -0.5),
        .adaptiveStabilizer: vec(1.0, -1.0, -1.0, 1.0, 0.5, 0.1, 0.4, 0.5),
        .crisisNavigator: vec(1.0, -1.0, -1.0, -1.0, 0.9, 0.0, 1.0, -0.7),
        .purposeLedPlanner: vec(-1.0, 1.0, 1.0, 1.0, -0.5, 0.6, -0.7, 1.0),
        .analyticalArchitect: vec(-1.0, 1.0, 1.0, -1.0, -0.1, 0.7, -0.5, -0.2),
        .reflectiveSynthesizer: vec(-1.0, 1.0, -1.0, 1.0, -0.2, -0.3, -0.7, 0.7),
        .independentPathfinder: vec(-1.0, 1.0, -1.0, -1.0, 0.5, -0.2, -0.2, -0.1),
        .steadyAlignmentBuilder: vec(-1.0, -1.0, 1.0, 1.0, 0.1, 0.8, -0.4, 0.8),
        .qualitySentinel: vec(-1.0, -1.0, 1.0, -1.0, 0.2, 0.8, -0.2, -0.3),
        .supportiveAdapter: vec(-1.0, -1.0, -1.0, 1.0, -0.1, 0.0, -0.1, 0.9),
        .pragmaticRealist: vec(-1.0, -1.0, -1.0, -1.0, 0.4, 0.1, 0.3, -0.6)
    ]

    private static let calibrationOffsets: [LoomPersonalityProfileID: Double] =
        Dictionary(uniqueKeysWithValues: LoomPersonalityProfileID.allCases.map { ($0, 0.0) })

    private static let q1Bonus: [OnboardingStressSourceAnswer: [LoomPersonalityProfileID: Double]] = [
        .tooManyPrioritiesCompeting: [.strategicIntegrator: 0.50, .momentumBuilder: 0.35, .adaptiveStabilizer: 0.35, .purposeLedPlanner: 0.25],
        .feelingBehindOrDisorganized: [.momentumBuilder: 0.40, .steadyAlignmentBuilder: 0.35, .qualitySentinel: 0.35, .operationalCommander: 0.20],
        .distractionsAreStealingMyFocus: [.purposeLedPlanner: 0.35, .analyticalArchitect: 0.35, .structuredClarityDriver: 0.25, .qualitySentinel: 0.25],
        .workPressure: [.operationalCommander: 0.45, .crisisNavigator: 0.50, .pragmaticRealist: 0.35, .momentumBuilder: 0.25],
        .moneyPressure: [.qualitySentinel: 0.40, .pragmaticRealist: 0.45, .operationalCommander: 0.30, .steadyAlignmentBuilder: 0.20],
        .lowEnergyHealth: [.supportiveAdapter: 0.40, .steadyAlignmentBuilder: 0.30, .purposeLedPlanner: 0.30, .adaptiveStabilizer: 0.25],
        .relationshipTension: [.steadyAlignmentBuilder: 0.45, .supportiveAdapter: 0.45, .strategicIntegrator: 0.30, .adaptiveStabilizer: 0.35],
        .notSureYet: [.reflectiveSynthesizer: 0.25, .independentPathfinder: 0.25, .adaptiveCatalyst: 0.20, .purposeLedPlanner: 0.15]
    ]

    private static let q2Bonus: [OnboardingBreakPointAnswer: [LoomPersonalityProfileID: Double]] = [
        .dontStart: [.purposeLedPlanner: 0.55, .analyticalArchitect: 0.40, .reflectiveSynthesizer: 0.35, .qualitySentinel: 0.25],
        .loseMomentum: [.adaptiveCatalyst: 0.55, .adaptiveStabilizer: 0.40, .reflectiveSynthesizer: 0.35, .supportiveAdapter: 0.25],
        .getDistracted: [.rapidExperimenter: 0.45, .adaptiveCatalyst: 0.35, .independentPathfinder: 0.35, .crisisNavigator: 0.20],
        .overthinkIt: [.analyticalArchitect: 0.55, .purposeLedPlanner: 0.45, .reflectiveSynthesizer: 0.40, .qualitySentinel: 0.25],
        .dontFinish: [.rapidExperimenter: 0.45, .adaptiveCatalyst: 0.40, .independentPathfinder: 0.35, .reflectiveSynthesizer: 0.30],
        .notSure: [.reflectiveSynthesizer: 0.15, .supportiveAdapter: 0.15]
    ]

    private static let q4Bonus: [OnboardingPlanningRealityAnswer: [LoomPersonalityProfileID: Double]] = [
        .reactToUrgent: [.crisisNavigator: 0.60, .pragmaticRealist: 0.35, .adaptiveStabilizer: 0.25, .operationalCommander: 0.25],
        .simpleTodo: [.steadyAlignmentBuilder: 0.30, .supportiveAdapter: 0.25, .qualitySentinel: 0.25, .pragmaticRealist: 0.20],
        .planButOffTrack: [.adaptiveCatalyst: 0.35, .adaptiveStabilizer: 0.35, .reflectiveSynthesizer: 0.25, .purposeLedPlanner: 0.20],
        .planAndFollowThrough: [.momentumBuilder: 0.45, .operationalCommander: 0.45, .steadyAlignmentBuilder: 0.35, .qualitySentinel: 0.35],
        .dependsOnDay: [.adaptiveStabilizer: 0.30, .supportiveAdapter: 0.30, .reflectiveSynthesizer: 0.25, .independentPathfinder: 0.20]
    ]

    private static let q5Bonus: [OnboardingDesiredChangeAnswer: [LoomPersonalityProfileID: Double]] = [
        .inControl: [.momentumBuilder: 0.35, .steadyAlignmentBuilder: 0.30, .qualitySentinel: 0.25, .purposeLedPlanner: 0.25],
        .clearDirection: [.structuredClarityDriver: 0.35, .purposeLedPlanner: 0.35, .analyticalArchitect: 0.30, .strategicIntegrator: 0.30],
        .followThrough: [.momentumBuilder: 0.35, .operationalCommander: 0.35, .steadyAlignmentBuilder: 0.30, .qualitySentinel: 0.30],
        .fasterProgress: [.structuredClarityDriver: 0.35, .rapidExperimenter: 0.35, .operationalCommander: 0.30, .crisisNavigator: 0.25],
        .balancedLife: [.supportiveAdapter: 0.40, .steadyAlignmentBuilder: 0.35, .strategicIntegrator: 0.30, .adaptiveStabilizer: 0.30, .purposeLedPlanner: 0.25]
    ]
}

extension OnboardingPersonalityMatchResult {
    var winnerRecord: PurposeProfileRecord {
        PurposeProfilesCatalog.record(named: winner.profileName) ?? PurposeProfilesCatalog.fallback()
    }

    var alternativeProfileNames: [String] {
        Array(topProfiles.dropFirst().map(\.profileName))
    }
}
