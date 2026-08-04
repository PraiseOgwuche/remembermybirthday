import Foundation
import Contacts

struct ContactMatchCandidate: Identifiable, Hashable {
    let id: String
    let fullName: String
    let phoneNumber: String
    let existingBirthday: DateComponents?
    let contactIdentifier: String
}

enum ContactBirthdayMatcher {
    static func findMatches(for name: String, limit: Int = 5) -> [ContactMatchCandidate] {
        let store = CNContactStore()
        let status = CNContactStore.authorizationStatus(for: .contacts)
        let canReadContacts: Bool
        #if os(iOS)
        if #available(iOS 18.0, *) {
            canReadContacts = status == .authorized || status == .limited
        } else {
            canReadContacts = status == .authorized
        }
        #else
        canReadContacts = status == .authorized
        #endif
        guard canReadContacts else { return [] }

        let keys: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactNicknameKey as CNKeyDescriptor,
            CNContactBirthdayKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor
        ]

        let request = CNContactFetchRequest(keysToFetch: keys)
        var scored: [(Int, ContactMatchCandidate)] = []
        let needle = BirthdayNameNormalizer.nameMatchKey(name)
        let needleFirst = BirthdayNameNormalizer.firstName(from: name).lowercased()

        do {
            try store.enumerateContacts(with: request) { contact, stop in
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

                let key = BirthdayNameNormalizer.nameMatchKey(full)
                var score = 0
                if key == needle { score = 100 }
                else if key.hasPrefix(needle) || needle.hasPrefix(key) { score = 80 }
                else if key.contains(needle) || needle.contains(key) { score = 60 }
                else if given.lowercased() == needleFirst { score = 50 }
                else { return }

                let phone = preferredPhone(from: contact) ?? ""
                let candidate = ContactMatchCandidate(
                    id: contact.identifier,
                    fullName: full,
                    phoneNumber: phone,
                    existingBirthday: contact.birthday,
                    contactIdentifier: contact.identifier
                )
                scored.append((score, candidate))
                if scored.count > 40 { stop.pointee = true }
            }
        } catch {
            return []
        }

        return scored
            .sorted { $0.0 > $1.0 }
            .prefix(limit)
            .map(\.1)
    }

    static func writeBirthday(
        contactIdentifier: String,
        month: Int,
        day: Int,
        year: Int?
    ) throws {
        let store = CNContactStore()
        let keys: [CNKeyDescriptor] = [
            CNContactBirthdayKey as CNKeyDescriptor,
            CNContactIdentifierKey as CNKeyDescriptor
        ]
        let contact = try store.unifiedContact(withIdentifier: contactIdentifier, keysToFetch: keys)
        let mutable = contact.mutableCopy() as! CNMutableContact
        var comps = DateComponents()
        comps.month = month
        comps.day = day
        comps.year = year
        mutable.birthday = comps

        let save = CNSaveRequest()
        save.update(mutable)
        try store.execute(save)
    }

    private static func preferredPhone(from contact: CNContact) -> String? {
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
