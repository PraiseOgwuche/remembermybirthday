import Foundation

struct GiftIdea: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
}

/// On-device gift suggestions.
enum GiftIdeasProvider {
    static func ideas(for person: BirthdayPerson, limit: Int = 5) -> [GiftIdea] {
        var pool: [GiftIdea] = []
        let rel = person.relationship.lowercased()
        let notes = person.notes.lowercased()
        let name = person.firstName

        if rel.contains("partner") || rel.contains("spouse") || rel.contains("wife")
            || rel.contains("husband") || rel.contains("girlfriend") || rel.contains("boyfriend") {
            pool += [
                GiftIdea(id: "date", title: "Plan a date night", detail: "Reservation or a homemade dinner — make it about time together."),
                GiftIdea(id: "photo", title: "Print a favorite photo", detail: "A framed moment lands better than another gadget."),
                GiftIdea(id: "handwritten", title: "Handwritten note", detail: "Say the thing you usually only think.")
            ]
        } else if rel.contains("mom") || rel.contains("dad") || rel.contains("parent")
            || rel.contains("mother") || rel.contains("father") {
            pool += [
                GiftIdea(id: "visit", title: "Visit or FaceTime", detail: "Presence beats presents for parents more often than we admit."),
                GiftIdea(id: "plant", title: "A plant they’ll actually keep", detail: "Something low-maintenance with a card from you."),
                GiftIdea(id: "memory", title: "A memory book page", detail: "One printed page of photos + a short story.")
            ]
        } else if rel.contains("kid") || rel.contains("child") || rel.contains("son") || rel.contains("daughter") {
            pool += [
                GiftIdea(id: "experience", title: "An experience", detail: "Museum, zoo, or a day out they’ll talk about."),
                GiftIdea(id: "book", title: "A book + reading time", detail: "Gift the book and the evening to read it together."),
                GiftIdea(id: "craft", title: "Something you make", detail: "Handmade beats store-bought for little ones.")
            ]
        } else if rel.contains("coworker") || rel.contains("colleague") || rel.contains("boss") {
            pool += [
                GiftIdea(id: "coffee", title: "Coffee or tea run", detail: "Small, thoughtful, desk-friendly."),
                GiftIdea(id: "card", title: "A sincere card", detail: "At work, words often mean more than stuff."),
                GiftIdea(id: "snack", title: "Their favorite snack", detail: "If you know it — that’s the whole gift.")
            ]
        }

        if notes.contains("coffee") || notes.contains("tea") {
            pool.append(GiftIdea(id: "notes-drink", title: "Specialty coffee or tea", detail: "You already noted they love it — lean into that."))
        }
        if notes.contains("book") || notes.contains("read") {
            pool.append(GiftIdea(id: "notes-book", title: "A book in their lane", detail: "Match a title to something in your notes."))
        }
        if notes.contains("plant") || notes.contains("garden") {
            pool.append(GiftIdea(id: "notes-plant", title: "A plant or seeds", detail: "Green gifts last longer than flowers."))
        }
        if notes.contains("travel") || notes.contains("trip") {
            pool.append(GiftIdea(id: "notes-travel", title: "Travel-sized treat", detail: "Nice toiletries, a packing cube, or a journal."))
        }
        if notes.contains("wine") || notes.contains("whiskey") || notes.contains("beer") {
            pool.append(GiftIdea(id: "notes-drink2", title: "A bottle they’ll remember", detail: "Pair with a short note about why you picked it."))
        }

        // Universal fallbacks
        pool += [
            GiftIdea(id: "message", title: "A great birthday message", detail: "Open Draft message — often that’s the gift."),
            GiftIdea(id: "donate", title: "Donate in their name", detail: "If they care about a cause, give there."),
            GiftIdea(id: "playlist", title: "A playlist for \(name)", detail: "Songs that are “them” — share the link."),
            GiftIdea(id: "time", title: "Protected time together", detail: "Block an hour with no phones. Put it on the calendar."),
            GiftIdea(id: "favorite", title: "Their usual, upgraded", detail: "The coffee / snack / flower they always get — nicer version.")
        ]

        // Stable shuffle by person id so ideas feel personal but don’t reshuffle every glance.
        var generator = SeededGenerator(seed: person.id.hashValue)
        let shuffled = pool.shuffled(using: &generator)

        var seen = Set<String>()
        var result: [GiftIdea] = []
        for idea in shuffled {
            guard seen.insert(idea.id).inserted else { continue }
            result.append(idea)
            if result.count >= limit { break }
        }
        return result
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed))
        if state == 0 { state = 0xA511_E9B3_C7D2_F014 }
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
