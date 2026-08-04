import Foundation
import Contacts
import EventKit

struct ImportedBirthday: Hashable, Identifiable, Sendable {
    var id: String { matchKey }
    let name: String
    let birthMonth: Int
    let birthDay: Int
    let birthYear: Int?
    let phoneNumber: String
    let source: Source

    var matchKey: String {
        BirthdayNameNormalizer.matchKey(name: name, month: birthMonth, day: birthDay)
    }

    enum Source: String {
        case contacts = "Contacts"
        case calendar = "Calendar"

        var priority: Int {
            switch self {
            case .contacts: return 2
            case .calendar: return 1
            }
        }
    }
}

@MainActor
final class BirthdayImporter: ObservableObject {
    @Published private(set) var contactsStatus: AccessStatus = .notDetermined
    @Published private(set) var calendarStatus: AccessStatus = .notDetermined
    @Published private(set) var lastImportCount = 0
    @Published var statusMessage: String?

    enum AccessStatus {
        case notDetermined, allowed, denied
    }

    private let contactStore = CNContactStore()
    private let eventStore = EKEventStore()

    func refreshStatuses() {
        contactsStatus = mapContactsStatus(CNContactStore.authorizationStatus(for: .contacts))
        calendarStatus = mapEventStatus(EKEventStore.authorizationStatus(for: .event))
    }

    func connectAndImport() async -> [ImportedBirthday] {
        statusMessage = nil
        refreshStatuses()

        var grantedAny = false

        if contactsStatus != .allowed {
            do {
                let granted = try await contactStore.requestAccess(for: .contacts)
                contactsStatus = granted ? .allowed : .denied
                if granted { grantedAny = true }
            } catch {
                contactsStatus = .denied
            }
        } else {
            grantedAny = true
        }

        if calendarStatus != .allowed {
            do {
                let granted: Bool
                if #available(iOS 17.0, macOS 14.0, *) {
                    granted = try await eventStore.requestFullAccessToEvents()
                } else {
                    granted = try await eventStore.requestAccess(to: .event)
                }
                calendarStatus = granted ? .allowed : .denied
                if granted { grantedAny = true }
            } catch {
                calendarStatus = .denied
            }
        } else {
            grantedAny = true
        }

        guard grantedAny else {
            statusMessage = "Access was denied. You can still add birthdays manually."
            return []
        }

        let includeContacts = contactsStatus == .allowed
        let includeCalendar = calendarStatus == .allowed

        let outcome = await Task.detached(priority: .userInitiated) {
            var results: [ImportedBirthday] = []
            var errorMessage: String?

            if includeContacts {
                let fetched = ContactsBirthdayReader.fetchBirthdays()
                results.append(contentsOf: fetched.items)
                if let error = fetched.errorMessage { errorMessage = error }
            }
            if includeCalendar {
                results.append(contentsOf: CalendarBirthdayReader.fetchBirthdays())
            }

            return (Self.dedupeImports(results), errorMessage)
        }.value

        if let errorMessage = outcome.1 {
            statusMessage = errorMessage
        }
        lastImportCount = outcome.0.count
        return outcome.0
    }

    @discardableResult
    func backfillPhoneNumbers(for people: [BirthdayPerson]) async -> Int {
        refreshStatuses()
        if contactsStatus != .allowed {
            do {
                let granted = try await contactStore.requestAccess(for: .contacts)
                contactsStatus = granted ? .allowed : .denied
            } catch {
                contactsStatus = .denied
            }
        }
        guard contactsStatus == .allowed else { return 0 }

        let snapshots = people.map {
            PhoneBackfillTarget(
                name: $0.name,
                birthMonth: $0.birthMonth,
                birthDay: $0.birthDay,
                needsPhone: !$0.hasPhoneNumber
            )
        }

        let phonesByKey = await Task.detached(priority: .utility) {
            ContactsBirthdayReader.phoneMatches(for: snapshots)
        }.value

        var updated = 0
        for person in people where !person.hasPhoneNumber {
            let birthdayKey = BirthdayNameNormalizer.matchKey(
                name: person.name,
                month: person.birthMonth,
                day: person.birthDay
            )
            let nameKey = BirthdayNameNormalizer.nameMatchKey(person.name)
            if let phone = phonesByKey[birthdayKey] ?? phonesByKey[nameKey], !phone.isEmpty {
                person.phoneNumber = phone
                person.updatedAt = Date()
                updated += 1
            }
        }
        return updated
    }

    nonisolated static func dedupeImports(_ results: [ImportedBirthday]) -> [ImportedBirthday] {
        var unique: [String: ImportedBirthday] = [:]

        for item in results {
            let cleanedName = BirthdayNameNormalizer.cleanDisplayName(item.name)
            guard !cleanedName.isEmpty else { continue }

            let normalized = ImportedBirthday(
                name: cleanedName,
                birthMonth: item.birthMonth,
                birthDay: item.birthDay,
                birthYear: item.birthYear,
                phoneNumber: item.phoneNumber,
                source: item.source
            )

            if let existing = unique[normalized.matchKey] {
                unique[normalized.matchKey] = prefer(existing, normalized)
            } else {
                unique[normalized.matchKey] = normalized
            }
        }

        return unique.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    nonisolated private static func prefer(_ a: ImportedBirthday, _ b: ImportedBirthday) -> ImportedBirthday {
        if a.source.priority != b.source.priority {
            return a.source.priority > b.source.priority ? a : b
        }
        let aHasPhone = !a.phoneNumber.isEmpty
        let bHasPhone = !b.phoneNumber.isEmpty
        if aHasPhone != bHasPhone {
            return aHasPhone ? a : b
        }
        if (a.birthYear != nil) != (b.birthYear != nil) {
            return a.birthYear != nil ? a : b
        }
        if a.name.count != b.name.count {
            return a.name.count < b.name.count ? a : b
        }
        return a
    }

    private func mapContactsStatus(_ status: CNAuthorizationStatus) -> AccessStatus {
        #if os(iOS)
        if #available(iOS 18.0, *) {
            switch status {
            case .authorized, .limited: return .allowed
            case .denied, .restricted: return .denied
            case .notDetermined: return .notDetermined
            @unknown default: return .denied
            }
        }
        #endif
        switch status {
        case .authorized: return .allowed
        case .denied, .restricted: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .denied
        }
    }

    private func mapEventStatus(_ status: EKAuthorizationStatus) -> AccessStatus {
        switch status {
        case .fullAccess, .authorized, .writeOnly: return .allowed
        case .denied, .restricted: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .denied
        }
    }
}

struct PhoneBackfillTarget: Sendable {
    let name: String
    let birthMonth: Int
    let birthDay: Int
    let needsPhone: Bool
}

enum ContactsBirthdayReader {
    struct FetchResult: Sendable {
        var items: [ImportedBirthday]
        var errorMessage: String?
    }

    nonisolated static func fetchBirthdays() -> FetchResult {
        let store = CNContactStore()
        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactNicknameKey as CNKeyDescriptor,
            CNContactBirthdayKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor
        ]
        let request = CNContactFetchRequest(keysToFetch: keys)
        var output: [ImportedBirthday] = []

        do {
            try store.enumerateContacts(with: request) { contact, _ in
                guard let birthday = contact.birthday,
                      let month = birthday.month,
                      let day = birthday.day else { return }
                guard let name = displayName(contact) else { return }

                output.append(
                    ImportedBirthday(
                        name: BirthdayNameNormalizer.cleanDisplayName(name),
                        birthMonth: month,
                        birthDay: day,
                        birthYear: birthday.year,
                        phoneNumber: preferredPhone(from: contact) ?? "",
                        source: .contacts
                    )
                )
            }
            return FetchResult(items: output, errorMessage: nil)
        } catch {
            return FetchResult(items: output, errorMessage: "Couldn’t read Contacts.")
        }
    }

    /// Returns phones keyed by birthday match key and name match key.
    nonisolated static func phoneMatches(for targets: [PhoneBackfillTarget]) -> [String: String] {
        let needed = targets.filter(\.needsPhone)
        guard !needed.isEmpty else { return [:] }

        let store = CNContactStore()
        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactNicknameKey as CNKeyDescriptor,
            CNContactBirthdayKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor
        ]
        let request = CNContactFetchRequest(keysToFetch: keys)
        var byBirthdayKey: [String: String] = [:]
        var byNameKey: [String: String] = [:]

        do {
            try store.enumerateContacts(with: request) { contact, _ in
                guard let phone = preferredPhone(from: contact), !phone.isEmpty else { return }
                guard let name = displayName(contact) else { return }
                let cleaned = BirthdayNameNormalizer.cleanDisplayName(name)
                let nameKey = BirthdayNameNormalizer.nameMatchKey(cleaned)
                if byNameKey[nameKey] == nil {
                    byNameKey[nameKey] = phone
                }
                if let birthday = contact.birthday,
                   let month = birthday.month,
                   let day = birthday.day {
                    let key = BirthdayNameNormalizer.matchKey(name: cleaned, month: month, day: day)
                    byBirthdayKey[key] = phone
                }
            }
        } catch {
            return [:]
        }

        var matched: [String: String] = [:]
        for target in needed {
            let birthdayKey = BirthdayNameNormalizer.matchKey(
                name: target.name,
                month: target.birthMonth,
                day: target.birthDay
            )
            let nameKey = BirthdayNameNormalizer.nameMatchKey(target.name)
            if let phone = byBirthdayKey[birthdayKey] ?? byNameKey[nameKey] {
                matched[birthdayKey] = phone
                matched[nameKey] = phone
            }
        }
        return matched
    }

    nonisolated private static func displayName(_ contact: CNContact) -> String? {
        let given = contact.givenName.trimmingCharacters(in: .whitespacesAndNewlines)
        let family = contact.familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        let nickname = contact.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        if !given.isEmpty || !family.isEmpty {
            return [given, family].filter { !$0.isEmpty }.joined(separator: " ")
        }
        if !nickname.isEmpty { return nickname }
        return nil
    }

    nonisolated private static func preferredPhone(from contact: CNContact) -> String? {
        let numbers = contact.phoneNumbers
        guard !numbers.isEmpty else { return nil }
        let preferredLabels = [CNLabelPhoneNumberiPhone, CNLabelPhoneNumberMobile, CNLabelPhoneNumberMain]
        for label in preferredLabels {
            if let match = numbers.first(where: { $0.label == label }) {
                return match.value.stringValue
            }
        }
        return numbers.first?.value.stringValue
    }
}

enum CalendarBirthdayReader {
    nonisolated static func fetchBirthdays() -> [ImportedBirthday] {
        let eventStore = EKEventStore()
        let calendars = eventStore.calendars(for: .event)
        let birthdayCalendars = calendars.filter {
            $0.type == .birthday || $0.title.localizedCaseInsensitiveContains("birthday")
        }
        guard !birthdayCalendars.isEmpty else { return [] }

        let start = Date()
        guard let end = Calendar.current.date(byAdding: .year, value: 1, to: start) else { return [] }
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: birthdayCalendars)
        let events = eventStore.events(matching: predicate)

        return events.compactMap { event in
            let title = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleaned = BirthdayNameNormalizer.cleanDisplayName(title)
            guard !cleaned.isEmpty else { return nil }
            let components = Calendar.current.dateComponents([.month, .day], from: event.startDate)
            guard let month = components.month, let day = components.day else { return nil }
            return ImportedBirthday(
                name: cleaned,
                birthMonth: month,
                birthDay: day,
                birthYear: nil,
                phoneNumber: "",
                source: .calendar
            )
        }
    }
}
