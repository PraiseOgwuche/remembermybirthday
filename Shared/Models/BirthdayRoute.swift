import Foundation

enum BirthdayRoute: Hashable {
    case add
    case voiceAdd
    case addFromContact(contactIdentifier: String, name: String, phone: String)
    case voiceAddFromContact(contactIdentifier: String, name: String, phone: String)
    case detail(UUID)
    case edit(UUID)
    case message(UUID)
}
