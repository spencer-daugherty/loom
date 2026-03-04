import Foundation

enum PassionAutoWriteSuggestionTable {
    static let orderedEmotionKeys = ["love", "vows", "thrill", "just"]

    private static let csvData = """
type,passion
Love,Family time
Love,Deep conversations
Love,Helping others
Love,Building things
Love,Learning new ideas
Love,Creative work
Love,Solving problems
Love,Personal growth
Love,Meaningful work
Love,Nature walks
Love,Adventure travel
Love,Exploring cities
Love,Fitness training
Love,Healthy living
Love,Cooking meals
Love,Music discovery
Love,Reading books
Love,Writing ideas
Love,Teaching others
Love,Mentoring people
Love,Community building
Love,Friendship
Love,Laughter
Love,Storytelling
Love,Faith practice
Love,Spiritual growth
Love,Volunteering
Love,Innovation
Love,Entrepreneurship
Love,Leadership
Love,Strategy thinking
Love,Design
Love,Photography
Love,Art creation
Love,Film making
Love,Gaming
Love,Sports
Love,Competition
Love,Outdoor adventure
Love,Hiking trails
Love,Ocean time
Love,Quiet mornings
Love,Sunrise views
Love,Coffee chats
Love,Late night talks
Love,Freedom
Love,Independence
Love,Making impact
Love,Building legacy
Love,Creating value
Vow,Honest living
Vow,Keep promises
Vow,Do the work
Vow,Show up daily
Vow,Protect family
Vow,Lead by example
Vow,Tell the truth
Vow,Stay curious
Vow,Finish what I start
Vow,Keep learning
Vow,Serve others
Vow,Build trust
Vow,Stay disciplined
Vow,Respect others
Vow,Practice gratitude
Vow,Keep perspective
Vow,Act with courage
Vow,Do the right thing
Vow,Be dependable
Vow,Listen first
Vow,Choose integrity
Vow,Stay humble
Vow,Protect my time
Vow,Honor commitments
Vow,Own my mistakes
Vow,Grow every year
Vow,Seek wisdom
Vow,Give back
Vow,Lift others
Vow,Stay patient
Vow,Work with purpose
Vow,Stay resilient
Vow,Respect myself
Vow,Stay present
Vow,Care deeply
Vow,Think long term
Vow,Keep improving
Vow,Value people
Vow,Protect peace
Vow,Choose kindness
Vow,Speak clearly
Vow,Build something real
Vow,Leave things better
Vow,Stay focused
Vow,Respect my word
Vow,Pursue excellence
Vow,Stay balanced
Vow,Act with intention
Vow,Lead responsibly
Vow,Live with purpose
Thrill,Big ideas
Thrill,Solving puzzles
Thrill,Building products
Thrill,Creative breakthroughs
Thrill,Learning fast
Thrill,New challenges
Thrill,Winning moments
Thrill,Bold moves
Thrill,Starting projects
Thrill,Finishing strong
Thrill,Discovery
Thrill,Exploration
Thrill,Adventure travel
Thrill,Trying new things
Thrill,Deep thinking
Thrill,Strategy games
Thrill,Competition
Thrill,Fast progress
Thrill,Innovation
Thrill,Entrepreneurship
Thrill,Leading teams
Thrill,Teaching others
Thrill,Creating systems
Thrill,Design thinking
Thrill,Story creation
Thrill,Public speaking
Thrill,Debate
Thrill,New technology
Thrill,Future thinking
Thrill,Complex problems
Thrill,Risk taking
Thrill,Breaking limits
Thrill,High performance
Thrill,Skill mastery
Thrill,Outdoor adventure
Thrill,Mountain views
Thrill,Ocean waves
Thrill,Night drives
Thrill,City energy
Thrill,Live events
Thrill,Music festivals
Thrill,Sports moments
Thrill,Unexpected ideas
Thrill,Connecting dots
Thrill,Turning vision real
Thrill,Momentum
Thrill,Growth challenges
Thrill,Breakthrough moments
Thrill,Making impact
Thrill,Building the future
Hate,Broken promises
Hate,Dishonesty
Hate,Excuses
Hate,Laziness
Hate,Disrespect
Hate,Cruelty
Hate,Bullying
Hate,Manipulation
Hate,Blaming others
Hate,Selfishness
Hate,Greed
Hate,Corruption
Hate,Cheating
Hate,Gossip
Hate,Drama
Hate,Victim mindset
Hate,Quitting early
Hate,Fake behavior
Hate,Arrogance
Hate,Close mindedness
Hate,Intolerance
Hate,Negativity
Hate,Wasteful habits
Hate,Time wasting
Hate,Poor effort
Hate,Half work
Hate,Ignoring problems
Hate,Avoiding truth
Hate,Playing small
Hate,Weak standards
Hate,Toxic behavior
Hate,Broken trust
Hate,Lying
Hate,Backstabbing
Hate,Unfair treatment
Hate,Taking advantage
Hate,Harmful habits
Hate,Neglect
Hate,Irresponsibility
Hate,Lack of integrity
Hate,Lack of accountability
Hate,Giving up
Hate,Staying stagnant
Hate,Fear control
Hate,Playing the victim
Hate,Abusing power
Hate,Empty talk
Hate,False promises
Hate,Energy drain
Hate,Mindless scrolling
Hate,Settling for less
"""

    static let suggestionsByEmotion: [String: [String]] = {
        var table: [String: [String]] = [
            "love": [],
            "vows": [],
            "thrill": [],
            "just": []
        ]

        for rawLine in csvData.split(whereSeparator: \.isNewline).dropFirst() {
            let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            let parts = line.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }
            let type = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
            let passion = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let emotion = normalizedEmotionKey(from: type), !passion.isEmpty else { continue }
            table[emotion, default: []].append(passion)
        }

        return table
    }()

    static func pickSuggestions(
        filterEmotion: String?,
        existingByEmotion: [String: [String]],
        singleBucketCount: Int = 2
    ) -> [(emotion: String, passion: String)] {
        let normalizedExistingByEmotion = Dictionary(uniqueKeysWithValues: orderedEmotionKeys.map { key in
            let existing = existingByEmotion[key] ?? []
            return (key, Set(existing.map(normalizedValue)))
        })

        if let filterEmotion,
           orderedEmotionKeys.contains(filterEmotion) {
            let candidates = (suggestionsByEmotion[filterEmotion] ?? [])
                .filter { !(normalizedExistingByEmotion[filterEmotion] ?? []).contains(normalizedValue($0)) }
                .shuffled()
            return Array(candidates.prefix(max(1, singleBucketCount))).map { (emotion: filterEmotion, passion: $0) }
        }

        var selected: [(emotion: String, passion: String)] = []
        var usedNormalizedAcrossBuckets = Set<String>()

        for emotion in orderedEmotionKeys {
            let existingSet = normalizedExistingByEmotion[emotion] ?? []
            let candidates = (suggestionsByEmotion[emotion] ?? [])
                .filter { !existingSet.contains(normalizedValue($0)) }
                .filter { !usedNormalizedAcrossBuckets.contains(normalizedValue($0)) }
                .shuffled()

            guard let first = candidates.first else { continue }
            usedNormalizedAcrossBuckets.insert(normalizedValue(first))
            selected.append((emotion: emotion, passion: first))
        }

        return selected
    }

    private static func normalizedEmotionKey(from raw: String) -> String? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if value.contains("love") { return "love" }
        if value.contains("vow") || value.contains("commit") { return "vows" }
        if value.contains("thrill") || value.contains("excite") { return "thrill" }
        if value.contains("hate") || value.contains("just") { return "just" }
        return nil
    }

    private static func normalizedValue(_ raw: String) -> String {
        raw
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: #"[^\p{L}\p{N}\s]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
