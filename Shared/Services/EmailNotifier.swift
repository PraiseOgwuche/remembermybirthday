import Foundation

/// Sends transactional email via the companion backend (SendGrid). No-op without backend URL + email.
enum EmailNotifier {
    enum Event: String, CaseIterable {
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
                path: path(for: event),
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

        let dedupeKey = reminderDedupeKey(personName: personName, daysUntil: daysUntil)
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

    /// Returns an error message on failure; nil on success.
    @discardableResult
    static func sendTest(event: Event, name: String? = nil) async -> String? {
        let email = AppSettingsStore.notificationEmail
        guard isValidEmail(email) else {
            return "Add your email above first."
        }
        let backend = CompanionConfig.resolvedBackendURL
        guard !backend.isEmpty else {
            return "Add Backend URL below (e.g. https://remember-companion.onrender.com)."
        }

        var body: [String: Any] = ["email": email]
        switch event {
        case .welcome, .signIn:
            body["name"] = name ?? "Friend"
        case .reminder:
            // Bypass yearly dedupe for manual tests.
            UserDefaults.standard.removeObject(forKey: reminderDedupeKey(personName: "Test", daysUntil: 3))
            body["personName"] = "Test"
            body["daysUntil"] = 3
            body["note"] = "Manual test from Remember My Birthday Settings."
        }

        do {
            try await post(path: path(for: event), body: body, baseURL: backend)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// Back-compat for Settings single button.
    @discardableResult
    static func sendTestEmail() async -> String? {
        await sendTest(event: .reminder)
    }

    private static func path(for event: Event) -> String {
        switch event {
        case .welcome: return "/v1/email/welcome"
        case .signIn: return "/v1/email/signIn"
        case .reminder: return "/v1/email/reminder"
        }
    }

    private static func reminderDedupeKey(personName: String, daysUntil: Int) -> String {
        let year = Calendar.current.component(.year, from: Date())
        return "email.reminder.\(personName.lowercased()).\(daysUntil).\(year)"
    }

    private static func post(path: String, body: [String: Any], baseURL: String) async throws {
        let trimmed = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: trimmed + path) else {
            throw NSError(domain: "EmailNotifier", code: 1, userInfo: [NSLocalizedDescriptionKey: "Backend URL looks invalid."])
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.timeoutInterval = 45
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
                userInfo: [NSLocalizedDescriptionKey: "Email failed (\(http.statusCode)). \(snippet.prefix(160))"]
            )
        }
    }

    private static func isValidEmail(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("@"), trimmed.contains("."), trimmed.count >= 5 else { return false }
        return true
    }
}
