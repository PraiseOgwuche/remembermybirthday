import Foundation
import Contacts
import EventKit

struct ImportedBirthday: Hashable, Identifiable {
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

    /// Requests Contacts + Calendar access, then returns unique birthdays found.
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

        var results: [ImportedBirthday] = []
        if contactsStatus == .allowed {
            results.append(contentsOf: fetchFromContacts())
        }
        if calendarStatus == .allowed {
            results.append(contentsOf: fetchFromCalendar())
        }

        let merged = Self.dedupeImports(results)
        lastImportCount = merged.count
        return merged
    }

    /// Fills missing phone numbers on saved people by matching Contacts.
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

        let directory = buildPhoneDirectory()
        var updated = 0

        for person in people where !person.hasPhoneNumber {
            let key = BirthdayNameNormalizer.matchKey(
                name: person.name,
                month: person.birthMonth,
                day: person.birthDay
            )
            if let phone = directory.byBirthdayKey[key], !phone.isEmpty {
                person.phoneNumber = phone
                person.updatedAt = Date()
                updated += 1
                continue
            }

            let nameKey = BirthdayNameNormalizer.nameMatchKey(person.name)
            if let phone = directory.byNameKey[nameKey], !phone.isEmpty {
                person.phoneNumber = phone
                person.updatedAt = Date()
                updated += 1
            }
        }

        return updated
    }

    static func dedupeImports(_ results: [ImportedBirthday]) -> [ImportedBirthday] {
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

    private static func prefer(_ a: ImportedBirthday, _ b: ImportedBirthday) -> ImportedBirthday {
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

    private func fetchFromContacts() -> [ImportedBirthday] {
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
            try contactStore.enumerateContacts(with: request) { contact, _ in
                guard let birthday = contact.birthday,
                      let month = birthday.month,
                      let day = birthday.day else { return }

                guard let name = contactDisplayName(contact) else { return }

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
        } catch {
            statusMessage = "Couldn’t read Contacts."
        }
        return output
    }

    private func fetchFromCalendar() -> [ImportedBirthday] {
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

    private struct PhoneDirectory {
        var byBirthdayKey: [String: String] = [:]
        var byNameKey: [String: String] = [:]
    }

    private func buildPhoneDirectory() -> PhoneDirectory {
        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactNicknameKey as CNKeyDescriptor,
            CNContactBirthdayKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor
        ]
        let request = CNContactFetchRequest(keysToFetch: keys)
        var directory = PhoneDirectory()

        do {
            try contactStore.enumerateContacts(with: request) { contact, _ in
                guard let phone = preferredPhone(from: contact), !phone.isEmpty else { return }
                guard let name = contactDisplayName(contact) else { return }
                let cleaned = BirthdayNameNormalizer.cleanDisplayName(name)
                let nameKey = BirthdayNameNormalizer.nameMatchKey(cleaned)
                if directory.byNameKey[nameKey] == nil {
                    directory.byNameKey[nameKey] = phone
                }

                if let birthday = contact.birthday,
                   let month = birthday.month,
                   let day = birthday.day {
                    let key = BirthdayNameNormalizer.matchKey(name: cleaned, month: month, day: day)
                    directory.byBirthdayKey[key] = phone
                }
            }
        } catch {
            statusMessage = "Couldn’t read Contacts for phone numbers."
        }

        return directory
    }

    private func contactDisplayName(_ contact: CNContact) -> String? {
        let given = contact.givenName.trimmingCharacters(in: .whitespacesAndNewlines)
        let family = contact.familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        let nickname = contact.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        if !given.isEmpty || !family.isEmpty {
            return [given, family].filter { !$0.isEmpty }.joined(separator: " ")
        }
        if !nickname.isEmpty { return nickname }
        return nil
    }

    private func preferredPhone(from contact: CNContact) -> String? {
        let numbers = contact.phoneNumbers
        guard !numbers.isEmpty else { return nil }

        let preferredLabels: [String] = [
            CNLabelPhoneNumberiPhone,
            CNLabelPhoneNumberMobile,
            CNLabelPhoneNumberMain
        ]

        for label in preferredLabels {
            if let match = numbers.first(where: { $0.label == label }) {
                return match.value.stringValue
            }
        }
        return numbers.first?.value.stringValue
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
