import SwiftUI
import SwiftData
import Contacts

struct VoiceAddView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var notificationScheduler: NotificationScheduler

    /// When set (from a contact prompt), name/phone are locked to that contact.
    var prefillContact: ContactPromptCandidate? = nil

    #if os(iOS)
    @StateObject private var capture = VoiceBirthdayCapture()
    #endif

    @State private var step: Step = .listen
    @State private var parse = SpokenBirthdayParse(rawTranscript: "")
    @State private var candidates: [ContactMatchCandidate] = []
    @State private var selectedCandidate: ContactMatchCandidate?
    @State private var updateContactBirthday = true
    @State private var statusMessage: String?
    @State private var manualName = ""
    @State private var manualDate = Date()
    @State private var didApplyPrefill = false

    enum Step {
        case listen
        case confirm
        case done
    }

    var body: some View {
        Group {
            switch step {
            case .listen:
                listenStep
            case .confirm:
                confirmStep
            case .done:
                doneStep
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RememberColors.pageBackground.ignoresSafeArea())
        .navigationTitle("Add by voice")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    #if os(iOS)
                    capture.stop()
                    #endif
                    dismiss()
                }
            }
        }
        #if os(iOS)
        .task {
            applyPrefillIfNeeded()
            _ = await capture.requestPermissions()
            _ = await requestContactsIfNeeded()
        }
        .onDisappear {
            capture.discard()
        }
        #else
        .onAppear {
            applyPrefillIfNeeded()
        }
        #endif
    }

    private func applyPrefillIfNeeded() {
        guard !didApplyPrefill, let prefill = prefillContact else { return }
        didApplyPrefill = true
        manualName = prefill.fullName
        selectedCandidate = ContactMatchCandidate(
            id: prefill.contactIdentifier,
            fullName: prefill.fullName,
            phoneNumber: prefill.phoneNumber,
            existingBirthday: nil,
            contactIdentifier: prefill.contactIdentifier
        )
        candidates = [selectedCandidate!]
        updateContactBirthday = true
    }

    private var listenStep: some View {
        VStack(spacing: 24) {
            Text(
                prefillContact.map { "Say \($0.firstName)’s birthday — like “March 14” or “August 20.”" }
                    ?? "Say something like “Alex, March 14” or “Sandra’s birthday is August 20.”"
            )
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            #if os(iOS)
            Text(capture.transcript.isEmpty ? (capture.isRecording ? "Listening…" : "Tap Start, then say a name and birthday.") : capture.transcript)
                .font(.title3.weight(.medium))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 80)
                .padding(16)
                .background(RememberColors.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 24)

            if let errorMessage = capture.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 24)
            }

            Button {
                toggleRecording()
            } label: {
                Text(capture.isRecording ? "Stop" : (capture.transcript.isEmpty ? "Start listening" : "Listen again"))
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 24)
            .disabled(!capture.isAuthorized && capture.errorMessage != nil)

            if !capture.transcript.isEmpty, !capture.isRecording {
                Text("Looks good? Tap Continue — or Listen again to retry.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Button("Continue") {
                Task { await processTranscript(capture.transcript) }
            }
            .font(.body.weight(.semibold))
            .disabled(capture.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            #else
            Text("Voice add is available on iPhone.")
                .foregroundStyle(.secondary)
            #endif

            Spacer()
        }
        .padding(.top, 24)
    }

    private var confirmStep: some View {
        Form {
            Section("Heard") {
                if prefillContact != nil {
                    LabeledContent("Name", value: manualName)
                } else if let name = parse.name {
                    LabeledContent("Name", value: name)
                } else {
                    TextField("Name", text: $manualName)
                }
                if let month = parse.month, let day = parse.day {
                    LabeledContent("Birthday") {
                        Text(formatted(month: month, day: day, year: parse.year))
                    }
                } else {
                    DatePicker("Birthday", selection: $manualDate, displayedComponents: [.date])
                }
                Text("“\(parse.rawTranscript)”")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if prefillContact != nil {
                Section {
                    Toggle("Also update Contacts birthday", isOn: $updateContactBirthday)
                } footer: {
                    Text("Keeps \(BirthdayNameNormalizer.firstName(from: manualName))’s contact card in sync.")
                }
            } else if !candidates.isEmpty {
                Section {
                    ForEach(candidates) { candidate in
                        Button {
                            selectedCandidate = candidate
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(candidate.fullName)
                                        .foregroundStyle(.primary)
                                    if !candidate.phoneNumber.isEmpty {
                                        Text(candidate.phoneNumber)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if selectedCandidate == candidate {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                    Button("None of these — add as new") {
                        selectedCandidate = nil
                    }
                } header: {
                    Text("Is this them?")
                } footer: {
                    Text("If you confirm a contact, we can save the birthday on their contact card too.")
                }

                if selectedCandidate != nil {
                    Section {
                        Toggle("Also update Contacts birthday", isOn: $updateContactBirthday)
                    }
                }
            } else {
                Section {
                    Text("No close Contacts match. We’ll add them as new in Remember My Birthday.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let statusMessage {
                Section {
                    Text(statusMessage)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button("Save") {
                    save()
                }
                .fontWeight(.semibold)
            }
        }
    }

    private var doneStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)
            Text("Saved")
                .font(.title2.weight(.bold))
            Text(statusMessage ?? "They’re in Remember My Birthday now.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            Spacer()
        }
        .padding(.top, 48)
    }

    #if os(iOS)
    private func toggleRecording() {
        if capture.isRecording {
            capture.stop()
        } else {
            do {
                try capture.start()
            } catch {
                capture.errorMessage = error.localizedDescription
            }
        }
    }
    #endif

    private func processTranscript(_ text: String) async {
        #if os(iOS)
        capture.stop()
        #endif
        parse = BirthdaySpeechParser.parse(text)
        if let prefill = prefillContact {
            manualName = prefill.fullName
            selectedCandidate = ContactMatchCandidate(
                id: prefill.contactIdentifier,
                fullName: prefill.fullName,
                phoneNumber: prefill.phoneNumber,
                existingBirthday: nil,
                contactIdentifier: prefill.contactIdentifier
            )
            candidates = [selectedCandidate!]
        } else {
            manualName = parse.name ?? ""
            if let name = parse.name, !name.isEmpty {
                let matches = await Task.detached(priority: .userInitiated) {
                    ContactBirthdayMatcher.findMatches(for: name)
                }.value
                candidates = matches
                selectedCandidate = matches.first
            } else {
                candidates = []
                selectedCandidate = nil
            }
        }
        if let month = parse.month, let day = parse.day {
            var comps = DateComponents()
            comps.month = month
            comps.day = day
            comps.year = parse.year ?? Calendar.current.component(.year, from: Date())
            manualDate = Calendar.current.date(from: comps) ?? Date()
        }
        step = .confirm
    }

    private func save() {
        statusMessage = nil
        let name: String
        if let prefill = prefillContact {
            name = prefill.fullName
        } else if let parsed = parse.name, !parsed.isEmpty {
            name = selectedCandidate?.fullName ?? parsed
        } else {
            name = manualName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !name.isEmpty else {
            statusMessage = "Add a name to continue."
            return
        }

        let month: Int
        let day: Int
        let year: Int?
        if let m = parse.month, let d = parse.day {
            month = m
            day = d
            year = parse.year
        } else {
            let cal = Calendar.current
            month = cal.component(.month, from: manualDate)
            day = cal.component(.day, from: manualDate)
            year = nil
        }

        let phone = selectedCandidate?.phoneNumber ?? prefillContact?.phoneNumber ?? ""
        let contactId = selectedCandidate?.contactIdentifier ?? prefillContact?.contactIdentifier ?? ""
        let person = BirthdayPerson(
            name: name,
            birthMonth: month,
            birthDay: day,
            birthYear: year,
            phoneNumber: phone,
            contactIdentifier: contactId
        )
        modelContext.insert(person)
        try? modelContext.save()

        let writeId = selectedCandidate?.contactIdentifier ?? prefillContact?.contactIdentifier
        if updateContactBirthday, let writeId, !writeId.isEmpty {
            do {
                try ContactBirthdayMatcher.writeBirthday(
                    contactIdentifier: writeId,
                    month: month,
                    day: day,
                    year: year
                )
            } catch {
                statusMessage = "Saved in Remember My Birthday, but couldn’t update Contacts: \(error.localizedDescription)"
            }
        }

        if statusMessage == nil {
            statusMessage = phone.isEmpty
                ? "\(BirthdayNameNormalizer.firstName(from: name)) was added."
                : "\(BirthdayNameNormalizer.firstName(from: name)) was added with their number."
        }
        step = .done

        Task {
            await notificationScheduler.reschedule(for: person)
        }
    }

    private func formatted(month: Int, day: Int, year: Int?) -> String {
        var comps = DateComponents()
        comps.month = month
        comps.day = day
        comps.year = year ?? 2000
        let date = Calendar.current.date(from: comps) ?? Date()
        if year != nil {
            return date.formatted(.dateTime.month().day().year())
        }
        return date.formatted(.dateTime.month().day())
    }

    private func requestContactsIfNeeded() async -> Bool {
        let store = CNContactStore()
        let status = CNContactStore.authorizationStatus(for: .contacts)
        #if os(iOS)
        if #available(iOS 18.0, *) {
            if status == .authorized || status == .limited { return true }
        } else if status == .authorized {
            return true
        }
        #else
        if status == .authorized { return true }
        #endif
        do {
            return try await store.requestAccess(for: .contacts)
        } catch {
            return false
        }
    }
}
