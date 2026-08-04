import Foundation

enum BirthdayNameNormalizer {
    /// Cleans calendar-style titles: "Ani Singh’s 29th" → "Ani Singh"
    static func cleanDisplayName(_ raw: String) -> String {
        var name = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        let patterns = [
            #"(?i)['’]s\s+\d{1,3}(st|nd|rd|th)\s*$"#,
            #"(?i)['’]s\s+birthday\s*$"#,
            #"(?i)\s+birthday\s*$"#,
            #"(?i)\s+bday\s*$"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(name.startIndex..<name.endIndex, in: name)
                name = regex.stringByReplacingMatches(in: name, range: range, withTemplate: "")
            }
        }

        return name
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Stable key for deduping Contacts + Calendar duplicates.
    static func matchKey(name: String, month: Int, day: Int) -> String {
        let cleaned = cleanDisplayName(name)
        // Ignore parenthetical nicknames/locations for matching: "Jide (houston)" ≈ "Jide"
        let withoutParens = cleaned.replacingOccurrences(
            of: #"\([^)]*\)"#,
            with: " ",
            options: .regularExpression
        )
        let folded = withoutParens
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9\s]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return "\(folded)|\(month)|\(day)"
    }

    static func initials(from name: String) -> String {
        let cleaned = cleanDisplayName(name)
        let withoutParens = cleaned.replacingOccurrences(
            of: #"\([^)]*\)"#,
            with: " ",
            options: .regularExpression
        )
        let tokens = withoutParens.split(whereSeparator: \.isWhitespace).map(String.init)

        var letters: [Character] = []
        for token in tokens {
            guard let letter = token.first(where: \.isLetter) else { continue }
            letters.append(letter)
            if letters.count == 2 { break }
        }

        if letters.isEmpty, let letter = cleaned.first(where: \.isLetter) {
            letters = [letter]
        }

        return String(letters).uppercased()
    }

    /// "Somto Muo" → "Somto"; strips parentheticals first.
    static func firstName(from name: String) -> String {
        let cleaned = cleanDisplayName(name)
        let withoutParens = cleaned.replacingOccurrences(
            of: #"\([^)]*\)"#,
            with: " ",
            options: .regularExpression
        )
        .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let first = withoutParens.split(whereSeparator: \.isWhitespace).first else {
            return "friend"
        }
        let token = String(first).trimmingCharacters(in: CharacterSet(charactersIn: ",."))
        return token.isEmpty ? "friend" : token
    }

    /// Name-only key for matching Contacts phones to calendar-imported people.
    static func nameMatchKey(_ name: String) -> String {
        let cleaned = cleanDisplayName(name)
        let withoutParens = cleaned.replacingOccurrences(
            of: #"\([^)]*\)"#,
            with: " ",
            options: .regularExpression
        )
        return withoutParens
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9\s]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
