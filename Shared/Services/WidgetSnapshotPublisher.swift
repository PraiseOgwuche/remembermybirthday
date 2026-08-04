import Foundation

enum WidgetSnapshotPublisher {
    static func publish(people: [BirthdayPerson]) {
        let top = people.sorted { $0.daysUntil < $1.daysUntil }.prefix(5)
        let snapshots: [WidgetPersonSnapshot] = top.map { person in
            let saved = person.savedDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            let draft = saved.isEmpty
                ? BirthdayMessageComposer.draft(for: person, tone: .warm, variant: 0)
                : saved
            return WidgetPersonSnapshot(
                id: person.id.uuidString,
                displayName: person.displayName,
                firstName: person.firstName,
                shortDate: person.shortDate,
                daysUntil: person.daysUntil,
                countdownLabel: person.countdownLabel,
                draft: draft,
                phone: person.sanitizedPhoneNumber,
                birthMonth: person.birthMonth
            )
        }
        WidgetSnapshotStore.saveSnapshot(
            WidgetSnapshot(updatedAt: Date(), people: Array(snapshots))
        )
    }
}
