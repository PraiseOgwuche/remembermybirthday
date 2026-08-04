import Foundation

enum MessageTone: String, CaseIterable, Identifiable {
    case warm
    case short
    case funny
    case heartfelt

    var id: String { rawValue }

    var title: String {
        switch self {
        case .warm: return "Warm"
        case .short: return "Short"
        case .funny: return "Funny"
        case .heartfelt: return "Heartfelt"
        }
    }
}

enum BirthdayMessageComposer {
    static func draft(
        for person: BirthdayPerson,
        tone: MessageTone,
        variant: Int = 0
    ) -> String {
        let name = person.firstName
        let safeName = name.isEmpty ? "friend" : name
        let relationship = person.relationship.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let noteHint = usableNote(from: person.notes)

        let templates = templates(for: tone, name: safeName, relationship: relationship, noteHint: noteHint)
        let index = abs(variant) % max(templates.count, 1)
        return templates[index]
    }

    /// Prefer a short personal note fragment; ignore long dumps so we don’t invent intimacy.
    private static func usableNote(from notes: String) -> String? {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.count <= 80 else { return nil }
        // Skip notes that look like internal reminders rather than something to say.
        let lower = trimmed.lowercased()
        if lower.contains("gift") || lower.contains("buy") || lower.contains("amazon") {
            return nil
        }
        return trimmed
    }

    private static func templates(
        for tone: MessageTone,
        name: String,
        relationship: String,
        noteHint: String?
    ) -> [String] {
        let relPhrase = relationshipPhrase(relationship)

        switch tone {
        case .warm:
            var list = [
                "Happy birthday, \(name)! Hope today treats you well — grateful for you\(relPhrase).",
                "Happy birthday, \(name)! Wishing you a really good day and a year ahead that feels kind.",
                "Happy birthday, \(name)! Thinking of you today and hoping it’s full of easy joy."
            ]
            if let noteHint {
                list.append("Happy birthday, \(name)! \(noteHint) — hope today is wonderful.")
            }
            return list

        case .short:
            return [
                "Happy birthday, \(name)! Hope you have a great day.",
                "Happy birthday, \(name)! Enjoy every bit of today.",
                "Happy birthday, \(name)!"
            ]

        case .funny:
            return [
                "Happy birthday, \(name)! Another trip around the sun — still no cape required.",
                "Happy birthday, \(name)! May your cake be good and your group chats be quiet.",
                "Happy birthday, \(name)! Age is just a number… and today that number gets cake."
            ]

        case .heartfelt:
            var list = [
                "Happy birthday, \(name). I’m really glad you’re in my life\(relPhrase). Hope today feels as special as you are.",
                "Happy birthday, \(name). Thank you for being you — wishing you peace, joy, and a year that loves you back.",
                "Happy birthday, \(name). You’ve meant more than I probably say out loud. Hope today is gentle and full of love."
            ]
            if let noteHint {
                list.append("Happy birthday, \(name). \(noteHint) I’m grateful for you — hope today is beautiful.")
            }
            return list
        }
    }

    private static func relationshipPhrase(_ relationship: String) -> String {
        guard !relationship.isEmpty else { return "" }
        // Light touch only for common labels.
        let known = ["friend", "sister", "brother", "mom", "dad", "mother", "father", "partner", "wife", "husband", "colleague", "coworker"]
        if known.contains(where: { relationship.contains($0) }) {
            return ""
        }
        return ""
    }
}
