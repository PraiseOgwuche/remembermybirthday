import Foundation
import SwiftData

@Model
final class BirthdayPerson: Identifiable {
    var id: UUID
    var name: String
    var birthMonth: Int
    var birthDay: Int
    var birthYear: Int?
    var relationship: String
    var nickname: String
    var notes: String
    var phoneNumber: String = ""
    /// Links this person to a Contacts card when we know it.
    var contactIdentifier: String = ""
    /// Last draft the user prepared (used for scheduled send + reopen).
    var savedDraft: String = ""
    /// When set, a “ready to send” notification fires at this time.
    var scheduledSendAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        name: String,
        birthMonth: Int,
        birthDay: Int,
        birthYear: Int? = nil,
        relationship: String = "",
        nickname: String = "",
        notes: String = "",
        phoneNumber: String = "",
        contactIdentifier: String = "",
        savedDraft: String = "",
        scheduledSendAt: Date? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.birthMonth = birthMonth
        self.birthDay = birthDay
        self.birthYear = birthYear
        self.relationship = relationship
        self.nickname = nickname
        self.notes = notes
        self.phoneNumber = phoneNumber
        self.contactIdentifier = contactIdentifier
        self.savedDraft = savedDraft
        self.scheduledSendAt = scheduledSendAt
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var displayName: String {
        nickname.isEmpty ? name : nickname
    }

    var hasPhoneNumber: Bool {
        !phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasScheduledSend: Bool {
        guard let scheduledSendAt else { return false }
        return scheduledSendAt > Date()
    }

    /// Digits-oriented value for sms: / Messages compose.
    var sanitizedPhoneNumber: String {
        let trimmed = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowed = trimmed.filter { $0.isNumber || $0 == "+" }
        return allowed.isEmpty ? trimmed : allowed
    }

    /// First name only — warmer in birthday messages than full legal names.
    var firstName: String {
        BirthdayNameNormalizer.firstName(from: displayName)
    }

    var nextBirthday: Date {
        BirthdayMath.nextBirthday(month: birthMonth, day: birthDay, from: Date())
    }

    var daysUntil: Int {
        BirthdayMath.daysUntil(nextBirthday)
    }

    var ageTurning: Int? {
        guard let birthYear else { return nil }
        let year = Calendar.current.component(.year, from: nextBirthday)
        return year - birthYear
    }

    var shortDate: String {
        let components = DateComponents(month: birthMonth, day: birthDay)
        let date = Calendar.current.date(from: components) ?? Date()
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    var formattedDate: String {
        let components = DateComponents(month: birthMonth, day: birthDay)
        let date = Calendar.current.date(from: components) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = birthYear == nil ? "MMMM d" : "MMMM d, yyyy"
        if let birthYear {
            var withYear = components
            withYear.year = birthYear
            if let full = Calendar.current.date(from: withYear) {
                return formatter.string(from: full)
            }
        }
        return formatter.string(from: date)
    }

    var countdownLabel: String {
        switch daysUntil {
        case 0: return "Today"
        case 1: return "Tomorrow"
        default: return "\(daysUntil) days"
        }
    }
}

enum BirthdayMath {
    static func nextBirthday(month: Int, day: Int, from reference: Date = Date()) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: reference)
        var components = calendar.dateComponents([.year], from: today)
        components.month = month
        components.day = day

        guard var candidate = calendar.date(from: components) else {
            return today
        }

        candidate = calendar.startOfDay(for: candidate)
        if candidate < today {
            components.year = (components.year ?? 0) + 1
            candidate = calendar.date(from: components).map(calendar.startOfDay(for:)) ?? today
        }
        return candidate
    }

    static func daysUntil(_ date: Date, from reference: Date = Date()) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: reference)
        let end = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }
}

enum ReminderOffset: Int, CaseIterable, Identifiable {
    case twoWeeks = 14
    case oneWeek = 7
    case threeDays = 3
    case dayOf = 0

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .twoWeeks: return "2 weeks before"
        case .oneWeek: return "1 week before"
        case .threeDays: return "3 days before"
        case .dayOf: return "Morning of"
        }
    }

    func notificationTitle(for name: String) -> String {
        switch self {
        case .twoWeeks: return "Two weeks · \(name)"
        case .oneWeek: return "One week · \(name)"
        case .threeDays: return "3 days · \(name)"
        case .dayOf: return "Today · \(name)"
        }
    }

    func body(for name: String) -> String {
        switch self {
        case .twoWeeks:
            return "\(name)'s birthday is in two weeks. Draft a message or start gift ideas?"
        case .oneWeek:
            return "One week until \(name)'s birthday. Perfect time to plan something thoughtful."
        case .threeDays:
            return "\(name)'s birthday is in 3 days. Grab a gift or get a message ready."
        case .dayOf:
            return "It's \(name)'s birthday today. Send a warm wish — don’t let this one slip."
        }
    }
}
