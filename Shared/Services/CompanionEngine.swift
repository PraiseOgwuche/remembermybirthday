import Foundation

struct CompanionPlan: Equatable, Sendable {
    enum Action: String, Sendable {
        case call
        case message
        case giftAndMessage
    }

    enum Source: String, Sendable {
        case local
        case apple
        case anthropic
    }

    let action: Action
    let primaryTitle: String
    let reason: String
    let whenLabel: String
    let wantsGift: Bool
    let source: Source

    var systemImage: String {
        switch action {
        case .call: return "phone.fill"
        case .message, .giftAndMessage: return "text.bubble.fill"
        }
    }
}

enum CompanionEngine {
    static func plan(for person: BirthdayPerson) -> CompanionPlan {
        let rel = person.relationship.lowercased()
        let notes = person.notes.lowercased()
        let name = person.firstName
        let close = isClose(rel: rel, notes: notes)
        let work = isWork(rel: rel, notes: notes)
        let hasPhone = person.hasPhoneNumber

        let action: CompanionPlan.Action
        let primaryTitle: String
        let reason: String
        let wantsGift: Bool

        if close && hasPhone && !work {
            action = person.daysUntil <= 3 && shouldPreferGift(rel: rel, notes: notes)
                ? .giftAndMessage
                : .call
            primaryTitle = action == .call ? "Call \(name)" : "Message \(name) + gift idea"
            reason = action == .call
                ? "Close relationship — a call usually lands better than a text."
                : "Close enough that a small gift plus a warm note fits."
            wantsGift = action == .giftAndMessage || shouldPreferGift(rel: rel, notes: notes)
        } else if work {
            action = .message
            primaryTitle = "Message \(name)"
            reason = "Work relationship — a short message is usually right."
            wantsGift = false
        } else if hasPhone && close {
            action = .call
            primaryTitle = "Call \(name)"
            reason = "You have their number and they’re close — call first."
            wantsGift = shouldPreferGift(rel: rel, notes: notes)
        } else {
            action = .message
            primaryTitle = hasPhone ? "Message \(name)" : "Draft a message"
            reason = hasPhone
                ? "A thoughtful text keeps it easy and personal."
                : "Add a phone number to Call or Send in one tap."
            wantsGift = close && person.daysUntil <= 14
        }

        return CompanionPlan(
            action: action,
            primaryTitle: primaryTitle,
            reason: reason,
            whenLabel: whenLabel(for: person),
            wantsGift: wantsGift,
            source: .local
        )
    }

    private static func isClose(rel: String, notes: String) -> Bool {
        let keys = ["mom", "dad", "mother", "father", "parent", "wife", "husband", "spouse",
                    "partner", "girlfriend", "boyfriend", "brother", "sister", "sibling",
                    "son", "daughter", "family", "best friend", "bestie"]
        return keys.contains { rel.contains($0) || notes.contains($0) }
    }

    private static func isWork(rel: String, notes: String) -> Bool {
        let keys = ["coworker", "colleague", "boss", "manager", "client", "work", "teammate"]
        return keys.contains { rel.contains($0) || notes.contains($0) }
    }

    private static func shouldPreferGift(rel: String, notes: String) -> Bool {
        if notes.contains("gift") || notes.contains("present") { return true }
        let giftRels = ["mom", "dad", "wife", "husband", "partner", "son", "daughter", "spouse"]
        return giftRels.contains { rel.contains($0) }
    }

    private static func whenLabel(for person: BirthdayPerson) -> String {
        switch person.daysUntil {
        case 0:
            return "Do this today — morning or right after work."
        case 1:
            return "Best tonight after work, or first thing tomorrow morning."
        case 2...3:
            return "Nudge yourself after work the day before."
        default:
            return "We’ll remind you early — act when the reminder lands."
        }
    }
}
