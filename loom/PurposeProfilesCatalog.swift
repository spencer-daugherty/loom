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
        let areas: [String]
        let vision: String
        let passions: [String]
    }

    struct ScoredProfile: Sendable {
        let record: PurposeProfileRecord
        let score: Double
    }

    private struct BonusRule: Sendable {
        let score: Double
        let stress: [String]
        let breakPoint: [String]
        let planning: [String]
        let desired: [String]
        let areas: [String]
        let signals: [String]
    }

    private struct SelectionContext: Sendable {
        let stressWeights: [String: Double]
        let breakWeights: [String: Double]
        let planningWeights: [String: Double]
        let changeWeights: [String: Double]
        let areaWeights: [String: Double]
        let signalWeights: [String: Double]
        let comboBonuses: [BonusRule]
    }

    private struct NormalizedInputs: Sendable {
        let stress: String
        let breakPoint: String
        let planning: String
        let desired: String
        let areas: [String]
        let signals: [String]
        let visionKey: String
        let passionKey: String
    }

    private static let emptyContext = SelectionContext(
        stressWeights: [:],
        breakWeights: [:],
        planningWeights: [:],
        changeWeights: [:],
        areaWeights: [:],
        signalWeights: [:],
        comboBonuses: []
    )

    private static let signalLexicon: [String: [String]] = [
        "clarity": [
            "clear",
            "clarity",
            "direction",
            "priorities",
            "focused",
            "focus",
            "boundaries",
            "simple systems"
        ],
        "consistency": [
            "routine",
            "routines",
            "steady",
            "stable",
            "consistency",
            "consistent",
            "follow through",
            "promises",
            "calm"
        ],
        "execution": [
            "action",
            "daily action",
            "progress",
            "faster progress",
            "finish",
            "momentum",
            "shipping",
            "commitments"
        ],
        "analysis": [
            "deep learning",
            "learning",
            "education",
            "writing ideas clearly",
            "writing",
            "designing systems",
            "systems",
            "framework"
        ],
        "relationships": [
            "relationships",
            "family",
            "home",
            "present at home",
            "community",
            "coaching others",
            "coaching",
            "teaching",
            "love"
        ],
        "leadership": [
            "leading teams",
            "teams",
            "public speaking",
            "leadership",
            "impact",
            "service"
        ],
        "exploration": [
            "travel and exploration",
            "travel",
            "exploration",
            "creative problem solving",
            "creative",
            "building useful products",
            "products",
            "entrepreneurship"
        ],
        "recovery": [
            "health",
            "energy",
            "fitness training",
            "fitness",
            "recovery",
            "burning out",
            "burn out"
        ],
        "finance": [
            "financial independence",
            "financial",
            "finances",
            "wealth",
            "business",
            "career"
        ],
        "meaning": [
            "meaningful",
            "purpose",
            "values",
            "faith",
            "spiritual"
        ],
        "autonomy": [
            "deep work",
            "autonomy",
            "autonomous",
            "independent",
            "solo"
        ]
    ]

    private static let selectionContexts: [String: SelectionContext] = [
        normalizedKey("Strategic Integrator"): context(
            stressWeights: [
                "Too many priorities competing": 3.6,
                "Work pressure": 1.0,
                "Not sure yet": 0.5
            ],
            breakWeights: [
                "I overthink it": 0.7,
                "I'm not sure": 0.6
            ],
            planningWeights: [
                "Plan and follow through consistently": 1.9,
                "Plan, but get off track": 1.7,
                "It depends on the day": 0.4
            ],
            changeWeights: [
                "I know what matters (clear direction)": 2.4,
                "I make faster progress on big goals": 1.0,
                "I feel in control (less stress)": 0.8
            ],
            areaWeights: [
                "Career & Business": 1.2,
                "Service & Impact": 1.1,
                "Love & Relationships": 0.7,
                "Home & Life": 0.5,
                "Learning & Education": 0.4
            ],
            signalWeights: [
                "clarity": 1.1,
                "relationships": 0.9,
                "leadership": 0.9,
                "execution": 0.4,
                "finance": 0.3
            ],
            comboBonuses: [
                bonus(
                    score: 1.0,
                    stress: ["Too many priorities competing"],
                    desired: ["I know what matters (clear direction)"]
                ),
                bonus(
                    score: 0.8,
                    stress: ["Too many priorities competing"],
                    planning: ["Plan and follow through consistently", "Plan, but get off track"]
                )
            ]
        ),
        normalizedKey("Structured Clarity Driver"): context(
            stressWeights: [
                "Too many priorities competing": 2.4,
                "Feeling behind or disorganized": 1.4,
                "Not sure yet": 0.6
            ],
            breakWeights: [
                "I overthink it": 1.4,
                "I don't start": 0.5
            ],
            planningWeights: [
                "Keep a simple to-do list": 1.0,
                "Plan, but get off track": 1.2,
                "Plan and follow through consistently": 0.9
            ],
            changeWeights: [
                "I know what matters (clear direction)": 2.8,
                "I feel in control (less stress)": 1.6
            ],
            areaWeights: [
                "Career & Business": 1.0,
                "Learning & Education": 1.0,
                "Wealth & Finance": 0.7,
                "Service & Impact": 0.6
            ],
            signalWeights: [
                "clarity": 1.4,
                "analysis": 1.0,
                "execution": 0.3
            ],
            comboBonuses: [
                bonus(
                    score: 1.0,
                    stress: ["Too many priorities competing"],
                    breakPoint: ["I overthink it"],
                    desired: ["I know what matters (clear direction)"]
                )
            ]
        ),
        normalizedKey("Adaptive Catalyst"): context(
            stressWeights: [
                "Feeling behind or disorganized": 1.7,
                "Distractions are stealing my focus": 0.8,
                "Low energy / health": 0.5
            ],
            breakWeights: [
                "I start, then lose momentum": 2.5,
                "I don't start": 1.4,
                "I get distracted": 1.0
            ],
            planningWeights: [
                "React to what's urgent": 1.0,
                "It depends on the day": 1.0,
                "Plan, but get off track": 0.8
            ],
            changeWeights: [
                "I make faster progress on big goals": 2.4,
                "I follow through (consistency)": 1.5
            ],
            areaWeights: [
                "Career & Business": 0.9,
                "Lifestyle & Experiences": 1.1,
                "Service & Impact": 0.9,
                "Love & Relationships": 0.5
            ],
            signalWeights: [
                "execution": 0.9,
                "leadership": 0.8,
                "exploration": 0.7,
                "relationships": 0.5
            ],
            comboBonuses: [
                bonus(
                    score: 1.1,
                    breakPoint: ["I start, then lose momentum"],
                    desired: ["I make faster progress on big goals", "I follow through (consistency)"]
                )
            ]
        ),
        normalizedKey("Rapid Experimenter"): context(
            stressWeights: [
                "Feeling behind or disorganized": 1.3,
                "Work pressure": 1.1,
                "Not sure yet": 0.9
            ],
            breakWeights: [
                "I start, then lose momentum": 1.3,
                "I get distracted": 1.2,
                "I don't start": 0.8
            ],
            planningWeights: [
                "React to what's urgent": 1.9,
                "It depends on the day": 1.3
            ],
            changeWeights: [
                "I make faster progress on big goals": 2.5,
                "I know what matters (clear direction)": 0.8
            ],
            areaWeights: [
                "Career & Business": 0.9,
                "Learning & Education": 1.0,
                "Lifestyle & Experiences": 1.1,
                "Wealth & Finance": 0.5
            ],
            signalWeights: [
                "execution": 0.8,
                "exploration": 1.2,
                "analysis": 0.3
            ],
            comboBonuses: [
                bonus(
                    score: 1.0,
                    planning: ["React to what's urgent"],
                    desired: ["I make faster progress on big goals"]
                )
            ]
        ),
        normalizedKey("Momentum Builder"): context(
            stressWeights: [
                "Feeling behind or disorganized": 1.5,
                "Money pressure": 1.0,
                "Low energy / health": 1.0
            ],
            breakWeights: [
                "I start, then lose momentum": 3.0,
                "I don't finish what I start": 1.4
            ],
            planningWeights: [
                "Plan and follow through consistently": 2.6,
                "Keep a simple to-do list": 0.9
            ],
            changeWeights: [
                "I follow through (consistency)": 2.7,
                "I feel balanced across life": 1.0
            ],
            areaWeights: [
                "Health & Energy": 1.0,
                "Home & Life": 1.1,
                "Love & Relationships": 1.0,
                "Career & Business": 0.8
            ],
            signalWeights: [
                "consistency": 1.3,
                "recovery": 0.6,
                "relationships": 0.5,
                "execution": 0.6
            ],
            comboBonuses: [
                bonus(
                    score: 1.2,
                    breakPoint: ["I start, then lose momentum"],
                    planning: ["Plan and follow through consistently"],
                    desired: ["I follow through (consistency)"]
                )
            ]
        ),
        normalizedKey("Operational Commander"): context(
            stressWeights: [
                "Work pressure": 2.5,
                "Too many priorities competing": 1.6,
                "Money pressure": 1.1
            ],
            breakWeights: [
                "I don't finish what I start": 1.1,
                "I get distracted": 0.8
            ],
            planningWeights: [
                "React to what's urgent": 2.0,
                "Keep a simple to-do list": 1.4,
                "Plan and follow through consistently": 0.8
            ],
            changeWeights: [
                "I feel in control (less stress)": 2.5,
                "I make faster progress on big goals": 1.2
            ],
            areaWeights: [
                "Career & Business": 1.2,
                "Home & Life": 1.0,
                "Wealth & Finance": 0.8,
                "Service & Impact": 0.8
            ],
            signalWeights: [
                "execution": 1.2,
                "clarity": 0.9,
                "leadership": 1.0,
                "finance": 0.4
            ],
            comboBonuses: [
                bonus(
                    score: 1.3,
                    stress: ["Work pressure"],
                    planning: ["React to what's urgent"],
                    desired: ["I feel in control (less stress)"]
                ),
                bonus(
                    score: 0.7,
                    areas: ["Career & Business", "Home & Life"]
                )
            ]
        ),
        normalizedKey("Adaptive Stabilizer"): context(
            stressWeights: [
                "Low energy / health": 1.9,
                "Relationship tension": 1.4,
                "Feeling behind or disorganized": 1.1
            ],
            breakWeights: [
                "I get distracted": 1.0,
                "I start, then lose momentum": 1.1,
                "I'm not sure": 0.7
            ],
            planningWeights: [
                "Plan, but get off track": 1.7,
                "It depends on the day": 1.2
            ],
            changeWeights: [
                "I follow through (consistency)": 1.8,
                "I feel balanced across life": 2.1
            ],
            areaWeights: [
                "Love & Relationships": 1.0,
                "Home & Life": 1.1,
                "Health & Energy": 1.0,
                "Mindset & Resilience": 0.8
            ],
            signalWeights: [
                "consistency": 0.9,
                "relationships": 0.8,
                "recovery": 1.0,
                "meaning": 0.4
            ],
            comboBonuses: [
                bonus(
                    score: 1.0,
                    stress: ["Low energy / health", "Relationship tension"],
                    desired: ["I feel balanced across life", "I follow through (consistency)"]
                )
            ]
        ),
        normalizedKey("Crisis Navigator"): context(
            stressWeights: [
                "Work pressure": 2.0,
                "Too many priorities competing": 1.5,
                "Not sure yet": 0.8
            ],
            breakWeights: [
                "I don't finish what I start": 1.0,
                "I overthink it": 0.5
            ],
            planningWeights: [
                "React to what's urgent": 3.1
            ],
            changeWeights: [
                "I feel in control (less stress)": 2.0,
                "I make faster progress on big goals": 1.7
            ],
            areaWeights: [
                "Service & Impact": 1.3,
                "Career & Business": 1.0,
                "Home & Life": 0.9
            ],
            signalWeights: [
                "execution": 1.0,
                "leadership": 0.8,
                "clarity": 0.5
            ],
            comboBonuses: [
                bonus(
                    score: 1.4,
                    stress: ["Work pressure", "Too many priorities competing"],
                    planning: ["React to what's urgent"],
                    desired: ["I feel in control (less stress)", "I make faster progress on big goals"]
                ),
                bonus(
                    score: 0.8,
                    areas: ["Service & Impact", "Home & Life"]
                )
            ]
        ),
        normalizedKey("Purpose-Led Planner"): context(
            stressWeights: [
                "Distractions are stealing my focus": 3.1,
                "Too many priorities competing": 1.5,
                "Low energy / health": 0.6
            ],
            breakWeights: [
                "I don't start": 2.7,
                "I get distracted": 2.1
            ],
            planningWeights: [
                "Plan and follow through consistently": 2.0,
                "Plan, but get off track": 1.0
            ],
            changeWeights: [
                "I know what matters (clear direction)": 2.1,
                "I follow through (consistency)": 1.2
            ],
            areaWeights: [
                "Faith & Spirituality": 1.1,
                "Mindset & Resilience": 1.1,
                "Learning & Education": 0.8,
                "Health & Energy": 0.7
            ],
            signalWeights: [
                "clarity": 1.0,
                "consistency": 0.9,
                "autonomy": 0.6,
                "meaning": 0.8,
                "analysis": 0.4
            ],
            comboBonuses: [
                bonus(
                    score: 1.4,
                    stress: ["Distractions are stealing my focus"],
                    breakPoint: ["I don't start", "I get distracted"],
                    desired: ["I know what matters (clear direction)"]
                )
            ]
        ),
        normalizedKey("Analytical Architect"): context(
            stressWeights: [
                "Not sure yet": 1.0,
                "Too many priorities competing": 0.7
            ],
            breakWeights: [
                "I overthink it": 3.1
            ],
            planningWeights: [
                "Keep a simple to-do list": 1.1,
                "Plan and follow through consistently": 0.9
            ],
            changeWeights: [
                "I know what matters (clear direction)": 2.2,
                "I feel in control (less stress)": 1.3
            ],
            areaWeights: [
                "Learning & Education": 1.3,
                "Wealth & Finance": 0.9,
                "Career & Business": 0.8,
                "Home & Life": 0.4
            ],
            signalWeights: [
                "analysis": 1.5,
                "clarity": 0.7,
                "autonomy": 0.6,
                "finance": 0.5
            ],
            comboBonuses: [
                bonus(
                    score: 1.3,
                    breakPoint: ["I overthink it"],
                    desired: ["I know what matters (clear direction)", "I feel in control (less stress)"],
                    areas: ["Learning & Education", "Wealth & Finance"]
                )
            ]
        ),
        normalizedKey("Reflective Synthesizer"): context(
            stressWeights: [
                "Not sure yet": 1.8,
                "Relationship tension": 0.8,
                "Low energy / health": 0.7
            ],
            breakWeights: [
                "I overthink it": 2.2,
                "I don't start": 1.1
            ],
            planningWeights: [
                "It depends on the day": 2.0,
                "Keep a simple to-do list": 0.6
            ],
            changeWeights: [
                "I feel balanced across life": 1.9,
                "I know what matters (clear direction)": 1.5
            ],
            areaWeights: [
                "Faith & Spirituality": 1.0,
                "Mindset & Resilience": 1.2,
                "Learning & Education": 1.0,
                "Lifestyle & Experiences": 0.6
            ],
            signalWeights: [
                "analysis": 0.9,
                "meaning": 1.0,
                "exploration": 0.6,
                "autonomy": 0.4
            ],
            comboBonuses: [
                bonus(
                    score: 1.2,
                    breakPoint: ["I overthink it"],
                    desired: ["I feel balanced across life", "I know what matters (clear direction)"],
                    areas: ["Mindset & Resilience", "Faith & Spirituality"]
                )
            ]
        ),
        normalizedKey("Independent Pathfinder"): context(
            stressWeights: [
                "Not sure yet": 1.2,
                "Distractions are stealing my focus": 1.0,
                "Too many priorities competing": 0.7
            ],
            breakWeights: [
                "I don't start": 1.1,
                "I get distracted": 0.8
            ],
            planningWeights: [
                "It depends on the day": 1.7,
                "Keep a simple to-do list": 0.7
            ],
            changeWeights: [
                "I make faster progress on big goals": 1.9,
                "I know what matters (clear direction)": 1.1
            ],
            areaWeights: [
                "Learning & Education": 1.2,
                "Lifestyle & Experiences": 1.0,
                "Career & Business": 0.7,
                "Wealth & Finance": 0.4
            ],
            signalWeights: [
                "exploration": 1.0,
                "autonomy": 1.4,
                "analysis": 0.6,
                "execution": 0.3
            ],
            comboBonuses: [
                bonus(
                    score: 1.0,
                    stress: ["Not sure yet"],
                    planning: ["It depends on the day"],
                    desired: ["I make faster progress on big goals"]
                )
            ]
        ),
        normalizedKey("Steady Alignment Builder"): context(
            stressWeights: [
                "Relationship tension": 3.5,
                "Low energy / health": 0.8,
                "Not sure yet": 0.5
            ],
            breakWeights: [
                "I'm not sure": 1.0,
                "I don't finish what I start": 0.9,
                "I don't start": 0.5
            ],
            planningWeights: [
                "Plan and follow through consistently": 1.9,
                "Plan, but get off track": 1.0
            ],
            changeWeights: [
                "I feel balanced across life": 2.2,
                "I follow through (consistency)": 1.5
            ],
            areaWeights: [
                "Love & Relationships": 1.3,
                "Home & Life": 1.1,
                "Service & Impact": 0.8,
                "Faith & Spirituality": 0.6
            ],
            signalWeights: [
                "relationships": 1.3,
                "consistency": 1.0,
                "meaning": 0.5
            ],
            comboBonuses: [
                bonus(
                    score: 1.5,
                    stress: ["Relationship tension"],
                    desired: ["I feel balanced across life", "I follow through (consistency)"]
                )
            ]
        ),
        normalizedKey("Quality Sentinel"): context(
            stressWeights: [
                "Work pressure": 1.7,
                "Feeling behind or disorganized": 1.2,
                "Money pressure": 0.8
            ],
            breakWeights: [
                "I overthink it": 1.6,
                "I don't finish what I start": 1.1
            ],
            planningWeights: [
                "Keep a simple to-do list": 1.2,
                "Plan and follow through consistently": 1.3
            ],
            changeWeights: [
                "I feel in control (less stress)": 2.3,
                "I follow through (consistency)": 1.0
            ],
            areaWeights: [
                "Wealth & Finance": 1.0,
                "Career & Business": 0.9,
                "Health & Energy": 0.8,
                "Home & Life": 0.6
            ],
            signalWeights: [
                "clarity": 1.0,
                "analysis": 1.1,
                "consistency": 0.7,
                "finance": 0.4
            ],
            comboBonuses: [
                bonus(
                    score: 1.1,
                    stress: ["Work pressure", "Feeling behind or disorganized"],
                    desired: ["I feel in control (less stress)"]
                )
            ]
        ),
        normalizedKey("Supportive Adapter"): context(
            stressWeights: [
                "Relationship tension": 1.6,
                "Low energy / health": 1.4,
                "Not sure yet": 1.0
            ],
            breakWeights: [
                "I'm not sure": 1.7,
                "I get distracted": 0.8
            ],
            planningWeights: [
                "It depends on the day": 1.8,
                "Keep a simple to-do list": 0.8
            ],
            changeWeights: [
                "I feel balanced across life": 2.4,
                "I feel in control (less stress)": 0.9
            ],
            areaWeights: [
                "Love & Relationships": 1.1,
                "Home & Life": 1.1,
                "Health & Energy": 0.9,
                "Faith & Spirituality": 0.7
            ],
            signalWeights: [
                "relationships": 1.2,
                "recovery": 0.8,
                "consistency": 0.7,
                "meaning": 0.4
            ],
            comboBonuses: [
                bonus(
                    score: 1.1,
                    stress: ["Relationship tension", "Low energy / health"],
                    breakPoint: ["I'm not sure"],
                    desired: ["I feel balanced across life"]
                )
            ]
        ),
        normalizedKey("Pragmatic Realist"): context(
            stressWeights: [
                "Money pressure": 2.6,
                "Work pressure": 1.8
            ],
            breakWeights: [
                "I overthink it": 0.7,
                "I don't start": 0.6
            ],
            planningWeights: [
                "React to what's urgent": 1.8,
                "Keep a simple to-do list": 1.3
            ],
            changeWeights: [
                "I feel in control (less stress)": 1.9,
                "I make faster progress on big goals": 1.4
            ],
            areaWeights: [
                "Wealth & Finance": 1.2,
                "Career & Business": 1.0,
                "Home & Life": 0.6,
                "Service & Impact": 0.4
            ],
            signalWeights: [
                "finance": 1.2,
                "execution": 0.8,
                "clarity": 0.8
            ],
            comboBonuses: [
                bonus(
                    score: 1.2,
                    stress: ["Money pressure"],
                    planning: ["React to what's urgent"],
                    desired: ["I feel in control (less stress)", "I make faster progress on big goals"]
                )
            ]
        )
    ]

    static func bestMatch(
        inputs: Inputs,
        catalog: [PurposeProfileRecord] = PurposeProfilesCatalog.all()
    ) -> PurposeProfileRecord {
        guard
            let responses = OnboardingQuestionnaireResponses(
                stressSource: inputs.stress,
                breakPoint: inputs.breakPoint,
                selectedAreas: inputs.areas,
                planningReality: inputs.planning,
                desiredChange: inputs.desired
            )
        else {
            return PurposeProfilesCatalog.fallback()
        }
        let result = OnboardingPersonalityMatcher.match(responses: responses)
        return catalog.first(where: {
            PurposeProfilesCatalog.normalized($0.profile) == PurposeProfilesCatalog.normalized(result.winner.profileName)
        }) ?? PurposeProfilesCatalog.record(named: result.winner.profileName) ?? PurposeProfilesCatalog.fallback()
    }

    static func rankedMatches(
        inputs: Inputs,
        catalog: [PurposeProfileRecord] = PurposeProfilesCatalog.all()
    ) -> [ScoredProfile] {
        guard
            !catalog.isEmpty,
            let responses = OnboardingQuestionnaireResponses(
                stressSource: inputs.stress,
                breakPoint: inputs.breakPoint,
                selectedAreas: inputs.areas,
                planningReality: inputs.planning,
                desiredChange: inputs.desired
            )
        else {
            return []
        }
        let result = OnboardingPersonalityMatcher.match(responses: responses)
        return result.rankedProfiles.compactMap { ranked in
            let record = catalog.first(where: {
                PurposeProfilesCatalog.normalized($0.profile) == PurposeProfilesCatalog.normalized(ranked.profileName)
            }) ?? PurposeProfilesCatalog.record(named: ranked.profileName)
            return record.map { ScoredProfile(record: $0, score: ranked.rawScore) }
        }
    }

    private static func pickFromTopBand(ranked: [ScoredProfile], seed: String) -> PurposeProfileRecord {
        guard let top = ranked.first else { return PurposeProfilesCatalog.fallback() }
        let threshold = max(top.score * 0.88, top.score - 1.15)
        let band = ranked.filter { $0.score >= threshold }
        guard band.count > 1 else { return top.record }
        let index = Int(stableHash("\(seed)|band") % UInt64(band.count))
        return band[index].record
    }

    private static func tieBreakRank(seed: String, profile: String) -> UInt64 {
        stableHash("\(seed)|\(profile.lowercased())")
    }

    private static func buildSeed(from normalized: NormalizedInputs) -> String {
        [
            normalized.stress,
            normalized.breakPoint,
            normalized.planning,
            normalized.desired,
            normalized.areas.joined(separator: "|"),
            normalized.signals.joined(separator: "|"),
            normalized.visionKey,
            normalized.passionKey
        ].joined(separator: "||")
    }

    private static func normalizedInputs(from inputs: Inputs) -> NormalizedInputs {
        let areas = normalizedAreaKeys(inputs.areas)
        let signals = extractSignals(vision: inputs.vision, passions: inputs.passions)
        return NormalizedInputs(
            stress: normalizedKey(inputs.stress),
            breakPoint: normalizedKey(inputs.breakPoint),
            planning: normalizedKey(inputs.planning),
            desired: normalizedKey(inputs.desired),
            areas: areas,
            signals: signals,
            visionKey: normalizedKey(inputs.vision),
            passionKey: inputs.passions.map(normalizedKey).filter { !$0.isEmpty }.sorted().joined(separator: "|")
        )
    }

    private static func areaScore(_ weights: [String: Double], normalizedAreas: [String]) -> Double {
        let matches = normalizedAreas
            .compactMap { value -> Double? in
                guard let score = weights[value], score > 0 else { return nil }
                return score
            }
            .sorted(by: >)
            .prefix(3)
        guard !matches.isEmpty else { return 0 }
        let total = matches.reduce(0, +)
        return total / Double(matches.count)
    }

    private static func signalScore(_ weights: [String: Double], signals: [String]) -> Double {
        signals.reduce(0) { $0 + (weights[$1] ?? 0) }
    }

    private static func bonusScore(_ bonuses: [BonusRule], normalized: NormalizedInputs) -> Double {
        bonuses.reduce(0) { partial, bonus in
            partial + (matches(bonus: bonus, normalized: normalized) ? bonus.score : 0)
        }
    }

    private static func matches(bonus: BonusRule, normalized: NormalizedInputs) -> Bool {
        if !bonus.stress.isEmpty && !bonus.stress.contains(normalized.stress) {
            return false
        }
        if !bonus.breakPoint.isEmpty && !bonus.breakPoint.contains(normalized.breakPoint) {
            return false
        }
        if !bonus.planning.isEmpty && !bonus.planning.contains(normalized.planning) {
            return false
        }
        if !bonus.desired.isEmpty && !bonus.desired.contains(normalized.desired) {
            return false
        }
        if !bonus.areas.isEmpty && !bonus.areas.contains(where: { normalized.areas.contains($0) }) {
            return false
        }
        if !bonus.signals.isEmpty && !bonus.signals.contains(where: { normalized.signals.contains($0) }) {
            return false
        }
        return true
    }

    private static func extractSignals(vision: String, passions: [String]) -> [String] {
        let combined = normalizedKey(([vision] + passions).joined(separator: " "))
        guard !combined.isEmpty else { return [] }
        return signalLexicon.keys.sorted().filter { signal in
            (signalLexicon[signal] ?? []).contains { phrase in
                combined.contains(normalizedKey(phrase))
            }
        }
    }

    private static func normalizedAreaKeys(_ rawAreas: [String]) -> [String] {
        var keys: Set<String> = []
        for area in rawAreas {
            let normalized = normalizedKey(area)
            guard !normalized.isEmpty else { continue }
            keys.insert(normalized)
            if normalized.range(of: "(career|business|work|job|entrepreneur|product)", options: .regularExpression) != nil {
                keys.insert(normalizedKey("Career & Business"))
            }
            if normalized.range(of: "(faith|spiritual|church|religion)", options: .regularExpression) != nil {
                keys.insert(normalizedKey("Faith & Spirituality"))
            }
            if normalized.range(of: "(wealth|finance|money|financial|budget|invest)", options: .regularExpression) != nil {
                keys.insert(normalizedKey("Wealth & Finance"))
            }
            if normalized.range(of: "(learn|study|education|school|knowledge)", options: .regularExpression) != nil {
                keys.insert(normalizedKey("Learning & Education"))
            }
            if normalized.range(of: "(love|relationship|marriage|partner|family)", options: .regularExpression) != nil {
                keys.insert(normalizedKey("Love & Relationships"))
            }
            if normalized.range(of: "(health|fitness|energy|wellness|recovery)", options: .regularExpression) != nil {
                keys.insert(normalizedKey("Health & Energy"))
            }
            if normalized.range(of: "(lifestyle|travel|experience|fun|adventure)", options: .regularExpression) != nil {
                keys.insert(normalizedKey("Lifestyle & Experiences"))
            }
            if normalized.range(of: "(mindset|mental|resilience|clarity|inner)", options: .regularExpression) != nil {
                keys.insert(normalizedKey("Mindset & Resilience"))
            }
            if normalized.range(of: "(service|impact|community|help|mentor|teach|coach)", options: .regularExpression) != nil {
                keys.insert(normalizedKey("Service & Impact"))
            }
            if normalized.range(of: "(home|house|family life|household|life admin)", options: .regularExpression) != nil {
                keys.insert(normalizedKey("Home & Life"))
            }
        }
        return keys.sorted()
    }

    private static func context(
        stressWeights: [String: Double] = [:],
        breakWeights: [String: Double] = [:],
        planningWeights: [String: Double] = [:],
        changeWeights: [String: Double] = [:],
        areaWeights: [String: Double] = [:],
        signalWeights: [String: Double] = [:],
        comboBonuses: [BonusRule] = []
    ) -> SelectionContext {
        SelectionContext(
            stressWeights: normalizeMap(stressWeights),
            breakWeights: normalizeMap(breakWeights),
            planningWeights: normalizeMap(planningWeights),
            changeWeights: normalizeMap(changeWeights),
            areaWeights: normalizeMap(areaWeights),
            signalWeights: normalizeMap(signalWeights),
            comboBonuses: comboBonuses
        )
    }

    private static func bonus(
        score: Double,
        stress: [String] = [],
        breakPoint: [String] = [],
        planning: [String] = [],
        desired: [String] = [],
        areas: [String] = [],
        signals: [String] = []
    ) -> BonusRule {
        BonusRule(
            score: score,
            stress: stress.map(normalizedKey).filter { !$0.isEmpty },
            breakPoint: breakPoint.map(normalizedKey).filter { !$0.isEmpty },
            planning: planning.map(normalizedKey).filter { !$0.isEmpty },
            desired: desired.map(normalizedKey).filter { !$0.isEmpty },
            areas: areas.map(normalizedKey).filter { !$0.isEmpty },
            signals: signals.map(normalizedKey).filter { !$0.isEmpty }
        )
    }

    private static func normalizeMap(_ values: [String: Double]) -> [String: Double] {
        Dictionary(uniqueKeysWithValues: values.compactMap { key, value in
            let normalized = normalizedKey(key)
            guard !normalized.isEmpty else { return nil }
            return (normalized, value)
        })
    }

    private static func normalizedKey(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "`", with: "'")
            .replacingOccurrences(of: "&", with: " and ")
            .replacingOccurrences(of: "[^a-z0-9']+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
