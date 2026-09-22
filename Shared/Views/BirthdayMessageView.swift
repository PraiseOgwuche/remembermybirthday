import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

struct BirthdayMessageView: View {
    let person: BirthdayPerson

    @EnvironmentObject private var notificationScheduler: NotificationScheduler
    @EnvironmentObject private var deepLinkRouter: MessageDeepLinkRouter
    @Environment(\.modelContext) private var modelContext

    @State private var tone: MessageTone = .warm
    @State private var draft = ""
    @State private var variant = 0
    @State private var didCopy = false
    @State private var showingMessageCompose = false
    @State private var showingSchedule = false
    @State private var scheduleDate = Date()
    @State private var scheduleStatus: String?
    @State private var phoneHelpMessage: String?

    private let buttonHeight: CGFloat = 54
    private let buttonCorner: CGFloat = 12

    private var draftIsEmpty: Bool {
        draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Tone")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                toneChips

                ZStack(alignment: .bottomTrailing) {
                    TextEditor(text: $draft)
                        .font(.body)
                        .frame(minHeight: 180)
                        .padding(12)
                        .padding(.bottom, 28)
                        .scrollContentBackground(.hidden)
                        .background(
                            RememberColors.cardBackground,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                        )

                    Button {
                        copyDraft()
                    } label: {
                        HStack(spacing: 6) {
                            if didCopy {
                                Text("Copied")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .transition(.opacity)
                            }
                            Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                                .font(.body.weight(.medium))
                                .foregroundStyle(didCopy ? Color.accentColor : Color.secondary)
                        }
                        .padding(10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(draftIsEmpty)
                    .accessibilityLabel(didCopy ? "Copied" : "Copy message")
                    .padding(6)
                }

                if person.hasScheduledSend, let when = person.scheduledSendAt {
                    Text("Scheduled for \(when.formatted(date: .abbreviated, time: .shortened))")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                if let scheduleStatus {
                    Text(scheduleStatus)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    #if os(iOS)
                    Button {
                        sendInMessages()
                    } label: {
                        primaryLabel("Send in Messages")
                    }
                    .buttonStyle(.plain)
                    .disabled(draftIsEmpty)

                    Text(sendHelpText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    #endif

                    Button {
                        prepareScheduleSheet()
                    } label: {
                        secondaryLabel(person.hasScheduledSend ? "Reschedule send" : "Schedule for birthday")
                    }
                    .buttonStyle(.plain)
                    .disabled(draftIsEmpty)

                    if person.hasScheduledSend {
                        Button("Cancel schedule") {
                            Task { await cancelSchedule() }
                        }
                        .font(.body.weight(.medium))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                    }

                    ShareLink(item: draft) {
                        secondaryLabel("Share")
                    }
                    .disabled(draftIsEmpty)

                    if let topGift = GiftIdeasProvider.ideas(for: person, limit: 1).first {
                        Text("Gift idea: \(topGift.title)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                    }

                    Button("New draft") {
                        regenerate()
                    }
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                }
            }
            .padding(20)
        }
        .background(RememberColors.pageBackground.ignoresSafeArea())
        .navigationTitle("Draft message")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingMessageCompose) {
            MessageComposeView(
                recipients: [person.sanitizedPhoneNumber],
                body: draft,
                onFinish: { showingMessageCompose = false }
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showingSchedule) {
            scheduleSheet
        }
        .alert(
            "Add a phone number",
            isPresented: Binding(
                get: { phoneHelpMessage != nil },
                set: { if !$0 { phoneHelpMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { phoneHelpMessage = nil }
        } message: {
            Text(phoneHelpMessage ?? "")
        }
        #endif
        .onAppear {
            if draft.isEmpty {
                let draftKey = "companion.enhance.draft.\(person.id.uuidString)"
                let legacyDraftKey = "companion.ai.draft.\(person.id.uuidString)"
                if let enhanceDraft = UserDefaults.standard.string(forKey: draftKey), !enhanceDraft.isEmpty {
                    draft = enhanceDraft
                } else if let legacyDraft = UserDefaults.standard.string(forKey: legacyDraftKey), !legacyDraft.isEmpty {
                    draft = legacyDraft
                    UserDefaults.standard.set(legacyDraft, forKey: draftKey)
                    UserDefaults.standard.removeObject(forKey: legacyDraftKey)
                } else if !person.savedDraft.isEmpty {
                    draft = person.savedDraft
                } else {
                    draft = BirthdayMessageComposer.draft(for: person, tone: tone, variant: variant)
                }
            }
            let action = deepLinkRouter.consumeWidgetAction()
            if action.send {
                #if os(iOS)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    sendInMessages()
                }
                #endif
            } else if action.schedule {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    prepareScheduleSheet()
                }
            }
        }
        .onChange(of: tone) { _, newTone in
            variant = 0
            draft = BirthdayMessageComposer.draft(for: person, tone: newTone, variant: 0)
            didCopy = false
        }
        .onChange(of: draft) { _, newValue in
            person.savedDraft = newValue
            person.updatedAt = Date()
        }
    }

    private var scheduleSheet: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        "Send reminder",
                        selection: $scheduleDate,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                } footer: {
                    Text("At this time you’ll get a notification with your draft. Tap Send to open Messages ready to go — Apple doesn’t allow apps to auto-send iMessage.")
                }

                #if DEBUG
                Section {
                    Button("Test in 5 seconds") {
                        Task { await scheduleTestSoon() }
                    }
                }
                #endif
            }
            .navigationTitle("Schedule")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingSchedule = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Schedule") {
                        Task { await confirmSchedule() }
                    }
                    .fontWeight(.semibold)
                    .disabled(draftIsEmpty)
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.medium])
        #endif
    }

    private var sendHelpText: String {
        if person.hasPhoneNumber {
            return "Opens Messages to \(person.firstName) with this text ready — you just tap Send."
        }
        return "No phone on file yet. Edit this person to add one, or reconnect Contacts so we can pull it."
    }

    private var toneChips: some View {
        HStack(spacing: 8) {
            ForEach(MessageTone.allCases) { option in
                Button {
                    tone = option
                } label: {
                    Text(option.title)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            option == tone ? Color.accentColor : RememberColors.cardBackground,
                            in: Capsule()
                        )
                        .foregroundStyle(option == tone ? Color.white : Color.primary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func primaryLabel(_ title: String) -> some View {
        Text(title)
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: buttonHeight)
            .background(
                Color.accentColor,
                in: RoundedRectangle(cornerRadius: buttonCorner, style: .continuous)
            )
    }

    private func secondaryLabel(_ title: String) -> some View {
        Text(title)
            .font(.body.weight(.semibold))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: buttonHeight)
            .background(
                RememberColors.cardBackground,
                in: RoundedRectangle(cornerRadius: buttonCorner, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: buttonCorner, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
            )
    }

    private func regenerate() {
        variant += 1
        draft = BirthdayMessageComposer.draft(for: person, tone: tone, variant: variant)
        didCopy = false
    }

    private func copyDraft() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
        withAnimation(.easeOut(duration: 0.15)) {
            didCopy = true
        }
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation(.easeOut(duration: 0.2)) {
                didCopy = false
            }
        }
    }

    private func prepareScheduleSheet() {
        if let existing = person.scheduledSendAt, existing > Date() {
            scheduleDate = existing
        } else {
            var components = Calendar.current.dateComponents([.year, .month, .day], from: person.nextBirthday)
            components.hour = 9
            components.minute = 0
            scheduleDate = Calendar.current.date(from: components) ?? person.nextBirthday
            if scheduleDate <= Date() {
                scheduleDate = Date().addingTimeInterval(60 * 5)
            }
        }
        showingSchedule = true
    }

    private func confirmSchedule() async {
        let ok = await notificationScheduler.scheduleSend(
            for: person,
            at: scheduleDate,
            draft: draft
        )
        try? modelContext.save()
        showingSchedule = false
        if ok {
            scheduleStatus = "Scheduled for \(scheduleDate.formatted(date: .abbreviated, time: .shortened))."
        } else {
            scheduleStatus = "Couldn’t schedule. Check notification permission and pick a future time."
        }
    }

    private func cancelSchedule() async {
        await notificationScheduler.clearScheduledSend(for: person)
        try? modelContext.save()
        scheduleStatus = "Schedule canceled."
    }

    private func scheduleTestSoon() async {
        await notificationScheduler.scheduleTestSend(for: person, draft: draft)
        showingSchedule = false
        scheduleStatus = "Test send notification in ~5 seconds."
    }

    #if os(iOS)
    private func sendInMessages() {
        guard !draftIsEmpty else { return }
        person.savedDraft = draft
        person.updatedAt = Date()
        try? modelContext.save()

        guard person.hasPhoneNumber else {
            phoneHelpMessage = "Add \(person.firstName)’s phone in Edit person. If they’re in Contacts with a number, we can pull it automatically."
            return
        }

        if MessageComposeView.canSendText {
            showingMessageCompose = true
        } else {
            MessageComposeView.openSMSURL(phone: person.sanitizedPhoneNumber, body: draft)
        }
    }
    #endif
}
