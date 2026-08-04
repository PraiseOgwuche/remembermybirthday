import SwiftUI
import SwiftData

struct WatchRootView: View {
    @Query private var people: [BirthdayPerson]

    private var sortedPeople: [BirthdayPerson] {
        people.sorted { $0.daysUntil < $1.daysUntil }
    }

    private var upcoming: [BirthdayPerson] {
        Array(sortedPeople.prefix(8))
    }

    var body: some View {
        NavigationStack {
            Group {
                if sortedPeople.isEmpty {
                    ContentUnavailableView(
                        "No Birthdays",
                        systemImage: "gift",
                        description: Text("Add people on iPhone — they’ll show up here.")
                    )
                } else {
                    List {
                        if let next = upcoming.first {
                            Section {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(next.displayName)
                                        .font(.headline)
                                    Text(watchHeadline(for: next))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 2)
                            } header: {
                                Text("Next up")
                            }
                        }

                        Section("Coming up") {
                            ForEach(upcoming) { person in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(person.displayName)
                                            .font(.body.weight(.medium))
                                        Text(person.shortDate)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 4)
                                    Text(person.countdownLabel)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(person.daysUntil <= 7 ? Color.accentColor : Color.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Remember My Birthday")
        }
    }

    private func watchHeadline(for person: BirthdayPerson) -> String {
        switch person.daysUntil {
        case 0: return "Birthday is today"
        case 1: return "Birthday is tomorrow"
        default: return "In \(person.daysUntil) days · \(person.shortDate)"
        }
    }
}
