import Foundation

struct CompanionAIResult: Codable, Sendable, Equatable {
    var action: String
    var primaryTitle: String
    var reason: String
    var whenLabel: String
    var wantsGift: Bool
    var source: String
    var draftSuggestion: String?
    var giftTitles: [String]

    var plan: CompanionPlan {
        CompanionPlan(
            action: CompanionPlan.Action(rawValue: action) ?? .message,
            primaryTitle: primaryTitle,
            reason: reason,
            whenLabel: whenLabel,
            wantsGift: wantsGift,
            source: CompanionPlan.Source(rawValue: source) ?? .local
        )
    }

    static func from(plan: CompanionPlan, draft: String?, gifts: [String]) -> CompanionAIResult {
        CompanionAIResult(
            action: plan.action.rawValue,
            primaryTitle: plan.primaryTitle,
            reason: plan.reason,
            whenLabel: plan.whenLabel,
            wantsGift: plan.wantsGift,
            source: plan.source.rawValue,
            draftSuggestion: draft,
            giftTitles: gifts
        )
    }
}

enum CompanionAIError: LocalizedError {
    case disabled
    case missingAPIKey
    case unavailable
    case network(String)

    var errorDescription: String? {
        switch self {
        case .disabled: return "Companion tips are turned off in Settings."
        case .missingAPIKey: return "Companion server isn’t set up yet (DEBUG only)."
        case .unavailable: return "On-device companion isn’t available on this device right now."
        case .network(let message): return message
        }
    }
}

enum CompanionAIService {
    static func localPlan(for person: BirthdayPerson) -> CompanionPlan {
        CompanionEngine.plan(for: person)
    }

    /// Explicit user action only — never auto-fire on every screen open.
    static func enhance(for person: BirthdayPerson, local: CompanionPlan) async throws -> CompanionAIResult {
        guard AppSettingsStore.aiEnabled else { throw CompanionAIError.disabled }
        let provider = AppSettingsStore.aiProvider
        guard provider != .off else { throw CompanionAIError.disabled }

        if let cached = CompanionAICache.load(personId: person.id) {
            return cached
        }

        let result: CompanionAIResult
        switch provider {
        case .apple:
            result = try await enhanceWithApple(person: person, local: local)
        case .anthropic:
            result = try await enhanceWithAnthropic(person: person, local: local)
        case .auto:
            if let apple = try? await enhanceWithApple(person: person, local: local) {
                result = apple
            } else {
                result = try await enhanceWithAnthropic(person: person, local: local)
            }
        case .off:
            throw CompanionAIError.disabled
        }

        CompanionAICache.save(result, personId: person.id)
        return result
    }

    private static func enhanceWithApple(person: BirthdayPerson, local: CompanionPlan) async throws -> CompanionAIResult {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return try await AppleCompanionAI.enhance(person: person, local: local)
        }
        #endif
        throw CompanionAIError.unavailable
    }

    private static func enhanceWithAnthropic(person: BirthdayPerson, local: CompanionPlan) async throws -> CompanionAIResult {
        let backend = CompanionConfig.resolvedBackendURL
        if !backend.isEmpty {
            return try await AnthropicCompanionClient.enhanceViaBackend(baseURL: backend, person: person, local: local)
        }
        #if DEBUG
        guard AISecrets.hasAnthropicKey else { throw CompanionAIError.missingAPIKey }
        return try await AnthropicCompanionClient.enhanceDirect(person: person, local: local)
        #else
        throw CompanionAIError.network("Companion server isn’t configured yet. Local tips still work.")
        #endif
    }
}

enum CompanionAICache {
    private static func key(_ id: UUID) -> String { "companion.ai.cache.\(id.uuidString)" }

    static func load(personId: UUID) -> CompanionAIResult? {
        guard let data = UserDefaults.standard.data(forKey: key(personId)),
              let decoded = try? JSONDecoder().decode(Wrapper.self, from: data),
              decoded.savedAt.timeIntervalSinceNow > -60 * 60 * 24 * 14 else { return nil }
        return decoded.result
    }

    static func save(_ result: CompanionAIResult, personId: UUID) {
        let wrapper = Wrapper(savedAt: Date(), result: result)
        if let data = try? JSONEncoder().encode(wrapper) {
            UserDefaults.standard.set(data, forKey: key(personId))
        }
    }

    static func clear(personId: UUID) {
        UserDefaults.standard.removeObject(forKey: key(personId))
    }

    private struct Wrapper: Codable {
        var savedAt: Date
        var result: CompanionAIResult
    }
}
