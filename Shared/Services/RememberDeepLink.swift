import Foundation

enum RememberDeepLink {
    static let scheme = "remembermybirthday"

    enum Action: String {
        case message
        case send
        case schedule
        case detail
    }

    static func url(action: Action, personId: UUID) -> URL {
        URL(string: "\(scheme)://\(action.rawValue)/\(personId.uuidString)")!
    }

    static func parse(_ url: URL) -> (Action, UUID)? {
        guard url.scheme == scheme,
              let host = url.host,
              let action = Action(rawValue: host) else { return nil }
        let idString = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let id = UUID(uuidString: idString) else { return nil }
        return (action, id)
    }
}
