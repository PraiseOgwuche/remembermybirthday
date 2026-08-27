import Foundation

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, macOS 26.0, *)
enum AppleCompanionAI {
    static func enhance(person: BirthdayPerson, local: CompanionPlan) async throws -> CompanionAIResult {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw CompanionAIError.unavailable
        }

        let session = LanguageModelSession(
            instructions: """
            You are a birthday companion. Reply with ONLY JSON:
            {"action":"call|message|giftAndMessage","primaryTitle":"...","reason":"...","whenLabel":"...","wantsGift":true,"draft":"...","gifts":["...","..."]}
            Be concise. Draft under 200 characters.
            """
        )

        let prompt = """
        Name: \(person.displayName)
        Relationship: \(person.relationship.isEmpty ? "unknown" : person.relationship)
        Notes: \(person.notes.isEmpty ? "none" : String(person.notes.prefix(120)))
        Days until birthday: \(person.daysUntil)
        Has phone: \(person.hasPhoneNumber)
        Local suggestion: \(local.action.rawValue)
        """

        let response = try await session.respond(to: prompt)
        return try AnthropicCompanionClient.parseModelJSON(
            response.content,
            fallback: local,
            source: .apple
        )
    }
}
#endif
