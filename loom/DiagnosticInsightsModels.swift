import Foundation

struct DiagnosticAnswers: Codable, Hashable {
    var stress: String
    var breaksFirst: String
    var areas: [String]
    var planningStyle: String
    var firstChange: String

    init(
        stress: String,
        breaksFirst: String,
        areas: [String],
        planningStyle: String,
        firstChange: String
    ) {
        self.stress = stress
        self.breaksFirst = breaksFirst
        self.areas = areas
        self.planningStyle = planningStyle
        self.firstChange = firstChange
    }

    init(snapshot: PersonalizationSnapshot) {
        self.stress = snapshot.stressSource
        self.breaksFirst = snapshot.breakPoint
        self.areas = snapshot.lifeAreasSelected
        self.planningStyle = snapshot.planningReality
        self.firstChange = snapshot.desiredChange
    }
}

struct DiagnosticInsights: Codable, Hashable {
    var rootCause: String
    var nextDirection: String
    var debug: LoomAIDebug?
    var usage: LoomAIUsage?
}

struct DiagnosticInsightsClient: Codable, Hashable {
    var appVersion: String?
    var platform: String
    var screen: String

    init(
        appVersion: String? = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
        platform: String = "ios",
        screen: String = "diagnostic_insights"
    ) {
        self.appVersion = appVersion
        self.platform = platform
        self.screen = screen
    }
}
