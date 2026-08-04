import SwiftUI
import SwiftData

struct RemindersSettingsView: View {
    @EnvironmentObject private var notificationScheduler: NotificationScheduler
    @Query private var people: [BirthdayPerson]
    @Environment(\.dismiss) private var dismiss

    private var nextPerson: BirthdayPerson? {
        people.sorted { $0.daysUntil < $1.daysUntil }.first
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Status") {
                        Text(statusLabel)
                            .foregroundStyle(notificationScheduler.isAuthorized ? Color.primary : Color.orange)
                    }
                    LabeledContent("Scheduled") {
                        Text("\(notificationScheduler.pendingCount)")
                    }
                    LabeledContent("Delivery time") {
                        Text("9:00 AM")
                    }
                } footer: {
                    Text("Reminders are sent 2 weeks, 1 week, 3 days before, and the morning of each birthday.")
                }

                if !notificationScheduler.isAuthorized {
                    Section {
                        Button("Enable notifications") {
                            Task {
                                _ = await notificationScheduler.requestAuthorizationIfNeeded()
                                await reschedule()
                            }
                        }
                        if notificationScheduler.authorizationStatus == .denied {
                            Button("Open Settings") {
                                notificationScheduler.openSystemSettings()
                            }
                        }
                    }
                } else {
                    Section {
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
                    } footer: {
                        Text("Test alert appears in about 5 seconds. Leave the app or lock the phone to see the banner clearly. Tapping it opens that person’s draft message.")
                    }
                }
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #endif
            .navigationTitle("Reminders")
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
            }
            .onReceive(NotificationCenter.default.publisher(for: MessageDeepLinkRouter.openMessageNotification)) { _ in
                dismiss()
            }
        }
    }

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

    private func reschedule() async {
        await notificationScheduler.rescheduleAll(people)
        await notificationScheduler.refreshStatus()
    }
}
