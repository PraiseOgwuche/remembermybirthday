import SwiftUI
import SwiftData

struct OnboardingFlowView: View {
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var notificationScheduler: NotificationScheduler
    @Environment(\.modelContext) private var modelContext
    @StateObject private var importer = BirthdayImporter()

    @State private var step: Step = .connect
    @State private var isImporting = false
    @State private var imported: [ImportedBirthday] = []
    @State private var draftName = ""
    @State private var draftDate = Date()
    @State private var manualAdded = 0

    private let manualTarget = 3

    enum Step: Int {
        case connect = 0
        case results = 1
        case manual = 2
        case notifications = 3
        case widget = 4
    }

    @State private var preferredWidgetSize = AppSettingsStore.preferredWidgetSize
    @State private var showingWidgetHowTo = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                stepIndicator
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                Group {
                    switch step {
                    case .connect:
                        connectStep
                    case .results:
                        resultsStep
                    case .manual:
                        manualStep
                    case .notifications:
                        notificationsStep
                    case .widget:
                        widgetStep
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RememberColors.pageBackground.ignoresSafeArea())
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .sheet(isPresented: $showingWidgetHowTo) {
                widgetHowToSheet
            }
        }
    }

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<5, id: \.self) { index in
                stepDot(
                    active: step.rawValue == index,
                    done: step.rawValue > index
                )
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Setup progress")
    }

    private func stepDot(active: Bool, done: Bool) -> some View {
        Capsule()
            .fill(active || done ? Color.accentColor : Color.secondary.opacity(0.25))
            .frame(width: active ? 28 : 10, height: 6)
            .animation(.easeInOut(duration: 0.2), value: step)
    }

    // MARK: - Connect

    private var connectStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header(
                        title: "Connect your birthdays",
                        subtitle: "Remember My Birthday can pull birthdays already saved in Contacts and your Birthday calendar — so you don’t start from scratch."
                    )

                    VStack(spacing: 12) {
                        sourceRow(
                            icon: "person.crop.circle",
                            title: "Contacts",
                            detail: "People with a birthday on their contact card"
                        )
                        sourceRow(
                            icon: "calendar",
                            title: "Birthday calendar",
                            detail: "Birthdays that already appear in Calendar"
                        )
                    }

                    Text("We’ll ask for permission next. You can skip and add people manually.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(24)
            }

            bottomBar {
                Button {
                    Task { await runImport() }
                } label: {
                    labelButton(isImporting ? "Connecting…" : "Continue")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isImporting)

                Button("Add manually instead") {
                    step = .manual
                }
                .font(.body.weight(.medium))
                .padding(.top, 4)
            }
        }
        .navigationTitle("Set up")
    }

    // MARK: - Results

    private var resultsStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header(
                        title: imported.isEmpty ? "No birthdays found" : "Found \(imported.count) birthdays",
                        subtitle: imported.isEmpty
                            ? "That’s common — many people never fill birthdays into Contacts. Add a few important ones next."
                            : "These will be saved to Remember My Birthday with reminders. You can edit or remove anyone later."
                    )

                    if !imported.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(imported.prefix(12)) { item in
                                HStack {
                                    Text(item.name)
                                        .font(.body.weight(.medium))
                                    Spacer()
                                    Text(monthDay(item))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 12)
                                if item.id != imported.prefix(12).last?.id {
                                    Divider()
                                }
                            }
                            if imported.count > 12 {
                                Text("+\(imported.count - 12) more")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 12)
                            }
                        }
                        .padding(16)
                        .background(RememberColors.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    if let message = importer.statusMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(24)
            }

            bottomBar {
                Button {
                    saveImported()
                    if imported.isEmpty {
                        step = .manual
                    } else {
                        step = .notifications
                    }
                } label: {
                    labelButton(imported.isEmpty ? "Add people manually" : "Save & continue")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                if !imported.isEmpty {
                    Button("Add more people") {
                        saveImported()
                        step = .manual
                    }
                    .font(.body.weight(.medium))
                    .padding(.top, 4)
                }
            }
        }
        .navigationTitle("Import")
    }

    // MARK: - Manual

    private var manualStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header(
                        title: "Who must you never forget?",
                        subtitle: "Add up to \(manualTarget) people now. You can always add more later."
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        ProgressView(value: Double(manualAdded), total: Double(manualTarget))
                        Text("\(manualAdded) of \(manualTarget) added")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RememberColors.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 14) {
                        TextField("Name", text: $draftName)
                            .textContentType(.name)
                            .padding(14)
                            .background(RememberColors.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                        DatePicker("Birthday", selection: $draftDate, displayedComponents: [.date])
                            .datePickerStyle(.compact)
                            .padding(14)
                            .background(RememberColors.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                        Button {
                            addManual()
                        } label: {
                            labelButton("Save person")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSaveManual)
                    }
                }
                .padding(24)
            }

            bottomBar {
                Button {
                    step = .notifications
                } label: {
                    labelButton(manualAdded == 0 ? "Skip for now" : "Continue")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .navigationTitle("Add people")
    }

    // MARK: - Notifications

    private var notificationsStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header(
                        title: "Turn on reminders",
                        subtitle: "This is the whole point. We’ll nudge you 2 weeks, 1 week, 3 days before — and the morning of — with something useful to do."
                    )

                    VStack(spacing: 12) {
                        sourceRow(
                            icon: "bell.badge.fill",
                            title: "Actionable alerts",
                            detail: "Not just a date — prompts to draft a message or plan a gift"
                        )
                        sourceRow(
                            icon: "clock.fill",
                            title: "Morning delivery",
                            detail: "Reminders arrive at 9:00 AM local time by default"
                        )
                    }

                    Text("You can change notification settings anytime in iOS Settings.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(24)
            }

            bottomBar {
                Button {
                    Task { await enableRemindersThenWidget() }
                } label: {
                    labelButton("Enable reminders")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Not now") {
                    #if os(iOS)
                    step = .widget
                    #else
                    finishOnboarding()
                    #endif
                }
                .font(.body.weight(.medium))
                .padding(.top, 4)
            }
        }
        .navigationTitle("Reminders")
    }

    // MARK: - Widget

    private var widgetStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header(
                        title: "Add Remember My Birthday to Home Screen",
                        subtitle: "Apple won’t let apps add a widget for you — but once it’s there, the next birthday, draft, and Send are one tap away."
                    )

                    Picker("Size", selection: $preferredWidgetSize) {
                        ForEach(AppSettingsStore.PreferredWidgetSize.allCases) { size in
                            Text(size.title).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: preferredWidgetSize) { _, size in
                        AppSettingsStore.preferredWidgetSize = size
                    }

                    Text(preferredWidgetSize.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    HStack {
                        Spacer(minLength: 0)
                        WidgetSetupPreview(size: preferredWidgetSize)
                            .animation(.easeInOut(duration: 0.2), value: preferredWidgetSize)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 8)

                    VStack(alignment: .leading, spacing: 10) {
                        howToRow(number: "1", text: "Long-press an empty spot on your Home Screen")
                        howToRow(number: "2", text: "Tap Edit → Add Widget")
                        howToRow(number: "3", text: "Search “Remember My Birthday” and choose \(preferredWidgetSize.title)")
                    }
                }
                .padding(24)
            }

            bottomBar {
                Button {
                    AppSettingsStore.preferredWidgetSize = preferredWidgetSize
                    AppSettingsStore.sawWidgetOnboarding = true
                    showingWidgetHowTo = true
                } label: {
                    labelButton("Show me how")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("I’ll do this later") {
                    finishOnboarding()
                }
                .font(.body.weight(.medium))
                .padding(.top, 4)
            }
        }
        .navigationTitle("Widget")
    }

    private var widgetHowToSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Add the \(preferredWidgetSize.title.lowercased()) widget")
                        .font(.title2.weight(.bold))

                    Text("Keep Remember My Birthday open in App Switcher if you want, then:")
                        .foregroundStyle(.secondary)

                    howToRow(number: "1", text: "Go to your Home Screen and long-press a blank area until the icons jiggle")
                    howToRow(number: "2", text: "Tap Edit (top left) → Add Widget")
                    howToRow(number: "3", text: "Search for Remember My Birthday")
                    howToRow(number: "4", text: "Swipe to \(preferredWidgetSize.title), then tap Add Widget")

                    Text("You’ll see the next birthday, a draft message, and Send / Schedule right on the Home Screen.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .padding(24)
            }
            .background(RememberColors.pageBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingWidgetHowTo = false
                        finishOnboarding()
                    }
                    .fontWeight(.semibold)
                }
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #endif
    }

    private func howToRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Color.accentColor, in: Circle())
            Text(text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RememberColors.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Shared chrome

    private func header(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title.weight(.bold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sourceRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(RememberColors.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func bottomBar<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 10) {
            content()
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity)
        .background {
            RememberColors.pageBackground
                .shadow(color: .black.opacity(0.06), radius: 8, y: -2)
        }
    }

    private func labelButton(_ title: String) -> some View {
        Text(title)
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
    }

    private func monthDay(_ item: ImportedBirthday) -> String {
        var components = DateComponents()
        components.month = item.birthMonth
        components.day = item.birthDay
        let date = Calendar.current.date(from: components) ?? Date()
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    // MARK: - Actions

    private func runImport() async {
        isImporting = true
        imported = await importer.connectAndImport()
        isImporting = false
        step = .results
    }

    private func saveImported() {
        for item in imported {
            let cleaned = BirthdayNameNormalizer.cleanDisplayName(item.name)
            if alreadyExists(name: cleaned, month: item.birthMonth, day: item.birthDay) {
                continue
            }
            let person = BirthdayPerson(
                name: cleaned,
                birthMonth: item.birthMonth,
                birthDay: item.birthDay,
                birthYear: item.birthYear,
                phoneNumber: item.phoneNumber
            )
            modelContext.insert(person)
            Task { await notificationScheduler.reschedule(for: person) }
        }
    }

    private func alreadyExists(name: String, month: Int, day: Int) -> Bool {
        let descriptor = FetchDescriptor<BirthdayPerson>()
        guard let existing = try? modelContext.fetch(descriptor) else { return false }
        let key = BirthdayNameNormalizer.matchKey(name: name, month: month, day: day)
        return existing.contains {
            BirthdayNameNormalizer.matchKey(name: $0.name, month: $0.birthMonth, day: $0.birthDay) == key
        }
    }

    private var canSaveManual: Bool {
        !draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && manualAdded < manualTarget
    }

    private func addManual() {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let calendar = Calendar.current
        let person = BirthdayPerson(
            name: trimmed,
            birthMonth: calendar.component(.month, from: draftDate),
            birthDay: calendar.component(.day, from: draftDate)
        )
        modelContext.insert(person)
        manualAdded += 1
        draftName = ""
        Task { await notificationScheduler.reschedule(for: person) }
    }

    private func enableRemindersThenWidget() async {
        let granted = await notificationScheduler.requestAuthorizationIfNeeded()
        if granted {
            let descriptor = FetchDescriptor<BirthdayPerson>()
            if let people = try? modelContext.fetch(descriptor) {
                await notificationScheduler.rescheduleAll(people)
                WidgetSnapshotPublisher.publish(people: people)
            }
        }
        #if os(iOS)
        step = .widget
        #else
        finishOnboarding()
        #endif
    }

    private func finishOnboarding() {
        AppSettingsStore.sawWidgetOnboarding = true
        AppSettingsStore.preferredWidgetSize = preferredWidgetSize
        let descriptor = FetchDescriptor<BirthdayPerson>()
        if let people = try? modelContext.fetch(descriptor) {
            WidgetSnapshotPublisher.publish(people: people)
        }
        authManager.completeOnboarding()
    }
}
