import Foundation
import Contacts
import UserNotifications
import Combine

struct ContactPromptCandidate: Identifiable, Hashable, Sendable {
    enum Reason: String, Sendable {
        case newContact
        case engagement
    }

    var id: String { contactIdentifier }
    let contactIdentifier: String
    let fullName: String
    let phoneNumber: String
    let reason: Reason

    var firstName: String {
        BirthdayNameNormalizer.firstName(from: fullName)
    }
}

enum ContactPromptAction {
    static let categoryId = "CONTACT_BIRTHDAY_PROMPT"
    static let yes = "CONTACT_PROMPT_YES"
    static let no = "CONTACT_PROMPT_NO"
    static let inactivityNotificationId = "contact.prompt.inactivity"
}

@MainActor
final class ContactBirthdayPromptCoordinator: ObservableObject {
    static let shared = ContactBirthdayPromptCoordinator()

    @Published var inAppPrompt: ContactPromptCandidate?

    /// Days of no opens before we treat the user as inactive (engagement nudge).
    var inactivityDays: Int = AppSettingsStore.promptInactivityDays
    /// Minimum gap between any contact-birthday prompts.
    var minDaysBetweenPrompts: Int = AppSettingsStore.promptCooldownDays
    /// Days after last open to fire a “come back” notification.
    var inactivityNudgeDelayDays: Int = AppSettingsStore.promptNudgeDelayDays
    /// When false, skip random in-app engagement nudges.
    var softEngageEnabled: Bool = AppSettingsStore.softEngageEnabled

    private let center = UNUserNotificationCenter.current()

    func registerNotificationCategory() {
        let yes = UNNotificationAction(
            identifier: ContactPromptAction.yes,
            title: "Yes",
            options: [.foreground]
        )
        let no = UNNotificationAction(
            identifier: ContactPromptAction.no,
            title: "No",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: ContactPromptAction.categoryId,
            actions: [yes, no],
            intentIdentifiers: [],
            options: []
        )

        center.getNotificationCategories { existing in
            var next = existing
            next.insert(category)
            self.center.setNotificationCategories(next)
        }
    }

    /// Call when the main list becomes active. Prefer new contacts; otherwise engagement.
    func evaluateOnAppActive(people: [BirthdayPerson], notificationsAuthorized: Bool) async {
        let previousActive = ContactBirthdayPromptStore.lastActiveAt
        let wasInactive: Bool = {
            guard let previousActive else { return false }
            let days = Calendar.current.dateComponents([.day], from: previousActive, to: Date()).day ?? 0
            return days >= inactivityDays
        }()

        ContactBirthdayPromptStore.markActive()

        let trackedIds = Set(people.map(\.contactIdentifier).filter { !$0.isEmpty })
        let trackedNames = Set(people.map { BirthdayNameNormalizer.nameMatchKey($0.name) })
        let dismissed = ContactBirthdayPromptStore.dismissedContactIds

        let eligible = await Task.detached(priority: .utility) {
            Self.eligibleContacts(
                dismissed: dismissed,
                trackedIds: trackedIds,
                trackedNames: trackedNames
            )
        }.value
        let known = ContactBirthdayPromptStore.knownContactIds

        // First scan: learn the address book without treating everyone as “new”.
        if known.isEmpty {
            ContactBirthdayPromptStore.knownContactIds = Set(eligible.map(\.contactIdentifier))
            if notificationsAuthorized {
                await scheduleInactivityNudge(from: eligible)
            }
            return
        }

        let newOnes = eligible.filter { !known.contains($0.contactIdentifier) }
        ContactBirthdayPromptStore.knownContactIds = Set(eligible.map(\.contactIdentifier)).union(known)

        // Keep a future re-engagement notification warm.
        if notificationsAuthorized {
            await scheduleInactivityNudge(from: eligible)
        }

        guard canPromptNow() else { return }
        guard inAppPrompt == nil, MessageDeepLinkRouter.shared.pendingContactAdd == nil else { return }

        if let fresh = newOnes.first {
            let candidate = ContactPromptCandidate(
                contactIdentifier: fresh.contactIdentifier,
                fullName: fresh.fullName,
                phoneNumber: fresh.phoneNumber,
                reason: .newContact
            )
            await present(candidate, preferNotification: false, notificationsAuthorized: notificationsAuthorized)
            return
        }

        if wasInactive, let pick = eligible.randomElement() {
            await present(pick, preferNotification: true, notificationsAuthorized: notificationsAuthorized)
            return
        }

        // Soft engagement: occasional in-app nudge when they open the app.
        if shouldSoftEngage(), let pick = eligible.randomElement() {
            await present(pick, preferNotification: false, notificationsAuthorized: notificationsAuthorized)
        }
    }

    func dismissPrompt(_ candidate: ContactPromptCandidate) {
        ContactBirthdayPromptStore.dismiss(contactId: candidate.contactIdentifier)
        if inAppPrompt?.contactIdentifier == candidate.contactIdentifier {
            inAppPrompt = nil
        }
        center.removePendingNotificationRequests(withIdentifiers: [
            notificationId(for: candidate.contactIdentifier),
            ContactPromptAction.inactivityNotificationId
        ])
        center.removeDeliveredNotifications(withIdentifiers: [
            notificationId(for: candidate.contactIdentifier),
            ContactPromptAction.inactivityNotificationId
        ])
    }

    func acceptPrompt(_ candidate: ContactPromptCandidate) {
        ContactBirthdayPromptStore.markPrompted(contactId: candidate.contactIdentifier)
        inAppPrompt = nil
        MessageDeepLinkRouter.shared.openContactBirthdayAdd(candidate)
    }

    func handleNotificationResponse(actionIdentifier: String, userInfo: [AnyHashable: Any]) {
        guard let contactId = userInfo["contactIdentifier"] as? String,
              let name = userInfo["contactName"] as? String else { return }
        let phone = userInfo["phone"] as? String ?? ""
        let reasonRaw = userInfo["reason"] as? String ?? ContactPromptCandidate.Reason.engagement.rawValue
        let reason = ContactPromptCandidate.Reason(rawValue: reasonRaw) ?? .engagement
        let candidate = ContactPromptCandidate(
            contactIdentifier: contactId,
            fullName: name,
            phoneNumber: phone,
            reason: reason
        )

        switch actionIdentifier {
        case ContactPromptAction.no:
            dismissPrompt(candidate)
        case ContactPromptAction.yes, UNNotificationDefaultActionIdentifier:
            acceptPrompt(candidate)
        default:
            break
        }
    }

    // MARK: - Private

    private func canPromptNow() -> Bool {
        guard let last = ContactBirthdayPromptStore.lastPromptAt else { return true }
        let days = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
        return days >= minDaysBetweenPrompts
    }

    private func shouldSoftEngage() -> Bool {
        guard softEngageEnabled else { return false }
        // ~25% chance when eligible and cooldown passed — keeps it light.
        return Int.random(in: 0..<4) == 0
    }

    private func present(
        _ candidate: ContactPromptCandidate,
        preferNotification: Bool,
        notificationsAuthorized: Bool
    ) async {
        ContactBirthdayPromptStore.markPrompted(contactId: candidate.contactIdentifier)
        var known = ContactBirthdayPromptStore.knownContactIds
        known.insert(candidate.contactIdentifier)
        ContactBirthdayPromptStore.knownContactIds = known

        if preferNotification, notificationsAuthorized {
            await postNotification(for: candidate, delaySeconds: 1)
        } else {
            inAppPrompt = candidate
        }
    }

    private func postNotification(for candidate: ContactPromptCandidate, delaySeconds: TimeInterval) async {
        let content = UNMutableNotificationContent()
        content.title = candidate.reason == .newContact
            ? "New contact · \(candidate.firstName)"
            : "Quick one · \(candidate.firstName)"
        content.body = "Want to add \(candidate.firstName)’s birthday? We’ll save it in Remember My Birthday and on their contact card."
        content.sound = .default
        content.categoryIdentifier = ContactPromptAction.categoryId
        content.userInfo = [
            "kind": "contactBirthdayPrompt",
            "contactIdentifier": candidate.contactIdentifier,
            "contactName": candidate.fullName,
            "phone": candidate.phoneNumber,
            "reason": candidate.reason.rawValue
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(delaySeconds, 1), repeats: false)
        let request = UNNotificationRequest(
            identifier: notificationId(for: candidate.contactIdentifier),
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    private func scheduleInactivityNudge(from eligible: [ContactPromptCandidate]) async {
        center.removePendingNotificationRequests(withIdentifiers: [ContactPromptAction.inactivityNotificationId])
        guard let pick = eligible.randomElement() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Remember My Birthday · \(pick.firstName)"
        content.body = "It’s been a bit — want to add \(pick.firstName)’s birthday so you don’t miss it?"
        content.sound = .default
        content.categoryIdentifier = ContactPromptAction.categoryId
        content.userInfo = [
            "kind": "contactBirthdayPrompt",
            "contactIdentifier": pick.contactIdentifier,
            "contactName": pick.fullName,
            "phone": pick.phoneNumber,
            "reason": ContactPromptCandidate.Reason.engagement.rawValue
        ]

        let seconds = TimeInterval(inactivityNudgeDelayDays * 24 * 60 * 60)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(seconds, 60), repeats: false)
        let request = UNNotificationRequest(
            identifier: ContactPromptAction.inactivityNotificationId,
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    private func notificationId(for contactId: String) -> String {
        "contact.prompt.\(contactId)"
    }

    nonisolated static func eligibleContacts(
        dismissed: Set<String>,
        trackedIds: Set<String>,
        trackedNames: Set<String>
    ) -> [ContactPromptCandidate] {
        let store = CNContactStore()
        let status = CNContactStore.authorizationStatus(for: .contacts)
        let canRead: Bool
        #if os(iOS)
        if #available(iOS 18.0, *) {
            canRead = status == .authorized || status == .limited
        } else {
            canRead = status == .authorized
        }
        #else
        canRead = status == .authorized
        #endif
        guard canRead else { return [] }

        let keys: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactNicknameKey as CNKeyDescriptor,
            CNContactBirthdayKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor
        ]

        let request = CNContactFetchRequest(keysToFetch: keys)
        var results: [ContactPromptCandidate] = []

        do {
            try store.enumerateContacts(with: request) { contact, _ in
                if contact.birthday != nil { return }
                if dismissed.contains(contact.identifier) { return }
                if trackedIds.contains(contact.identifier) { return }

                let given = contact.givenName.trimmingCharacters(in: .whitespacesAndNewlines)
                let family = contact.familyName.trimmingCharacters(in: .whitespacesAndNewlines)
                let nickname = contact.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
                let full: String
                if !given.isEmpty || !family.isEmpty {
                    full = [given, family].filter { !$0.isEmpty }.joined(separator: " ")
                } else if !nickname.isEmpty {
                    full = nickname
                } else {
                    return
                }

                if trackedNames.contains(BirthdayNameNormalizer.nameMatchKey(full)) { return }

                let phone = preferredPhone(from: contact) ?? ""
                results.append(
                    ContactPromptCandidate(
                        contactIdentifier: contact.identifier,
                        fullName: full,
                        phoneNumber: phone,
                        reason: .engagement
                    )
                )
            }
        } catch {
            return []
        }

        return results.sorted { lhs, rhs in
            let l = lhs.phoneNumber.isEmpty ? 0 : 1
            let r = rhs.phoneNumber.isEmpty ? 0 : 1
            if l != r { return l > r }
            return lhs.fullName.localizedCaseInsensitiveCompare(rhs.fullName) == .orderedAscending
        }
    }

    nonisolated private static func preferredPhone(from contact: CNContact) -> String? {
        let numbers = contact.phoneNumbers
        guard !numbers.isEmpty else { return nil }
        let preferred = [CNLabelPhoneNumberiPhone, CNLabelPhoneNumberMobile, CNLabelPhoneNumberMain]
        for label in preferred {
            if let match = numbers.first(where: { $0.label == label }) {
                return match.value.stringValue
            }
        }
        return numbers.first?.value.stringValue
    }
}
