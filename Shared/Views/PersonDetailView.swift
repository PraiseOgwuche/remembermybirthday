import SwiftUI

struct PersonDetailView: View {
    let person: BirthdayPerson

    @State private var giftIdeas: [GiftIdea] = []
    @State private var plan: CompanionPlan
    @State private var isEnhancing = false
    @State private var enhanceError: String?
    @State private var aiDraft: String?
    @State private var aiGiftTitles: [String] = []

    init(person: BirthdayPerson) {
        self.person = person
        _plan = State(initialValue: CompanionEngine.plan(for: person))
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(person.displayName)
                        .font(.title.weight(.bold))
                    Text(countdownLine)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
                .accessibilityElement(children: .combine)
            }

            companionSection

            Section("Details") {
                LabeledContent("Birthday") {
                    Text(person.formattedDate)
                }
                if person.hasPhoneNumber {
                    LabeledContent("Phone") {
                        Text(person.phoneNumber)
                    }
                }
                if !person.relationship.isEmpty {
                    LabeledContent("Relationship") {
                        Text(person.relationship)
                    }
                }
                if !person.nickname.isEmpty {
                    LabeledContent("Nickname") {
                        Text(person.nickname)
                    }
                }
                if !person.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notes")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(person.notes)
                            .font(.body)
                    }
                    .padding(.vertical, 2)
                }
            }

            if !displayGifts.isEmpty {
                Section {
                    ForEach(displayGifts, id: \.self) { title in
                        if let idea = giftIdeas.first(where: { $0.title == title }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(idea.title)
                                    .font(.body.weight(.semibold))
                                Text(idea.detail)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        } else {
                            Text(title)
                                .font(.body.weight(.semibold))
                                .padding(.vertical, 2)
                        }
                    }
                    Button("Shuffle ideas") {
                        aiGiftTitles = []
                        giftIdeas = GiftIdeasProvider.ideas(for: person, limit: 5)
                    }
                    .font(.subheadline.weight(.medium))
                } header: {
                    Text("Gift ideas")
                } footer: {
                    Text(aiGiftTitles.isEmpty
                         ? "On-device ideas from relationship and notes. Add tastes in Notes for better picks."
                         : "Includes an enhanced pass (cached so it won’t re-run soon).")
                }
            }

            Section {
                NavigationLink(value: BirthdayRoute.message(person.id)) {
                    Label(aiDraft == nil ? "Draft birthday message" : "Open draft (enhanced)", systemImage: "text.bubble")
                        .font(.body.weight(.semibold))
                }
                NavigationLink(value: BirthdayRoute.edit(person.id)) {
                    Label("Edit person", systemImage: "pencil")
                }
            } footer: {
                if person.hasScheduledSend, let when = person.scheduledSendAt {
                    Text("Send scheduled for \(when.formatted(date: .abbreviated, time: .shortened)). You’ll get a notification with Send / Review.")
                } else if person.hasPhoneNumber {
                    Text("Draft a message, then Send in Messages — or Schedule for birthday morning.")
                } else {
                    Text("Add a phone number to enable Send in Messages for \(person.firstName).")
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
        .navigationTitle(person.displayName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            plan = CompanionEngine.plan(for: person)
            if giftIdeas.isEmpty {
                giftIdeas = GiftIdeasProvider.ideas(for: person, limit: 5)
            }
            if let cached = CompanionAICache.load(personId: person.id) {
                applyEnhanceResult(cached)
            }
        }
    }

    private var companionSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Label(plan.primaryTitle, systemImage: plan.systemImage)
                    .font(.body.weight(.semibold))
                Text(plan.reason)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(plan.whenLabel)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                primaryActionControl

                if AppSettingsStore.aiEnabled && AppSettingsStore.aiProvider != .off {
                    Button {
                        Task { await enhanceTip() }
                    } label: {
                        if isEnhancing {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Label(
                                plan.source == .local ? "Enhance tip" : "Refresh tip",
                                systemImage: "lightbulb"
                            )
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isEnhancing)
                }

                if let enhanceError {
                    Text(enhanceError)
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }

                Text(sourceCaption)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        } header: {
            Text("Companion")
        } footer: {
            Text("Local tip is always free. Enhance only runs when you tap — results cache for 2 weeks.")
        }
    }

    @ViewBuilder
    private var primaryActionControl: some View {
        switch plan.action {
        case .call:
            Button {
                CompanionActions.openCall(phoneDigits: person.sanitizedPhoneNumber)
            } label: {
                Text(plan.primaryTitle)
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!person.hasPhoneNumber)
        case .message, .giftAndMessage:
            NavigationLink(value: BirthdayRoute.message(person.id)) {
                Text(plan.primaryTitle)
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private var displayGifts: [String] {
        if !aiGiftTitles.isEmpty { return aiGiftTitles }
        return giftIdeas.map(\.title)
    }

    private var sourceCaption: String {
        switch plan.source {
        case .local: return "Source: on-device"
        case .apple: return "Source: on-device enhance"
        case .anthropic: return "Source: companion server (cached)"
        }
    }

    private var countdownLine: String {
        switch person.daysUntil {
        case 0:
            return "Birthday is today · \(person.shortDate)"
        case 1:
            return "Birthday is tomorrow · \(person.shortDate)"
        default:
            return "In \(person.daysUntil) days · \(person.shortDate)"
        }
    }

    @MainActor
    private func enhanceTip() async {
        enhanceError = nil
        isEnhancing = true
        defer { isEnhancing = false }
        do {
            if plan.source != .local {
                CompanionAICache.clear(personId: person.id)
            }
            let result = try await CompanionAIService.enhance(for: person, local: CompanionEngine.plan(for: person))
            applyEnhanceResult(result)
        } catch {
            enhanceError = error.localizedDescription
        }
    }

    private func applyEnhanceResult(_ result: CompanionAIResult) {
        plan = result.plan
        aiDraft = result.draftSuggestion
        aiGiftTitles = result.giftTitles
        if let draft = result.draftSuggestion, !draft.isEmpty {
            UserDefaults.standard.set(draft, forKey: "companion.enhance.draft.\(person.id.uuidString)")
        }
    }
}
