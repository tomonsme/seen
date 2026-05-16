import SwiftUI
import UIKit

private enum AppScreen {
    case home
    case scan
    case analyzing
    case duoHandoff
    case result
    case duoResult
    case partySetup
    case partyVote
    case partyResult
    case dailyDrop
}

private enum ScanSubject {
    case selfScan
    case duoFirstScan
    case friendScan

    var title: String {
        switch self {
        case .selfScan: "Aura Scan"
        case .duoFirstScan: "Duo Read"
        case .friendScan: "Friend Scan"
        }
    }

    var subtitle: String {
        switch self {
        case .selfScan: "7 questions"
        case .duoFirstScan: "Your side"
        case .friendScan: "Build the duo read"
        }
    }

    var analyzingTitle: String {
        switch self {
        case .selfScan: "Scanning your aura"
        case .duoFirstScan: "Locking your side"
        case .friendScan: "Reading the duo chemistry"
        }
    }
}

struct ContentView: View {
    @State private var screen: AppScreen = .home
    @State private var answers: [String: AuraAnswer] = [:]
    @State private var scanIndex = 0
    @State private var analysis: AuraAnalysis?
    @State private var primaryAnalysis: AuraAnalysis?
    @State private var compatibility: AuraCompatibility?
    @State private var partyNames: [String] = ["", "", "", ""]
    @State private var partyVoteIndex = 0
    @State private var partyVotes: [String: String] = [:]
    @State private var partyResult: PartyPollResult?
    @State private var dailyDrop: DailyDrop?
    @State private var scanSubject: ScanSubject = .selfScan
    @State private var selectedDuoMode: DuoMode = .crushCheck
    @State private var errorMessage: String?
    @State private var sharePayload: SharePayload?
    @State private var requestID = UUID()

    private let analyzer = AuraAnalyzer()

    var body: some View {
        ZStack {
            AuraBackground()

            switch screen {
            case .home:
                HomeView(
                    onStartDuo: startNewDuoRead,
                    onStartSolo: startNewSoloScan,
                    onStartParty: startPartyVote,
                    onInstantRoast: startInstantRoast,
                    onDailyDrop: openDailyDrop
                )
            case .scan:
                ScanView(
                    currentIndex: $scanIndex,
                    answers: $answers,
                    title: scanSubject.title,
                    subtitle: scanSubject.subtitle,
                    canStart: canStartScan,
                    onStart: startScan,
                    onCancel: resetScan
                )
            case .analyzing:
                AnalyzingView(title: scanSubject.analyzingTitle)
                    .task(id: requestID) {
                        await runScan()
                    }
            case .duoHandoff:
                DuoHandoffView(
                    mode: selectedDuoMode,
                    onContinue: continueDuoFriendScan,
                    onCancel: resetScan
                )
            case .result:
                if let analysis {
                    ResultView(
                        analysis: analysis,
                        onRestart: resetScan,
                        onDuoRead: startFriendScan,
                        onShare: { renderShareImage(for: analysis) }
                    )
                }
            case .duoResult:
                if let compatibility {
                    DuoResultView(
                        compatibility: compatibility,
                        onRestart: resetScan,
                        onStartMode: startNewDuoRead,
                        onShare: { renderDuoShareImage(for: compatibility) }
                    )
                }
            case .partySetup:
                PartySetupView(
                    names: $partyNames,
                    onStart: beginPartyQuestions,
                    onCancel: resetScan
                )
            case .partyVote:
                PartyVoteView(
                    currentIndex: $partyVoteIndex,
                    votes: $partyVotes,
                    names: cleanedPartyNames,
                    onFinish: finishPartyVote,
                    onCancel: resetScan
                )
            case .partyResult:
                if let partyResult {
                    PartyResultView(
                        result: partyResult,
                        onRestart: startPartyVote,
                        onShare: { renderPartyShareImage(for: partyResult) }
                    )
                }
            case .dailyDrop:
                if let dailyDrop {
                    DailyDropView(
                        drop: dailyDrop,
                        onBack: resetScan,
                        onInstantRoast: startInstantRoast,
                        onShare: { renderDailyDropShareImage(for: dailyDrop) }
                    )
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(AuraPalette.hotPink)
        .sheet(item: $sharePayload) { payload in
            ShareSheet(activityItems: payload.activityItems)
                .ignoresSafeArea()
        }
        .overlay(alignment: .top) {
            if let errorMessage {
                AuraToast(message: errorMessage) {
                    withAnimation(.easeOut(duration: 0.18)) {
                        self.errorMessage = nil
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, 12)
                .padding(.horizontal, 16)
            }
        }
        .onAppear(perform: routeInitialScreen)
    }

    private var canStartScan: Bool {
        auraQuestions.allSatisfy { answers[$0.id] != nil }
    }

    private func routeInitialScreen() {
        if compatibility != nil {
            screen = .duoResult
        } else if partyResult != nil {
            screen = .partyResult
        } else if dailyDrop != nil {
            screen = .dailyDrop
        } else if analysis != nil {
            screen = .result
        } else {
            screen = .home
        }
    }

    private func startNewSoloScan() {
        answers = [:]
        scanIndex = 0
        analysis = nil
        primaryAnalysis = nil
        compatibility = nil
        partyResult = nil
        dailyDrop = nil
        selectedDuoMode = .crushCheck
        scanSubject = .selfScan
        AuraHaptics.impact()
        screen = .scan
    }

    private func startInstantRoast() {
        answers = Dictionary(uniqueKeysWithValues: auraQuestions.map { question in
            (question.id, AuraAnswer.allCases.randomElement() ?? .sometimes)
        })
        scanIndex = auraQuestions.count - 1
        analysis = LocalAuraAnalyzer().analyze(answers: answers)
        primaryAnalysis = analysis
        compatibility = nil
        partyResult = nil
        dailyDrop = nil
        selectedDuoMode = .crushCheck
        scanSubject = .selfScan
        AuraHaptics.success()
        screen = .result
    }

    private func startNewDuoRead(mode: DuoMode) {
        answers = [:]
        scanIndex = 0
        analysis = nil
        primaryAnalysis = nil
        compatibility = nil
        partyResult = nil
        dailyDrop = nil
        selectedDuoMode = mode
        scanSubject = .duoFirstScan
        AuraHaptics.impact()
        screen = .scan
    }

    private func startScan() {
        guard canStartScan else { return }
        AuraHaptics.impact()
        errorMessage = nil
        requestID = UUID()
        screen = .analyzing
    }

    private func runScan() async {
        do {
            let result = try await analyzer.analyze(answers: answers)
            try await Task.sleep(for: .milliseconds(700))
            await MainActor.run {
                if scanSubject == .friendScan, let primaryAnalysis {
                    compatibility = LocalCompatibilityAnalyzer().analyze(first: primaryAnalysis, second: result, mode: selectedDuoMode)
                    AuraHaptics.success()
                    screen = .duoResult
                    return
                }

                if scanSubject == .duoFirstScan {
                    primaryAnalysis = result
                    answers = [:]
                    scanIndex = 0
                    scanSubject = .friendScan
                    AuraHaptics.success()
                    screen = .duoHandoff
                    return
                }

                analysis = result
                primaryAnalysis = result
                AuraHaptics.success()
                screen = .result
            }
        } catch {
            await MainActor.run {
                let result = LocalAuraAnalyzer().analyze(answers: answers)
                if scanSubject == .friendScan, let primaryAnalysis {
                    compatibility = LocalCompatibilityAnalyzer().analyze(first: primaryAnalysis, second: result, mode: selectedDuoMode)
                    errorMessage = error.localizedDescription
                    screen = .duoResult
                    return
                }

                if scanSubject == .duoFirstScan {
                    primaryAnalysis = result
                    answers = [:]
                    scanIndex = 0
                    scanSubject = .friendScan
                    errorMessage = error.localizedDescription
                    screen = .duoHandoff
                    return
                }

                analysis = result
                primaryAnalysis = result
                errorMessage = error.localizedDescription
                screen = .result
            }
        }
    }

    private func resetScan() {
        answers = [:]
        scanIndex = 0
        analysis = nil
        primaryAnalysis = nil
        compatibility = nil
        partyNames = ["", "", "", ""]
        partyVoteIndex = 0
        partyVotes = [:]
        partyResult = nil
        dailyDrop = nil
        selectedDuoMode = .crushCheck
        scanSubject = .selfScan
        screen = .home
    }

    private func startFriendScan() {
        guard let analysis else { return }
        AuraHaptics.impact()
        primaryAnalysis = analysis
        answers = [:]
        scanIndex = 0
        selectedDuoMode = .crushCheck
        scanSubject = .friendScan
        screen = .duoHandoff
    }

    private var cleanedPartyNames: [String] {
        partyNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private func startPartyVote() {
        answers = [:]
        scanIndex = 0
        analysis = nil
        primaryAnalysis = nil
        compatibility = nil
        partyNames = ["", "", "", ""]
        partyVoteIndex = 0
        partyVotes = [:]
        partyResult = nil
        dailyDrop = nil
        AuraHaptics.impact()
        screen = .partySetup
    }

    private func openDailyDrop() {
        answers = [:]
        scanIndex = 0
        analysis = nil
        primaryAnalysis = nil
        compatibility = nil
        partyResult = nil
        dailyDrop = LocalDailyDropProvider().today()
        AuraHaptics.impact()
        screen = .dailyDrop
    }

    private func beginPartyQuestions() {
        guard cleanedPartyNames.count >= 2 else { return }
        partyVoteIndex = 0
        partyVotes = [:]
        AuraHaptics.impact()
        screen = .partyVote
    }

    private func finishPartyVote() {
        partyResult = LocalPartyPollAnalyzer().analyze(names: cleanedPartyNames, votes: partyVotes)
        AuraHaptics.success()
        screen = .partyResult
    }

    private func continueDuoFriendScan() {
        AuraHaptics.impact()
        screen = .scan
    }

    private func renderShareImage(for analysis: AuraAnalysis) {
        let renderer = ImageRenderer(content: AuraStoryCard(analysis: analysis, width: 1080))
        renderer.scale = 1

        if let image = renderer.uiImage {
            AuraHaptics.impact()
            sharePayload = SharePayload(image: image, text: CaptionCopy.captions(for: analysis).first)
        }
    }

    private func renderDuoShareImage(for compatibility: AuraCompatibility) {
        let renderer = ImageRenderer(content: AuraDuoStoryCard(compatibility: compatibility, width: 1080))
        renderer.scale = 1

        if let image = renderer.uiImage {
            AuraHaptics.impact()
            sharePayload = SharePayload(image: image, text: CaptionCopy.captions(for: compatibility).first)
        }
    }

    private func renderPartyShareImage(for result: PartyPollResult) {
        let renderer = ImageRenderer(content: PartyVoteStoryCard(result: result, width: 1080))
        renderer.scale = 1

        if let image = renderer.uiImage {
            AuraHaptics.impact()
            sharePayload = SharePayload(image: image, text: CaptionCopy.captions(for: result).first)
        }
    }

    private func renderDailyDropShareImage(for drop: DailyDrop) {
        let renderer = ImageRenderer(content: DailyDropStoryCard(drop: drop, width: 1080))
        renderer.scale = 1

        if let image = renderer.uiImage {
            AuraHaptics.impact()
            sharePayload = SharePayload(image: image, text: CaptionCopy.captions(for: drop).first)
        }
    }
}

private struct HomeView: View {
    let onStartDuo: (DuoMode) -> Void
    let onStartSolo: () -> Void
    let onStartParty: () -> Void
    let onInstantRoast: () -> Void
    let onDailyDrop: () -> Void

    private let sample = AuraAnalysis(
        auraScore: 87,
        socialType: "Fast-Reply Ice Queen",
        badgeTitle: "Read Receipt Royalty",
        rarity: "Top 8% notification menace",
        visual: .pulse,
        roast: "You act emotionally unavailable but reply instantly.",
        hiddenPattern: "You hide effort by pretending it was accidental.",
        receipt: "Typed, deleted, replied in 12 seconds.",
        matchup: "Best with someone direct enough to skip the guessing game.",
        shareLine: "Emotionally unavailable. Chronically online.",
        friendHook: "Ask friends if you are unreadable or just fast with notifications.",
        challenge: "Send this to the friend who clocks your reply speed.",
        metrics: [
            AuraMetric(name: "Overthink", value: 88),
            AuraMetric(name: "Unbothered Act", value: 79),
            AuraMetric(name: "Main Character", value: 64),
            AuraMetric(name: "Readability", value: 31)
        ]
    )

    var body: some View {
        VStack(spacing: 0) {
            AuraHeader()
                .padding(.horizontal, 20)
                .padding(.top, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HomeLaunchDeck(
                        analysis: sample,
                        onInstantRoast: onInstantRoast
                    )

                    HomeModeDock(
                        onStartSolo: onStartSolo,
                        onStartDuo: onStartDuo
                    )
                }
                .frame(maxWidth: 680, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .frame(maxWidth: .infinity)
            }

            AuraBottomBar {
                HomeTabBar(
                    onFriends: onStartParty,
                    onReveal: onInstantRoast,
                    onDaily: onDailyDrop
                )
            }
        }
    }
}

private struct HomeLaunchDeck: View {
    let analysis: AuraAnalysis
    let onInstantRoast: () -> Void

    var body: some View {
        Button(action: onInstantRoast) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AuraPalette.storyBackground)

                HStack(alignment: .center, spacing: 18) {
                    AuraMysteryStack(analysis: analysis)

                    VStack(alignment: .leading, spacing: 13) {
                        HStack(spacing: 8) {
                            SignalPill(icon: "bolt.fill", title: "1 tap")
                            SignalPill(icon: "square.and.arrow.up", title: "story")
                        }

                        Text("Reveal your read")
                            .font(.system(size: 34, weight: .black))
                            .lineSpacing(1)
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.58)

                        Text("One card.")
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(AuraPalette.subtext)
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14, weight: .black))
                            Text("TAP TO FLIP")
                                .font(.system(size: 12, weight: .black, design: .monospaced))
                        }
                        .foregroundStyle(AuraPalette.accent)
                    }
                }
                .padding(20)
            }
            .frame(height: 256)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(AuraPalette.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct AuraMysteryStack: View {
    let analysis: AuraAnalysis

    var body: some View {
        ZStack {
            MysteryCard(offset: CGSize(width: -16, height: 18), rotation: -10, color: AuraPalette.violet.opacity(0.36))
            MysteryCard(offset: CGSize(width: 16, height: 10), rotation: 9, color: AuraPalette.hotPink.opacity(0.34))

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AuraPalette.panelHigh)
                .frame(width: 128, height: 164)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(analysis.visual.gradient, lineWidth: 3)
                )
                .overlay {
                    VStack(spacing: 12) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 34, weight: .black))
                            .foregroundStyle(.white)

                        HStack(spacing: 5) {
                            ForEach(0..<4, id: \.self) { index in
                                Capsule()
                                    .fill(index < 3 ? analysis.visual.accent : AuraPalette.border)
                                    .frame(width: 18, height: 6)
                            }
                        }

                        Text("AURA")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(AuraPalette.muted)
                    }
                }
        }
        .frame(width: 150, height: 190)
        .accessibilityHidden(true)
    }
}

private struct MysteryCard: View {
    let offset: CGSize
    let rotation: Double
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(color)
            .frame(width: 118, height: 154)
            .rotationEffect(.degrees(rotation))
            .offset(offset)
    }
}

private struct HomeQuickAction: View {
    let title: String
    let icon: String
    let accent: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(accent)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(title)
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(.white)

            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(AuraPalette.panel)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AuraPalette.border, lineWidth: 1)
        )
    }
}

private struct HomeModeDock: View {
    let onStartSolo: () -> Void
    let onStartDuo: (DuoMode) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            HomeModeChip(title: "Full Scan", icon: "person.fill.questionmark", accent: AuraPalette.accent, action: onStartSolo)
            HomeModeChip(title: "Crush", icon: DuoMode.crushCheck.icon, accent: DuoMode.crushCheck.accent) {
                onStartDuo(.crushCheck)
            }
        }
    }
}

private struct HomeTabBar: View {
    let onFriends: () -> Void
    let onReveal: () -> Void
    let onDaily: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            HomeTabItem(title: "Friends", icon: "person.3.fill", action: onFriends)

            Button(action: onReveal) {
                VStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 21, weight: .black))
                    Text("Reveal")
                        .font(.system(size: 13, weight: .black))
                        .lineLimit(1)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(AuraPalette.neonGradient)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.22), lineWidth: 1)
                )
                .shadow(color: AuraPalette.accent.opacity(0.25), radius: 14, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reveal My Aura")

            HomeTabItem(title: "Daily", icon: "calendar", action: onDaily)
        }
        .frame(height: 70)
    }
}

private struct HomeTabItem: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .black))
                Text(title)
                    .font(.system(size: 12, weight: .black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(AuraPalette.panel)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AuraPalette.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct HomeModeChip: View {
    let title: String
    let icon: String
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(accent)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Text(title)
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)

                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 74)
            .background(AuraPalette.panel)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(accent.opacity(0.24), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct HomeActionGrid: View {
    let onDailyDrop: () -> Void
    let onInstantRoast: () -> Void
    let onStartParty: () -> Void
    let onStartDuo: (DuoMode) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pick")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(.white)

            LazyVGrid(columns: columns, spacing: 10) {
                HomeActionTile(title: "Daily", icon: "calendar", accent: AuraPalette.violet, action: onDailyDrop)
                HomeActionTile(title: "Instant", icon: "bolt.fill", accent: AuraPalette.hotPink, action: onInstantRoast)
                HomeActionTile(title: "Group", icon: "person.3.fill", accent: AuraPalette.accent, action: onStartParty)
                HomeActionTile(title: "Crush", icon: DuoMode.crushCheck.icon, accent: DuoMode.crushCheck.accent) {
                    onStartDuo(.crushCheck)
                }
                HomeActionTile(title: "Bestie", icon: DuoMode.bestieAudit.icon, accent: DuoMode.bestieAudit.accent) {
                    onStartDuo(.bestieAudit)
                }
                HomeActionTile(title: "Soft Launch", icon: DuoMode.softLaunchTest.icon, accent: DuoMode.softLaunchTest.accent) {
                    onStartDuo(.softLaunchTest)
                }
            }
        }
    }
}

private struct HomeActionTile: View {
    let title: String
    let icon: String
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                HStack {
                    Text(title)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(AuraPalette.muted)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 128)
            .background(AuraPalette.panel)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(accent.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct HomeVisualPreview: View {
    let analysis: AuraAnalysis

    var body: some View {
        HStack(spacing: 14) {
            AuraVisualBadge(analysis: analysis, size: 96)

            VStack(alignment: .leading, spacing: 10) {
                Text("AURA \(analysis.auraScore)")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(analysis.visual.accent)

                MiniBarSet(metrics: analysis.metrics)
            }
        }
        .padding(16)
        .background(AuraPalette.panelHigh)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AuraPalette.border, lineWidth: 1)
        )
    }
}

private struct HomeSignalStrip: View {
    var body: some View {
        HStack(spacing: 10) {
            SignalPill(icon: "bolt.fill", title: "1 tap")
            SignalPill(icon: "person.3.fill", title: "group")
            SignalPill(icon: "square.and.arrow.up", title: "share")
        }
    }
}

private struct DailyDropButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "calendar")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(AuraPalette.violet)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Drop")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(.white)
                    Text("A new read every day. No account, no save.")
                        .font(.system(size: 13, weight: .semibold))
                        .lineSpacing(3)
                        .foregroundStyle(AuraPalette.subtext)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Today's screenshot prompt is waiting.")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(AuraPalette.violet)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(AuraPalette.muted)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AuraPalette.panelHigh)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AuraPalette.violet.opacity(0.34), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct InstantRoastButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(AuraPalette.hotPink)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Instant Roast")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(.white)
                    Text("Get a shareable AURA result without answering questions.")
                        .font(.system(size: 13, weight: .semibold))
                        .lineSpacing(3)
                        .foregroundStyle(AuraPalette.subtext)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("One tap. Screenshot bait.")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(AuraPalette.hotPink)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(AuraPalette.muted)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AuraPalette.panelHigh)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AuraPalette.hotPink.opacity(0.34), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct PartyModeButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(AuraPalette.neonGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Group Vote")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(.white)
                    Text("Pass the phone. Vote who fits each prompt.")
                        .font(.system(size: 13, weight: .semibold))
                        .lineSpacing(3)
                        .foregroundStyle(AuraPalette.subtext)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Find out who gets exposed.")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(AuraPalette.hotPink)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(AuraPalette.muted)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AuraPalette.panelHigh)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AuraPalette.hotPink.opacity(0.32), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct DuoModeButton: View {
    let mode: DuoMode
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: mode.icon)
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(mode.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.rawValue)
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(.white)
                    Text(mode.subtitle)
                        .font(.system(size: 13, weight: .semibold))
                        .lineSpacing(3)
                        .foregroundStyle(AuraPalette.subtext)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(mode.teaser)
                        .font(.system(size: 12, weight: .black))
                        .lineSpacing(2)
                        .foregroundStyle(mode.accent)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(AuraPalette.muted)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AuraPalette.panel)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AuraPalette.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct HomeHero: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                SignalPill(icon: "bolt.fill", title: "1 tap")
                SignalPill(icon: "person.3.fill", title: "group")
                SignalPill(icon: "square.and.arrow.up", title: "share")
            }

            HStack(spacing: 18) {
                AuraOrbitGraphic()

                VStack(alignment: .leading, spacing: 10) {
                    Text("AURA")
                        .font(.system(size: 42, weight: .black))
                        .tracking(2)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text("Pick. Read. Share.")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(AuraPalette.subtext)
                        .lineLimit(1)
                }
            }
            .padding(18)
            .background(AuraPalette.panelHigh)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AuraPalette.border, lineWidth: 1)
            )
        }
        .padding(.vertical, 4)
    }
}

private struct AuraOrbitGraphic: View {
    @State private var spin = false

    var body: some View {
        ZStack {
            Circle()
                .fill(AuraPalette.hotPink.opacity(0.18))
                .frame(width: 118, height: 118)
            Circle()
                .stroke(AuraPalette.neonGradient, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .frame(width: 108, height: 108)
                .rotationEffect(.degrees(spin ? 360 : 0))
            Circle()
                .stroke(AuraPalette.cyan.opacity(0.55), lineWidth: 2)
                .frame(width: 78, height: 78)
                .rotationEffect(.degrees(spin ? -360 : 0))
            Circle()
                .fill(.white)
                .frame(width: 14, height: 14)
                .offset(x: 31, y: -22)
            Image(systemName: "sparkles")
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(.white)
        }
        .frame(width: 124, height: 124)
        .onAppear {
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                spin = true
            }
        }
    }
}

private struct HomePreviewCard: View {
    let analysis: AuraAnalysis

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            AuraVisualBadge(analysis: analysis, size: 94)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text("PREVIEW")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(analysis.visual.accent)
                    Text("AURA \(analysis.auraScore)")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(AuraPalette.muted)
                }

                Text(analysis.socialType)
                    .font(.system(size: 20, weight: .black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.white)

                Text(analysis.roast)
                    .font(.system(size: 15, weight: .bold))
                    .lineSpacing(3)
                    .foregroundStyle(AuraPalette.subtext)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(AuraPalette.panel)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AuraPalette.border, lineWidth: 1)
        )
    }
}

private struct HomeProofPill: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(AuraPalette.accent)
            Text(title)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
            Text(subtitle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AuraPalette.muted)
                .lineLimit(2)
                .minimumScaleFactor(0.76)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .auraPanel()
    }
}

private struct HomeModeRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let accent: Color

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(accent)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 13, weight: .semibold))
                    .lineSpacing(3)
                    .foregroundStyle(AuraPalette.subtext)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .auraPanel()
    }
}

private struct ScanView: View {
    @Binding var currentIndex: Int
    @Binding var answers: [String: AuraAnswer]
    let title: String
    let subtitle: String
    let canStart: Bool
    let onStart: () -> Void
    let onCancel: () -> Void

    private var question: AuraQuestion {
        auraQuestions[min(currentIndex, auraQuestions.count - 1)]
    }

    private var progress: Double {
        Double(currentIndex + 1) / Double(auraQuestions.count)
    }

    var body: some View {
        VStack(spacing: 0) {
            AuraTopBar(title: title, subtitle: subtitle) {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(AuraIconButtonStyle())
                .accessibilityLabel("Close scan")
            }

            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Question \(currentIndex + 1) of \(auraQuestions.count)")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(AuraPalette.muted)
                        Spacer()
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(AuraPalette.subtext)
                    }

                    ProgressView(value: progress)
                        .tint(AuraPalette.accent)
                        .accessibilityLabel("Scan progress")
                }

                Spacer(minLength: 18)

                VStack(alignment: .leading, spacing: 16) {
                    Text(question.prompt)
                        .font(.system(size: 38, weight: .bold))
                        .lineSpacing(3)
                        .minimumScaleFactor(0.64)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(question.detail)
                        .font(.system(size: 17, weight: .medium))
                        .lineSpacing(5)
                        .foregroundStyle(AuraPalette.subtext)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 12) {
                    ForEach(AuraAnswer.allCases) { answer in
                        AnswerButton(
                            answer: answer,
                            isSelected: answers[question.id] == answer,
                            action: { select(answer) }
                        )
                    }
                }

                Spacer(minLength: 20)

                HStack(spacing: 10) {
                    AuraSecondaryButton(
                        title: "Back",
                        systemImage: "chevron.left",
                        action: {
                            withAnimation(.easeOut(duration: 0.18)) {
                                currentIndex = max(0, currentIndex - 1)
                            }
                        }
                    )
                    .disabled(currentIndex == 0)
                    .opacity(currentIndex == 0 ? 0.45 : 1)

                    AuraPrimaryButton(
                        title: currentIndex == auraQuestions.count - 1 ? "See My Result" : "Next",
                        systemImage: currentIndex == auraQuestions.count - 1 ? "sparkles" : "chevron.right",
                        action: advance
                    )
                    .disabled(answers[question.id] == nil)
                    .opacity(answers[question.id] == nil ? 0.45 : 1)
                }
            }
            .frame(maxWidth: 620, alignment: .leading)
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func select(_ answer: AuraAnswer) {
        AuraHaptics.impact()
        let selectedID = question.id
        let selectedIndex = currentIndex
        withAnimation(.easeOut(duration: 0.16)) {
            answers[selectedID] = answer
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            guard currentIndex == selectedIndex, answers[selectedID] == answer else { return }
            advance()
        }
    }

    private func advance() {
        guard answers[question.id] != nil else { return }

        if currentIndex == auraQuestions.count - 1 {
            onStart()
            return
        }

        withAnimation(.easeOut(duration: 0.18)) {
            currentIndex = min(auraQuestions.count - 1, currentIndex + 1)
        }
    }
}

private struct AnswerButton: View {
    let answer: AuraAnswer
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(answer.rawValue)
                    .font(.system(size: 17, weight: .bold))
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(isSelected ? AuraPalette.accent : AuraPalette.muted)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .padding(.horizontal, 16)
            .background(isSelected ? AuraPalette.panelHigh : AuraPalette.panel)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? AuraPalette.accent.opacity(0.8) : AuraPalette.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct SignalPill: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .font(.system(size: 12, weight: .black))
        .foregroundStyle(AuraPalette.subtext)
        .frame(maxWidth: .infinity)
        .frame(height: 38)
        .background(AuraPalette.panel)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(AuraPalette.border, lineWidth: 1))
    }
}

private struct AnalyzingView: View {
    let title: String
    @State private var pulse = false
    private let steps = ["Reading your answers", "Writing your result", "Building your share card"]

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(AuraPalette.hotPink.opacity(0.25), lineWidth: 18)
                    .frame(width: 154, height: 154)
                    .scaleEffect(pulse ? 1.18 : 0.92)
                    .opacity(pulse ? 0.2 : 1)
                AuraLogo(size: 92)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.system(size: 34, weight: .bold))
                Text("This usually takes a few seconds.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AuraPalette.subtext)
            }

            VStack(alignment: .leading, spacing: 14) {
                ForEach(steps, id: \.self) { step in
                    Label(step, systemImage: "sparkle")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AuraPalette.subtext)
                }
            }

            Spacer()
        }
        .frame(maxWidth: 620, alignment: .leading)
        .padding(24)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

private struct DuoHandoffView: View {
    let mode: DuoMode
    let onContinue: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            AuraTopBar(title: mode.rawValue, subtitle: "Your side is locked") {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(AuraIconButtonStyle())
                .accessibilityLabel("Cancel")
            }

            VStack(alignment: .leading, spacing: 22) {
                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(AuraPalette.neonGradient)
                        .frame(width: 118, height: 118)
                    Image(systemName: mode.icon)
                        .font(.system(size: 42, weight: .black))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(mode.handoffTitle)
                        .font(.system(size: 44, weight: .black))
                        .lineSpacing(2)
                        .minimumScaleFactor(0.68)
                        .foregroundStyle(.white)

                    Text(mode.handoffText)
                        .font(.system(size: 17, weight: .semibold))
                        .lineSpacing(5)
                        .foregroundStyle(AuraPalette.subtext)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Label("No names needed", systemImage: "person.crop.circle.badge.questionmark")
                    Label("No result saved", systemImage: "lock.open.display")
                    Label("One share card at the end", systemImage: "square.and.arrow.up")
                }
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(AuraPalette.subtext)
                .padding(18)
                .auraPanel()

                Spacer()
            }
            .frame(maxWidth: 620, alignment: .leading)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            AuraBottomBar {
                AuraPrimaryButton(
                    title: "Next Person Starts",
                    systemImage: "arrow.right",
                    action: onContinue
                )
            }
        }
    }
}

private struct PartySetupView: View {
    @Binding var names: [String]
    let onStart: () -> Void
    let onCancel: () -> Void

    private var cleanCount: Int {
        names.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            AuraTopBar(title: "Group Vote", subtitle: "Local, anonymous-ish, not saved") {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(AuraIconButtonStyle())
                .accessibilityLabel("Cancel")
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Add the people in the room.")
                            .font(.system(size: 42, weight: .black))
                            .lineSpacing(2)
                            .minimumScaleFactor(0.62)
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("AURA asks six prompts. Everyone passes the phone and votes who fits. The final card exposes the room.")
                            .font(.system(size: 16, weight: .semibold))
                            .lineSpacing(5)
                            .foregroundStyle(AuraPalette.subtext)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: 10) {
                        ForEach(names.indices, id: \.self) { index in
                            HStack(spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.system(size: 14, weight: .black, design: .monospaced))
                                    .foregroundStyle(AuraPalette.muted)
                                    .frame(width: 28, height: 28)
                                    .background(AuraPalette.panelHigh)
                                    .clipShape(Circle())

                                TextField("Friend \(index + 1)", text: $names[index])
                                    .textInputAutocapitalization(.words)
                                    .autocorrectionDisabled()
                                    .font(.system(size: 18, weight: .black))
                                    .foregroundStyle(.white)
                                    .submitLabel(index == names.indices.last ? .done : .next)
                            }
                            .padding(16)
                            .background(AuraPalette.panel)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(AuraPalette.border, lineWidth: 1)
                            )
                        }
                    }

                    HStack(spacing: 10) {
                        HomeProofPill(icon: "person.3.fill", title: "2-4 People", subtitle: "Same phone")
                        HomeProofPill(icon: "eye.slash.fill", title: "No Login", subtitle: "No names saved")
                    }

                    Text("Use nicknames if you want. This is built for screenshots, not storage.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AuraPalette.muted)
                        .padding(.bottom, 106)
                }
                .frame(maxWidth: 620, alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity)
            }

            AuraBottomBar {
                AuraPrimaryButton(
                    title: cleanCount >= 2 ? "Start Group Vote" : "Add 2 People",
                    systemImage: "arrow.right",
                    action: onStart
                )
                .disabled(cleanCount < 2)
                .opacity(cleanCount < 2 ? 0.45 : 1)
            }
        }
    }
}

private struct PartyVoteView: View {
    @Binding var currentIndex: Int
    @Binding var votes: [String: String]
    let names: [String]
    let onFinish: () -> Void
    let onCancel: () -> Void

    private var question: PartyPollQuestion {
        partyPollQuestions[min(currentIndex, partyPollQuestions.count - 1)]
    }

    private var progress: Double {
        Double(currentIndex + 1) / Double(partyPollQuestions.count)
    }

    var body: some View {
        VStack(spacing: 0) {
            AuraTopBar(title: "Group Vote", subtitle: "Question \(currentIndex + 1) of \(partyPollQuestions.count)") {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(AuraIconButtonStyle())
                .accessibilityLabel("Cancel")
            }

            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundStyle(AuraPalette.muted)
                        Spacer()
                        Text("tap one name")
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundStyle(AuraPalette.subtext)
                    }

                    ProgressView(value: progress)
                        .tint(AuraPalette.hotPink)
                }

                Spacer(minLength: 18)

                VStack(alignment: .leading, spacing: 14) {
                    Text(question.prompt)
                        .font(.system(size: 40, weight: .black))
                        .lineSpacing(3)
                        .minimumScaleFactor(0.58)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(question.detail)
                        .font(.system(size: 17, weight: .semibold))
                        .lineSpacing(5)
                        .foregroundStyle(AuraPalette.subtext)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 12) {
                    ForEach(names, id: \.self) { name in
                        Button(action: { select(name) }) {
                            HStack(spacing: 12) {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 15, weight: .black))
                                    .foregroundStyle(.white)
                                    .frame(width: 34, height: 34)
                                    .background(AuraPalette.hotPink)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                                Text(name)
                                    .font(.system(size: 19, weight: .black))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)

                                Spacer()

                                Image(systemName: votes[question.id] == name ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 20, weight: .black))
                                    .foregroundStyle(votes[question.id] == name ? AuraPalette.hotPink : AuraPalette.muted)
                            }
                            .padding(16)
                            .background(AuraPalette.panel)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(votes[question.id] == name ? AuraPalette.hotPink.opacity(0.75) : AuraPalette.border, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer(minLength: 20)

                HStack(spacing: 10) {
                    AuraSecondaryButton(
                        title: "Back",
                        systemImage: "chevron.left",
                        action: {
                            withAnimation(.easeOut(duration: 0.18)) {
                                currentIndex = max(0, currentIndex - 1)
                            }
                        }
                    )
                    .disabled(currentIndex == 0)
                    .opacity(currentIndex == 0 ? 0.45 : 1)

                    AuraPrimaryButton(
                        title: currentIndex == partyPollQuestions.count - 1 ? "Reveal Vote" : "Next",
                        systemImage: currentIndex == partyPollQuestions.count - 1 ? "sparkles" : "chevron.right",
                        action: advance
                    )
                    .disabled(votes[question.id] == nil)
                    .opacity(votes[question.id] == nil ? 0.45 : 1)
                }
            }
            .frame(maxWidth: 620, alignment: .leading)
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func select(_ name: String) {
        AuraHaptics.impact()
        let selectedID = question.id
        let selectedIndex = currentIndex
        withAnimation(.easeOut(duration: 0.16)) {
            votes[selectedID] = name
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            guard currentIndex == selectedIndex, votes[selectedID] == name else { return }
            advance()
        }
    }

    private func advance() {
        guard votes[question.id] != nil else { return }

        if currentIndex == partyPollQuestions.count - 1 {
            onFinish()
            return
        }

        withAnimation(.easeOut(duration: 0.18)) {
            currentIndex = min(partyPollQuestions.count - 1, currentIndex + 1)
        }
    }
}

private struct PartyResultView: View {
    let result: PartyPollResult
    let onRestart: () -> Void
    let onShare: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            AuraTopBar(title: "Group Vote", subtitle: result.winner) {
                Button(action: onRestart) {
                    Image(systemName: "arrow.counterclockwise")
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(AuraIconButtonStyle())
                .accessibilityLabel("Restart")
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    PartyResultHero(result: result)

                    PartyVoteBoard(scores: result.scores)
                    VisualInsightGrid(items: [
                        VisualInsight(icon: "text.bubble.fill", title: "Receipt", text: result.receipt, accent: AuraPalette.hotPink)
                    ])
                    NoSaveBand()

                    Text(result.disclaimer)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AuraPalette.muted)
                        .padding(.bottom, 106)
                }
                .frame(maxWidth: 680, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity)
            }

            AuraBottomBar {
                HStack(spacing: 10) {
                    AuraSecondaryButton(title: "New Vote", systemImage: "arrow.counterclockwise", action: onRestart)
                    AuraPrimaryButton(title: "Share Vote", systemImage: "square.and.arrow.up", action: onShare)
                }
            }
        }
    }
}

private struct PartyResultHero: View {
    let result: PartyPollResult

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("GROUP VOTE")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(AuraPalette.hotPink)
                Spacer()
                Text("LOCAL")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(AuraPalette.subtext)
            }

            HStack(alignment: .center, spacing: 18) {
                VoteDonutChart(scores: result.scores)

                VStack(alignment: .leading, spacing: 10) {
                    Text(result.winner)
                        .font(.system(size: 38, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)

                    Text(result.shareLine)
                        .font(.system(size: 16, weight: .black))
                        .lineSpacing(3)
                        .foregroundStyle(AuraPalette.hotPink)
                        .lineLimit(2)
                }
            }

            Text(result.verdict)
                .font(.system(size: 18, weight: .bold))
                .lineSpacing(4)
                .lineLimit(3)
                .foregroundStyle(AuraPalette.subtext)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .background(AuraPalette.panelHigh)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AuraPalette.border, lineWidth: 1)
        )
    }
}

private struct PartyVoteBoard: View {
    let scores: [PartyPollScore]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Votes")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(scores.reduce(0) { $0 + $1.votes }) total")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(AuraPalette.muted)
            }

            ForEach(scores) { score in
                PartyScoreRow(score: score, maxVotes: max(1, scores.first?.votes ?? 1))
            }
        }
        .padding(18)
        .auraPanel()
    }
}

private struct VoteDonutChart: View {
    let scores: [PartyPollScore]

    private var total: Int {
        max(1, scores.reduce(0) { $0 + $1.votes })
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(AuraPalette.border, lineWidth: 16)

            ForEach(Array(scores.prefix(4).enumerated()), id: \.element.id) { index, score in
                Circle()
                    .trim(from: start(for: index), to: end(for: index))
                    .stroke(color(for: index), style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }

            VStack(spacing: 0) {
                Text("\(scores.first?.votes ?? 0)")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("TOP")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(AuraPalette.muted)
            }
        }
        .frame(width: 118, height: 118)
    }

    private func start(for index: Int) -> CGFloat {
        let prior = scores.prefix(index).reduce(0) { $0 + $1.votes }
        return CGFloat(prior) / CGFloat(total)
    }

    private func end(for index: Int) -> CGFloat {
        let through = scores.prefix(index + 1).reduce(0) { $0 + $1.votes }
        return CGFloat(through) / CGFloat(total)
    }

    private func color(for index: Int) -> Color {
        [AuraPalette.hotPink, AuraPalette.accent, AuraPalette.violet, AuraPalette.cyan][index % 4]
    }
}

private struct DailyDropView: View {
    let drop: DailyDrop
    let onBack: () -> Void
    let onInstantRoast: () -> Void
    let onShare: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            AuraTopBar(title: "Daily Drop", subtitle: drop.tag) {
                Button(action: onBack) {
                    Image(systemName: "xmark")
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(AuraIconButtonStyle())
                .accessibilityLabel("Close")
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    DailyDropHero(drop: drop)
                    VisualInsightGrid(items: [
                        VisualInsight(icon: "calendar", title: "Prompt", text: drop.prompt, accent: AuraPalette.violet),
                        VisualInsight(icon: "text.bubble.fill", title: "Receipt", text: drop.receipt, accent: AuraPalette.accent)
                    ])

                    Button(action: onInstantRoast) {
                        HStack(spacing: 12) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 16, weight: .black))
                                .foregroundStyle(.white)
                                .frame(width: 38, height: 38)
                                .background(AuraPalette.hotPink)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Need another hit?")
                                    .font(.system(size: 16, weight: .black))
                                    .foregroundStyle(.white)
                                Text("Run Instant Roast next.")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AuraPalette.subtext)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .black))
                                .foregroundStyle(AuraPalette.muted)
                        }
                        .padding(16)
                        .background(AuraPalette.panel)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(AuraPalette.border, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    NoSaveBand()

                    Text(drop.disclaimer)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AuraPalette.muted)
                        .padding(.bottom, 106)
                }
                .frame(maxWidth: 680, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity)
            }

            AuraBottomBar {
                HStack(spacing: 10) {
                    AuraSecondaryButton(title: "Home", systemImage: "house.fill", action: onBack)
                    AuraPrimaryButton(title: "Share Drop", systemImage: "square.and.arrow.up", action: onShare)
                }
            }
        }
    }
}

private struct DailyDropHero: View {
    let drop: DailyDrop

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(drop.tag)
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(AuraPalette.violet)
                Spacer()
                Text("TODAY")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(AuraPalette.subtext)
            }

            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(AuraPalette.violet)
                    Image(systemName: "calendar")
                        .font(.system(size: 42, weight: .black))
                        .foregroundStyle(.white)
                }
                .frame(width: 112, height: 112)

                Text(drop.title)
                    .font(.system(size: 34, weight: .black))
                    .lineSpacing(2)
                    .minimumScaleFactor(0.58)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(drop.verdict)
                .font(.system(size: 18, weight: .bold))
                .lineSpacing(4)
                .lineLimit(3)
                .foregroundStyle(AuraPalette.subtext)
                .fixedSize(horizontal: false, vertical: true)

            Text(drop.shareLine)
                .font(.system(size: 16, weight: .black))
                .lineSpacing(4)
                .foregroundStyle(AuraPalette.violet)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .background(AuraPalette.panelHigh)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AuraPalette.border, lineWidth: 1)
        )
    }
}

private struct PartyScoreRow: View {
    let score: PartyPollScore
    let maxVotes: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(score.name)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Spacer()
                Text("\(score.votes)")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(AuraPalette.subtext)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(AuraPalette.border)
                    Capsule()
                        .fill(AuraPalette.hotPink)
                        .frame(width: max(10, proxy.size.width * CGFloat(score.votes) / CGFloat(maxVotes)))
                }
            }
            .frame(height: 8)
        }
        .padding(14)
        .background(AuraPalette.panelHigh)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct ResultView: View {
    let analysis: AuraAnalysis
    let onRestart: () -> Void
    let onDuoRead: () -> Void
    let onShare: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            AuraTopBar(title: "Your Aura", subtitle: analysis.socialType) {
                Button(action: onRestart) {
                    Image(systemName: "arrow.counterclockwise")
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(AuraIconButtonStyle())
                .accessibilityLabel("Restart")
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ResultSnapshotPanel(analysis: analysis)
                    AuraRadarPanel(analysis: analysis)
                    DuoReadPrompt(action: onDuoRead)
                    ResultProofStrip(analysis: analysis)

                    Text(analysis.disclaimer)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AuraPalette.muted)
                        .padding(.bottom, 106)
                }
                .frame(maxWidth: 680, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity)
            }

            AuraBottomBar {
                HStack(spacing: 10) {
                    AuraSecondaryButton(title: "Duo Read", systemImage: "person.2.fill", action: onDuoRead)
                    AuraPrimaryButton(title: "Share Card", systemImage: "square.and.arrow.up", action: onShare)
                }
            }
        }
    }
}

private struct ResultSnapshotPanel: View {
    let analysis: AuraAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                AuraVisualBadge(analysis: analysis, size: 126)

                VStack(alignment: .leading, spacing: 9) {
                    Text(analysis.badgeTitle.uppercased())
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(analysis.visual.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(analysis.socialType)
                        .font(.system(size: 30, weight: .black))
                        .lineSpacing(1)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.58)

                    Text(analysis.roast)
                        .font(.system(size: 17, weight: .black))
                        .lineSpacing(3)
                        .foregroundStyle(AuraPalette.subtext)
                        .lineLimit(2)
                }
            }

            HStack(spacing: 10) {
                SnapshotMetric(value: "\(analysis.auraScore)", label: "AURA", accent: analysis.visual.accent)
                SnapshotMetric(value: analysis.rarity.replacingOccurrences(of: "Top ", with: ""), label: "RARITY", accent: AuraPalette.hotPink)
            }
        }
        .padding(20)
        .background(AuraPalette.panelHigh)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AuraPalette.border, lineWidth: 1)
        )
    }
}

private struct SnapshotMetric: View {
    let value: String
    let label: String
    let accent: Color

    var body: some View {
        HStack {
            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Spacer()
            Text(label)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(accent)
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
        .background(AuraPalette.panel)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct AuraRadarPanel: View {
    let analysis: AuraAnalysis

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            AuraRadarChart(metrics: analysis.metrics, accent: analysis.visual.accent)
                .frame(width: 152, height: 152)

            VStack(spacing: 10) {
                ForEach(analysis.metrics.prefix(4)) { metric in
                    RadarMetricRow(metric: metric)
                }
            }
        }
        .padding(18)
        .background(AuraPalette.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AuraPalette.border, lineWidth: 1)
        )
    }
}

private struct AuraRadarChart: View {
    let metrics: [AuraMetric]
    let accent: Color

    var body: some View {
        Canvas { context, size in
            let values = Array(metrics.prefix(4))
            let count = max(values.count, 3)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) * 0.44

            for step in 1...3 {
                var ring = Path()
                let scaled = radius * CGFloat(step) / 3
                for index in 0..<count {
                    let point = radarPoint(index: index, count: count, center: center, radius: scaled)
                    index == 0 ? ring.move(to: point) : ring.addLine(to: point)
                }
                ring.closeSubpath()
                context.stroke(ring, with: .color(.white.opacity(0.10)), lineWidth: 1)
            }

            var shape = Path()
            for index in 0..<count {
                let value = values.indices.contains(index) ? CGFloat(values[index].value) / 100 : 0.5
                let point = radarPoint(index: index, count: count, center: center, radius: radius * value)
                index == 0 ? shape.move(to: point) : shape.addLine(to: point)
            }
            shape.closeSubpath()
            context.fill(shape, with: .color(accent.opacity(0.34)))
            context.stroke(shape, with: .color(accent), lineWidth: 3)

            for index in 0..<count {
                let point = radarPoint(index: index, count: count, center: center, radius: radius)
                context.stroke(Path { path in
                    path.move(to: center)
                    path.addLine(to: point)
                }, with: .color(.white.opacity(0.08)), lineWidth: 1)
            }
        }
        .background(
            Circle()
                .fill(accent.opacity(0.10))
        )
    }

    private func radarPoint(index: Int, count: Int, center: CGPoint, radius: CGFloat) -> CGPoint {
        let angle = (CGFloat(index) / CGFloat(count)) * .pi * 2 - .pi / 2
        return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
    }
}

private struct RadarMetricRow: View {
    let metric: AuraMetric

    var body: some View {
        HStack(spacing: 8) {
            Text(metric.name)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(AuraPalette.subtext)
                .lineLimit(1)
                .minimumScaleFactor(0.62)

            Spacer(minLength: 0)

            Text("\(metric.value)")
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(metric.value > 70 ? AuraPalette.hotPink : AuraPalette.accent)
        }
        .padding(.horizontal, 10)
        .frame(height: 31)
        .background(AuraPalette.panelHigh)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ResultProofStrip: View {
    let analysis: AuraAnalysis

    var body: some View {
        HStack(spacing: 10) {
            ResultProofTile(icon: "text.bubble.fill", title: "Receipt", accent: analysis.visual.accent)
            ResultProofTile(icon: "eye.fill", title: "Pattern", accent: AuraPalette.violet)
            ResultProofTile(icon: "person.2.fill", title: "Match", accent: AuraPalette.accent)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(analysis.receipt). \(analysis.hiddenPattern). \(analysis.matchup)")
    }
}

private struct ResultProofTile: View {
    let icon: String
    let title: String
    let accent: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(accent)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(title)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(AuraPalette.subtext)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AuraPalette.panel)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AuraPalette.border, lineWidth: 1)
        )
    }
}

private struct DuoReadPrompt: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(AuraPalette.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text("Compare with a friend")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(.white)
                    Text("Pass the phone. Get the match card.")
                        .font(.system(size: 13, weight: .semibold))
                        .lineSpacing(3)
                        .foregroundStyle(AuraPalette.subtext)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(AuraPalette.muted)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AuraPalette.panel)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AuraPalette.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct DuoResultView: View {
    let compatibility: AuraCompatibility
    let onRestart: () -> Void
    let onStartMode: (DuoMode) -> Void
    let onShare: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            AuraTopBar(title: compatibility.modeTitle, subtitle: compatibility.title) {
                Button(action: onRestart) {
                    Image(systemName: "arrow.counterclockwise")
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(AuraIconButtonStyle())
                .accessibilityLabel("Restart")
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    DuoHero(compatibility: compatibility)
                    VisualInsightGrid(items: [
                        VisualInsight(icon: "bolt.heart.fill", title: "Tension", text: compatibility.tension, accent: AuraPalette.hotPink),
                        VisualInsight(icon: "checkmark.seal.fill", title: "Green", text: compatibility.greenFlag, accent: AuraPalette.accent)
                    ])
                    NextReadPanel(onStartMode: onStartMode)
                    NoSaveBand()

                    Text(compatibility.disclaimer)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AuraPalette.muted)
                        .padding(.bottom, 106)
                }
                .frame(maxWidth: 680, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity)
            }

            AuraBottomBar {
                HStack(spacing: 10) {
                    AuraSecondaryButton(title: "New Scan", systemImage: "arrow.counterclockwise", action: onRestart)
                    AuraPrimaryButton(title: "Share Duo", systemImage: "square.and.arrow.up", action: onShare)
                }
            }
        }
    }
}

private struct NextReadPanel: View {
    let onStartMode: (DuoMode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Run Another Read")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
                Spacer()
                Text("keep passing")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(AuraPalette.muted)
            }

            ForEach(DuoMode.allCases.filter { $0.rawValue != "" }) { mode in
                Button(action: { onStartMode(mode) }) {
                    HStack(spacing: 12) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(mode.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(mode.rawValue)
                                .font(.system(size: 15, weight: .black))
                                .foregroundStyle(.white)
                            Text(mode.teaser)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AuraPalette.subtext)
                                .lineLimit(2)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(AuraPalette.muted)
                    }
                    .padding(12)
                    .background(AuraPalette.panelHigh)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .auraPanel()
    }
}

private struct DuoHero: View {
    let compatibility: AuraCompatibility

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(compatibility.modeTitle.uppercased())
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(AuraPalette.hotPink)
                Spacer()
                Text("MATCH \(compatibility.score)")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(AuraPalette.subtext)
            }

            HStack(alignment: .center, spacing: 16) {
                AuraScoreDial(score: compatibility.score, accent: AuraPalette.hotPink)

                VStack(alignment: .leading, spacing: 10) {
                    Text(compatibility.title)
                        .font(.system(size: 29, weight: .black))
                        .lineSpacing(2)
                        .minimumScaleFactor(0.58)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(compatibility.shareLine)
                        .font(.system(size: 15, weight: .black))
                        .lineSpacing(3)
                        .foregroundStyle(AuraPalette.hotPink)
                        .lineLimit(2)
                }
            }

            Text(compatibility.verdict)
                .font(.system(size: 18, weight: .bold))
                .lineSpacing(4)
                .lineLimit(3)
                .foregroundStyle(AuraPalette.subtext)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                DuoTypeRow(label: "You", value: compatibility.firstType)
                DuoTypeRow(label: "Friend", value: compatibility.secondType)
            }
        }
        .padding(22)
        .background(AuraPalette.panelHigh)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AuraPalette.border, lineWidth: 1)
        )
    }
}

private struct DuoTypeRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(AuraPalette.muted)
                .frame(width: 54, alignment: .leading)
            Text(value)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
        .background(AuraPalette.panel)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct AuraResultHero: View {
    let analysis: AuraAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(analysis.badgeTitle.uppercased())
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(analysis.visual.accent)
                Spacer()
                Text("AURA \(analysis.auraScore)")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(AuraPalette.subtext)
            }

            Text(analysis.socialType)
                .font(.system(size: 42, weight: .bold))
                .lineSpacing(2)
                .minimumScaleFactor(0.58)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text(analysis.roast)
                .font(.system(size: 24, weight: .black))
                .lineSpacing(4)
                .minimumScaleFactor(0.68)
                .lineLimit(3)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 18) {
                AuraVisualBadge(analysis: analysis, size: 138)

                VStack(alignment: .leading, spacing: 8) {
                    Text(analysis.shareLine)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(22)
        .background(AuraPalette.panelHigh)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AuraPalette.border, lineWidth: 1)
        )
    }
}

private struct AuraDashboardPanel: View {
    let analysis: AuraAnalysis

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            AuraScoreDial(score: analysis.auraScore, accent: analysis.visual.accent)

            VStack(alignment: .leading, spacing: 12) {
                MiniBarSet(metrics: analysis.metrics)
            }
        }
        .padding(18)
        .background(AuraPalette.panel)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AuraPalette.border, lineWidth: 1)
        )
    }
}

private struct AuraScoreDial: View {
    let score: Int
    let accent: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(AuraPalette.border, lineWidth: 14)
            Circle()
                .trim(from: 0, to: CGFloat(score) / 100)
                .stroke(accent, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(score)")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("AURA")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(AuraPalette.muted)
            }
        }
        .frame(width: 112, height: 112)
    }
}

private struct MiniBarSet: View {
    let metrics: [AuraMetric]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(metrics) { metric in
                HStack(spacing: 8) {
                    Text(metric.name)
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(AuraPalette.subtext)
                        .frame(width: 92, alignment: .leading)
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(AuraPalette.border)
                            Capsule()
                                .fill(metric.value > 70 ? AuraPalette.hotPink : AuraPalette.accent)
                                .frame(width: max(8, proxy.size.width * CGFloat(metric.value) / 100))
                        }
                    }
                    .frame(height: 8)
                }
            }
        }
    }
}

private struct VisualInsight: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let text: String
    let accent: Color
}

private struct VisualInsightGrid: View {
    let items: [VisualInsight]

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: item.icon)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(item.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                    Text(item.title)
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(item.accent)
                        .lineLimit(1)

                    Text(item.text)
                        .font(.system(size: 14, weight: .black))
                        .lineSpacing(3)
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .minimumScaleFactor(0.72)
                }
                .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
                .padding(14)
                .background(AuraPalette.panel)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AuraPalette.border, lineWidth: 1)
                )
            }
        }
    }
}

private struct AuraVisualBadge: View {
    let analysis: AuraAnalysis
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(AuraPalette.panelHigh)

            Image(analysis.avatarAssetName)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))

            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .stroke(analysis.visual.gradient, lineWidth: max(3, size * 0.035))

            VStack {
                Spacer()
                Text("\(analysis.auraScore)")
                    .font(.system(size: size * 0.15, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, size * 0.09)
                    .padding(.vertical, size * 0.035)
                    .background(AuraPalette.background.opacity(0.78))
                    .clipShape(Capsule())
                    .padding(.bottom, size * 0.10)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(analysis.badgeTitle) avatar, aura score \(analysis.auraScore)")
    }
}

private struct ShareChallengeBand: View {
    let text: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "paperplane.fill")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(AuraPalette.hotPink)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(text)
                .font(.system(size: 16, weight: .black))
                .lineSpacing(4)
                .minimumScaleFactor(0.78)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(analysisGradient)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        )
    }

    private var analysisGradient: LinearGradient {
        LinearGradient(
            colors: [AuraPalette.hotPink.opacity(0.55), AuraPalette.violet.opacity(0.42), AuraPalette.panelHigh],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct CaptionRail: View {
    let title: String
    let captions: [String]
    @State private var copiedIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
                Spacer()
                Text("tap to copy")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(AuraPalette.muted)
            }

            ForEach(Array(captions.enumerated()), id: \.offset) { index, caption in
                Button(action: { copy(caption, index: index) }) {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: copiedIndex == index ? "checkmark.circle.fill" : "text.quote")
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(copiedIndex == index ? AuraPalette.accent : AuraPalette.hotPink)
                            .frame(width: 34, height: 34)
                            .background(AuraPalette.panelHigh)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        Text(caption)
                            .font(.system(size: 15, weight: .black))
                            .lineSpacing(4)
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 8)

                        Text(copiedIndex == index ? "Copied" : "Copy")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(copiedIndex == index ? AuraPalette.accent : AuraPalette.muted)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AuraPalette.panel)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(copiedIndex == index ? AuraPalette.accent.opacity(0.35) : AuraPalette.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .auraPanel()
    }

    private func copy(_ caption: String, index: Int) {
        UIPasteboard.general.string = caption
        AuraHaptics.success()
        withAnimation(.easeOut(duration: 0.18)) {
            copiedIndex = index
        }
    }
}

private struct NoSaveBand: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.open.display")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AuraPalette.accent)
                .frame(width: 34, height: 34)
                .background(AuraPalette.panelHigh)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text("Private by default")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(.white)
                Text("This result is not tied to an account. Share the card or restart the scan.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AuraPalette.subtext)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AuraPalette.accent.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AuraPalette.accent.opacity(0.22), lineWidth: 1)
        )
    }
}

private struct ResultStat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(AuraPalette.muted)
            Text(value)
                .font(.system(size: value.count > 10 ? 18 : value.count > 4 ? 20 : 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(3)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .auraPanel()
    }
}

private struct ResultBlock: View {
    let title: String
    let text: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AuraPalette.accent)
            Text(text)
                .font(.system(size: 22, weight: .bold))
                .lineSpacing(4)
                .minimumScaleFactor(0.72)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .auraPanel()
    }
}

private struct AuraMetricBar: View {
    let metric: AuraMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(metric.name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AuraPalette.subtext)
                Spacer()
                Text("\(metric.value)%")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(AuraPalette.border)
                    Capsule()
                        .fill(AuraPalette.accent)
                        .frame(width: max(10, proxy.size.width * CGFloat(metric.value) / 100))
                }
            }
            .frame(height: 8)
        }
    }
}

private struct AuraStoryCard: View {
    let analysis: AuraAnalysis
    let width: CGFloat

    private var scale: CGFloat { width / 1080 }

    var body: some View {
        ZStack {
            AuraPalette.storyBackground

            VStack(alignment: .leading, spacing: 38 * scale) {
                HStack {
                    AuraLogo(size: 84 * scale)
                    Text("AURA")
                        .font(.system(size: 44 * scale, weight: .bold))
                        .tracking(3 * scale)
                    Spacer()
                    Text("SCORE \(analysis.auraScore)")
                        .font(.system(size: 27 * scale, weight: .bold, design: .monospaced))
                        .foregroundStyle(AuraPalette.accent)
                }

                Spacer()

                HStack(alignment: .center, spacing: 28 * scale) {
                    AuraVisualBadge(analysis: analysis, size: 190 * scale)
                    VStack(alignment: .leading, spacing: 12 * scale) {
                        Text(analysis.badgeTitle.uppercased())
                            .font(.system(size: 28 * scale, weight: .bold, design: .monospaced))
                            .foregroundStyle(analysis.visual.accent)
                        Text(analysis.socialType)
                            .font(.system(size: 58 * scale, weight: .bold))
                            .lineSpacing(2 * scale)
                            .minimumScaleFactor(0.50)
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(analysis.rarity.uppercased())
                            .font(.system(size: 22 * scale, weight: .black, design: .monospaced))
                            .foregroundStyle(AuraPalette.muted)
                    }
                }

                VStack(alignment: .leading, spacing: 14 * scale) {
                    Text(analysis.shareLine.uppercased())
                        .font(.system(size: 28 * scale, weight: .black, design: .monospaced))
                        .foregroundStyle(analysis.visual.accent)

                    Text(analysis.roast)
                        .font(.system(size: 48 * scale, weight: .black))
                        .lineSpacing(9 * scale)
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.62)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Text(analysis.challenge)
                    .font(.system(size: 31 * scale, weight: .bold))
                    .lineSpacing(7 * scale)
                    .foregroundStyle(AuraPalette.subtext)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Text("aura.app")
                        .font(.system(size: 28 * scale, weight: .bold, design: .monospaced))
                        .foregroundStyle(AuraPalette.muted)
                    Spacer()
                    Text("POST THE READ")
                        .font(.system(size: 24 * scale, weight: .bold, design: .monospaced))
                        .foregroundStyle(AuraPalette.muted)
                }
            }
            .padding(72 * scale)
        }
        .frame(width: width, height: width * 16 / 9)
        .clipShape(RoundedRectangle(cornerRadius: 72 * scale, style: .continuous))
    }
}

private struct AuraDuoStoryCard: View {
    let compatibility: AuraCompatibility
    let width: CGFloat

    private var scale: CGFloat { width / 1080 }

    var body: some View {
        ZStack {
            AuraPalette.storyBackground

            VStack(alignment: .leading, spacing: 36 * scale) {
                HStack {
                    AuraLogo(size: 84 * scale)
                    Text("AURA")
                        .font(.system(size: 44 * scale, weight: .bold))
                        .tracking(3 * scale)
                    Spacer()
                    Text("\(compatibility.modeTitle.uppercased()) \(compatibility.score)")
                        .font(.system(size: 27 * scale, weight: .bold, design: .monospaced))
                        .foregroundStyle(AuraPalette.hotPink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.42)
                }

                Spacer()

                Text(compatibility.shareLine.uppercased())
                    .font(.system(size: 30 * scale, weight: .black, design: .monospaced))
                    .foregroundStyle(AuraPalette.hotPink)

                Text(compatibility.title)
                    .font(.system(size: 68 * scale, weight: .black))
                    .lineSpacing(4 * scale)
                    .minimumScaleFactor(0.58)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(compatibility.verdict)
                    .font(.system(size: 39 * scale, weight: .bold))
                    .lineSpacing(9 * scale)
                    .foregroundStyle(AuraPalette.subtext)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 15 * scale) {
                    DuoStoryType(label: "YOU", value: compatibility.firstType, scale: scale)
                    DuoStoryType(label: "FRIEND", value: compatibility.secondType, scale: scale)
                }

                Spacer()

                HStack {
                    Text("aura.app")
                        .font(.system(size: 28 * scale, weight: .bold, design: .monospaced))
                        .foregroundStyle(AuraPalette.muted)
                    Spacer()
                    Text(compatibility.modeTitle.uppercased())
                        .font(.system(size: 24 * scale, weight: .bold, design: .monospaced))
                        .foregroundStyle(AuraPalette.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.52)
                }
            }
            .padding(72 * scale)
        }
        .frame(width: width, height: width * 16 / 9)
        .clipShape(RoundedRectangle(cornerRadius: 72 * scale, style: .continuous))
    }
}

private struct PartyVoteStoryCard: View {
    let result: PartyPollResult
    let width: CGFloat

    private var scale: CGFloat { width / 1080 }

    var body: some View {
        ZStack {
            AuraPalette.storyBackground

            VStack(alignment: .leading, spacing: 36 * scale) {
                HStack {
                    AuraLogo(size: 84 * scale)
                    Text("AURA")
                        .font(.system(size: 44 * scale, weight: .bold))
                        .tracking(3 * scale)
                    Spacer()
                    Text("GROUP VOTE")
                        .font(.system(size: 27 * scale, weight: .bold, design: .monospaced))
                        .foregroundStyle(AuraPalette.hotPink)
                }

                Spacer()

                Text(result.shareLine.uppercased())
                    .font(.system(size: 30 * scale, weight: .black, design: .monospaced))
                    .foregroundStyle(AuraPalette.hotPink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(result.title)
                    .font(.system(size: 72 * scale, weight: .black))
                    .lineSpacing(4 * scale)
                    .minimumScaleFactor(0.52)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(result.verdict)
                    .font(.system(size: 39 * scale, weight: .bold))
                    .lineSpacing(9 * scale)
                    .foregroundStyle(AuraPalette.subtext)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 14 * scale) {
                    ForEach(result.scores.prefix(4)) { score in
                        HStack(spacing: 16 * scale) {
                            Text(score.name)
                                .font(.system(size: 30 * scale, weight: .black))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.62)
                            Spacer()
                            Text("\(score.votes)")
                                .font(.system(size: 28 * scale, weight: .black, design: .monospaced))
                                .foregroundStyle(AuraPalette.hotPink)
                        }
                        .padding(.horizontal, 20 * scale)
                        .frame(height: 62 * scale)
                        .background(AuraPalette.panel.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 14 * scale, style: .continuous))
                    }
                }

                Spacer()

                HStack {
                    Text("aura.app")
                        .font(.system(size: 28 * scale, weight: .bold, design: .monospaced))
                        .foregroundStyle(AuraPalette.muted)
                    Spacer()
                    Text("NOT SAVED")
                        .font(.system(size: 24 * scale, weight: .bold, design: .monospaced))
                        .foregroundStyle(AuraPalette.muted)
                }
            }
            .padding(72 * scale)
        }
        .frame(width: width, height: width * 16 / 9)
        .clipShape(RoundedRectangle(cornerRadius: 72 * scale, style: .continuous))
    }
}

private struct DailyDropStoryCard: View {
    let drop: DailyDrop
    let width: CGFloat

    private var scale: CGFloat { width / 1080 }

    var body: some View {
        ZStack {
            AuraPalette.storyBackground

            VStack(alignment: .leading, spacing: 36 * scale) {
                HStack {
                    AuraLogo(size: 84 * scale)
                    Text("AURA")
                        .font(.system(size: 44 * scale, weight: .bold))
                        .tracking(3 * scale)
                    Spacer()
                    Text("DAILY DROP")
                        .font(.system(size: 27 * scale, weight: .bold, design: .monospaced))
                        .foregroundStyle(AuraPalette.violet)
                }

                Spacer()

                Text(drop.tag.uppercased())
                    .font(.system(size: 30 * scale, weight: .black, design: .monospaced))
                    .foregroundStyle(AuraPalette.violet)

                Text(drop.title)
                    .font(.system(size: 72 * scale, weight: .black))
                    .lineSpacing(4 * scale)
                    .minimumScaleFactor(0.52)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(drop.verdict)
                    .font(.system(size: 39 * scale, weight: .bold))
                    .lineSpacing(9 * scale)
                    .foregroundStyle(AuraPalette.subtext)
                    .fixedSize(horizontal: false, vertical: true)

                Text(drop.shareLine.uppercased())
                    .font(.system(size: 30 * scale, weight: .black, design: .monospaced))
                    .foregroundStyle(AuraPalette.violet)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                HStack {
                    Text("aura.app")
                        .font(.system(size: 28 * scale, weight: .bold, design: .monospaced))
                        .foregroundStyle(AuraPalette.muted)
                    Spacer()
                    Text("NEW DROP DAILY")
                        .font(.system(size: 24 * scale, weight: .bold, design: .monospaced))
                        .foregroundStyle(AuraPalette.muted)
                }
            }
            .padding(72 * scale)
        }
        .frame(width: width, height: width * 16 / 9)
        .clipShape(RoundedRectangle(cornerRadius: 72 * scale, style: .continuous))
    }
}

private struct DuoStoryType: View {
    let label: String
    let value: String
    let scale: CGFloat

    var body: some View {
        HStack(spacing: 16 * scale) {
            Text(label)
                .font(.system(size: 22 * scale, weight: .black, design: .monospaced))
                .foregroundStyle(AuraPalette.muted)
                .frame(width: 120 * scale, alignment: .leading)
            Text(value)
                .font(.system(size: 30 * scale, weight: .black))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
            Spacer()
        }
        .padding(.horizontal, 20 * scale)
        .frame(height: 62 * scale)
        .background(AuraPalette.panel.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 14 * scale, style: .continuous))
    }
}

private struct AuraScoreRing: View {
    let score: Int

    var body: some View {
        ZStack {
            Circle()
                .stroke(AuraPalette.border, lineWidth: 14)
            Circle()
                .trim(from: 0, to: CGFloat(score) / 100)
                .stroke(AuraPalette.accent, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(score)")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                Text("AURA")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(AuraPalette.muted)
            }
        }
    }
}

private struct AuraHeader: View {
    var body: some View {
        HStack(spacing: 12) {
            AuraLogo(size: 42)
            Text("AURA")
                .font(.system(size: 20, weight: .bold))
                .tracking(1.6)
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}

private struct AuraTopBar<Leading: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let leading: () -> Leading

    var body: some View {
        HStack(spacing: 12) {
            leading()

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AuraPalette.muted)
            }

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
}

private struct AuraBottomBar<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 18)
            .background(.ultraThinMaterial)
    }
}

private struct AuraPrimaryButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(AuraPalette.accent)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct AuraSecondaryButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(AuraPalette.panel)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AuraPalette.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct AuraIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .black))
            .foregroundStyle(.white)
            .background(configuration.isPressed ? AuraPalette.accent.opacity(0.35) : AuraPalette.panel)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AuraPalette.border, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

private struct AuraLogo: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(AuraPalette.neonGradient)
            Circle()
                .stroke(.white.opacity(0.92), lineWidth: max(2, size * 0.075))
                .frame(width: size * 0.52, height: size * 0.52)
            Circle()
                .fill(.white)
                .frame(width: size * 0.14, height: size * 0.14)
                .offset(x: size * 0.12, y: -size * 0.08)
        }
        .frame(width: size, height: size)
    }
}

private struct AuraBackground: View {
    var body: some View {
        ZStack {
            AuraPalette.background.ignoresSafeArea()
            LinearGradient(
                colors: [
                    AuraPalette.panelHigh.opacity(0.35),
                    .clear,
                    AuraPalette.accent.opacity(0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
}

private enum AuraPalette {
    static let background = Color(red: 0.035, green: 0.039, blue: 0.055)
    static let panel = Color(red: 0.075, green: 0.083, blue: 0.110)
    static let panelHigh = Color(red: 0.105, green: 0.118, blue: 0.150)
    static let border = Color.white.opacity(0.11)
    static let subtext = Color(red: 0.800, green: 0.830, blue: 0.880)
    static let muted = Color(red: 0.560, green: 0.590, blue: 0.660)
    static let accent = Color(red: 0.090, green: 0.740, blue: 0.720)
    static let hotPink = Color(red: 0.960, green: 0.250, blue: 0.580)
    static let violet = Color(red: 0.450, green: 0.350, blue: 0.950)
    static let cyan = Color(red: 0.140, green: 0.760, blue: 0.950)

    static let neonGradient = LinearGradient(
        colors: [hotPink, violet, cyan],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let storyBackground = LinearGradient(
        colors: [
            Color(red: 0.035, green: 0.039, blue: 0.055),
            Color(red: 0.075, green: 0.083, blue: 0.110),
            Color(red: 0.020, green: 0.100, blue: 0.105)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

private extension DuoMode {
    var icon: String {
        switch self {
        case .crushCheck:
            "heart.fill"
        case .bestieAudit:
            "person.2.fill"
        case .softLaunchTest:
            "sparkles"
        case .groupChatTrial:
            "text.bubble.fill"
        }
    }

    var accent: Color {
        switch self {
        case .crushCheck:
            AuraPalette.hotPink
        case .bestieAudit:
            AuraPalette.accent
        case .softLaunchTest:
            AuraPalette.violet
        case .groupChatTrial:
            AuraPalette.cyan
        }
    }
}

private extension AuraVisual {
    var accent: Color {
        switch self {
        case .pulse: Color(red: 0.960, green: 0.250, blue: 0.580)
        case .prism: Color(red: 0.520, green: 0.430, blue: 0.980)
        case .spark: Color(red: 0.940, green: 0.740, blue: 0.220)
        case .eclipse: Color(red: 0.620, green: 0.700, blue: 0.820)
        case .signal: AuraPalette.accent
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .pulse:
            LinearGradient(colors: [accent, AuraPalette.violet], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .prism:
            LinearGradient(colors: [AuraPalette.violet, AuraPalette.cyan, AuraPalette.hotPink], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .spark:
            LinearGradient(colors: [accent, AuraPalette.hotPink], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .eclipse:
            LinearGradient(colors: [accent, AuraPalette.panelHigh], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .signal:
            LinearGradient(colors: [AuraPalette.accent, AuraPalette.cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

private extension AuraAnalysis {
    var avatarAssetName: String {
        let type = socialType.lowercased()
        let badge = badgeTitle.lowercased()
        let combined = "\(type) \(badge) \(shareLine.lowercased())"

        if type.contains("ice") || type.contains("frozen") {
            return "AvatarIceQueen"
        }

        if combined.contains("main character")
            || combined.contains("scene")
            || combined.contains("plot")
            || combined.contains("trailer")
            || combined.contains("celebrity")
            || combined.contains("camera roll") {
            return "AvatarMainCharacter"
        }

        if combined.contains("hard to read")
            || combined.contains("unreadable")
            || combined.contains("mystery")
            || combined.contains("phantom")
            || combined.contains("missing context")
            || combined.contains("redacted")
            || combined.contains("vague") {
            return "AvatarHardToRead"
        }

        if combined.contains("chaos")
            || combined.contains("storm")
            || combined.contains("spiral")
            || combined.contains("private tab")
            || combined.contains("quiet alarm")
            || combined.contains("gentle alarm") {
            return "AvatarSoftChaos"
        }

        if combined.contains("unbothered")
            || combined.contains("chill")
            || combined.contains("polite wall")
            || combined.contains("soft block")
            || combined.contains("actress") {
            return "AvatarUnbothered"
        }

        if combined.contains("receipt")
            || combined.contains("reply")
            || combined.contains("notification")
            || combined.contains("instant")
            || combined.contains("ghost")
            || combined.contains("archive")
            || combined.contains("typist") {
            return "AvatarReadReceipt"
        }

        switch visual {
        case .pulse:
            return "AvatarIceQueen"
        case .prism:
            return "AvatarMainCharacter"
        case .spark:
            return "AvatarSoftChaos"
        case .eclipse:
            return "AvatarHardToRead"
        case .signal:
            return "AvatarReadReceipt"
        }
    }
}

private struct AuraPanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AuraPalette.panel)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AuraPalette.border, lineWidth: 1)
            )
    }
}

private extension View {
    func auraPanel() -> some View {
        modifier(AuraPanelModifier())
    }
}

private enum CaptionCopy {
    static func captions(for analysis: AuraAnalysis) -> [String] {
        [
            "\(analysis.shareLine) AURA read: \(analysis.socialType).",
            "\(analysis.roast) I fear this is accurate.",
            "\(analysis.challenge) My AURA score is \(analysis.auraScore)."
        ]
    }

    static func captions(for compatibility: AuraCompatibility) -> [String] {
        [
            "\(compatibility.shareLine) AURA gave us \(compatibility.score).",
            "\(compatibility.title). The group chat needs to review this.",
            "\(compatibility.modeTitle): \(compatibility.verdict)"
        ]
    }

    static func captions(for result: PartyPollResult) -> [String] {
        [
            "\(result.shareLine) AURA group vote has spoken.",
            "\(result.title). No result was saved, but the evidence remains.",
            "\(result.winner) won the room and everyone needs to explain."
        ]
    }

    static func captions(for drop: DailyDrop) -> [String] {
        [
            "\(drop.shareLine) Today's AURA drop was too specific.",
            "\(drop.title): \(drop.prompt)",
            "\(drop.verdict) New drop tomorrow."
        ]
    }
}

private struct SharePayload: Identifiable {
    let id = UUID()
    let image: UIImage
    let text: String?

    var activityItems: [Any] {
        if let text {
            [image, text]
        } else {
            [image]
        }
    }
}

private struct AuraToast: View {
    let message: String
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AuraPalette.hotPink)

            Text(message)
                .font(.system(size: 13, weight: .bold))
                .lineLimit(3)

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .black))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .auraPanel()
    }
}

private enum AuraHaptics {
    static func impact() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
