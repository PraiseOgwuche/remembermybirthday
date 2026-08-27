import Foundation

enum AnthropicCompanionClient {
    /// Cheapest capable model — keep prompts tiny; only call on user tap.
    private static let model = "claude-haiku-4-5-20251001"
    private static let maxTokens = 280

    static func enhanceDirect(person: BirthdayPerson, local: CompanionPlan) async throws -> CompanionAIResult {
        guard let apiKey = AISecrets.anthropicAPIKey, !apiKey.isEmpty else {
            throw CompanionAIError.missingAPIKey
        }
        return try await request(
            url: URL(string: "https://api.anthropic.com/v1/messages")!,
            headers: [
                "x-api-key": apiKey,
                "anthropic-version": "2023-06-01",
                "content-type": "application/json"
            ],
            person: person,
            local: local,
            source: .anthropic
        )
    }

    static func enhanceViaBackend(baseURL: String, person: BirthdayPerson, local: CompanionPlan) async throws -> CompanionAIResult {
        let trimmed = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: trimmed + "/v1/companion") else {
            throw CompanionAIError.network("Backend URL looks invalid.")
        }
        return try await request(
            url: url,
            headers: ["content-type": "application/json"],
            person: person,
            local: local,
            source: .anthropic,
            backendStyle: true
        )
    }

    private static func request(
        url: URL,
        headers: [String: String],
        person: BirthdayPerson,
        local: CompanionPlan,
        source: CompanionPlan.Source,
        backendStyle: Bool = false
    ) async throws -> CompanionAIResult {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }

        let userPrompt = """
        Birthday companion. Reply ONLY compact JSON keys:
        action (call|message|giftAndMessage), primaryTitle, reason, whenLabel, wantsGift (bool), draft (string), gifts (array of 2 short gift strings).
        Person: \(person.displayName). Relationship: \(person.relationship.isEmpty ? "unknown" : person.relationship). Notes: \(person.notes.isEmpty ? "none" : String(person.notes.prefix(160))). Days until: \(person.daysUntil). Has phone: \(person.hasPhoneNumber). Local hint action: \(local.action.rawValue).
        Keep draft under 220 chars. No preamble.
        """

        let body: [String: Any]
        if backendStyle {
            body = [
                "personName": person.displayName,
                "relationship": person.relationship,
                "notes": String(person.notes.prefix(160)),
                "daysUntil": person.daysUntil,
                "hasPhone": person.hasPhoneNumber,
                "localAction": local.action.rawValue
            ]
        } else {
            body = [
                "model": model,
                "max_tokens": maxTokens,
                "messages": [
                    ["role": "user", "content": userPrompt]
                ]
            ]
        }

        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw CompanionAIError.network("No response.")
        }
        guard (200...299).contains(http.statusCode) else {
            let snippet = String(data: data, encoding: .utf8) ?? ""
            throw CompanionAIError.network("Companion request failed (\(http.statusCode)). \(snippet.prefix(160))")
        }

        if backendStyle {
            return try JSONDecoder().decode(CompanionAIResult.self, from: data)
        }

        let text = try extractAnthropicText(from: data)
        return try parseModelJSON(text, fallback: local, source: source)
    }

    private static func extractAnthropicText(from data: Data) throws -> String {
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let content = obj?["content"] as? [[String: Any]]
        let text = content?.first?["text"] as? String
        guard let text, !text.isEmpty else {
            throw CompanionAIError.network("Companion returned an empty reply.")
        }
        return text
    }

    static func parseModelJSON(_ text: String, fallback: CompanionPlan, source: CompanionPlan.Source) throws -> CompanionAIResult {
        let cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return CompanionAIResult.from(plan: fallback, draft: nil, gifts: [])
        }

        let actionRaw = json["action"] as? String ?? fallback.action.rawValue
        let action = CompanionPlan.Action(rawValue: actionRaw) ?? fallback.action
        let plan = CompanionPlan(
            action: action,
            primaryTitle: json["primaryTitle"] as? String ?? fallback.primaryTitle,
            reason: json["reason"] as? String ?? fallback.reason,
            whenLabel: json["whenLabel"] as? String ?? fallback.whenLabel,
            wantsGift: (json["wantsGift"] as? Bool) ?? fallback.wantsGift,
            source: source
        )
        let gifts = (json["gifts"] as? [String]) ?? []
        let draft = json["draft"] as? String
        return CompanionAIResult.from(plan: plan, draft: draft, gifts: Array(gifts.prefix(3)))
    }
}
