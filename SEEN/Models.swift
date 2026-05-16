import Foundation

enum AuraAnswer: String, CaseIterable, Codable, Identifiable {
    case no = "No"
    case sometimes = "Sometimes"
    case yes = "Yes"

    var id: String { rawValue }

    var weight: Int {
        switch self {
        case .no: 0
        case .sometimes: 1
        case .yes: 2
        }
    }
}

struct AuraQuestion: Identifiable, Hashable {
    let id: String
    let prompt: String
    let detail: String
}

struct PartyPollQuestion: Identifiable, Hashable {
    let id: String
    let prompt: String
    let detail: String
}

struct DailyDrop: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let prompt: String
    let verdict: String
    let receipt: String
    let shareLine: String
    let tag: String
    let disclaimer: String

    init(
        id: String,
        title: String,
        prompt: String,
        verdict: String,
        receipt: String,
        shareLine: String,
        tag: String,
        disclaimer: String = "For entertainment only. Daily drops are generated locally and not saved."
    ) {
        self.id = id
        self.title = title
        self.prompt = prompt
        self.verdict = verdict
        self.receipt = receipt
        self.shareLine = shareLine
        self.tag = tag
        self.disclaimer = disclaimer
    }
}

let auraQuestions: [AuraQuestion] = [
    AuraQuestion(id: "overthink_texts", prompt: "Do you overthink texts?", detail: "Especially after a dry reply."),
    AuraQuestion(id: "act_unbothered", prompt: "Do you act unbothered?", detail: "Even when you are very bothered."),
    AuraQuestion(id: "emotionally_available", prompt: "Are you emotionally available?", detail: "Be honest. Your friends already know."),
    AuraQuestion(id: "reply_fast", prompt: "Do you reply instantly?", detail: "While pretending you just saw it."),
    AuraQuestion(id: "main_character", prompt: "Do you have main character energy?", detail: "Accidental or fully intentional."),
    AuraQuestion(id: "hard_to_read", prompt: "Are you hard to read?", detail: "Mystery or poor communication."),
    AuraQuestion(id: "spiral_silently", prompt: "Do you spiral silently?", detail: "The group chat gets the live commentary.")
]

let partyPollQuestions: [PartyPollQuestion] = [
    PartyPollQuestion(id: "overthinks", prompt: "Who overthinks the most?", detail: "The group chat has evidence."),
    PartyPollQuestion(id: "main_character", prompt: "Who has main character energy?", detail: "Accidental or fully directed."),
    PartyPollQuestion(id: "hard_to_read", prompt: "Who is hardest to read?", detail: "Mystery, chaos, or bad texting."),
    PartyPollQuestion(id: "secret_softie", prompt: "Who is secretly the soft one?", detail: "Cold outside, notes app inside."),
    PartyPollQuestion(id: "soft_launch", prompt: "Who would soft launch first?", detail: "Close Friends is part of the legal record."),
    PartyPollQuestion(id: "needs_approval", prompt: "Who needs group chat approval?", detail: "No major decisions without witnesses.")
]

struct AuraMetric: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let value: Int

    init(id: UUID = UUID(), name: String, value: Int) {
        self.id = id
        self.name = name
        self.value = value
    }
}

enum AuraVisual: String, Codable, Hashable {
    case pulse
    case prism
    case spark
    case eclipse
    case signal

    var symbol: String {
        switch self {
        case .pulse: "bolt.fill"
        case .prism: "sparkles"
        case .spark: "star.fill"
        case .eclipse: "moon.fill"
        case .signal: "dot.radiowaves.left.and.right"
        }
    }
}

enum DuoMode: String, CaseIterable, Codable, Identifiable, Hashable {
    case crushCheck = "Crush Check"
    case bestieAudit = "Bestie Audit"
    case softLaunchTest = "Soft Launch Test"
    case groupChatTrial = "Group Chat Trial"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .crushCheck:
            "For the person you keep explaining to your friends."
        case .bestieAudit:
            "For the friend who knows too much."
        case .softLaunchTest:
            "For the almost-postable situation."
        case .groupChatTrial:
            "For the duo that needs witnesses."
        }
    }

    var teaser: String {
        switch self {
        case .crushCheck:
            "Is this chemistry or just notifications?"
        case .bestieAudit:
            "Find out who carries the lore."
        case .softLaunchTest:
            "Close Friends or drafts?"
        case .groupChatTrial:
            "Let the screenshots testify."
        }
    }

    var handoffTitle: String {
        switch self {
        case .crushCheck:
            "Hand it to the crush."
        case .bestieAudit:
            "Hand it to your bestie."
        case .softLaunchTest:
            "Hand it to the soft launch."
        case .groupChatTrial:
            "Hand it to the defendant."
        }
    }

    var handoffText: String {
        switch self {
        case .crushCheck:
            "Your side is hidden. Let them answer, then AURA says if the chemistry is cute, chaotic, or a screenshot risk."
        case .bestieAudit:
            "Your side is hidden. Let them answer, then AURA audits the friendship dynamic."
        case .softLaunchTest:
            "Your side is hidden. Let them answer, then AURA checks if this is postable or just confusing."
        case .groupChatTrial:
            "Your side is hidden. Let them answer, then AURA delivers the verdict for the group chat."
        }
    }
}

struct AuraAnalysis: Identifiable, Codable, Hashable {
    let id: UUID
    let auraScore: Int
    let socialType: String
    let badgeTitle: String
    let rarity: String
    let visual: AuraVisual
    let roast: String
    let hiddenPattern: String
    let receipt: String
    let matchup: String
    let shareLine: String
    let friendHook: String
    let challenge: String
    let metrics: [AuraMetric]
    let disclaimer: String

    init(
        id: UUID = UUID(),
        auraScore: Int,
        socialType: String,
        badgeTitle: String,
        rarity: String,
        visual: AuraVisual,
        roast: String,
        hiddenPattern: String,
        receipt: String,
        matchup: String,
        shareLine: String,
        friendHook: String,
        challenge: String,
        metrics: [AuraMetric],
        disclaimer: String = "For entertainment only. Not a medical or psychological diagnosis."
    ) {
        self.id = id
        self.auraScore = min(100, max(0, auraScore))
        self.socialType = socialType
        self.badgeTitle = badgeTitle
        self.rarity = rarity
        self.visual = visual
        self.roast = roast
        self.hiddenPattern = hiddenPattern
        self.receipt = receipt
        self.matchup = matchup
        self.shareLine = shareLine
        self.friendHook = friendHook
        self.challenge = challenge
        self.metrics = metrics
        self.disclaimer = disclaimer
    }
}

struct AuraCompatibility: Identifiable, Codable, Hashable {
    let id: UUID
    let modeTitle: String
    let modeHook: String
    let score: Int
    let title: String
    let verdict: String
    let tension: String
    let greenFlag: String
    let shareLine: String
    let firstType: String
    let secondType: String
    let disclaimer: String

    init(
        id: UUID = UUID(),
        modeTitle: String = DuoMode.crushCheck.rawValue,
        modeHook: String = DuoMode.crushCheck.subtitle,
        score: Int,
        title: String,
        verdict: String,
        tension: String,
        greenFlag: String,
        shareLine: String,
        firstType: String,
        secondType: String,
        disclaimer: String = "For entertainment only. Not a medical, psychological, or relationship diagnosis."
    ) {
        self.id = id
        self.modeTitle = modeTitle
        self.modeHook = modeHook
        self.score = min(100, max(0, score))
        self.title = title
        self.verdict = verdict
        self.tension = tension
        self.greenFlag = greenFlag
        self.shareLine = shareLine
        self.firstType = firstType
        self.secondType = secondType
        self.disclaimer = disclaimer
    }
}

struct PartyPollScore: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let votes: Int

    init(id: UUID = UUID(), name: String, votes: Int) {
        self.id = id
        self.name = name
        self.votes = votes
    }
}

struct PartyPollResult: Identifiable, Codable, Hashable {
    let id: UUID
    let winner: String
    let title: String
    let verdict: String
    let receipt: String
    let shareLine: String
    let scores: [PartyPollScore]
    let disclaimer: String

    init(
        id: UUID = UUID(),
        winner: String,
        title: String,
        verdict: String,
        receipt: String,
        shareLine: String,
        scores: [PartyPollScore],
        disclaimer: String = "For entertainment only. Votes are local and not saved."
    ) {
        self.id = id
        self.winner = winner
        self.title = title
        self.verdict = verdict
        self.receipt = receipt
        self.shareLine = shareLine
        self.scores = scores
        self.disclaimer = disclaimer
    }
}
