import Foundation

/// When the app opens, email for people at reminder milestones (deduped server-side-ish via UserDefaults).
enum EmailReminderSweep {
    private static let milestones: Set<Int> = [0, 1, 3, 7, 14]

    static func run(people: [BirthdayPerson]) {
        for person in people where milestones.contains(person.daysUntil) {
            EmailNotifier.sendBirthdayReminder(
                personName: person.displayName,
                daysUntil: person.daysUntil,
                note: person.relationship.isEmpty ? nil : person.relationship
            )
        }
    }
}
