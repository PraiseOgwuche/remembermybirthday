import Foundation

/// Sends transactional email via the companion backend (Resend). No-op without backend URL + email.
enum EmailNotifier {
    enum Event: String {
        case welcome
        case signIn
        case reminder
    }

    static func sendAccountEvent(_ event: Event, name: String?) {
        guard AppSettingsStore.emailAccountEvents else { return }
        let email = AppSettingsStore.notificationEmail
        guard isValidEmail(email) else { return }
        let backend = CompanionConfig.resolvedBackendURL
        guard !backend.isEmpty else { return }

        Task.detached(priority: .utility) {
            try? await post(
                path: "/v1/email/\(event.rawValue)",
                body: [
                    "email": email,
                    "name": name ?? "there"
                ],
                baseURL: backend
            )
        }
    }

    /// Call sparingly (e.g. when a local reminder fires) — not on every list refresh.
    static func sendBirthdayReminder(personName: String, daysUntil: Int, note: String?) {
        guard AppSettingsStore.emailBirthdayReminders else { return }
        let email = AppSettingsStore.notificationEmail
        guard isValidEmail(email) else { return }
        let backend = CompanionConfig.resolvedBackendURL
        guard !backend.isEmpty else { return }

        let dedupeKey = "email.reminder.\(personName.lowercased()).\(daysUntil).\(Calendar.current.component(.year, from: Date()))"
        if UserDefaults.standard.bool(forKey: dedupeKey) { return }
        UserDefaults.standard.set(true, forKey: dedupeKey)

        Task.detached(priority: .utility) {
            var body: [String: Any] = [
                "email": email,
                "personName": personName,
                "daysUntil": daysUntil
            ]
            if let note, !note.isEmpty { body["note"] = note }
            try? await post(path: "/v1/email/reminder", body: body, baseURL: backend)
        }
    }

    private static func post(path: String, body: [String: Any], baseURL: String) async throws {
        let trimmed = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: trimmed + path) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200...299).contains(http.statusCode) else {
            let snippet = String(data: data, encoding: .utf8) ?? ""
            throw NSError(
                domain: "EmailNotifier",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Email failed (\(http.statusCode)). \(snippet.prefix(120))"]
            )
        }
    }

    /// Returns an error message on failure; nil on success.
    @discardableResult
    static func sendTestEmail() async -> String? {
        let email = AppSettingsStore.notificationEmail
        guard isValidEmail(email) else { return "Add your email above first." }
        let backend = CompanionConfig.resolvedBackendURL
        guard !backend.isEmpty else { return "Set a Backend URL (or ship a production URL in CompanionConfig)." }
        do {
            try await post(
                path: "/v1/email/reminder",
                body: [
                    "email": email,
                    "personName": "Test",
                    "daysUntil": 3,
                    "note": "This is a test from Remember My Birthday."
                ],
                baseURL: backend
            )
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private static func isValidEmail(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("@"), trimmed.contains("."), trimmed.count >= 5 else { return false }
        return true
    }
}
