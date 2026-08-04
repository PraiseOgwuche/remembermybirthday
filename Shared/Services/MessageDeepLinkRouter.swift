import Foundation
import Combine

@MainActor
final class MessageDeepLinkRouter: ObservableObject {
    static let shared = MessageDeepLinkRouter()

    @Published var pendingPersonId: UUID?
    @Published var preferMessageScreen = false
    @Published var preferSend = false
    @Published var preferSchedule = false

    @Published var pendingContactAdd: ContactPromptCandidate?

    static let openMessageNotification = Notification.Name("Remember.openBirthdayMessage")
    static let openContactAddNotification = Notification.Name("Remember.openContactBirthdayAdd")

    func openMessage(for personId: UUID) {
        pendingPersonId = personId
        preferMessageScreen = true
        preferSend = false
        preferSchedule = false
        NotificationCenter.default.post(
            name: Self.openMessageNotification,
            object: nil,
            userInfo: ["personId": personId.uuidString]
        )
    }

    func openSend(for personId: UUID) {
        pendingPersonId = personId
        preferMessageScreen = true
        preferSend = true
        preferSchedule = false
        NotificationCenter.default.post(
            name: Self.openMessageNotification,
            object: nil,
            userInfo: ["personId": personId.uuidString, "preferSend": true]
        )
    }

    func openSchedule(for personId: UUID) {
        pendingPersonId = personId
        preferMessageScreen = true
        preferSend = false
        preferSchedule = true
        NotificationCenter.default.post(
            name: Self.openMessageNotification,
            object: nil,
            userInfo: ["personId": personId.uuidString, "preferSchedule": true]
        )
    }

    func openDetail(for personId: UUID) {
        pendingPersonId = personId
        preferMessageScreen = false
        preferSend = false
        preferSchedule = false
        NotificationCenter.default.post(
            name: Self.openMessageNotification,
            object: nil,
            userInfo: ["personId": personId.uuidString]
        )
    }

    func handle(url: URL) {
        guard let (action, id) = RememberDeepLink.parse(url) else { return }
        switch action {
        case .message:
            openMessage(for: id)
        case .send:
            openSend(for: id)
        case .schedule:
            openSchedule(for: id)
        case .detail:
            openDetail(for: id)
        }
    }

    func openContactBirthdayAdd(_ candidate: ContactPromptCandidate) {
        pendingContactAdd = candidate
        NotificationCenter.default.post(
            name: Self.openContactAddNotification,
            object: nil,
            userInfo: ["contactIdentifier": candidate.contactIdentifier]
        )
    }

    func consume() -> (UUID, preferMessage: Bool)? {
        guard let id = pendingPersonId else { return nil }
        let preferMessage = preferMessageScreen || preferSend || preferSchedule
        pendingPersonId = nil
        preferMessageScreen = false
        return (id, preferMessage)
    }

    func consumeWidgetAction() -> (send: Bool, schedule: Bool) {
        let send = preferSend
        let schedule = preferSchedule
        preferSend = false
        preferSchedule = false
        return (send, schedule)
    }

    func consumeContactAdd() -> ContactPromptCandidate? {
        let value = pendingContactAdd
        pendingContactAdd = nil
        return value
    }
}
