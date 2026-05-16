import Foundation

enum AuraAnalyzerError: LocalizedError {
    case invalidResponse
    case missingEndpoint

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "The AI result could not be read."
        case .missingEndpoint:
            "AURA analysis endpoint is not configured."
        }
    }
}

protocol AuraAnalyzing {
    func analyze(answers: [String: AuraAnswer]) async throws -> AuraAnalysis
}

struct AuraAnalyzer: AuraAnalyzing {
    private let remote = RemoteAuraAnalyzer()
    private let fallback = LocalAuraAnalyzer()

    func analyze(answers: [String: AuraAnswer]) async throws -> AuraAnalysis {
        do {
            return try await remote.analyze(answers: answers)
        } catch {
            return fallback.analyze(answers: answers)
        }
    }
}

struct LocalAuraAnalyzer {
    func analyze(answers: [String: AuraAnswer]) -> AuraAnalysis {
        let total = auraQuestions.reduce(0) { partial, question in
            partial + (answers[question.id]?.weight ?? 1)
        }
        let score = min(98, max(41, 44 + total * 5))
        let overthink = answers["overthink_texts"]?.weight ?? 1
        let unbothered = answers["act_unbothered"]?.weight ?? 1
        let available = answers["emotionally_available"]?.weight ?? 1
        let mainCharacter = answers["main_character"]?.weight ?? 1
        let hardToRead = answers["hard_to_read"]?.weight ?? 1

        let type: AuraType
        if overthink >= 2 && unbothered >= 1 {
            type = .fastReplyIceQueen
        } else if mainCharacter >= 2 {
            type = .mainCharacterWitness
        } else if hardToRead >= 2 || available == 0 {
            type = .softLaunchMystery
        } else if total >= 10 {
            type = .groupChatOracle
        } else {
            type = .lowKeyChaos
        }
        let copy = type.copy()

        return AuraAnalysis(
            auraScore: score,
            socialType: copy.socialType,
            badgeTitle: copy.badgeTitle,
            rarity: copy.rarity,
            visual: copy.visual,
            roast: copy.roast,
            hiddenPattern: copy.hiddenPattern,
            receipt: copy.receipt,
            matchup: copy.matchup,
            shareLine: copy.shareLine,
            friendHook: copy.friendHook,
            challenge: copy.challenge,
            metrics: [
                AuraMetric(name: "Overthink", value: min(100, 34 + overthink * 28 + total * 2)),
                AuraMetric(name: "Unbothered Act", value: min(100, 38 + unbothered * 26 + hardToRead * 8)),
                AuraMetric(name: "Main Character", value: min(100, 35 + mainCharacter * 30 + total)),
                AuraMetric(name: "Readability", value: max(12, 86 - hardToRead * 26 - unbothered * 10))
            ]
        )
    }
}

struct LocalCompatibilityAnalyzer {
    func analyze(first: AuraAnalysis, second: AuraAnalysis, mode: DuoMode = .crushCheck) -> AuraCompatibility {
        let scoreGap = abs(first.auraScore - second.auraScore)
        let visualBonus = first.visual == second.visual ? 10 : 0
        let metricGap = zip(first.metrics, second.metrics).reduce(0) { partial, pair in
            partial + abs(pair.0.value - pair.1.value)
        } / max(1, min(first.metrics.count, second.metrics.count))
        let rawScore = 88 - scoreGap / 2 - metricGap / 5 + visualBonus
        let score = min(98, max(42, rawScore))
        let copy = DuoCopy.copy(for: score, first: first, second: second, mode: mode)

        return AuraCompatibility(
            modeTitle: mode.rawValue,
            modeHook: mode.subtitle,
            score: score,
            title: copy.title,
            verdict: copy.verdict,
            tension: copy.tension,
            greenFlag: copy.greenFlag,
            shareLine: copy.shareLine,
            firstType: first.socialType,
            secondType: second.socialType
        )
    }
}

struct LocalPartyPollAnalyzer {
    func analyze(names: [String], votes: [String: String]) -> PartyPollResult {
        let cleanNames = names.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let fallbackNames = cleanNames.isEmpty ? ["Someone"] : cleanNames
        var counts = Dictionary(uniqueKeysWithValues: fallbackNames.map { ($0, 0) })

        for selected in votes.values {
            guard counts[selected] != nil else { continue }
            counts[selected, default: 0] += 1
        }

        let scores = fallbackNames
            .map { PartyPollScore(name: $0, votes: counts[$0, default: 0]) }
            .sorted { lhs, rhs in
                if lhs.votes == rhs.votes {
                    lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                } else {
                    lhs.votes > rhs.votes
                }
            }

        let winner = scores.first?.name ?? fallbackNames[0]
        let topVotes = scores.first?.votes ?? 0
        let runnerUp = scores.dropFirst().first?.name ?? "the group chat"
        let totalVotes = max(1, votes.count)
        let heat = Int((Double(topVotes) / Double(totalVotes)) * 100)

        let title: String
        let verdict: String
        let receipt: String
        let shareLine: String

        if heat >= 60 {
            title = "\(winner) Won The Lore Vote"
            verdict = "The room did not hesitate. \(winner) is officially the person everyone has notes on."
            receipt = "Vote share: \(heat)%. That is not a coincidence, that is a group consensus."
            shareLine = "\(winner) got exposed by the group chat."
        } else if topVotes == 1 {
            title = "No Clear Villain"
            verdict = "The votes scattered, which means this group has too many plotlines running at once."
            receipt = "\(winner) barely led the board while \(runnerUp) stayed suspiciously close."
            shareLine = "No winner. Everyone is under review."
        } else {
            title = "\(winner) Is The Main Evidence"
            verdict = "\(winner) took the top spot, but \(runnerUp) is close enough to request a recount."
            receipt = "The group vote says \(winner) has the strongest aura in the room tonight."
            shareLine = "\(winner) won, but the group has questions."
        }

        return PartyPollResult(
            winner: winner,
            title: title,
            verdict: verdict,
            receipt: receipt,
            shareLine: shareLine,
            scores: scores
        )
    }
}

struct LocalDailyDropProvider {
    func today(now: Date = Date(), calendar: Calendar = .current) -> DailyDrop {
        let startOfDay = calendar.startOfDay(for: now)
        let dayNumber = calendar.ordinality(of: .day, in: .era, for: startOfDay) ?? 1
        let index = abs(dayNumber) % drops.count
        let base = drops[index]

        return DailyDrop(
            id: dailyKey(for: startOfDay, calendar: calendar),
            title: base.title,
            prompt: base.prompt,
            verdict: base.verdict,
            receipt: base.receipt,
            shareLine: base.shareLine,
            tag: base.tag
        )
    }

    private func dailyKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    private var drops: [DailyDropTemplate] {
        [
            DailyDropTemplate(title: "The Screenshot Test", prompt: "Who would you send this to first?", verdict: "If one name appeared instantly, that is the read. AURA is not saying text them, but your thumb already voted.", receipt: "Today's signal is about impulse. The first person you thought of probably owns the storyline.", shareLine: "My daily drop called out my camera roll.", tag: "SCREENSHOT"),
            DailyDropTemplate(title: "Close Friends Energy", prompt: "What are you posting for attention but calling casual?", verdict: "Today rewards people who can admit the soft launch was never subtle. The vibe is private, but the clues are public.", receipt: "If the caption needs explaining, the group chat already has the explanation.", shareLine: "Close Friends was the message.", tag: "SOFT LAUNCH"),
            DailyDropTemplate(title: "Reply Speed Trial", prompt: "Are you busy, or are you performing busy?", verdict: "The daily verdict says your notification habits are louder than your words. You can be mysterious or reachable, but doing both is suspicious.", receipt: "You saw it. You decided the timing needed choreography.", shareLine: "Busy, but somehow already typing.", tag: "TEXTING"),
            DailyDropTemplate(title: "Group Chat Weather", prompt: "Who is about to become the topic?", verdict: "Today has evidence-board energy. Someone's tiny update is going to become a full panel discussion.", receipt: "No one asked for screenshots, which means everyone is waiting for them.", shareLine: "The group chat forecast is messy.", tag: "LORE"),
            DailyDropTemplate(title: "Main Character Audit", prompt: "Is this a normal day or an episode?", verdict: "AURA says the plot is trying to find you. Keep acting surprised if you want, but the room noticed the entrance.", receipt: "The outfit, the timing, the tiny inconvenience. All suspiciously cinematic.", shareLine: "Not dramatic. Just correctly lit.", tag: "AURA"),
            DailyDropTemplate(title: "Unreadable Era", prompt: "Are you mysterious or just not explaining anything?", verdict: "Today's drop says the mystery is working, but not always in your favor. Someone is filling in the blanks for you.", receipt: "Low context creates high fan fiction.", shareLine: "Hard to read, easy to screenshot.", tag: "MYSTERY"),
            DailyDropTemplate(title: "Bestie Evidence", prompt: "Who knows too much and still stayed?", verdict: "The daily read belongs to the person who has seen every version and kept the receipts with love.", receipt: "Some friendships are built on loyalty. This one also has timestamps.", shareLine: "My bestie has federal-level receipts.", tag: "BESTIE")
        ]
    }
}

private struct DailyDropTemplate {
    let title: String
    let prompt: String
    let verdict: String
    let receipt: String
    let shareLine: String
    let tag: String
}

private enum DuoCopy {
    static func copy(for score: Int, first: AuraAnalysis, second: AuraAnalysis, mode: DuoMode) -> DuoResultCopy {
        let typePair = "\(first.socialType) x \(second.socialType)"
        let base: DuoResultCopy

        if score >= 86 {
            base = [
                DuoResultCopy(title: "Main Feed Match", verdict: "This is the kind of duo that makes everyone else feel like they missed a prequel.", tension: "The risk: you both know exactly how to make a small moment dramatic.", greenFlag: "The green flag: the chemistry is obvious without needing a caption.", shareLine: "Too compatible to be casual."),
                DuoResultCopy(title: "Screenshot Chemistry", verdict: "Your combined aura has group chat evidence written all over it.", tension: "The risk: one look becomes a theory thread.", greenFlag: "The green flag: you make each other easier to read.", shareLine: "The group chat will have opinions."),
                DuoResultCopy(title: "Plot Armor Pair", verdict: "\(typePair) should not work this smoothly, which is exactly why it does.", tension: "The risk: minor plans become full episodes.", greenFlag: "The green flag: neither of you has to over-explain the bit.", shareLine: "High chemistry. Low plausible denial.")
            ].randomElement()!
        } else if score >= 72 {
            base = [
                DuoResultCopy(title: "High Chemistry, Mild Drama", verdict: "This duo has enough spark to be fun and enough tension to keep screenshots alive.", tension: "The risk: both of you wait for the other person to say the obvious thing.", greenFlag: "The green flag: the banter carries even when the timing is messy.", shareLine: "Fun together. Slightly dangerous."),
                DuoResultCopy(title: "Soft Launch Material", verdict: "The vibe is strong enough to notice and vague enough to deny.", tension: "The risk: mixed signals could become the whole personality of this duo.", greenFlag: "The green flag: you both make ordinary moments feel postable.", shareLine: "Not official. Very observable."),
                DuoResultCopy(title: "Mutual Menace Energy", verdict: "\(typePair) is a funny combination because neither side is as chill as advertised.", tension: "The risk: you enable the exact behavior your friends complain about.", greenFlag: "The green flag: the laughter arrives before the explanation.", shareLine: "Compatible, but supervised.")
            ].randomElement()!
        } else if score >= 58 {
            base = [
                DuoResultCopy(title: "Chaos-Compatible", verdict: "This could be iconic, but only if one of you stops pretending to be normal.", tension: "The risk: both of you read between lines that were not there.", greenFlag: "The green flag: the weirdness is mutual enough to become a feature.", shareLine: "Messy, but not boring."),
                DuoResultCopy(title: "Interesting Problem", verdict: "\(typePair) has enough contrast to be either hilarious or exhausting.", tension: "The risk: timing, tone, and ego all want separate meetings.", greenFlag: "The green flag: neither of you is forgettable to the other.", shareLine: "A little friction. A lot of lore."),
                DuoResultCopy(title: "Group Chat Experiment", verdict: "This duo needs witnesses because the chemistry is not self-explanatory.", tension: "The risk: one person says 'it's fine' and it is absolutely not fine.", greenFlag: "The green flag: friends would keep asking what happened next.", shareLine: "Needs context. Has potential.")
            ].randomElement()!
        } else {
            base = [
                DuoResultCopy(title: "Screenshot Pending", verdict: "This match is less 'easy chemistry' and more 'why are we still talking about it?'", tension: "The risk: one person wants clarity while the other communicates in fog.", greenFlag: "The green flag: the contrast is memorable, even when it is inconvenient.", shareLine: "Low score. High curiosity."),
                DuoResultCopy(title: "Mixed Signal Match", verdict: "\(typePair) feels like a notification you should not open but absolutely will.", tension: "The risk: both of you could accidentally turn silence into a storyline.", greenFlag: "The green flag: boring is not on the menu.", shareLine: "Not stable. Still interesting."),
                DuoResultCopy(title: "Do Not Leave Unsupervised", verdict: "This duo may not be peaceful, but the post-game analysis would be elite.", tension: "The risk: assumptions become facts before anyone asks a question.", greenFlag: "The green flag: at least the group chat will be fed.", shareLine: "Bad idea, good story.")
            ].randomElement()!
        }

        return personalize(base, for: mode)
    }

    private static func personalize(_ copy: DuoResultCopy, for mode: DuoMode) -> DuoResultCopy {
        switch mode {
        case .crushCheck:
            DuoResultCopy(
                title: "Crush Check: \(copy.title)",
                verdict: "\(copy.verdict) The flirt potential is visible enough that pretending not to notice is a choice.",
                tension: "Crush risk: \(copy.tension.replacingOccurrences(of: "The risk: ", with: ""))",
                greenFlag: copy.greenFlag,
                shareLine: "Crush check says: \(copy.shareLine)"
            )
        case .bestieAudit:
            DuoResultCopy(
                title: "Bestie Audit: \(copy.title)",
                verdict: "\(copy.verdict) This is friend chemistry with enough evidence to survive a notes-app investigation.",
                tension: "Bestie risk: \(copy.tension.replacingOccurrences(of: "The risk: ", with: ""))",
                greenFlag: "Bestie proof: \(copy.greenFlag.replacingOccurrences(of: "The green flag: ", with: ""))",
                shareLine: "Bestie audit: \(copy.shareLine)"
            )
        case .softLaunchTest:
            DuoResultCopy(
                title: "Soft Launch Test: \(copy.title)",
                verdict: "\(copy.verdict) The real question is whether this belongs on close friends or should stay in drafts.",
                tension: "Soft launch risk: \(copy.tension.replacingOccurrences(of: "The risk: ", with: ""))",
                greenFlag: "Postable proof: \(copy.greenFlag.replacingOccurrences(of: "The green flag: ", with: ""))",
                shareLine: "Soft launch test: \(copy.shareLine)"
            )
        case .groupChatTrial:
            DuoResultCopy(
                title: "Group Chat Verdict: \(copy.title)",
                verdict: "\(copy.verdict) The group chat would request more screenshots before closing the case.",
                tension: "Exhibit A: \(copy.tension.replacingOccurrences(of: "The risk: ", with: ""))",
                greenFlag: "Defense: \(copy.greenFlag.replacingOccurrences(of: "The green flag: ", with: ""))",
                shareLine: "Group chat verdict: \(copy.shareLine)"
            )
        }
    }
}

private struct DuoResultCopy {
    let title: String
    let verdict: String
    let tension: String
    let greenFlag: String
    let shareLine: String
}

private enum AuraType {
    case fastReplyIceQueen
    case mainCharacterWitness
    case softLaunchMystery
    case groupChatOracle
    case lowKeyChaos

    func copy() -> AuraCopy {
        copies.randomElement() ?? copies[0]
    }

    private var copies: [AuraCopy] {
        switch self {
        case .fastReplyIceQueen:
            [
                AuraCopy(socialType: "Fast-Reply Ice Queen", badgeTitle: "Read Receipt Royalty", rarity: "Top 8% notification menace", visual: .pulse, roast: "You act emotionally unavailable but reply instantly.", hiddenPattern: "You hide effort by pretending it was accidental.", receipt: "Typed, deleted, replied in 12 seconds.", matchup: "Best with someone direct enough to skip the guessing game.", shareLine: "Emotionally unavailable. Chronically online.", friendHook: "Ask friends if you are unreadable or just fast with notifications.", challenge: "Send this to the friend who clocks your reply speed."),
                AuraCopy(socialType: "Read Receipt Royalty", badgeTitle: "The Instant Ghost", rarity: "Rare combo: cold tone, warm battery", visual: .pulse, roast: "You leave people on read spiritually, not technically.", hiddenPattern: "You care first, then perform distance after.", receipt: "You say 'just saw this' with the screen still warm.", matchup: "Best with someone who answers the question you avoided.", shareLine: "Fast replies. Slow feelings.", friendHook: "Send it to someone who has seen your typing bubble disappear.", challenge: "Post this and let the group chat verify the evidence."),
                AuraCopy(socialType: "Notification Actress", badgeTitle: "The Chill Performance", rarity: "Top 12% fake unbothered", visual: .pulse, roast: "Your phone is face down but your soul is refreshing.", hiddenPattern: "You create distance so nobody can see the anticipation.", receipt: "You memorized the timestamp, then acted surprised.", matchup: "Best with someone secure enough to make the first move twice.", shareLine: "Pretending not to care. Refreshing anyway.", friendHook: "Ask friends if your chill act is convincing.", challenge: "Send this to the person who knows your phone is never dead."),
                AuraCopy(socialType: "Soft Block Energy", badgeTitle: "The Polite Wall", rarity: "Limited edition mixed signal", visual: .pulse, roast: "You respond like a door opened exactly two inches.", hiddenPattern: "You want closeness, but only if it cannot embarrass you.", receipt: "You write 'haha no worries' like a legal document.", matchup: "Best with someone patient, funny, and impossible to intimidate.", shareLine: "Accessible, technically.", friendHook: "Send it to whoever has decoded your punctuation.", challenge: "Drop this in the chat and see who says 'finally.'"),
                AuraCopy(socialType: "Instant Icebreaker", badgeTitle: "The Frozen Typist", rarity: "Top 5% speed with denial", visual: .pulse, roast: "You are emotionally offline with perfect Wi-Fi.", hiddenPattern: "You use sarcasm to make sincerity less traceable.", receipt: "The reply was ready before the notification finished sliding in.", matchup: "Best with someone who can flirt through a brick wall.", shareLine: "Unavailable, but somehow already here.", friendHook: "Ask friends if the cold aura is fooling anyone.", challenge: "Send this to the person who knows you are not that busy.")
            ]
        case .mainCharacterWitness:
            [
                AuraCopy(socialType: "Main Character Witness", badgeTitle: "The Scene Stealer", rarity: "Top 6% accidental spotlight", visual: .prism, roast: "You say you hate attention, then enter every room like a trailer.", hiddenPattern: "You need witnesses more than permission.", receipt: "You call it a casual outfit, then everyone remembers it.", matchup: "Best with someone who lets you be dramatic without making it weird.", shareLine: "Not dramatic. Just correctly lit.", friendHook: "Ask friends if the main character energy is accidental.", challenge: "Send this to the friend who narrates your entrances."),
                AuraCopy(socialType: "Plot Armor Person", badgeTitle: "The Scene Surviver", rarity: "Rare chaos-to-content pipeline", visual: .prism, roast: "Bad decisions look suspiciously cinematic on you.", hiddenPattern: "You turn embarrassment into lore before anyone can judge it.", receipt: "You said 'this is so random' and built a whole episode.", matchup: "Best with someone who laughs first and asks questions later.", shareLine: "Plot armor, questionable choices.", friendHook: "Send it to the friend who has watched your side quests.", challenge: "Post this and let people vote on your worst episode."),
                AuraCopy(socialType: "Soft Launch Celebrity", badgeTitle: "The Casual Reveal", rarity: "Top 9% caption pressure", visual: .prism, roast: "You do not announce things. You leak them aesthetically.", hiddenPattern: "You want attention with plausible deniability.", receipt: "The blurry background was absolutely on purpose.", matchup: "Best with someone confident enough to survive your close friends list.", shareLine: "Private life. Public clues.", friendHook: "Ask friends if your soft launches are ever subtle.", challenge: "Send this to the person who notices every background detail."),
                AuraCopy(socialType: "Camera Roll Myth", badgeTitle: "The Archive Moment", rarity: "Top 11% memory curator", visual: .prism, roast: "You keep screenshots like a museum with bad lighting.", hiddenPattern: "You preserve proof because feelings need documentation.", receipt: "You have a photo for the exact era you said you forgot.", matchup: "Best with someone who can handle being part of the archive.", shareLine: "Every era has evidence.", friendHook: "Send it to the friend who asks you for receipts.", challenge: "Drop this in the group chat and wait for the screenshots."),
                AuraCopy(socialType: "Accidental Trailer", badgeTitle: "The Opening Shot", rarity: "Top 4% entrance energy", visual: .prism, roast: "You cannot go through a minor inconvenience without a soundtrack.", hiddenPattern: "You process life by making it watchable.", receipt: "You said 'not to be dramatic' before being exactly dramatic.", matchup: "Best with someone grounded enough to hold the camera steady.", shareLine: "Life event or season finale?", friendHook: "Ask friends which episode of you they survived.", challenge: "Send this to whoever knows your most cinematic meltdown.")
            ]
        case .softLaunchMystery:
            [
                AuraCopy(socialType: "Soft-Launch Mystery", badgeTitle: "The Unreadable One", rarity: "Top 7% context withholder", visual: .eclipse, roast: "You are not mysterious. You just communicate like a deleted scene.", hiddenPattern: "You test people by making them guess the rules.", receipt: "You post the corner of a sleeve and call it an update.", matchup: "Best with someone brave enough to ask the obvious question.", shareLine: "Hard to read, easy to screenshot.", friendHook: "Ask friends if you are mysterious or making everyone do homework.", challenge: "Send this to the friend who asks 'who is that?'"),
                AuraCopy(socialType: "Deleted Scene Energy", badgeTitle: "The Missing Context", rarity: "Rare emotionally redacted file", visual: .eclipse, roast: "Talking to you is watching episode four with no recap.", hiddenPattern: "You reveal feelings only after they expire.", receipt: "You say 'long story' and provide no short version.", matchup: "Best with someone curious but not easily punished by silence.", shareLine: "Low context. High impact.", friendHook: "Send it to someone who has begged you for details.", challenge: "Post this and let them identify the missing chapter."),
                AuraCopy(socialType: "Vague Text Villain", badgeTitle: "The Dot Dot Dot", rarity: "Top 10% suspense generator", visual: .eclipse, roast: "Your 'we need to talk' should come with a public warning.", hiddenPattern: "You create suspense when you actually want care.", receipt: "You sent 'nvm' and expected a full investigation.", matchup: "Best with someone calm enough to not spiral with you.", shareLine: "Three dots, full panic.", friendHook: "Ask friends if your texts need subtitles.", challenge: "Send this to the person traumatized by your 'nvm.'"),
                AuraCopy(socialType: "Close Friends Phantom", badgeTitle: "The Green Ring Myth", rarity: "Limited access emotional lore", visual: .eclipse, roast: "Your close friends story has more plot than your actual conversations.", hiddenPattern: "You confess sideways so nobody can hold you to it.", receipt: "The song choice was the message and everyone knew.", matchup: "Best with someone who can read the room without becoming the room.", shareLine: "Posted nothing. Said everything.", friendHook: "Send it to the friend who decodes your story songs.", challenge: "Post this and wait for 'is this about me?'"),
                AuraCopy(socialType: "Unreadable Softie", badgeTitle: "The Guarded Glow", rarity: "Top 13% secretly tender", visual: .eclipse, roast: "You look hard to reach because the doorbell is emotional labor.", hiddenPattern: "You protect softness by making people earn the map.", receipt: "You remember tiny details, then act like you barely noticed.", matchup: "Best with someone gentle, direct, and not allergic to clarity.", shareLine: "Mystery outside. Soft center.", friendHook: "Ask friends if the mystery is hiding a soft spot.", challenge: "Send this to whoever knows you care too much.")
            ]
        case .groupChatOracle:
            [
                AuraCopy(socialType: "Group Chat Oracle", badgeTitle: "The Screenshot Analyst", rarity: "Top 3% tone investigator", visual: .signal, roast: "You can read everyone except the person clearly flirting with you.", hiddenPattern: "You turn tiny tone shifts into full case files.", receipt: "You zoomed into a comma and called it intuition.", matchup: "Best with someone whose texts do not require a legal team.", shareLine: "The group chat was right again.", friendHook: "Ask friends if your analysis has gone too far.", challenge: "Send this to the friend who asks for screenshots first."),
                AuraCopy(socialType: "Tone Detective", badgeTitle: "The Evidence Board", rarity: "Rare investigative texting", visual: .signal, roast: "You hear a period at the end of a sentence like a siren.", hiddenPattern: "You mistake uncertainty for a mystery to solve.", receipt: "You said 'the vibe shifted' and produced exhibits.", matchup: "Best with someone consistent enough to calm the evidence board.", shareLine: "One period. Twelve theories.", friendHook: "Send it to the person who receives your case files.", challenge: "Drop this next to your most dramatic screenshot."),
                AuraCopy(socialType: "Receipt Librarian", badgeTitle: "The Archive Keeper", rarity: "Top 5% proof collector", visual: .signal, roast: "Your camera roll could win a civil case.", hiddenPattern: "You save proof because memory feels too editable.", receipt: "You found the exact message from three eras ago.", matchup: "Best with someone honest enough to survive your search bar.", shareLine: "Receipts organized. Feelings pending.", friendHook: "Ask friends if your archive is helpful or terrifying.", challenge: "Send this to whoever has asked you to delete evidence."),
                AuraCopy(socialType: "Vibe Prosecutor", badgeTitle: "The Objection", rarity: "Top 8% pattern recognizer", visual: .signal, roast: "You cross-examine a text before deciding if you are chill.", hiddenPattern: "You trust patterns more than promises.", receipt: "You knew the story was off before the second paragraph.", matchup: "Best with someone transparent enough to bore your suspicion.", shareLine: "Your honor, the vibe is guilty.", friendHook: "Send it to the friend who says 'wait, read it again.'", challenge: "Post this and let them submit evidence."),
                AuraCopy(socialType: "Social Weather App", badgeTitle: "The Forecast", rarity: "Rare room-reading range", visual: .signal, roast: "You predict everyone's mood and still ignore your own forecast.", hiddenPattern: "You scan the room so nobody has to scan you.", receipt: "You noticed the vibe change before the playlist did.", matchup: "Best with someone who asks how you feel first.", shareLine: "High chance of overanalysis.", friendHook: "Ask friends if your social forecast is too accurate.", challenge: "Send this to the friend who relies on your vibe checks.")
            ]
        case .lowKeyChaos:
            [
                AuraCopy(socialType: "Low-Key Chaos", badgeTitle: "The Calm-Looking Storm", rarity: "Top 9% silent spiral", visual: .spark, roast: "You seem chill because the meltdown is happening in a private tab.", hiddenPattern: "You downplay what you want until someone almost misses it.", receipt: "You said 'I'm good' with seven tabs of panic open.", matchup: "Best with someone steady enough to notice the quiet part.", shareLine: "Quiet aura. Loud inner monologue.", friendHook: "Ask friends if you look calm or if the chaos is visible.", challenge: "Send this to whoever has seen the private tab."),
                AuraCopy(socialType: "Calm-Looking Storm", badgeTitle: "The Silent Spiral", rarity: "Rare peaceful panic", visual: .spark, roast: "Your outside voice is fine. Your notes app is on fire.", hiddenPattern: "You make everything look manageable until it is cinematic.", receipt: "You organized the crisis before admitting it was a crisis.", matchup: "Best with someone who checks in before the plot twist.", shareLine: "Soft voice. Full crisis.", friendHook: "Send it to the friend who notices your quiet spiral.", challenge: "Post this and see who says 'this is you.'"),
                AuraCopy(socialType: "Private Tab Spiral", badgeTitle: "The Hidden Search", rarity: "Top 7% internal drama", visual: .spark, roast: "Your search history has seen the real you.", hiddenPattern: "You outsource panic to research so it feels productive.", receipt: "You googled the same question five different ways.", matchup: "Best with someone reassuring without becoming your therapist.", shareLine: "Researching feelings at 1:12 AM.", friendHook: "Ask friends if your calm face is legally convincing.", challenge: "Send this to whoever knows your panic research era."),
                AuraCopy(socialType: "Soft Chaos Operator", badgeTitle: "The Gentle Alarm", rarity: "Top 15% harmless disorder", visual: .spark, roast: "You are not messy. You are running too many emotional apps.", hiddenPattern: "You keep peace outside because inside is already loud.", receipt: "You made a plan, lost the plan, then improvised better.", matchup: "Best with someone flexible enough to laugh with you.", shareLine: "Organized enough to deny the chaos.", friendHook: "Send it to the person who knows your plan B through Z.", challenge: "Drop this in the chat and let them name the incident."),
                AuraCopy(socialType: "Chill Until Perceived", badgeTitle: "The Quiet Alarm", rarity: "Rare anti-attention spiral", visual: .spark, roast: "You are relaxed until someone correctly notices you.", hiddenPattern: "You want to be understood without being observed too loudly.", receipt: "You changed the subject right when it got accurate.", matchup: "Best with someone warm enough to not make noticing scary.", shareLine: "Please perceive responsibly.", friendHook: "Ask friends if you vanish when the read gets too accurate.", challenge: "Send this to the person who sees through the chill act.")
            ]
        }
    }
}

private struct AuraCopy {
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
}

struct RemoteAuraAnalyzer: AuraAnalyzing {
    func analyze(answers: [String: AuraAnswer]) async throws -> AuraAnalysis {
        guard let endpoint = AuraRuntimeConfig.analysisEndpoint else {
            throw AuraAnalyzerError.missingEndpoint
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = AuraRuntimeConfig.requestTimeout

        let body = RemoteAuraRequest(
            answers: Dictionary(uniqueKeysWithValues: auraQuestions.map { question in
                (question.id, answers[question.id]?.rawValue ?? AuraAnswer.sometimes.rawValue)
            })
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw AuraAnalyzerError.invalidResponse
        }

        let decoder = JSONDecoder()
        if let payload = try? decoder.decode(RemoteAuraPayload.self, from: data) {
            return payload.analysis
        }

        if let envelope = try? decoder.decode(RemoteAuraEnvelope.self, from: data) {
            return envelope.analysis.analysis
        }

        throw AuraAnalyzerError.invalidResponse
    }
}

private enum AuraRuntimeConfig {
    static var analysisEndpoint: URL? {
        guard let value = string(for: "AURA_ANALYSIS_ENDPOINT"),
              value.isEmpty == false else {
            return nil
        }

        return URL(string: value)
    }

    static var requestTimeout: TimeInterval {
        guard let value = string(for: "AURA_REQUEST_TIMEOUT"),
              let timeout = TimeInterval(value),
              timeout > 0 else {
            return 5
        }

        return timeout
    }

    private static func string(for key: String) -> String? {
        if let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
           let normalized = normalized(value) {
            return normalized
        }

        if let value = ProcessInfo.processInfo.environment[key],
           let normalized = normalized(value) {
            return normalized
        }

        return envValues[key].flatMap(normalized)
    }

    private static let envValues: [String: String] = {
        envFileURLs.reduce(into: [:]) { values, url in
            guard let content = try? String(contentsOf: url, encoding: .utf8) else {
                return
            }

            for line in content.components(separatedBy: .newlines) {
                guard let pair = parseEnvLine(line) else {
                    continue
                }
                values[pair.key] = pair.value
            }
        }
    }()

    private static var envFileURLs: [URL] {
        var urls: [URL] = []

        if let bundled = Bundle.main.url(forResource: "Aura", withExtension: "env") {
            urls.append(bundled)
        }

        if let resourcePath = Bundle.main.resourcePath {
            urls.append(URL(fileURLWithPath: resourcePath).appendingPathComponent(".env"))
        }

        urls.append(URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".env"))

        return urls
    }

    private static func parseEnvLine(_ line: String) -> (key: String, value: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false,
              trimmed.hasPrefix("#") == false,
              let separator = trimmed.firstIndex(of: "=") else {
            return nil
        }

        let key = String(trimmed[..<separator]).trimmingCharacters(in: .whitespacesAndNewlines)
        var value = String(trimmed[trimmed.index(after: separator)...]).trimmingCharacters(in: .whitespacesAndNewlines)

        if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
            (value.hasPrefix("'") && value.hasSuffix("'")) {
            value.removeFirst()
            value.removeLast()
        }

        guard key.isEmpty == false else {
            return nil
        }

        return (key, value)
    }

    nonisolated private static func normalized(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct RemoteAuraRequest: Encodable {
    let answers: [String: String]
}

private struct RemoteAuraEnvelope: Decodable {
    let analysis: RemoteAuraPayload
}

private struct RemoteAuraPayload: Decodable {
    let auraScore: Int
    let socialType: String
    let badgeTitle: String
    let rarity: String?
    let visual: AuraVisual
    let roast: String
    let hiddenPattern: String
    let receipt: String?
    let matchup: String?
    let shareLine: String
    let friendHook: String
    let challenge: String?
    let metrics: [RemoteMetric]

    var analysis: AuraAnalysis {
        AuraAnalysis(
            auraScore: auraScore,
            socialType: socialType,
            badgeTitle: badgeTitle,
            rarity: rarity ?? "Fresh scan",
            visual: visual,
            roast: roast,
            hiddenPattern: hiddenPattern,
            receipt: receipt ?? hiddenPattern,
            matchup: matchup ?? "Best with someone who can call the pattern out without making it weird.",
            shareLine: shareLine,
            friendHook: friendHook,
            challenge: challenge ?? "Send this to the friend who knows exactly what this means.",
            metrics: metrics.map { AuraMetric(name: $0.name, value: $0.value) }
        )
    }
}

private struct RemoteMetric: Decodable {
    let name: String
    let value: Int
}
