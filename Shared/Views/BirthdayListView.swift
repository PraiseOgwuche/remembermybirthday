import SwiftUI
import SwiftData

struct BirthdayListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var notificationScheduler: NotificationScheduler
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var deepLinkRouter: MessageDeepLinkRouter
    @Query private var people: [BirthdayPerson]
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var contactPrompts = ContactBirthdayPromptCoordinator.shared

    @State private var path = NavigationPath()
    @State private var showingReminders = false
    @State private var showingSettings = false
    @State private var contactAddChooser: ContactPromptCandidate?

    private var sortedPeople: [BirthdayPerson] {
        people.sorted { $0.daysUntil < $1.daysUntil }
    }

    private var peopleByMonth: [(title: String, people: [BirthdayPerson])] {
        let calendar = Calendar.current
        var monthOrder: [Int] = []
        var seen = Set<Int>()
        for person in sortedPeople {
            let month = calendar.component(.month, from: person.nextBirthday)
            if seen.insert(month).inserted {
                monthOrder.append(month)
            }
        }
        let grouped = Dictionary(grouping: sortedPeople) {
            calendar.component(.month, from: $0.nextBirthday)
        }
        return monthOrder.compactMap { month in
            guard let list = grouped[month], !list.isEmpty else { return nil }
            let title = list[0].nextBirthday.formatted(.dateTime.month(.wide))
            return (title, list)
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if sortedPeople.isEmpty {
                    ContentUnavailableView {
                        Label("No Birthdays", systemImage: "gift")
                    } description: {
                        Text("Add someone you care about. We’ll remind you early enough to do something about it.")
                    } actions: {
                        Button("Add Birthday") {
                            path.append(BirthdayRoute.add)
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Add by voice") {
                            path.append(BirthdayRoute.voiceAdd)
                        }
                    }
                } else {
                    list
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RememberColors.pageBackground.ignoresSafeArea())
            .navigationTitle("RMB")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .automatic) {
                    Button {
                        showingReminders = true
                    } label: {
                        Image(systemName: notificationScheduler.isAuthorized ? "bell.fill" : "bell.slash")
                    }
                    .accessibilityLabel("Reminders")
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Add birthday", systemImage: "plus") {
                            path.append(BirthdayRoute.add)
                        }
                        Button("Add by voice", systemImage: "mic.fill") {
                            path.append(BirthdayRoute.voiceAdd)
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add")
                }
            }
            .navigationDestination(for: BirthdayRoute.self) { route in
                switch route {
                case .add:
                    AddEditBirthdayView(mode: .add)
                case .voiceAdd:
                    VoiceAddView()
                        .environmentObject(notificationScheduler)
                case .addFromContact(let contactId, let name, let phone):
                    AddEditBirthdayView(mode: .addFromContact(
                        contactIdentifier: contactId,
                        name: name,
                        phone: phone
                    ))
                case .voiceAddFromContact(let contactId, let name, let phone):
                    VoiceAddView(
                        prefillContact: ContactPromptCandidate(
                            contactIdentifier: contactId,
                            fullName: name,
                            phoneNumber: phone,
                            reason: .engagement
                        )
                    )
                    .environmentObject(notificationScheduler)
                case .detail(let id):
                    if let person = people.first(where: { $0.id == id }) {
                        PersonDetailView(person: person)
                    } else {
                        missingPerson
                    }
                case .edit(let id):
                    if let person = people.first(where: { $0.id == id }) {
                        AddEditBirthdayView(mode: .edit(person))
                    } else {
                        missingPerson
                    }
                case .message(let id):
                    if let person = people.first(where: { $0.id == id }) {
                        BirthdayMessageView(person: person)
                    } else {
                        missingPerson
                    }
                }
            }
            .sheet(isPresented: $showingReminders) {
                RemindersSettingsView()
                    .environmentObject(notificationScheduler)
                    .environmentObject(deepLinkRouter)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(notificationScheduler)
                    .environmentObject(authManager)
                    .environmentObject(deepLinkRouter)
            }
            .sheet(item: $contactAddChooser) { candidate in
                ContactAddMethodSheet(
                    candidate: candidate,
                    onVoice: {
                        contactAddChooser = nil
                        path.append(
                            BirthdayRoute.voiceAddFromContact(
                                contactIdentifier: candidate.contactIdentifier,
                                name: candidate.fullName,
                                phone: candidate.phoneNumber
                            )
                        )
                    },
                    onType: {
                        contactAddChooser = nil
                        path.append(
                            BirthdayRoute.addFromContact(
                                contactIdentifier: candidate.contactIdentifier,
                                name: candidate.fullName,
                                phone: candidate.phoneNumber
                            )
                        )
                    },
                    onCancel: {
                        contactPrompts.dismissPrompt(candidate)
                        contactAddChooser = nil
                    }
                )
            }
            .alert(
                contactPrompts.inAppPrompt.map { "Add \($0.firstName)’s birthday?" } ?? "Add birthday?",
                isPresented: Binding(
                    get: { contactPrompts.inAppPrompt != nil },
                    set: { if !$0 { contactPrompts.inAppPrompt = nil } }
                )
            ) {
                Button("Yes") {
                    if let candidate = contactPrompts.inAppPrompt {
                        contactPrompts.acceptPrompt(candidate)
                    }
                }
                Button("No", role: .cancel) {
                    if let candidate = contactPrompts.inAppPrompt {
                        contactPrompts.dismissPrompt(candidate)
                    }
                }
            } message: {
                if let candidate = contactPrompts.inAppPrompt {
                    Text(
                        candidate.reason == .newContact
                            ? "Looks like a new contact. Want to save their birthday in Remember and on their card?"
                            : "A quick one — add \(candidate.firstName)’s birthday so you don’t miss it later."
                    )
                }
            }
            .task {
                await BirthdayStoreCleanup.dedupeExisting(
                    in: modelContext,
                    notificationScheduler: notificationScheduler
                )
                let importer = BirthdayImporter()
                _ = await importer.backfillPhoneNumbers(for: people)
                try? modelContext.save()
                await notificationScheduler.refreshStatus()
                if notificationScheduler.isAuthorized {
                    await notificationScheduler.rescheduleAll(people)
                }
                await contactPrompts.evaluateOnAppActive(
                    people: people,
                    notificationsAuthorized: notificationScheduler.isAuthorized
                )
                handlePendingDeepLink()
                handlePendingContactAdd()
                WidgetSnapshotPublisher.publish(people: people)
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task {
                    await notificationScheduler.refreshStatus()
                    await contactPrompts.evaluateOnAppActive(
                        people: people,
                        notificationsAuthorized: notificationScheduler.isAuthorized
                    )
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: MessageDeepLinkRouter.openMessageNotification)) { _ in
                handlePendingDeepLink()
            }
            .onReceive(NotificationCenter.default.publisher(for: MessageDeepLinkRouter.openContactAddNotification)) { _ in
                handlePendingContactAdd()
            }
            .onChange(of: deepLinkRouter.pendingPersonId) { _, _ in
                handlePendingDeepLink()
            }
            .onChange(of: deepLinkRouter.pendingContactAdd?.contactIdentifier) { _, _ in
                handlePendingContactAdd()
            }
            .onChange(of: path.count) { _, count in
                if count == 0 {
                    Task { await notificationScheduler.refreshStatus() }
                }
            }
            .onChange(of: people.count) { _, _ in
                Task { await notificationScheduler.refreshStatus() }
                WidgetSnapshotPublisher.publish(people: people)
            }
            .onAppear {
                WidgetSnapshotPublisher.publish(people: people)
            }
            .onOpenURL { url in
                deepLinkRouter.handle(url: url)
                handlePendingDeepLink()
            }
        }
    }

    private var missingPerson: some View {
        Text("This birthday was removed.")
            .foregroundStyle(.secondary)
    }

    private var list: some View {
        List {
            if !notificationScheduler.isAuthorized {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Reminders are off")
                            .font(.headline)
                        Text("Enable notifications so Remember can nudge you before birthdays — not after you’ve already missed them.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Enable reminders") {
                            Task {
                                let granted = await notificationScheduler.requestAuthorizationIfNeeded()
                                if granted {
                                    await notificationScheduler.rescheduleAll(people)
                                } else if notificationScheduler.authorizationStatus == .denied {
                                    notificationScheduler.openSystemSettings()
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 2)
                    }
                    .padding(.vertical, 4)
                }
            } else if notificationScheduler.pendingCount > 0 {
                Section {
                    Label(
                        "\(notificationScheduler.pendingCount) reminders scheduled",
                        systemImage: "bell.badge"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }

            if let next = sortedPeople.first {
                Section {
                    Button {
                        path.append(BirthdayRoute.detail(next.id))
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(next.displayName)
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(nextHeadline(for: next))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("Up Next")
                }
            }

            ForEach(Array(peopleByMonth.enumerated()), id: \.element.title) { index, section in
                Section {
                    ForEach(section.people) { person in
                        Button {
                            path.append(BirthdayRoute.detail(person.id))
                        } label: {
                            BirthdayRowView(person: person)
                        }
                        .buttonStyle(.plain)
                        #if os(iOS)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                delete(person)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        #endif
                        .contextMenu {
                            Button {
                                path.append(BirthdayRoute.message(person.id))
                            } label: {
                                Label("Draft message", systemImage: "text.bubble")
                            }
                            Button(role: .destructive) {
                                delete(person)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text(section.title)
                } footer: {
                    if index == peopleByMonth.count - 1 {
                        Text("Grouped by month — birthdays repeat every year. Reminders: 2 weeks, 1 week, 3 days before, and the morning of.")
                    } else {
                        EmptyView()
                    }
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
    }

    private func nextHeadline(for person: BirthdayPerson) -> String {
        switch person.daysUntil {
        case 0:
            return "Birthday is today · \(person.shortDate)"
        case 1:
            return "Birthday is tomorrow · \(person.shortDate)"
        default:
            return "In \(person.daysUntil) days · \(person.shortDate)"
        }
    }

    private func delete(_ person: BirthdayPerson) {
        Task {
            await notificationScheduler.cancel(for: person)
            modelContext.delete(person)
        }
    }

    private func handlePendingDeepLink() {
        guard let (personId, preferMessage) = deepLinkRouter.consume() else { return }
        guard people.contains(where: { $0.id == personId }) else { return }

        showingReminders = false
        showingSettings = false

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            var next = NavigationPath()
            next.append(BirthdayRoute.detail(personId))
            if preferMessage {
                next.append(BirthdayRoute.message(personId))
            }
            path = next
        }
    }

    private func handlePendingContactAdd() {
        guard let candidate = deepLinkRouter.consumeContactAdd() else { return }
        showingReminders = false
        contactAddChooser = candidate
    }
}

struct BirthdayRowView: View {
    let person: BirthdayPerson

    var body: some View {
        HStack(spacing: 14) {
            Text(initials)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: 40, height: 40)
                .background(Color.accentColor.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(person.displayName)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Text(person.shortDate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(person.countdownLabel)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(person.daysUntil <= 7 ? Color.accentColor : Color.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var initials: String {
        BirthdayNameNormalizer.initials(from: person.displayName)
    }
}
