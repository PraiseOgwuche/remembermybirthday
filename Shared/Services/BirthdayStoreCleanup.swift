import Foundation
import SwiftData

enum BirthdayStoreCleanup {
    /// Merges duplicate people already saved (e.g. Contacts + Calendar import).
    @MainActor
    static func dedupeExisting(
        in context: ModelContext,
        notificationScheduler: NotificationScheduler
    ) async {
        let descriptor = FetchDescriptor<BirthdayPerson>()
        guard let people = try? context.fetch(descriptor), people.count > 1 else { return }

        var groups: [String: [BirthdayPerson]] = [:]
        for person in people {
            let key = BirthdayNameNormalizer.matchKey(
                name: person.name,
                month: person.birthMonth,
                day: person.birthDay
            )
            groups[key, default: []].append(person)
        }

        for (_, group) in groups where group.count > 1 {
            let keeper = pickKeeper(from: group)
            let cleaned = BirthdayNameNormalizer.cleanDisplayName(keeper.name)
            if keeper.name != cleaned {
                keeper.name = cleaned
                keeper.updatedAt = Date()
            }

            for duplicate in group where duplicate.id != keeper.id {
                // Prefer keeping a year if the keeper lacked one.
                if keeper.birthYear == nil, let year = duplicate.birthYear {
                    keeper.birthYear = year
                }
                if keeper.nickname.isEmpty, !duplicate.nickname.isEmpty {
                    keeper.nickname = duplicate.nickname
                }
                if keeper.notes.isEmpty, !duplicate.notes.isEmpty {
                    keeper.notes = duplicate.notes
                }
                if keeper.relationship.isEmpty, !duplicate.relationship.isEmpty {
                    keeper.relationship = duplicate.relationship
                }
                if !keeper.hasPhoneNumber, duplicate.hasPhoneNumber {
                    keeper.phoneNumber = duplicate.phoneNumber
                }

                await notificationScheduler.cancel(for: duplicate)
                context.delete(duplicate)
            }

            await notificationScheduler.reschedule(for: keeper)
        }

        try? context.save()
    }

    private static func pickKeeper(from group: [BirthdayPerson]) -> BirthdayPerson {
        group.sorted { lhs, rhs in
            let lhsScore = qualityScore(lhs)
            let rhsScore = qualityScore(rhs)
            if lhsScore != rhsScore { return lhsScore > rhsScore }
            return lhs.createdAt < rhs.createdAt
        }.first!
    }

    private static func qualityScore(_ person: BirthdayPerson) -> Int {
        var score = 0
        let cleaned = BirthdayNameNormalizer.cleanDisplayName(person.name)
        if person.name == cleaned { score += 3 }
        if person.birthYear != nil { score += 2 }
        // Prefer names without trailing ordinal junk / longer "event" titles.
        if person.name.localizedCaseInsensitiveContains("birthday") { score -= 2 }
        if person.name.range(of: #"['’]s\s+\d"#, options: .regularExpression) != nil { score -= 3 }
        if !person.nickname.isEmpty { score += 1 }
        if !person.notes.isEmpty { score += 1 }
        if person.hasPhoneNumber { score += 3 }
        // Slightly prefer shorter cleaned names.
        score += max(0, 40 - cleaned.count) / 10
        return score
    }
}
