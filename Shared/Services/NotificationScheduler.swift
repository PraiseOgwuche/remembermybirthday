import Foundation
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

enum ReminderAction {
    static let categoryId = "BIRTHDAY_REMINDER"
    static let sendCategoryId = "BIRTHDAY_SEND"
    static let draftMessage = "DRAFT_MESSAGE"
    static let markDone = "MARK_DONE"
    static let snooze = "SNOOZE"
    static let sendNow = "SEND_NOW"
    static let reviewDraft = "REVIEW_DRAFT"
}

@MainActor
final class NotificationScheduler: ObservableObject {
    @Published private(set) var isAuthorized = false
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var pendingCount = 0

    private let center = UNUserNotificationCenter.current()
    var reminderHour: Int = AppSettingsStore.reminderHour

    func configure() {
        reminderHour = AppSettingsStore.reminderHour
        registerCategories()
        ContactBirthdayPromptCoordinator.shared.registerNotificationCategory()
        let prompts = ContactBirthdayPromptCoordinator.shared
        prompts.inactivityDays = AppSettingsStore.promptInactivityDays
        prompts.minDaysBetweenPrompts = AppSettingsStore.promptCooldownDays
        prompts.inactivityNudgeDelayDays = AppSettingsStore.promptNudgeDelayDays
        prompts.softEngageEnabled = AppSettingsStore.softEngageEnabled
        Task { await refreshStatus() }
    }

    func refreshStatus() async {
        await refreshAuthorization()
        await refreshPendingCount()
    }

    private func refreshAuthorization() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            isAuthorized = true
        default:
            isAuthorized = false
        }
    }

    private func refreshPendingCount() async {
        let pending = await center.pendingNotificationRequests()
        pendingCount = pending.filter { $0.identifier.hasPrefix("birthday.") }.count
    }

    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        await refreshStatus()
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            isAuthorized = true
            return true
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                isAuthorized = granted
                await refreshStatus()
                return granted
            } catch {
                isAuthorized = false
                return false
            }
        default:
            isAuthorized = false
            return false
        }
    }

    func reschedule(for person: BirthdayPerson) async {
        await reschedule(for: person, updatePendingCount: true)
    }

    /// - Parameter updatePendingCount: Pass `false` while batching so the UI count doesn’t flicker mid-pass.
    private func reschedule(for person: BirthdayPerson, updatePendingCount: Bool) async {
        await cancelReminderOffsets(for: person)
        if !isAuthorized {
            await refreshAuthorization()
        }
        guard isAuthorized else {
            if updatePendingCount { await refreshPendingCount() }
            return
        }

        let next = person.nextBirthday
        let name = person.displayName
        let draft = person.savedDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasDraft = !draft.isEmpty

        for offset in ReminderOffset.allCases {
            guard let fireDate = Calendar.current.date(byAdding: .day, value: -offset.rawValue, to: next) else {
                continue
            }

            var components = Calendar.current.dateComponents([.year, .month, .day], from: fireDate)
            components.hour = reminderHour
            components.minute = 0

            if let triggerDate = Calendar.current.date(from: components), triggerDate <= Date() {
                continue
            }

            let content = UNMutableNotificationContent()
            content.title = offset.notificationTitle(for: name)
            if hasDraft {
                content.body = draft.count > 110 ? String(draft.prefix(107)) + "…" : draft
            } else {
                content.body = offset.body(for: name)
            }
            content.sound = .default
            content.categoryIdentifier = ReminderAction.sendCategoryId
            content.threadIdentifier = "birthday.\(person.id.uuidString)"
            var userInfo: [String: Any] = [
                "personId": person.id.uuidString,
                "offsetDays": offset.rawValue,
                "personName": name,
                "phone": person.sanitizedPhoneNumber,
                "kind": hasDraft ? "reminderWithDraft" : "reminder"
            ]
            if hasDraft {
                userInfo["draft"] = draft
            }
            content.userInfo = userInfo

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: notificationId(personId: person.id, offset: offset),
                content: content,
                trigger: trigger
            )

            try? await center.add(request)
        }

        if let sendAt = person.scheduledSendAt, sendAt > Date(), !person.savedDraft.isEmpty {
            await scheduleSendNotification(for: person, at: sendAt, draft: person.savedDraft)
        }

        if updatePendingCount {
            await refreshPendingCount()
        }
    }

    func cancel(for person: BirthdayPerson) async {
        await cancelReminderOffsets(for: person)
        await cancelScheduledSend(for: person.id)
        await refreshStatus()
    }

    func cancelReminderOffsets(for person: BirthdayPerson) async {
        let ids = ReminderOffset.allCases.map { notificationId(personId: person.id, offset: $0) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    func cancelScheduledSend(for personId: UUID) async {
        center.removePendingNotificationRequests(withIdentifiers: [sendNotificationId(personId: personId)])
    }

    func scheduleSend(for person: BirthdayPerson, at date: Date, draft: String) async -> Bool {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let granted = await requestAuthorizationIfNeeded()
        guard granted else { return false }
        guard date > Date() else { return false }

        person.savedDraft = trimmed
        person.scheduledSendAt = date
        person.updatedAt = Date()

        await scheduleSendNotification(for: person, at: date, draft: trimmed)
        await refreshStatus()
        return true
    }

    func clearScheduledSend(for person: BirthdayPerson) async {
        person.scheduledSendAt = nil
        person.updatedAt = Date()
        await cancelScheduledSend(for: person.id)
        await refreshStatus()
    }

    func rescheduleAll(_ people: [BirthdayPerson]) async {
        await refreshAuthorization()
        guard isAuthorized else {
            await refreshPendingCount()
            return
        }
        for person in people {
            await reschedule(for: person, updatePendingCount: false)
        }
        await refreshPendingCount()
    }

    func scheduleTestReminder(for person: BirthdayPerson, delaySeconds: TimeInterval = 5) async {
        await refreshStatus()
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Test · \(person.displayName)"
        content.body = ReminderOffset.threeDays.body(for: person.displayName)
        content.sound = .default
        content.categoryIdentifier = ReminderAction.categoryId
        content.userInfo = [
            "personId": person.id.uuidString,
            "offsetDays": ReminderOffset.threeDays.rawValue,
            "personName": person.displayName,
            "isTest": true
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(delaySeconds, 1), repeats: false)
        let request = UNNotificationRequest(
            identifier: "birthday.test.\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    func scheduleTestSend(for person: BirthdayPerson, draft: String, delaySeconds: TimeInterval = 5) async {
        await refreshStatus()
        guard isAuthorized else { return }
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let content = makeSendContent(for: person, draft: trimmed)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(delaySeconds, 1), repeats: false)
        let request = UNNotificationRequest(
            identifier: "birthday.send.test.\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    func openSystemSettings() {
        #if os(iOS)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #endif
    }

    private func scheduleSendNotification(for person: BirthdayPerson, at date: Date, draft: String) async {
        await cancelScheduledSend(for: person.id)

        let content = makeSendContent(for: person, draft: draft)
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: sendNotificationId(personId: person.id),
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    private func makeSendContent(for person: BirthdayPerson, draft: String) -> UNMutableNotificationContent {
        let preview = draft.count > 110 ? String(draft.prefix(107)) + "…" : draft
        let content = UNMutableNotificationContent()
        content.title = "Ready to send · \(person.firstName)"
        content.body = preview
        content.sound = .default
        content.categoryIdentifier = ReminderAction.sendCategoryId
        content.threadIdentifier = "birthday.\(person.id.uuidString)"
        content.userInfo = [
            "personId": person.id.uuidString,
            "personName": person.displayName,
            "draft": draft,
            "phone": person.sanitizedPhoneNumber,
            "kind": "scheduledSend"
        ]
        return content
    }

    private func registerCategories() {
        let sendNow = UNNotificationAction(
            identifier: ReminderAction.sendNow,
            title: "Send",
            options: [.foreground]
        )
        let review = UNNotificationAction(
            identifier: ReminderAction.reviewDraft,
            title: "Review",
            options: [.foreground]
        )
        let gotIt = UNNotificationAction(
            identifier: ReminderAction.markDone,
            title: "Got it",
            options: []
        )
        let sendCategory = UNNotificationCategory(
            identifier: ReminderAction.sendCategoryId,
            actions: [sendNow, review, gotIt],
            intentIdentifiers: [],
            options: []
        )

        let legacyDraft = UNNotificationAction(
            identifier: ReminderAction.draftMessage,
            title: "Review",
            options: [.foreground]
        )
        let legacyCategory = UNNotificationCategory(
            identifier: ReminderAction.categoryId,
            actions: [legacyDraft, gotIt],
            intentIdentifiers: [],
            options: []
        )

        let contactYes = UNNotificationAction(
            identifier: ContactPromptAction.yes,
            title: "Yes",
            options: [.foreground]
        )
        let contactNo = UNNotificationAction(
            identifier: ContactPromptAction.no,
            title: "No",
            options: []
        )
        let contactCategory = UNNotificationCategory(
            identifier: ContactPromptAction.categoryId,
            actions: [contactYes, contactNo],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([sendCategory, legacyCategory, contactCategory])
    }

    private func notificationId(personId: UUID, offset: ReminderOffset) -> String {
        "birthday.\(personId.uuidString).\(offset.rawValue)"
    }

    private func sendNotificationId(personId: UUID) -> String {
        "birthday.send.\(personId.uuidString)"
    }
}

#if os(iOS)
final class ReminderNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        DispatchQueue.main.async {
            Self.maybeEmailFromNotification(notification.request.content.userInfo)
            completionHandler([.banner, .sound, .badge, .list])
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        DispatchQueue.main.async {
            Self.handle(response: response, center: center)
            completionHandler()
        }
    }

    private static func maybeEmailFromNotification(_ info: [AnyHashable: Any]) {
        #if os(watchOS)
        return
        #else
        guard (info["isTest"] as? Bool) != true else { return }
        let kind = info["kind"] as? String
        if kind == "contactBirthdayPrompt" { return }
        guard let name = info["personName"] as? String, !name.isEmpty else { return }
        let days = (info["offsetDays"] as? Int) ?? (info["offsetDays"] as? NSNumber)?.intValue
        EmailNotifier.sendBirthdayReminder(
            personName: name,
            daysUntil: days ?? 0,
            note: nil
        )
        #endif
    }

    private static func handle(response: UNNotificationResponse, center: UNUserNotificationCenter) {
        let info = response.notification.request.content.userInfo
        maybeEmailFromNotification(info)
        let kind = info["kind"] as? String

        if kind == "contactBirthdayPrompt"
            || response.notification.request.content.categoryIdentifier == ContactPromptAction.categoryId {
            Task { @MainActor in
                ContactBirthdayPromptCoordinator.shared.handleNotificationResponse(
                    actionIdentifier: response.actionIdentifier,
                    userInfo: info
                )
            }
            return
        }

        let personId = (info["personId"] as? String).flatMap(UUID.init)
        let draft = info["draft"] as? String
        let phone = info["phone"] as? String

        switch response.actionIdentifier {
        case ReminderAction.sendNow:
            Task { @MainActor in
                if let phone, !phone.isEmpty, let draft, !draft.isEmpty {
                    MessageComposeView.openSMSURL(phone: phone, body: draft)
                } else if let personId {
                    MessageDeepLinkRouter.shared.openMessage(for: personId)
                }
            }

        case ReminderAction.reviewDraft, ReminderAction.draftMessage:
            if let personId {
                Task { @MainActor in
                    MessageDeepLinkRouter.shared.openMessage(for: personId)
                }
            }

        case ReminderAction.markDone:
            break

        case UNNotificationDefaultActionIdentifier:
            if let personId {
                Task { @MainActor in
                    MessageDeepLinkRouter.shared.openMessage(for: personId)
                }
            }

        case ReminderAction.snooze:
            scheduleSnooze(from: response, center: center)

        default:
            break
        }
    }

    private static func scheduleSnooze(from response: UNNotificationResponse, center: UNUserNotificationCenter) {
        let info = response.notification.request.content.userInfo
        let name = (info["personName"] as? String) ?? "Someone"

        let content = UNMutableNotificationContent()
        content.title = "Reminder · \(name)"
        content.body = "\(name)'s birthday is still coming up. Want a message ready?"
        content.sound = .default
        content.categoryIdentifier = ReminderAction.categoryId
        content.userInfo = info

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 24 * 60 * 60, repeats: false)
        let request = UNNotificationRequest(
            identifier: "birthday.snooze.\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }
}
#endif
