import Foundation

enum PurposeVisionAutoWriteSuggestionTable {
    struct Entry {
        let text: String
        let tags: [String]
    }

    static let entries: [Entry] = [
        .init(text: "I build a calm and focused life where my daily choices create steady progress in the areas that matter most.", tags: ["wants_balance", "wants_clarity", "overwhelmed"]),
        .init(text: "I live with clarity and direction, using my time on what matters instead of reacting to everything around me.", tags: ["wants_clarity", "reactive", "overwhelmed"]),
        .init(text: "I create a life that feels organized, intentional, and deeply aligned with my real priorities.", tags: ["wants_control", "wants_clarity", "off_track"]),
        .init(text: "I move through my weeks with calm focus, protecting what matters and making meaningful progress without constant stress.", tags: ["overwhelmed", "focus_drift", "wants_balance"]),
        .init(text: "I build a steady life where I follow through consistently and trust myself to finish what matters.", tags: ["wants_consistency", "completion_gap", "consistent"]),
        .init(text: "I become someone who acts with intention, keeps promises to myself, and turns clear priorities into real results.", tags: ["wants_control", "wants_consistency", "completion_gap"]),
        .init(text: "I create momentum every week by focusing on the few actions that truly move my life forward.", tags: ["wants_progress", "momentum_drop", "overwhelmed"]),
        .init(text: "I live a disciplined and peaceful life where my attention is not scattered and my energy goes where it matters most.", tags: ["focus_drift", "wants_balance", "wants_control"]),
        .init(text: "I build a life that feels spacious, ordered, and purposeful instead of rushed, cluttered, and reactive.", tags: ["reactive", "overwhelmed", "wants_balance"]),
        .init(text: "I create real progress through simple consistent action, not pressure, chaos, or last-minute urgency.", tags: ["reactive", "wants_consistency", "wants_progress"]),

        .init(text: "I build meaningful work that creates value, supports my freedom, and reflects the best of what I can contribute.", tags: ["career_area", "wants_progress", "wants_clarity"]),
        .init(text: "I create work that is focused, useful, and financially strong while leaving room for a full life beyond work.", tags: ["career_area", "finance_area", "wants_balance"]),
        .init(text: "I build a career with clarity and momentum, where my effort compounds into meaningful contribution and freedom.", tags: ["career_area", "wants_progress", "wants_clarity"]),
        .init(text: "I create a business and work life that rewards deep focus, good systems, and work that genuinely matters.", tags: ["career_area", "productivity_area", "wants_control"]),
        .init(text: "I do work I am proud of, build something valuable, and create the freedom to choose how I live.", tags: ["career_area", "finance_area", "wants_progress"]),
        .init(text: "I build a career that is both effective and sustainable, where clear priorities drive strong results without burnout.", tags: ["career_area", "low_energy", "wants_balance"]),
        .init(text: "I become someone whose work is marked by focus, craftsmanship, and steady execution on what matters most.", tags: ["career_area", "productivity_area", "consistent"]),
        .init(text: "I create professional momentum by turning my best ideas into useful outcomes that help people and move my life forward.", tags: ["career_area", "wants_progress", "activation_gap"]),
        .init(text: "I build work that is ambitious and grounded, creating impact without losing my health, peace, or relationships.", tags: ["career_area", "health_area", "relationships_area"]),
        .init(text: "I create lasting value through focused work, strong follow-through, and the courage to keep building over time.", tags: ["career_area", "completion_gap", "wants_progress"]),

        .init(text: "I build financial stability and freedom so my decisions come from purpose and choice instead of pressure.", tags: ["finance_area", "financial_pressure", "wants_control"]),
        .init(text: "I create a life where money supports peace, flexibility, and the freedom to invest in what matters most.", tags: ["finance_area", "financial_pressure", "wants_balance"]),
        .init(text: "I become financially steady and intentional, using my resources to create security, options, and long-term freedom.", tags: ["finance_area", "wants_control", "wants_clarity"]),
        .init(text: "I build wealth with discipline and patience so my future feels secure, spacious, and self-directed.", tags: ["finance_area", "wants_consistency", "wants_balance"]),
        .init(text: "I create a strong financial foundation that lowers stress and gives me room to live with more confidence and choice.", tags: ["finance_area", "financial_pressure", "overwhelmed"]),
        .init(text: "I use money wisely, grow it steadily, and create a life that feels stable instead of stretched and reactive.", tags: ["finance_area", "financial_pressure", "reactive"]),
        .init(text: "I build enough financial strength to support my goals, protect my peace, and expand what is possible in my life.", tags: ["finance_area", "wants_progress", "wants_balance"]),
        .init(text: "I become someone who handles money with clarity, intention, and long-term thinking instead of avoidance or stress.", tags: ["finance_area", "wants_clarity", "wants_control"]),
        .init(text: "I create financial momentum through focused choices that build security now and freedom later.", tags: ["finance_area", "wants_progress", "consistent"]),
        .init(text: "I build a life where my finances are organized, resilient, and aligned with the future I want to create.", tags: ["finance_area", "wants_control", "off_track"]),

        .init(text: "I care for my health so I have the energy, strength, and clarity to fully live the life I want.", tags: ["health_area", "low_energy", "wants_progress"]),
        .init(text: "I build a strong and healthy life where my body and mind support the future I am trying to create.", tags: ["health_area", "low_energy", "wants_clarity"]),
        .init(text: "I create daily habits that give me more energy, more steadiness, and more trust in myself over time.", tags: ["health_area", "low_energy", "wants_consistency"]),
        .init(text: "I become someone whose energy is protected, whose health is supported, and whose daily life feels sustainable.", tags: ["health_area", "low_energy", "wants_balance"]),
        .init(text: "I live with more strength and vitality, making choices that support my body, mind, and long-term wellbeing.", tags: ["health_area", "wants_balance", "wants_progress"]),
        .init(text: "I build a healthy life that feels grounded and sustainable rather than extreme, inconsistent, or draining.", tags: ["health_area", "low_energy", "wants_consistency"]),
        .init(text: "I create the physical and mental energy to show up well for my work, relationships, and future.", tags: ["health_area", "career_area", "relationships_area"]),
        .init(text: "I become stronger, steadier, and more energized through simple habits I can actually maintain.", tags: ["health_area", "consistent", "activation_gap"]),
        .init(text: "I build health routines that reduce friction, increase energy, and help me live with more confidence and momentum.", tags: ["health_area", "low_energy", "wants_progress"]),
        .init(text: "I create a life where my health is a foundation for freedom, not something I keep postponing until later.", tags: ["health_area", "activation_gap", "wants_clarity"]),

        .init(text: "I build deep and steady relationships by showing up with presence, care, honesty, and intention.", tags: ["relationships_area", "relationship_stress", "wants_consistency"]),
        .init(text: "I create a life where the people I love feel supported, connected, and genuinely prioritized.", tags: ["relationships_area", "wants_balance", "wants_clarity"]),
        .init(text: "I become someone who protects meaningful relationships with consistent attention, warmth, and follow-through.", tags: ["relationships_area", "completion_gap", "wants_consistency"]),
        .init(text: "I build strong relationships that are honest, secure, and life-giving instead of rushed or neglected.", tags: ["relationships_area", "relationship_stress", "overwhelmed"]),
        .init(text: "I create more closeness and trust by being fully present with the people who matter most.", tags: ["relationships_area", "focus_drift", "wants_balance"]),
        .init(text: "I live in a way that strengthens love, friendship, and connection through the small ways I show up each day.", tags: ["relationships_area", "wants_consistency", "consistent"]),
        .init(text: "I build a relational life marked by care, depth, and consistency instead of distraction or emotional distance.", tags: ["relationships_area", "focus_drift", "wants_consistency"]),
        .init(text: "I create the time and emotional space to invest in the people I most want to love well.", tags: ["relationships_area", "overwhelmed", "wants_balance"]),
        .init(text: "I become someone whose relationships are strengthened by honesty, attention, and meaningful shared time.", tags: ["relationships_area", "wants_clarity", "wants_balance"]),
        .init(text: "I build a life where love is not squeezed to the margins but protected as part of what matters most.", tags: ["relationships_area", "reactive", "wants_clarity"])
    ]

    static func pickSuggestions(
        personalizationSnapshot: PersonalizationSnapshot?,
        currentVision: String,
        previousSuggestions: [String],
        count: Int = 2
    ) -> [String] {
        let excluded = Set(([currentVision] + previousSuggestions).map(normalizedValue).filter { !$0.isEmpty })
        let desiredTags = Set((personalizationSnapshot?.derivedTags ?? []) + (personalizationSnapshot?.lifeAreasSelected ?? []).map(normalizedAreaTag))
        let currentVisionTokens = Set(normalizedValue(currentVision).split(separator: " ").map(String.init))

        let ranked = entries
            .filter { !excluded.contains(normalizedValue($0.text)) }
            .map { entry -> (entry: Entry, score: Int) in
                let tagScore = entry.tags.reduce(0) { partial, tag in
                    partial + (desiredTags.contains(tag) ? 3 : 0)
                }
                let overlap = Set(normalizedValue(entry.text).split(separator: " ").map(String.init)).intersection(currentVisionTokens).count
                let noveltyScore = max(0, 8 - overlap)
                return (entry, tagScore + noveltyScore)
            }
            .sorted {
                if $0.score != $1.score { return $0.score > $1.score }
                return $0.entry.text < $1.entry.text
            }

        return Array(ranked.prefix(max(1, count)).map(\.entry.text))
    }

    private static func normalizedAreaTag(_ value: String) -> String {
        let lower = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lower.contains("career") || lower.contains("business") { return "career_area" }
        if lower.contains("wealth") || lower.contains("finance") { return "finance_area" }
        if lower.contains("health") { return "health_area" }
        if lower.contains("relationships") || lower.contains("love") { return "relationships_area" }
        if lower.contains("productivity") { return "productivity_area" }
        return lower.replacingOccurrences(of: " ", with: "_")
    }

    private static func normalizedValue(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: #"[^\p{L}\p{N}\s]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
