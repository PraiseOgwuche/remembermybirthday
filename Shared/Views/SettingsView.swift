import SwiftUI
import SwiftData

struct SettingsView: View {
    @EnvironmentObject private var notificationScheduler: NotificationScheduler
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var deepLinkRouter: MessageDeepLinkRouter
    @Query private var people: [BirthdayPerson]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var reminderHour = AppSettingsStore.reminderHour
    @State private var inactivityDays = AppSettingsStore.promptInactivityDays
    @State private var cooldownDays = AppSettingsStore.promptCooldownDays
    @State private var nudgeDelayDays = AppSettingsStore.promptNudgeDelayDays
    @State private var softEngage = AppSettingsStore.softEngageEnabled
    @State private var iCloudSync = AppSettingsStore.iCloudSyncEnabled
    @State private var importStatus: String?
    @State private var isImporting = false

    private var nextPerson: BirthdayPerson? {
        people.sorted { $0.daysUntil < $1.daysUntil }.first
    }

    var body: some View {
        NavigationStack {
            List {
                remindersSection
                promptsSection
                dataSection
                accountSection
                #if DEBUG
                debugSection
                #endif
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #endif
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await notificationScheduler.refreshStatus()
                notificationScheduler.reminderHour = AppSettingsStore.reminderHour
                applyPromptSettings()
            }
            .onReceive(NotificationCenter.default.publisher(for: MessageDeepLinkRouter.openMessageNotification)) { _ in
                dismiss()
            }
        }
    }

    private var remindersSection: some View {
        Section {
            LabeledContent("Status") {
                Text(statusLabel)
                    .foregroundStyle(notificationScheduler.isAuthorized ? Color.primary : Color.orange)
            }
            LabeledContent("Scheduled") {
                Text("\(notificationScheduler.pendingCount)")
            }

            Picker("Delivery time", selection: $reminderHour) {
                ForEach(6..<22, id: \.self) { hour in
                    Text(hourLabel(hour)).tag(hour)
                }
            }
            .onChange(of: reminderHour) { _, hour in
                AppSettingsStore.reminderHour = hour
                notificationScheduler.reminderHour = hour
                Task { await reschedule() }
            }

            if !notificationScheduler.isAuthorized {
                Button("Enable notifications") {
                    Task {
                        _ = await notificationScheduler.requestAuthorizationIfNeeded()
                        await reschedule()
                    }
                }
                if notificationScheduler.authorizationStatus == .denied {
                    Button("Open system Settings") {
                        notificationScheduler.openSystemSettings()
                    }
                }
            } else {
                Button("Refresh all reminders") {
                    Task { await reschedule() }
                }
                if let nextPerson {
                    Button("Send test alert for \(nextPerson.displayName)") {
                        Task { @MainActor in
                            await notificationScheduler.scheduleTestReminder(for: nextPerson)
                        }
                    }
                }
            }
        } header: {
            Text("Reminders")
        } footer: {
            Text("Reminders fire 2 weeks, 1 week, 3 days before, and the morning of each birthday.")
        }
    }

    private var promptsSection: some View {
        Section {
            Stepper("Ask after \(inactivityDays) days away", value: $inactivityDays, in: 2...30)
                .onChange(of: inactivityDays) { _, value in
                    AppSettingsStore.promptInactivityDays = value
                    applyPromptSettings()
                }
            Stepper("At most every \(cooldownDays) days", value: $cooldownDays, in: 1...30)
                .onChange(of: cooldownDays) { _, value in
                    AppSettingsStore.promptCooldownDays = value
                    applyPromptSettings()
                }
            Stepper("Come-back nudge in \(nudgeDelayDays) days", value: $nudgeDelayDays, in: 3...30)
                .onChange(of: nudgeDelayDays) { _, value in
                    AppSettingsStore.promptNudgeDelayDays = value
                    applyPromptSettings()
                }
            Toggle("Occasional in-app nudges", isOn: $softEngage)
                .onChange(of: softEngage) { _, value in
                    AppSettingsStore.softEngageEnabled = value
                    applyPromptSettings()
                }
        } header: {
            Text("Birthday prompts")
        } footer: {
            Text("When Contacts are missing birthdays, Remember My Birthday can ask — gently — so the list stays useful.")
        }
    }

    private var dataSection: some View {
        Section {
            Button {
                Task { await reimport() }
            } label: {
                if isImporting {
                    HStack {
                        ProgressView()
                        Text("Importing…")
                    }
                } else {
                    Text("Re-import from Contacts & Calendar")
                }
            }
            .disabled(isImporting)

            if let importStatus {
                Text(importStatus)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Toggle("iCloud sync", isOn: $iCloudSync)
                .onChange(of: iCloudSync) { _, value in
                    AppSettingsStore.iCloudSyncEnabled = value
                }
                .disabled(!AppSettingsStore.hasICloudAccount && !iCloudSync)
        } header: {
            Text("Data")
        } footer: {
            Text(iCloudFooter)
        }
    }

    private var accountSection: some View {
        Section("Account") {
            if let name = authManager.userName {
                LabeledContent("Signed in as", value: name)
            } else {
                LabeledContent("Account", value: "On this device")
            }
            Button("Sign out", role: .destructive) {
                authManager.signOut()
                dismiss()
            }
        }
    }

    #if DEBUG
    private var debugSection: some View {
        Section {
            Button("Reset setup (DEBUG)", role: .destructive) {
                authManager.resetForFreshLaunch()
                dismiss()
            }
        } footer: {
            Text("Clears sign-in and onboarding flags so you can retest the first-run flow. Birthdays stay on device.")
        }
    }
    #endif

    private var statusLabel: String {
        switch notificationScheduler.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return "On"
        case .denied:
            return "Off — enable in Settings"
        case .notDetermined:
            return "Not enabled yet"
        @unknown default:
            return "Unknown"
        }
    }

    private var iCloudFooter: String {
        if !AppSettingsStore.hasICloudAccount {
            return "Sign in to iCloud on this device to sync birthdays across iPhone, iPad, and Mac. Turn on, then fully quit and reopen Remember My Birthday."
        }
        if iCloudSync {
            return "Sync is on. Quit and reopen Remember My Birthday once so the CloudKit store can start. Watch still uses the shared App Group when available."
        }
        return "Keeps birthdays on this device only. Turn on to sync via your iCloud account (restart required)."
    }

    private func hourLabel(_ hour: Int) -> String {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = 0
        let date = Calendar.current.date(from: comps) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    private func applyPromptSettings() {
        let coordinator = ContactBirthdayPromptCoordinator.shared
        coordinator.inactivityDays = AppSettingsStore.promptInactivityDays
        coordinator.minDaysBetweenPrompts = AppSettingsStore.promptCooldownDays
        coordinator.inactivityNudgeDelayDays = AppSettingsStore.promptNudgeDelayDays
        coordinator.softEngageEnabled = AppSettingsStore.softEngageEnabled
    }

    private func reschedule() async {
        await notificationScheduler.rescheduleAll(people)
        await notificationScheduler.refreshStatus()
    }

    private func reimport() async {
        isImporting = true
        importStatus = nil
        let importer = BirthdayImporter()
        let imported = await importer.connectAndImport()
        var added = 0
        for item in imported {
            let cleaned = BirthdayNameNormalizer.cleanDisplayName(item.name)
            let key = BirthdayNameNormalizer.matchKey(name: cleaned, month: item.birthMonth, day: item.birthDay)
            let exists = people.contains {
                BirthdayNameNormalizer.matchKey(name: $0.name, month: $0.birthMonth, day: $0.birthDay) == key
            }
            if exists { continue }
            let person = BirthdayPerson(
                name: cleaned,
                birthMonth: item.birthMonth,
                birthDay: item.birthDay,
                birthYear: item.birthYear,
                phoneNumber: item.phoneNumber
            )
            modelContext.insert(person)
            await notificationScheduler.reschedule(for: person)
            added += 1
        }
        let phones = await importer.backfillPhoneNumbers(for: people)
        try? modelContext.save()
        isImporting = false
        if let message = importer.statusMessage, added == 0 {
            importStatus = message
        } else {
            importStatus = "Added \(added) new · updated \(phones) phone numbers."
        }
    }
}
