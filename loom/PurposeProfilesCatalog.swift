import Foundation

struct PurposeProfileRecord: Hashable, Sendable {
    let profile: String
    let strength: String
    let weakness: String
    let stressTrigger: String
    let breakingPoint: String
}

enum PurposeProfilesCatalog {
    private static let parsedRecords: [PurposeProfileRecord] = loadRecords()
    private static let builtInRecords: [PurposeProfileRecord] = [
        PurposeProfileRecord(
            profile: "Strategic Integrator",
            strength: "Translates ambitious direction into shared structure others can execute.",
            weakness: "Over-integration risk; excessive synthesis and stakeholder harmony can slow decisive tradeoffs.",
            stressTrigger: "Competing stakeholder priorities",
            breakingPoint: "Decision velocity (alignment continues past usefulness)"
        ),
        PurposeProfileRecord(
            profile: "Structured Clarity Driver",
            strength: "Forces clarity early and turns fuzzy ideas into sharp priorities and standards.",
            weakness: "May prematurely close exploration and create resistance if others feel bulldozed.",
            stressTrigger: "Ambiguity and slow consensus",
            breakingPoint: "Interpersonal smoothness (communication becomes blunt)"
        ),
        PurposeProfileRecord(
            profile: "Adaptive Catalyst",
            strength: "Generates momentum through experimentation and social energy.",
            weakness: "Follow-through can weaken when novelty fades without external structure.",
            stressTrigger: "Rigid plans and gatekeeping",
            breakingPoint: "Execution consistency (many starts, uneven finishes)"
        ),
        PurposeProfileRecord(
            profile: "Rapid Experimenter",
            strength: "Challenges assumptions quickly and converts uncertainty into data through action.",
            weakness: "Can create churn if direction changes too frequently.",
            stressTrigger: "Slow decision cycles",
            breakingPoint: "Context continuity (frequent pivots disrupt shared direction)"
        ),
        PurposeProfileRecord(
            profile: "Momentum Builder",
            strength: "Builds sustainable cadence through clear plans and human buy-in.",
            weakness: "May prioritize feasibility over bold upside.",
            stressTrigger: "Resource constraints and morale dips",
            breakingPoint: "Ambition (scope narrows to maintain stability)"
        ),
        PurposeProfileRecord(
            profile: "Operational Commander",
            strength: "Executes effectively under constraints; prioritizes, assigns, and enforces standards.",
            weakness: "Relationship debt accumulates if pressure becomes constant critique.",
            stressTrigger: "Missed commitments",
            breakingPoint: "Patience (tolerance for variance collapses)"
        ),
        PurposeProfileRecord(
            profile: "Adaptive Stabilizer",
            strength: "Maintains progress when conditions shift through flexible coordination.",
            weakness: "Absorbs too much responsibility and becomes an informal buffer.",
            stressTrigger: "Last-minute changes and interpersonal conflict",
            breakingPoint: "Boundary clarity (over-commitment reduces consistency)"
        ),
        PurposeProfileRecord(
            profile: "Crisis Navigator",
            strength: "Cuts through noise during chaos with strong triage and improvisation.",
            weakness: "Long-term systems may be neglected; urgency becomes the default mode.",
            stressTrigger: "Bureaucracy and slow escalation paths",
            breakingPoint: "Long-horizon planning (defaults to firefighting)"
        ),
        PurposeProfileRecord(
            profile: "Purpose-Led Planner",
            strength: "Maintains long-term direction through disciplined planning tied to values.",
            weakness: "Initiation friction; preparation can delay execution.",
            stressTrigger: "Noisy inputs and constant context switching",
            breakingPoint: "Start energy (stalling at launch)"
        ),
        PurposeProfileRecord(
            profile: "Analytical Architect",
            strength: "Builds rigorous systems and frameworks that withstand scrutiny.",
            weakness: "Under-communication can create misunderstanding.",
            stressTrigger: "Sloppy reasoning or vague definitions",
            breakingPoint: "Collaboration flow (withdraws rather than translating ideas)"
        ),
        PurposeProfileRecord(
            profile: "Reflective Synthesizer",
            strength: "Connects disparate ideas into coherent insight without seeking attention.",
            weakness: "Structure avoidance may prevent insights from becoming outcomes.",
            stressTrigger: "Tight deadlines and forced specificity",
            breakingPoint: "Deliverable packaging (refining replaces shipping)"
        ),
        PurposeProfileRecord(
            profile: "Independent Pathfinder",
            strength: "Explores difficult problems autonomously with high learning velocity.",
            weakness: "Independence may create coordination costs for teams.",
            stressTrigger: "Micromanagement",
            breakingPoint: "Team predictability (disappears into solo iteration)"
        ),
        PurposeProfileRecord(
            profile: "Steady Alignment Builder",
            strength: "Builds trust through reliability, consistency, and steady relationships.",
            weakness: "Avoids hard conversations too long to preserve harmony.",
            stressTrigger: "Interpersonal tension",
            breakingPoint: "Truth-telling (issues get smoothed over until they erupt)"
        ),
        PurposeProfileRecord(
            profile: "Quality Sentinel",
            strength: "Protects standards and identifies risks before failure occurs.",
            weakness: "Excess scrutiny can slow progress.",
            stressTrigger: "Unclear ownership and sloppy execution",
            breakingPoint: "Speed (momentum sacrificed for certainty)"
        ),
        PurposeProfileRecord(
            profile: "Supportive Adapter",
            strength: "Maintains stability through calm responsiveness and quiet problem solving.",
            weakness: "Becomes invisible if priorities are not self-defined.",
            stressTrigger: "Unclear expectations",
            breakingPoint: "Self-prioritization (work fragments across others' needs)"
        ),
        PurposeProfileRecord(
            profile: "Pragmatic Realist",
            strength: "Identifies what will work now and communicates it plainly.",
            weakness: "May neglect inspiration and relationship repair.",
            stressTrigger: "Emotionally driven decisions",
            breakingPoint: "Influence (truth delivered without adoption)"
        )
    ]
    private static let mergedRecords: [PurposeProfileRecord] = mergeParsedWithBuiltIn(parsed: parsedRecords)

    static func all() -> [PurposeProfileRecord] {
        mergedRecords
    }

    static func record(named profileName: String) -> PurposeProfileRecord? {
        let key = normalized(profileName)
        return all().first { normalized($0.profile) == key }
    }

    static func fallback() -> PurposeProfileRecord {
        all().first ?? builtInRecords.first!
    }

    private static func mergeParsedWithBuiltIn(parsed: [PurposeProfileRecord]) -> [PurposeProfileRecord] {
        guard !parsed.isEmpty else { return builtInRecords }
        let parsedMap = Dictionary(uniqueKeysWithValues: parsed.map { (normalized($0.profile), $0) })
        return builtInRecords.map { builtIn in
            parsedMap[normalized(builtIn.profile)] ?? builtIn
        }
    }

    private static func loadRecords() -> [PurposeProfileRecord] {
        guard
            let url = Bundle.main.url(forResource: "profiles", withExtension: "csv"),
            let csv = try? String(contentsOf: url, encoding: .utf8)
        else {
            return []
        }

        let rows = parseCSV(csv)
        guard let header = rows.first else { return [] }

        let profileIndex = index(of: "profile", in: header)
        let strengthIndex = index(of: "strength", in: header)
        let weaknessIndex = index(of: "weakness", in: header)
        let stressIndex = index(of: "stress_trigger", in: header)
        let breakingIndex = index(of: "breaking_point", in: header) ?? index(of: "fracture_point", in: header)

        guard
            let profileIndex,
            let strengthIndex,
            let weaknessIndex,
            let stressIndex,
            let breakingIndex
        else {
            return []
        }

        return rows.dropFirst().compactMap { row in
            let profile = value(at: profileIndex, in: row)
            let strength = value(at: strengthIndex, in: row)
            let weakness = value(at: weaknessIndex, in: row)
            let stressTrigger = value(at: stressIndex, in: row)
            let breakingPoint = value(at: breakingIndex, in: row)
            guard !profile.isEmpty, !strength.isEmpty, !weakness.isEmpty else { return nil }
            return PurposeProfileRecord(
                profile: profile,
                strength: strength,
                weakness: weakness,
                stressTrigger: stressTrigger,
                breakingPoint: breakingPoint
            )
        }
    }

    private static func index(of expected: String, in header: [String]) -> Int? {
        let expectedKey = normalizedHeader(expected)
        return header.firstIndex { normalizedHeader($0) == expectedKey }
    }

    private static func value(at index: Int, in row: [String]) -> String {
        guard row.indices.contains(index) else { return "" }
        return row[index].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedHeader(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    fileprivate static func normalized(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseCSV(_ input: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        let scalars = Array(input.unicodeScalars)
        var idx = 0

        func flushField() {
            row.append(field.trimmingCharacters(in: .whitespacesAndNewlines))
            field = ""
        }

        func flushRow() {
            flushField()
            if row.contains(where: { !$0.isEmpty }) {
                rows.append(row)
            }
            row = []
        }

        while idx < scalars.count {
            let scalar = scalars[idx]
            switch scalar {
            case "\"":
                if inQuotes, idx + 1 < scalars.count, scalars[idx + 1] == "\"" {
                    field.append("\"")
                    idx += 1
                } else {
                    inQuotes.toggle()
                }
            case "," where !inQuotes:
                flushField()
            case "\n" where !inQuotes:
                flushRow()
            case "\r" where !inQuotes:
                flushRow()
                if idx + 1 < scalars.count, scalars[idx + 1] == "\n" {
                    idx += 1
                }
            default:
                field.unicodeScalars.append(scalar)
            }
            idx += 1
        }

        if !field.isEmpty || !row.isEmpty {
            flushRow()
        }

        return rows
    }
}

enum PurposeProfileMatcher {
    struct Inputs: Sendable {
        let stress: String
        let breakPoint: String
        let planning: String
        let desired: String
        let rootCause: String
        let nextDirection: String
        let vision: String
        let passions: [String]
    }

    struct ScoredProfile: Sendable {
        let record: PurposeProfileRecord
        let score: Double
    }

    private static let stopWords: Set<String> = [
        "and", "are", "for", "from", "that", "this", "with", "your", "you", "the",
        "will", "into", "when", "then", "what", "have", "has", "but", "not", "yet",
        "too", "very", "more", "less", "across", "life", "loom", "through", "only"
    ]

    static func bestMatch(
        inputs: Inputs,
        catalog: [PurposeProfileRecord] = PurposeProfilesCatalog.all()
    ) -> PurposeProfileRecord {
        let ranked = rankedMatches(inputs: inputs, catalog: catalog)
        guard !ranked.isEmpty else { return PurposeProfilesCatalog.fallback() }
        let seed = buildEvidenceTokens(inputs).sorted().joined(separator: "|")
        return pickFromTopBand(ranked: ranked, seed: seed)
    }

    static func rankedMatches(
        inputs: Inputs,
        catalog: [PurposeProfileRecord] = PurposeProfilesCatalog.all()
    ) -> [ScoredProfile] {
        guard !catalog.isEmpty else { return [] }
        let evidence = buildEvidenceTokens(inputs)
        let stressTokens = tokenSet("\(inputs.stress) \(inputs.rootCause)")
        let executionTokens = tokenSet("\(inputs.breakPoint) \(inputs.planning) \(inputs.desired) \(inputs.nextDirection)")
        let visionTokens = tokenSet("\(inputs.vision) \(inputs.passions.joined(separator: " ")) \(inputs.desired)")
        let seed = evidence.sorted().joined(separator: "|")

        return catalog
            .map { record in
                let stressDescriptor = tokenSet(record.stressTrigger)
                let breakDescriptor = tokenSet(record.breakingPoint)
                let strengthDescriptor = tokenSet(record.strength)
                let weaknessDescriptor = tokenSet(record.weakness)
                let descriptorUnion = stressDescriptor
                    .union(breakDescriptor)
                    .union(strengthDescriptor)
                    .union(weaknessDescriptor)

                var score = 0.0
                score += overlap(stressTokens, stressDescriptor) * 3.0
                score += overlap(executionTokens, breakDescriptor) * 3.0
                score += overlap(visionTokens, strengthDescriptor) * 1.4
                score += overlap(executionTokens, weaknessDescriptor) * 1.4
                score += overlap(evidence, descriptorUnion) * 2.2

                return ScoredProfile(record: record, score: score)
            }
            .sorted { lhs, rhs in
                if abs(lhs.score - rhs.score) > 0.0001 {
                    return lhs.score > rhs.score
                }
                return tieBreakRank(seed: seed, profile: lhs.record.profile) < tieBreakRank(seed: seed, profile: rhs.record.profile)
            }
    }

    private static func buildEvidenceTokens(_ inputs: Inputs) -> Set<String> {
        let combined = [
            inputs.stress,
            inputs.breakPoint,
            inputs.planning,
            inputs.desired,
            inputs.rootCause,
            inputs.nextDirection,
            inputs.vision,
            inputs.passions.joined(separator: " ")
        ].joined(separator: " ")
        var tokens = tokenSet(combined)
        let signal = PurposeProfilesCatalog.normalized(combined)
        tokens.formUnion(expandedTokens(from: signal))
        return tokens
    }

    private static func expandedTokens(from signal: String) -> Set<String> {
        var out: Set<String> = []
        let expansions: [(String, [String])] = [
            ("too many priorities", ["competing", "priorities", "tradeoffs", "coordination"]),
            ("feeling behind", ["chaos", "stability", "cadence", "consistency"]),
            ("disorganized", ["chaos", "stability", "structure"]),
            ("distractions", ["focus", "noise", "context", "switching"]),
            ("work pressure", ["pressure", "commitments", "deadlines"]),
            ("money pressure", ["resources", "constraints", "budget", "finance"]),
            ("low energy", ["energy", "capacity", "recovery"]),
            ("health", ["energy", "capacity", "recovery"]),
            ("relationship tension", ["interpersonal", "tension", "conflict"]),
            ("i don t start", ["start", "activation", "friction"]),
            ("lose momentum", ["consistency", "cadence", "follow", "through"]),
            ("distracted", ["focus", "context", "switching"]),
            ("overthink", ["analysis", "delay", "specificity"]),
            ("don t finish", ["finish", "follow", "through", "consistency"]),
            ("react to what s urgent", ["urgent", "reactive", "firefighting", "triage"]),
            ("off track", ["drift", "consistency", "boundary"]),
            ("follow through consistently", ["consistency", "cadence", "reliability"]),
            ("in control", ["clarity", "standards", "ownership"]),
            ("clear direction", ["clarity", "priorities", "alignment"]),
            ("faster progress", ["momentum", "velocity", "shipping"]),
            ("balanced across life", ["balance", "harmony", "alignment"])
        ]
        for (needle, mapped) in expansions where signal.contains(needle) {
            mapped.forEach { out.insert($0) }
        }
        return out
    }

    private static func tokenSet(_ raw: String) -> Set<String> {
        let lowered = raw.lowercased()
        let cleaned = lowered.replacingOccurrences(of: "[^a-z0-9 ]", with: " ", options: .regularExpression)
        return Set(
            cleaned
                .split(separator: " ")
                .map(String.init)
                .filter { $0.count > 2 && !stopWords.contains($0) }
        )
    }

    private static func overlap(_ lhs: Set<String>, _ rhs: Set<String>) -> Double {
        guard !lhs.isEmpty, !rhs.isEmpty else { return 0 }
        let intersectionCount = lhs.intersection(rhs).count
        return Double(intersectionCount) / Double(max(rhs.count, 1))
    }

    private static func pickFromTopBand(ranked: [ScoredProfile], seed: String) -> PurposeProfileRecord {
        guard let top = ranked.first else { return PurposeProfilesCatalog.fallback() }
        let threshold = max(top.score * 0.92, top.score - 0.28)
        let band = ranked.filter { $0.score >= threshold }
        guard band.count > 1 else { return top.record }
        let index = Int(stableHash("\(seed)|band") % UInt64(band.count))
        return band[index].record
    }

    private static func tieBreakRank(seed: String, profile: String) -> UInt64 {
        stableHash("\(seed)|\(profile.lowercased())")
    }

    private static func stableHash(_ value: String) -> UInt64 {
        var hash: UInt64 = 1469598103934665603
        for scalar in value.unicodeScalars {
            hash ^= UInt64(scalar.value)
            hash = hash &* 1099511628211
        }
        return hash
    }
}
