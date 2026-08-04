import Foundation

struct SpokenBirthdayParse {
    var name: String?
    var month: Int?
    var day: Int?
    var year: Int?
    var rawTranscript: String
}

enum BirthdaySpeechParser {
    static func parse(_ transcript: String) -> SpokenBirthdayParse {
        let cleaned = transcript
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var result = SpokenBirthdayParse(rawTranscript: cleaned)

        // Date via NSDataDetector (handles "March 14", "3/14", "August 20th", etc.)
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
            let range = NSRange(cleaned.startIndex..<cleaned.endIndex, in: cleaned)
            if let match = detector.firstMatch(in: cleaned, options: [], range: range),
               let date = match.date {
                let comps = Calendar.current.dateComponents([.month, .day, .year], from: date)
                result.month = comps.month
                result.day = comps.day
                // Only keep year if the utterance likely included one (avoid random current year).
                if cleaned.range(of: #"\b(19|20)\d{2}\b"#, options: .regularExpression) != nil {
                    result.year = comps.year
                }
            }
        }

        result.name = extractName(from: cleaned)
        return result
    }

    private static func extractName(from text: String) -> String? {
        var working = text

        // Strip common lead-ins.
        let leadIns = [
            #"(?i)^(add|remember|save|it's|its|for)\s+"#,
            #"(?i)^(?:my\s+)?(?:friend|sister|brother|mom|dad|colleague|coworker)\s+"#
        ]
        for pattern in leadIns {
            working = working.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }

        // Cut off at birthday/date phrasing.
        let cutPatterns = [
            #"(?i)\s+('s|’s)?\s*birthday\b.*"#,
            #"(?i)\s+born\b.*"#,
            #"(?i)\s+on\b.*"#,
            #"(?i)\s+is\b.*"#,
            #"(?i)\s+was\b.*"#,
            #"(?i)\s+the\s+\d.*"#,
            #"(?i)\s+(january|february|march|april|may|june|july|august|september|october|november|december)\b.*"#,
            #"(?i)\s+\d{1,2}[\/\-]\d{1,2}.*"#
        ]
        for pattern in cutPatterns {
            working = working.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }

        working = working.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        guard !working.isEmpty else { return nil }

        // Keep at most three name tokens.
        let tokens = working.split(whereSeparator: \.isWhitespace).prefix(3).map(String.init)
        let name = tokens.joined(separator: " ")
        // Avoid treating pure numbers as names.
        if name.range(of: #"^[0-9\s]+$"#, options: .regularExpression) != nil { return nil }
        return name
    }
}
